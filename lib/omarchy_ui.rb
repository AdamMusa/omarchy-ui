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
  VERSION = "0.0.10"
  ZUI_VERSION = Zui::VERSION
  FRAMEWORK_ROOT = File.expand_path("..", __dir__)

  CORE_CONSTANTS = %i[
    PROTOCOL_VERSION MAX_MESSAGE_BYTES VALID_ID VALID_EVENT LOWER UPPER DIGITS
    ProtocolError AsciiPattern Value StateStore Node Animation Scheduler Task Binding StructuralBinding
    Command CommandResult CommandTimeout CommandOutputLimit Component ComponentRegistry COMPONENTS
    ICON_NAMES DEFAULT_COMPONENTS Builder Application
  ].freeze
  CORE_CONSTANTS.each { |name| const_set(name, Zui.const_get(name)) }

  # Quickshell's line parser has a practical ceiling below Zui's protocol
  # maximum. Identity property/event mappings are implicit in the Omarchy
  # bridge, so omit those duplicates from the initial component catalog while
  # preserving every custom mapping and all validation metadata.
  def self.component_protocol_schema(component)
    property_map = {}
    component.property_map.each do |source, target|
      property_map[source.to_s] = target.to_s unless source.to_s == target.to_s
    end
    event_map = {}
    component.event_map.each do |source, target|
      event_map[source.to_s] = target.to_s unless source.to_s == target.to_s
    end
    schema = {
      "qml" => component.qml,
      "properties" => component.properties.map(&:to_s),
      "events" => component.events.map(&:to_s),
      "container" => component.container
    }
    schema["property_map"] = property_map unless property_map.empty?
    schema["event_map"] = event_map unless event_map.empty?
    schema["auto_bind"] = false unless component.auto_bind
    schema
  end

  def self.component_protocol_chunks(registry, chunk_size: 24)
    chunks = []
    chunk = {}
    registry.protocol_schema.each do |name, definition|
      chunk[name] = definition
      if chunk.length >= chunk_size
        chunks << chunk
        chunk = {}
      end
    end
    chunks << chunk unless chunk.empty?
    chunks
  end

  class SourceBundle < Zui::SourceBundle
    def initialize(entrypoint, root: File.dirname(entrypoint))
      super(entrypoint, root:, embedded_frameworks: %w[zui omarchy_ui])
    end
  end

  def self.run(application = nil, ui: nil, &definition)
    if application && (ui || definition)
      raise ArgumentError, "pass a Zui application or a definition, not both"
    end

    instance = if application.nil?
      Application.new(ui:, &definition)
    elsif application.is_a?(Application)
      application
    elsif application.respond_to?(:build)
      application.build
    else
      raise ArgumentError, "expected a Zui::Application or an application module responding to build"
    end

    unless instance.is_a?(Application)
      raise ArgumentError, "application module did not build a Zui::Application"
    end

    instance.run
  end

  def self.plugin(ui: nil, &definition)
    run(ui:, &definition)
  end

  class << self
    alias application plugin
    alias app plugin
  end
end

module Zui
  class Component
    def to_h = OmarchyUI.component_protocol_schema(self)
  end

  class Application
    def start(output: $stdout, error: $stderr)
      @output = output
      @error = error
      @output.sync = true if @output.respond_to?(:sync=)
      @error.sync = true if @error.respond_to?(:sync=)
      @running = true
      pid = Object.const_defined?(:Process) && Process.respond_to?(:pid) ? Process.pid : 0
      emit("v" => PROTOCOL_VERSION, "type" => "ready", "pid" => pid, "surfaces" => @surfaces.keys)
      OmarchyUI.component_protocol_chunks(@components).each_with_index do |components, index|
        emit("v" => PROTOCOL_VERSION, "type" => "component_catalog", "reset" => index.zero?,
             "components" => components)
      end
      emit("v" => PROTOCOL_VERSION, "type" => "render", "surfaces" => tree,
           "surface_options" => @surface_options)
      @scheduler.start
      self
    end
  end
end

require_relative "omarchy_ui/project_config"
require_relative "omarchy_ui/generator"
require_relative "omarchy_ui/qml_compiler"
require_relative "omarchy_ui/runtime"
require_relative "omarchy_ui/plugin_package"
require_relative "omarchy_ui/plugin_publisher"
