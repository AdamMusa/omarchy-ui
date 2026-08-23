# frozen_string_literal: true

begin
  require "zui"
rescue LoadError
  development_zui = ENV["ZUI_SOURCE_DIR"] || File.expand_path("../../zui", __dir__)
  raise unless File.file?(File.join(development_zui, "lib", "zui.rb"))

  $LOAD_PATH.unshift(File.join(development_zui, "lib"))
  require "zui"
end

module OmarchyUI
  VERSION = "0.1.0"
  ZUI_VERSION = Zui::VERSION
  FRAMEWORK_ROOT = File.expand_path("..", __dir__)

  CORE_CONSTANTS = %i[
    PROTOCOL_VERSION MAX_MESSAGE_BYTES VALID_ID VALID_EVENT LOWER UPPER DIGITS
    ProtocolError AsciiPattern Value StateStore Node Animation Scheduler Task Binding StructuralBinding
    Command CommandResult CommandTimeout CommandOutputLimit Component ComponentRegistry COMPONENTS
    ICON_NAMES DEFAULT_COMPONENTS Builder Application
  ].freeze
  CORE_CONSTANTS.each { |name| const_set(name, Zui.const_get(name)) }

  class SourceBundle < Zui::SourceBundle
    def initialize(entrypoint, root: File.dirname(entrypoint))
      super(entrypoint, root:, embedded_frameworks: %w[zui omarchy_ui])
    end
  end

  def self.plugin(&definition)
    Application.new(&definition).run
  end

  class << self
    alias application plugin
    alias app plugin
  end
end

require_relative "omarchy_ui/generator"
require_relative "omarchy_ui/runtime"
