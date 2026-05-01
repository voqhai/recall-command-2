require 'sketchup.rb'

module CURIC
  class << self
    attr_accessor :tools_command
  end

  module Recall
    Sketchup.require("#{PATH}/observer")
    Sketchup.require("#{PATH}/override")

    class << self
      attr_accessor :command
      attr_reader :observer, :ui_data
    end

    IS_WIN = Sketchup.platform == :platform_win
    IS_OSX = Sketchup.platform == :platform_osx

    LIST_TOOL_ACTION = {
      'CameraOrbitTool' => {
        action: 'selectOrbitTool:',
        true_name: 'Orbit'
      },
      'PositionCameraTool' => {
        action: 'selectPositionCameraTool:',
        true_name: 'Position Camera'
      },
      'CameraDollyTool' => {
        action: 'selectDollyTool:',
        true_name: 'Pan'
      },
      'CameraPanTool' => {
        action: 'selectTurnTool:',
        true_name: 'Look Around'
      },
      'CameraWalkTool' => {
        action: 'selectWalkTool:',
        true_name: 'Walk'
      },
      'CameraZoomTool' => {
        action: 'selectZoomTool:',
        true_name: 'Zoom'
      },
      'CameraFOVTool' => {
        action: 'selectFieldOfViewTool:',
        true_name: 'FOV Tool'
      },
      'CameraZoomWindowTool' => {
        action: 'selectZoomWindowTool:',
        true_name: 'Zoom Window'
      },
      'ArcTool' => {
        action: 'selectArcTool:',
        true_name: '2 Point Arc'
      },
      'Arc3PointTool' => {
        action: 'selectArc3PointTool:',
        true_name: 'Arc Tool'
      },
      'Arc3PointPieTool' => {
        action: 'selectArc3PointPieTool:',
        true_name: 'Pie Tool'
      },
      'SketchCSTool' => {
        action: 'selectAxisTool:',
        true_name: 'Axis Tool'
      },
      'ComponentCSTool' => {
        action: 'selectAxisTool:',
        true_name: 'Axis Tool'
      },
      'CircleTool' => {
        action: 'selectCircleTool:',
        true_name: 'Circle Tool'
      },
      'EraseTool' => {
        action: 'selectEraseTool:',
        true_name: 'Erase'
      },
      'FreehandTool' => {
        action: 'selectFreehandTool:',
        true_name: 'Freehand Tool'
      },
      'SketchTool' => {
        action: 'selectLineTool:',
        true_name: 'Line Tool'
      },
      'MeasureTool' => {
        action: 'selectMeasureTool:',
        true_name: 'Measure Tool'
      },
      'MoveTool' => {
        action: 'selectMoveTool:',
        true_name: 'Move'
      },
      'OffsetTool' => {
        action: 'selectOffsetTool:',
        true_name: 'Offset'
      },
      'PaintTool' => {
        action: 'selectPaintTool:',
        true_name: 'Paint Bucket'
      },
      'PolyTool' => {
        action: 'selectPolygonTool:',
        true_name: 'Polygon Tool'
      },
      'ProtractorTool' => {
        action: 'selectProtractorTool:',
        true_name: 'Protractor'
      },
      'PushPullTool' => {
        action: 'selectPushPullTool:',
        true_name: 'Push Pull'
      },
      'RectangleTool' => {
        action: 'selectRectangleTool:',
        true_name: 'Rectangle'
      },
      'Rectangle3PointTool' => {
        action: 'selectRectangle3PointTool:',
        true_name: 'Rotated Rectangle'
      },
      'RotateTool' => {
        action: 'selectRotateTool:',
        true_name: 'Rotate'
      },
      'ScaleTool' => {
        action: 'selectScaleTool:',
        true_name: 'Scale'
      },
      'tool_namSectionPlaneToole' => {
        action: 'selectSectionPlaneTool:',
        true_name: 'Section Plane'
      },
      'TextTool' => {
        action: 'selectTextTool:',
        true_name: 'Text Tool'
      },
      'DimensionTool' => {
        action: 'selectDimensionTool:',
        true_name: 'Dimension'
      },
      'ExtrudeTool' => {
        action: 'selectExtrudeTool:',
        true_name: 'Follow Me'
      },
      'SelectionTool' => {
        action: 'selectSelectionTool:',
        true_name: 'Selection'
      },
    }.freeze

    file = __FILE__.dup.force_encoding('UTF-8')
    unless file_loaded? file
      @ui_data ||= {}
      @ui_data[:commands] = {}
      @ui_data[:history] = []

      # Attach Observer
      @observer = RecallOb.new

      @trace_manager = CommandTraceManager.new(self)
      @trace_manager.start

      CURIC.tools_command ||= UI.menu('Tools').add_submenu('Curic')
      menu_tool = CURIC.tools_command.add_submenu(PLUGIN_ID)

      @command = UI::Command.new("Call Last") { CURIC::Recall.invoke }
      @command.tooltip = "Recall last command"

      menu_tool.add_item(@command)

      file_loaded file
    end
  end
end
