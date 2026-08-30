# frozen_string_literal: true

module OmarchyUI
  VERSION = "0.0.5"
  ZUI_VERSION = Zui::VERSION
  FRAMEWORK_ROOT = ""

  CORE_CONSTANTS = %i[
    PROTOCOL_VERSION MAX_MESSAGE_BYTES VALID_ID VALID_EVENT LOWER UPPER DIGITS
    ProtocolError AsciiPattern Value StateStore Node Animation Scheduler Task Binding StructuralBinding
    Command CommandResult CommandTimeout CommandOutputLimit Component ComponentRegistry COMPONENTS
    ICON_NAMES DEFAULT_COMPONENTS Builder Application
  ].freeze
  CORE_CONSTANTS.each { |name| const_set(name, Zui.const_get(name)) }

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
end

module Zui
  class Component
    def to_h = OmarchyUI.component_protocol_schema(self)
  end
end
