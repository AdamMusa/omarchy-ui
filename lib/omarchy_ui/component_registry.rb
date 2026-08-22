# frozen_string_literal: true

module OmarchyUI
  Component = Data.define(:name, :qml, :properties, :events, :container) do
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

    def initialize
      @components = {}
    end

    def register(name, qml:, properties: [], events: [], container: false)
      key = name.to_sym
      raise ArgumentError, "component already registered: #{key}" if @components.key?(key)
      raise ArgumentError, "invalid component adapter: #{qml.inspect}" unless QML_FILE.match?(qml.to_s)

      @components[key] = Component.new(
        name: key,
        qml: qml.to_s,
        properties: properties.map(&:to_sym).freeze,
        events: events.map(&:to_sym).freeze,
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
