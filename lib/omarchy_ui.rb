# frozen_string_literal: true

require "json"
require "thread"
require_relative "omarchy_ui/component_registry"
require_relative "omarchy_ui/components"
require_relative "omarchy_ui/animation"
require_relative "omarchy_ui/protocol"
require_relative "omarchy_ui/state_store"
require_relative "omarchy_ui/node"

module OmarchyUI
  VERSION = "0.2.0"
  class Builder
    UNSET = Object.new.freeze

    def initialize(application)
      @application = application
      @stack = []
    end

    def component(type, id: nil, **props, &block)
      definition = @application.components.fetch(type)
      node = @application.build_node(type, explicit_id: id, props: props)
      append(node)
      if block
        raise ArgumentError, "#{type} is not a container" unless definition.container
        within(node, &block)
      end
      node
    end

    alias widget component
    alias qml_component component

    def register_component(name, qml:, properties: [], events: [], container: false)
      raise ArgumentError, "components must be registered before a surface" unless @stack.empty? && @application.surfaces.empty?
      @application.components.register(name, qml:, properties:, events:, container:)
    end

    def state(name = nil, initial = UNSET)
      return @application.state if name.nil?

      raise ArgumentError, "state requires an initial value" if initial.equal?(UNSET)

      @application.define_state(name, initial)
    end

    def bar_widget(&block)
      surface("bar", :container, id: "bar", &block)
    end

    def panel(name, &block)
      surface(name.to_s, :container, id: "panel.#{name}", &block)
    end

    # An application surface uses the same renderer and lifecycle as a panel,
    # but gives framework consumers an explicit application-level entry point.
    def app(name = :main, &block)
      surface(name.to_s, :container, id: "app.#{name}", &block)
    end

    def row(id: nil, **props, &block)
      container_node(:row, id:, props:, &block)
    end

    def column(id: nil, **props, &block)
      container_node(:column, id:, props:, &block)
    end

    def container(id: nil, **props, &block)
      container_node(:container, id:, props:, &block)
    end

    def grid(id: nil, **props, &block)
      container_node(:grid, id:, props:, &block)
    end

    def stack(id: nil, **props, &block)
      container_node(:stack, id:, props:, &block)
    end

    def scroll(id: nil, **props, &block)
      container_node(:scroll, id:, props:, &block)
    end

    def rectangle(id: nil, **props, &block)
      container_node(:rectangle, id:, props:, &block)
    end

    def text(value = UNSET, id: nil, **props, &reader)
      node = leaf_node(:text, id:, props:)
      bind_or_set(node, "text", value, reader)
      node
    end

    def icon(name, id: nil, **props)
      leaf_node(:icon, id:, props: props.merge(name: name.to_s))
    end

    def image(source, id: nil, **props)
      leaf_node(:image, id:, props: props.merge(source: source.to_s))
    end

    def spacer(id: nil, **props)
      leaf_node(:spacer, id:, props:)
    end

    def button(label, id: nil, **props, &handler)
      node = leaf_node(:button, id:, props: props.merge(text: label.to_s))
      @application.register_handler(node.id, "click", handler) if handler
      node
    end

    def action_button(icon, id: nil, **props, &handler)
      node = leaf_node(:action_button, id:, props: props.merge(icon: icon.to_s))
      @application.register_handler(node.id, "click", handler) if handler
      node
    end

    def toggle(label = "", id: nil, checked: UNSET, **props, &handler)
      input_node(:toggle, id:, value_property: :checked, value: checked,
                 props: props.merge(label: label.to_s), event: :change, handler: handler)
    end

    def toggle_switch(id: nil, checked: UNSET, **props, &handler)
      input_node(:toggle_switch, id:, value_property: :checked, value: checked,
                 props:, event: :change, handler: handler)
    end

    def text_field(value = UNSET, id: nil, **props, &handler)
      input_node(:text_field, id:, value_property: :text, value:, props:, event: :change, handler: handler)
    end

    def number_field(value = UNSET, id: nil, **props, &handler)
      input_node(:number_field, id:, value_property: :value, value:, props:, event: :change, handler: handler)
    end

    def slider(value = UNSET, id: nil, **props, &handler)
      input_node(:slider, id:, value_property: :value, value:, props:, event: :change, handler: handler)
    end

    def dropdown(value = UNSET, id: nil, **props, &handler)
      input_node(:dropdown, id:, value_property: :value, value:, props:, event: :change, handler: handler)
    end

    def multi_select(values = UNSET, id: nil, **props, &handler)
      input_node(:multi_select, id:, value_property: :values, value: values, props:, event: :change, handler: handler)
    end

    def button_group(value = UNSET, id: nil, **props, &handler)
      input_node(:button_group, id:, value_property: :value, value:, props:, event: :change, handler: handler)
    end

    def progress(value = UNSET, id: nil, **props)
      input_node(:progress, id:, value_property: :value, value:, props:)
    end

    def separator(id: nil, **props)
      leaf_node(:separator, id:, props:)
    end

    def section_header(value, id: nil, **props)
      leaf_node(:section_header, id:, props: props.merge(text: value.to_s))
    end

    def on_click(&handler)
      raise ArgumentError, "on_click must be inside a surface or control" if @stack.empty?
      raise ArgumentError, "on_click requires a block" unless handler

      @application.register_handler(@stack.last.id, "click", handler)
    end

    def on(target_or_event, event = nil, &handler)
      raise ArgumentError, "on requires a block" unless handler
      if target_or_event.is_a?(Node)
        raise ArgumentError, "on(node, event) requires an event" unless event
        node = target_or_event
        event_name = event
      else
        raise ArgumentError, "on must be inside a surface or control" if @stack.empty?
        node = @stack.last
        event_name = target_or_event
      end
      @application.register_handler(node.id, event_name, handler)
    end

    # Adds or reactively computes any supported property on the current control.
    def property(name, value = UNSET, &reader)
      raise ArgumentError, "property must be inside a control" if @stack.empty?

      bind_or_set(@stack.last, name.to_s, value, reader)
    end

    def bind(node, property, animation: nil, &reader)
      raise ArgumentError, "bind requires a node returned by a widget method" unless node.is_a?(Node)
      raise ArgumentError, "bind requires a block" unless reader

      transition = case animation
                   when nil then nil
                   when Animation then animation
                   when Hash then Animation.new(**animation)
                   else raise ArgumentError, "animation must be an OmarchyUI::Animation or options hash"
                   end
      @application.register_binding(node, property.to_s, reader, animation: transition)
      node
    end

    def animation(**options)
      Animation.new(**options)
    end

    def open_panel(name)
      @application.emit_effect("open_panel", "surface" => name.to_s)
    end

    def close_panel(name = nil)
      payload = name.nil? ? {} : { "surface" => name.to_s }
      @application.emit_effect("close_panel", payload)
    end

    private

    def surface(name, type, id:, &block)
      raise ArgumentError, "surface requires a block" unless block

      node = @application.build_node(type, explicit_id: id)
      @application.add_surface(name, node)
      within(node, &block)
      node
    end

    def container_node(type, id:, props:, &block)
      node = @application.build_node(type, explicit_id: id, props: props)
      append(node)
      within(node, &block) if block
      node
    end

    def leaf_node(type, id:, props:)
      node = @application.build_node(type, explicit_id: id, props: props)
      append(node)
      node
    end

    def input_node(type, id:, value_property:, value:, props:, event: nil, handler: nil)
      merged = props.dup
      merged[value_property] = value unless value.equal?(UNSET)
      node = leaf_node(type, id:, props: merged)
      @application.register_handler(node.id, event.to_s, handler) if event && handler
      node
    end

    def within(node, &block)
      @stack.push(node)
      instance_eval(&block)
    ensure
      @stack.pop
    end

    def append(node)
      raise ArgumentError, "#{node.type} must be inside bar_widget, panel, or a container" if @stack.empty?

      @stack.last.children << node
    end

    def bind_or_set(node, property, value, reader)
      if reader
        raise ArgumentError, "pass a value or a reactive block, not both" unless value.equal?(UNSET)

        @application.register_binding(node, property, reader)
      else
        raise ArgumentError, "text requires a value or block" if value.equal?(UNSET)

        node.props[property] = @application.normalize_value(value, property)
      end
    end
  end

  class Application
    attr_reader :state, :surfaces

    attr_reader :components

    def initialize(components: DEFAULT_COMPONENTS, &definition)
      @surfaces = {}
      @nodes = {}
      @bindings = []
      @handlers = {}
      @sequence = 0
      @output = nil
      @error = $stderr
      @running = false
      @write_lock = Mutex.new
      @components = components.dup
      @builder = Builder.new(self)
      @state = StateStore.new(method(:state_changed))
      @builder.instance_eval(&definition) if definition
      raise ArgumentError, "plugin defines no surfaces" if @surfaces.empty?
    end

    def define_state(name, initial)
      @state.define(name, initial)
    end

    def build_node(type, explicit_id: nil, props: {})
      definition = @components.fetch(type)
      @sequence += 1
      id = explicit_id ? explicit_id.to_s : "#{type}.#{@sequence}"
      validate_id!(id)
      raise ArgumentError, "duplicate control id: #{id}" if @nodes.key?(id)

      normalized_props = normalize_props(props)
      unknown = normalized_props.keys - definition.properties.map(&:to_s)
      raise ArgumentError, "unsupported properties for #{type}: #{unknown.join(', ')}" unless unknown.empty?
      node = Node.new(type:, id:, props: normalized_props)
      @nodes[id] = node
      node
    end

    def add_surface(name, node)
      key = name.to_s
      validate_id!(key)
      raise ArgumentError, "duplicate surface: #{key}" if @surfaces.key?(key)

      @surfaces[key] = node
    end

    def register_binding(node, property, reader, animation: nil)
      value = normalize_value(evaluate(reader), property)
      node.props[property] = value
      @bindings << Binding.new(node:, property:, reader:, last_value: value, animation: animation)
    end

    def register_handler(control_id, event, handler)
      raise ArgumentError, "handler requires a block" unless handler

      node = @nodes.fetch(control_id.to_s) { raise ArgumentError, "unknown event control: #{control_id}" }
      event_name = event.to_s
      unless @components.fetch(node.type).events.map(&:to_s).include?(event_name) || %w[mount unmount].include?(event_name)
        raise ArgumentError, "#{node.type} does not declare event: #{event_name}"
      end
      node.subscribe(event_name)

      key = [control_id.to_s, event_name]
      raise ArgumentError, "duplicate handler for #{key.join("/")}" if @handlers.key?(key)

      @handlers[key] = handler
    end

    def emit_effect(name, payload = {})
      emit("v" => PROTOCOL_VERSION, "type" => "effect", "name" => name.to_s, "payload" => payload)
    end

    def tree
      @surfaces.transform_values(&:to_h)
    end

    def normalize_value(value, property = nil)
      case value
      when Symbol then value.to_s
      when String, Numeric, TrueClass, FalseClass, NilClass then value
      when Array then value.map { |item| normalize_value(item, property) }
      when Hash
        value.each_with_object({}) { |(key, item), result| result[key.to_s] = normalize_value(item, property) }
      else
        raise ArgumentError, "unsupported property value for #{property}: #{value.class}"
      end
    end

    def start(output: $stdout, error: $stderr)
      @output = output
      @error = error
      @output.sync = true if @output.respond_to?(:sync=)
      @error.sync = true if @error.respond_to?(:sync=)
      @running = true
      emit(
        "v" => PROTOCOL_VERSION,
        "type" => "ready",
        "pid" => Process.pid,
        "surfaces" => @surfaces.keys
      )
      emit("v" => PROTOCOL_VERSION, "type" => "render", "components" => @components.protocol_schema, "surfaces" => tree)
      self
    end

    def run(input: $stdin, output: $stdout, error: $stderr)
      start(output:, error:)
      input.each_line do |line|
        receive(line)
      rescue StandardError => exception
        report_internal_error(exception)
      end
    ensure
      @running = false
    end

    def receive(raw_line)
      raise ProtocolError, "message exceeds #{MAX_MESSAGE_BYTES} bytes" if raw_line.bytesize > MAX_MESSAGE_BYTES

      message = JSON.parse(raw_line)
      validate_message!(message)
      dispatch_event(message)
    rescue JSON::ParserError => exception
      emit_protocol_error("invalid_json", exception.message)
    rescue ProtocolError => exception
      emit_protocol_error("invalid_message", exception.message)
    end

    private

    def state_changed(_name, _previous, _value)
      @bindings.each do |binding|
        value = normalize_value(evaluate(binding.reader), binding.property)
        next if value == binding.last_value

        binding.last_value = value
        binding.node.props[binding.property] = value
        patch = {
          "v" => PROTOCOL_VERSION,
          "type" => "patch",
          "op" => "set",
          "id" => binding.node.id,
          "property" => binding.property,
          "value" => value
        }
        patch["animation"] = binding.animation.to_h if binding.animation
        emit(patch)
      end
    end

    def dispatch_event(message)
      key = [message.fetch("id"), message.fetch("event")]
      handler = @handlers[key]
      raise ProtocolError, "unknown event target: #{key.join("/")}" unless handler

      @builder.instance_exec(message["payload"] || {}, &handler)
      acknowledgement = {
        "v" => PROTOCOL_VERSION,
        "type" => "ack",
        "seq" => message["seq"],
        "id" => message.fetch("id"),
        "event" => message.fetch("event")
      }
      acknowledgement["rss_kib"] = process_rss_kib if message.dig("payload", "diagnostics") == true
      emit(acknowledgement)
    rescue StandardError => exception
      emit(
        "v" => PROTOCOL_VERSION,
        "type" => "handler_error",
        "seq" => message["seq"],
        "id" => message["id"],
        "message" => exception.message.to_s[0, 500]
      )
      @error.puts("omarchy-ui handler error: #{exception.class}: #{exception.message}")
    end

    def validate_message!(message)
      raise ProtocolError, "message must be an object" unless message.is_a?(Hash)
      raise ProtocolError, "unsupported protocol version" unless message["v"] == PROTOCOL_VERSION
      raise ProtocolError, "unsupported message type" unless message["type"] == "event"
      raise ProtocolError, "invalid surface" unless VALID_ID.match?(message["surface"].to_s)
      raise ProtocolError, "unknown surface" unless @surfaces.key?(message["surface"])
      raise ProtocolError, "invalid control id" unless VALID_ID.match?(message["id"].to_s)
      unless surface_contains?(@surfaces.fetch(message["surface"]), message["id"])
        raise ProtocolError, "control does not belong to surface"
      end
      raise ProtocolError, "invalid event" unless VALID_EVENT.match?(message["event"].to_s)
      raise ProtocolError, "payload must be an object" unless message["payload"].nil? || message["payload"].is_a?(Hash)
      raise ProtocolError, "seq must be an integer" unless message["seq"].nil? || message["seq"].is_a?(Integer)
    end

    def surface_contains?(node, control_id)
      node.id == control_id || node.children.any? { |child| surface_contains?(child, control_id) }
    end

    def evaluate(callable)
      @builder.instance_exec(&callable)
    end

    def normalize_props(props)
      props.each_with_object({}) do |(key, value), result|
        result[key.to_s] = normalize_value(value, key)
      end
    end

    def validate_id!(id)
      raise ArgumentError, "invalid id: #{id.inspect}" unless VALID_ID.match?(id)
    end

    def emit(message)
      return unless @running && @output

      encoded = JSON.generate(message)
      @write_lock.synchronize { @output.puts(encoded) }
    end

    def emit_protocol_error(code, message)
      emit(
        "v" => PROTOCOL_VERSION,
        "type" => "protocol_error",
        "code" => code,
        "message" => message.to_s[0, 500]
      )
    end

    def report_internal_error(exception)
      @error.puts("omarchy-ui runtime error: #{exception.class}: #{exception.message}")
      emit(
        "v" => PROTOCOL_VERSION,
        "type" => "runtime_error",
        "message" => exception.message.to_s[0, 500]
      )
    end

    def process_rss_kib
      status = File.read("/proc/self/status")
      status[/^VmRSS:\s+(\d+)\s+kB$/, 1].to_i
    rescue SystemCallError
      0
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
