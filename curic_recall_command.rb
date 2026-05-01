require 'sketchup.rb'
require 'extensions.rb'

module CURIC
  module Recall
    PLUGIN = self
    PLUGIN_NAMESPACE  = 'Curic'.freeze
    PLUGIN_ID         = 'Recall Command'.freeze
    PLUGIN_NAME       = "#{PLUGIN_NAMESPACE} #{PLUGIN_ID}".freeze
    PLUGIN_VERSION    = '2.0.0'.freeze

    FILENAMESPACE = File.basename(__FILE__.dup.force_encoding('UTF-8'), '.*')
    PATH_ROOT     = File.dirname(__FILE__.dup.force_encoding('UTF-8')).freeze
    PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze

    unless file_loaded?(__FILE__)
      if Sketchup.version.to_i < 21
        msg = "#{PLUGIN_NAME} requires SketchUp 2021 or later (Ruby 2.7+). Plugin will not be loaded."
        puts msg
        UI.messagebox(msg)
      else
        ex = SketchupExtension.new(PLUGIN_NAME, "#{PATH}/loader")
        ex.version     = PLUGIN_VERSION
        ex.copyright   = 'Curic © 2021–2026'
        ex.creator     = 'Vo Quoc Hai (voqhai@curic.io)'
        ex.description = 'Instantly re-invoke the last used SketchUp command with a single shortcut.'
        Sketchup.register_extension(ex, true)
      end
    end
  end
end
file_loaded(__FILE__)
