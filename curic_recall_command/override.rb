# frozen_string_literal: true

module CURIC
  module Recall
    class << self
      attr_accessor :disable, :trace_manager
    end
    @disable = false

    module_function

    def history
      @ui_data[:history]
    end

    def push(command)
      @ui_data[:history] ||= []

      if @ui_data[:history].include?(command)
        @ui_data[:history].delete(command)
      end

      @ui_data[:history] << command

      if @ui_data[:history].length > 25
        @ui_data[:history] = @ui_data[:history][-25..-1]
      end

      unless command.is_a?(Hash) && command[:type] == 'NativeTool'
        PLUGIN.observer.last_tool_name = 'RubyTool'
      end

      PLUGIN.refresh_ui
    end

    def commands
      @ui_data[:commands].keys
    end

    def command_data(command)
      @ui_data[:commands][command]
    end

    def on_ui_new_command(command, block)
      @ui_data[:commands][command] ||= {}
      @ui_data[:commands][command][:proc] = block
    end

    # Fast path called by CommandTraceManager TracePoint callbacks.
    # The command object is already resolved, so we skip the O(n) proc search
    # used by push.
    def command_executed(command)
      return if @disable
      return if command == PLUGIN.command

      push(command)
    end

  end
end
