module CURIC::Recall

  class << self
    attr_accessor :time_call
  end

  def self.invoke
    if Sketchup.active_model.tools.active_tool_name != 'SelectionTool'
      Sketchup.send_action("selectSelectionTool:")
    elsif @time_call && Time.now - @time_call < 0.3
      last_command = PLUGIN.ui_data[:history][-1]

      if @observer.last_tool_name != 'RubyTool'
        call_native_tool(@observer.last_tool_name)
      elsif last_command
        data = command_data(last_command)
        block = data && data[:proc]
        block.call if block
      end
    end

    @time_call = Time.now
  end

  def self.clear!
    @ui_data[:history] = []
  end

  def self.call_native_tool(tool_name)
    action = LIST_TOOL_ACTION[tool_name]&.fetch(:action, nil)

    if action
      Sketchup.send_action(action)
    else
      Sketchup.send_action("selectSelectionTool:")
    end
  end

  def self.last_command_name
    last_command = PLUGIN.ui_data[:history][-1]
    if last_command.is_a?(UI::Command)
      last_command.menu_text
    else
      if LIST_TOOL_ACTION[PLUGIN.observer.last_tool_name]
        LIST_TOOL_ACTION[PLUGIN.observer.last_tool_name][:true_name]
      else
        PLUGIN.observer.last_tool_name
      end
    end
  rescue => exception
    ''
  end

  def self.refresh_ui
    return unless @observer.current_tool_name == 'SelectionTool'

    label = "#{IS_OSX ? '⌘' : '>'} Last command "
    value = CURIC::Recall.last_command_name

    Sketchup.set_status_text(label, SB_VCB_LABEL)
    Sketchup.set_status_text(value, SB_VCB_VALUE)
  end

  class RecallOb
    attr_accessor :last_tool_name, :current_tool_name
    def initialize
      @current_tool_name = ''
      @last_tool_name = ''
      Sketchup.add_observer(RecallOb_App.new(self))
    end

    # App
    class RecallOb_App < Sketchup::AppObserver
      def initialize(observers)
        @observer = observers

        begin
          attach_observers(Sketchup.active_model)
        rescue StandardError
        end
      end

      def onNewModel(model)
        attach_observers(model)
      end

      def onOpenModel(model)
        attach_observers(model)
      end

      def attach_observers(model)
        model.tools.add_observer(RecallOb_Tools.new(@observer))
      end
    end

    # Tools
    class RecallOb_Tools < Sketchup::ToolsObserver
      def initialize(observers)
        @observer = observers
      end

      def onActiveToolChanged(_tools, tool_name, tool_id)
        tool_name = fix_mac_tool_name(tool_name)
        tool_changed(tool_name, tool_id)
      end

      def fix_mac_tool_name(tool_name)
        if tool_name == 'eTool'
          tool_name = 'ScaleTool'
        elsif tool_name == 'ool'
          tool_name = 'MoveTool'
        elsif tool_name == 'onentCSTool'
          tool_name = 'ComponentCSTool'
        elsif tool_name == 'PullTool'
          tool_name = 'PushPullTool'
        end
        tool_name
      end

      def skip_native_tool?(tool_name)
        return true if tool_name.include?('Boolean')

        [
          'CameraDollyTool',
          'CameraOrbitTool',
          'SelectionTool',
          'OuterShellTool',
          'Fit3PointArcTool',
          '3DTextTool'
        ].include?(tool_name)
      end

      def tool_changed(tool_name, tool_id)
        @observer.current_tool_name = tool_name
        if tool_name == 'SelectionTool'
          CURIC::Recall.refresh_ui
        end

        if tool_name == 'RubyTool'
          # Skip PieMenu tool activations — not a user command
          action_tool = Sketchup.active_model.tools.active_tool
          return if piemenu_tool?(action_tool)
        else
          return if skip_native_tool?(tool_name)

          command = {
            type: 'NativeTool',
            tool_name: tool_name,
            tool_id: tool_id
          }
          PLUGIN.push(command)
        end

        @observer.last_tool_name = tool_name
      end

      def piemenu_tool?(tool)
        (
          Object.const_defined?('CURIC::PieMenu::PieMenuTool') &&
          tool.is_a?(CURIC::PieMenu::PieMenuTool)
        ) ||
          (
            Object.const_defined?('CURIC::PieMenu::CommandMemoryTool') &&
            tool.is_a?(CURIC::PieMenu::CommandMemoryTool)
          )
      rescue => exception
        false
      end
    end
  end

  class CommandTraceManager
    SCAN_INTERVAL_MIN    = 2.0
    SCAN_INTERVAL_MAX    = 30.0
    SCAN_INTERVAL_GROWTH = 2.0

    # TracePoint#enable(target:) was introduced in Ruby 2.6 (SketchUp 2021+ Ruby 2.7).
    # Probe once at class load time so we can fall back gracefully on older versions.
    TRACE_TARGET_SUPPORTED = begin
      probe = proc {}
      tp = TracePoint.new(:b_call) {}
      tp.enable(target: probe)
      tp.disable
      true
    rescue ArgumentError, TypeError, NotImplementedError
      puts 'Recall: TracePoint target: not supported on this Ruby version; command execution tracking disabled.'
      false
    end

    def initialize(plugin)
      @plugin = plugin
      @known_commands = {}  # command.object_id -> UI::Command
      @proc_commands   = {}  # proc.object_id    -> first UI::Command registered for that proc
      @tracepoints     = {}  # proc.object_id    -> TracePoint
      @timer_id        = nil
      @scan_interval   = SCAN_INTERVAL_MIN
    end

    def start
      # scan_commands also populates command metadata (on_ui_new_command) regardless
      # of whether TracePoint tracking is available, so always run the scanner.
      scan_commands
      start_scan_timer
    end

    def register_command(command)
      return unless command.is_a?(UI::Command)
      return if @known_commands.key?(command.object_id)

      @known_commands[command.object_id] = command
      block = command.proc
      return unless block

      @plugin.on_ui_new_command(command, block)

      return unless TRACE_TARGET_SUPPORTED

      pid = block.object_id

      if @proc_commands.key?(pid)
        # Another command shares this proc; the existing TracePoint covers it.
        return
      end

      @proc_commands[pid] = command

      tp = TracePoint.new(:b_call) do |_tp|
        @plugin.command_executed(command)
      end

      tp.enable(target: block)
      @tracepoints[pid] = tp
    rescue => exception
      puts "Recall TracePoint register error: #{exception.message}"
    end

    def stop
      @tracepoints.each_value(&:disable)
      @tracepoints.clear
      @known_commands.clear
      @proc_commands.clear
      UI.stop_timer(@timer_id) if @timer_id
      @timer_id = nil
    end

    private

    def start_scan_timer
      @timer_id = UI.start_timer(@scan_interval, false) { run_scan }
    end

    # Runs one scan pass then schedules the next with exponential back-off.
    # The interval doubles after each idle pass (no new commands found), up to
    # SCAN_INTERVAL_MAX, and resets to SCAN_INTERVAL_MIN whenever new commands
    # are discovered (e.g. a plugin loads late).
    def run_scan
      prev_count = @known_commands.size
      scan_commands
      if @known_commands.size > prev_count
        @scan_interval = SCAN_INTERVAL_MIN
      else
        @scan_interval = [@scan_interval * SCAN_INTERVAL_GROWTH, SCAN_INTERVAL_MAX].min
      end
    rescue => exception
      puts "Recall scan error: #{exception.message}"
    ensure
      start_scan_timer
    end

    def scan_commands
      ObjectSpace.each_object(UI::Command) { |command| register_command(command) }
    rescue => exception
      puts "Recall TracePoint scan error: #{exception.message}"
    end
  end
end
