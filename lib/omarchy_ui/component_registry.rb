# frozen_string_literal: true

module OmarchyUI
  Component = Struct.new(:name, :qml, :properties, :events, :container, keyword_init: true) do
    def to_h
      {
        "qml" => qml,
        "properties" => properties.map(&:to_s),
        "events" => events.map(&:to_s),
        "container" => container
      }
    end
  end

  class ComponentRegistry
    QML_FILE = /\A[A-Z][A-Za-z0-9]*\.qml\z/
    NAME = /\A[a-z][a-z0-9_]{0,63}\z/

    def initialize
      @components = {}
    end

    def register(name, qml:, properties: [], events: [], container: false)
      key = name.to_sym
      raise ArgumentError, "component already registered: #{key}" if @components.key?(key)
      raise ArgumentError, "invalid component name: #{name.inspect}" unless NAME.match?(key.to_s)
      raise ArgumentError, "invalid component adapter: #{qml.inspect}" unless QML_FILE.match?(qml.to_s)
      property_names = properties.map(&:to_sym)
      event_names = events.map(&:to_sym)
      invalid_property = property_names.find { |property| !NAME.match?(property.to_s) }
      invalid_event = event_names.find { |event| !NAME.match?(event.to_s) }
      raise ArgumentError, "invalid property name: #{invalid_property.inspect}" if invalid_property
      raise ArgumentError, "invalid event name: #{invalid_event.inspect}" if invalid_event

      @components[key] = Component.new(
        name: key,
        qml: qml.to_s,
        properties: property_names.uniq.freeze,
        events: event_names.uniq.freeze,
        container: !!container
      )
    end

    def fetch(name)
      @components.fetch(name.to_sym) { raise ArgumentError, "unknown component: #{name}" }
    end

    def key?(name)
      @components.key?(name.to_sym)
    end

    def protocol_schema
      @components.transform_keys(&:to_s).transform_values(&:to_h)
    end

    def dup
      copy = self.class.new
      @components.each_value do |component|
        copy.register(component.name, qml: component.qml, properties: component.properties,
                       events: component.events, container: component.container)
      end
      copy
    end
  end
end
