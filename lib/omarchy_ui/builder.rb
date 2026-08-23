# frozen_string_literal: true

module OmarchyUI
  class Builder
    UNSET = Object.new.freeze
    CONTAINERS = %i[
      row column container grid row_layout column_layout grid_layout flow center card
      stack scroll rectangle aspect_ratio constrained_box fitted_box wrap split_view stack_layout loader flickable focus_scope flipable border_image key_catcher
      page pane frame group_box tabs stack_view swipe_view drawer expansion_panel accordion tool_bar popup dialog
    ].freeze
    VALUE_INPUTS = {
      text_field: :text,
      text_area: :text,
      password_field: :text,
      number_field: :value,
      slider: :value,
      dial: :value,
      spin_box: :value,
      double_spin_box: :value,
      color_picker: :color,
      date_picker: :date,
      time_picker: :time,
      file_picker: :path,
      folder_picker: :path,
      font_picker: :family,
      dropdown: :value,
      multi_select: :values,
      button_group: :value,
      radio_group: :value
    }.freeze

    def initialize(application)
      @application = application
      @stack = []
      @dynamic_scopes = []
    end

    def component(type, id: nil, **props, &block)
      definition = @application.components.fetch(type)
      node = @application.build_node(type, explicit_id: id || scoped_id(type), props:)
      append(node)
      if block
        raise ArgumentError, "#{type} is not a container" unless definition.container
        within(node, &block)
      end
      node
    end
    alias widget component
    alias qml_component component

    CONTAINERS.each do |type|
      define_method(type) { |id: nil, **props, &block| component(type, id:, **props, &block) }
    end

    def register_component(name, qml:, properties: [], events: [], property_map: {}, event_map: {}, container: false, auto_bind: true)
      unless @stack.empty? && @application.surfaces.empty?
        raise ArgumentError, "components must be registered before a surface"
      end
      @application.components.register(name, qml:, properties:, events:, property_map:, event_map:, container:, auto_bind:)
    end

    def state(name = nil, initial = UNSET)
      return @application.state if name.nil?
      raise ArgumentError, "state requires an initial value" if initial.equal?(UNSET)
      @application.define_state(name, initial)
    end

    APP_OPTIONS = %i[title width height min_width min_height max_width max_height color visible maximized fullscreen].freeze

    def bar_widget(&block) = surface("bar", id: "bar", &block)
    def panel(name, &block) = surface(name.to_s, id: "panel.#{name}", &block)

    def app(name = :main, **options, &block)
      unknown = options.keys - APP_OPTIONS
      raise ArgumentError, "unsupported app options: #{unknown.join(', ')}" unless unknown.empty?
      surface(name.to_s, id: "app.#{name}", options:, &block)
    end

    def dynamic(type: :column, id: nil, **props, &renderer)
      raise ArgumentError, "dynamic requires a block" unless renderer
      definition = @application.components.fetch(type)
      raise ArgumentError, "dynamic component must be a container: #{type}" unless definition.container

      node = component(type, id:, **props)
      within_dynamic(node, &renderer)
      @application.register_structure(node, renderer)
      node
    end

    def text(value = UNSET, id: nil, **props, &reader)
      node = component(:text, id:, **props)
      bind_or_set(node, "text", value, reader)
      node
    end

    def label(value, id: nil, **props) = component(:label, id:, text: value.to_s, **props)
    def rich_text(markup, id: nil, **props) = component(:rich_text, id:, text: markup.to_s, **props)
    def markdown(source, id: nil, **props) = component(:markdown, id:, text: source.to_s, **props)
    def selectable_text(value, id: nil, **props) = component(:selectable_text, id:, text: value.to_s, **props)

    def icon(name, id: nil, **props) = component(:icon, id:, name: name.to_s, **props)
    def tooltip(value, id: nil, **props) = component(:tooltip, id:, text: value.to_s, **props)
    def image(source, id: nil, **props) = component(:image, id:, source: source.to_s, **props)
    def vector_image(source, id: nil, **props) = component(:vector_image, id:, source: source.to_s, **props)
    def font_loader(source, id: nil, **props) = component(:font_loader, id:, source: source.to_s, **props)
    def text_metrics(value, id: nil, **props) = component(:text_metrics, id:, text: value.to_s, **props)
    def animated_image(source, id: nil, **props) = component(:animated_image, id:, source: source.to_s, **props)
    def video(source, id: nil, **props) = component(:video, id:, source: source.to_s, **props)
    def audio(source, id: nil, **props) = component(:audio, id:, source: source.to_s, **props)
    def avatar(source = nil, id: nil, **props)
      source.nil? ? component(:avatar, id:, **props) : component(:avatar, id:, source: source.to_s, **props)
    end
    def badge(value = nil, id: nil, **props) = component(:badge, id:, value:, **props)
    def chip(label, id: nil, **props, &handler)
      action_component(:chip, :text, label, id:, props:, handler:)
    end
    def border_image(source, id: nil, **props, &block) = component(:border_image, id:, source: source.to_s, **props, &block)
    def window(title = "", id: nil, **props, &block)
      component(:window, id:, title: title.to_s, **props, &block)
    end
    def application_window(title = "", id: nil, **props, &block)
      component(:application_window, id:, title: title.to_s, **props, &block)
    end
    def page(title = "", id: nil, **props, &block)
      component(:page, id:, title: title.to_s, **props, &block)
    end
    def pane(id: nil, **props, &block)
      component(:pane, id:, **props, &block)
    end
    def frame(id: nil, **props, &block)
      component(:frame, id:, **props, &block)
    end
    def group_box(title = "", id: nil, **props, &block)
      component(:group_box, id:, title: title.to_s, **props, &block)
    end
    def tabs(labels = [], id: nil, **props, &block)
      component(:tabs, id:, labels: Array(labels), **props, &block)
    end
    def tab_bar(items = [], id: nil, **props)
      component(:tab_bar, id:, items: Array(items), **props)
    end
    def tab_button(label = "", id: nil, **props, &handler)
      action_component(:tab_button, :text, label, id:, props:, handler:)
    end
    def page_indicator(count, id: nil, **props)
      component(:page_indicator, id:, count:, **props)
    end
    def stack_view(id: nil, **props, &block)
      component(:stack_view, id:, **props, &block)
    end
    def swipe_view(id: nil, **props, &block)
      component(:swipe_view, id:, **props, &block)
    end
    def drawer(id: nil, **props, &block)
      component(:drawer, id:, **props, &block)
    end
    def navigation_rail(items = [], id: nil, **props)
      component(:navigation_rail, id:, items: Array(items), **props)
    end
    def breadcrumb(items = [], id: nil, **props)
      component(:breadcrumb, id:, items: Array(items), **props)
    end
    def pagination(count, id: nil, **props)
      component(:pagination, id:, count:, **props)
    end
    def expansion_panel(title = "", id: nil, **props, &block)
      component(:expansion_panel, id:, title: title.to_s, **props, &block)
    end
    def accordion(titles = [], id: nil, **props, &block)
      component(:accordion, id:, titles: Array(titles), **props, &block)
    end
    def tool_bar(id: nil, **props, &block)
      component(:tool_bar, id:, **props, &block)
    end
    def tool_separator(id: nil, **props)
      component(:tool_separator, id:, **props)
    end
    def menu(items = [], id: nil, **props)
      component(:menu, id:, items: Array(items), **props)
    end
    def menu_item(label = "", id: nil, value: nil, **props, &handler)
      item_props = props.merge(text: label.to_s)
      item_props[:value] = value unless value.nil?
      node = component(:menu_item, id:, **item_props)
      @application.register_handler(node.id, :trigger, handler) if handler
      node
    end
    def menu_separator(id: nil, **props)
      component(:menu_separator, id:, **props)
    end
    def menu_bar(menus = [], id: nil, **props)
      component(:menu_bar, id:, menus: Array(menus), **props)
    end
    def context_menu(items = [], id: nil, target: nil, **props)
      target_id = target.is_a?(Node) ? target.id : target
      menu_props = props.merge(items: Array(items))
      menu_props[:target] = target_id.to_s unless target_id.nil?
      component(:context_menu, id:, **menu_props)
    end
    def popup(id: nil, **props, &block)
      component(:popup, id:, **props, &block)
    end
    def dialog(title = "", id: nil, **props, &block)
      component(:dialog, id:, title: title.to_s, **props, &block)
    end
    def alert_dialog(title = "", message = "", id: nil, **props)
      component(:alert_dialog, id:, title: title.to_s, message: message.to_s, **props)
    end
    def message_dialog(title = "", message = "", id: nil, **props)
      component(:message_dialog, id:, title: title.to_s, message: message.to_s, **props)
    end
    def bottom_sheet(id: nil, **props, &block)
      component(:bottom_sheet, id:, **props, &block)
    end
    def modal_sheet(title = "", id: nil, **props, &block)
      component(:modal_sheet, id:, title: title.to_s, **props, &block)
    end
    def snackbar(message = "", id: nil, **props)
      component(:snackbar, id:, message: message.to_s, **props)
    end
    def banner(message = "", id: nil, **props)
      component(:banner, id:, message: message.to_s, **props)
    end
    def toast(message = "", id: nil, **props)
      component(:toast, id:, message: message.to_s, **props)
    end
    def layout_item_proxy(target, id: nil, **props)
      target_id = target.is_a?(Node) ? target.id : target.to_s
      raise ArgumentError, "layout_item_proxy target cannot be empty" if target_id.empty?
      component(:layout_item_proxy, id:, target: target_id, **props)
    end
    def border_overlay(id: nil, **props) = component(:border_overlay, id:, **props)
    def spacer(id: nil, **props) = component(:spacer, id:, **props)
    def separator(id: nil, **props) = component(:separator, id:, **props)
    def divider(id: nil, **props) = component(:divider, id:, **props)
    def section_header(value, id: nil, **props) = component(:section_header, id:, text: value.to_s, **props)
    def dialog_button_box(buttons = [], id: nil, **props)
      component(:dialog_button_box, id:, buttons: Array(buttons), **props)
    end
    def action(label, id: nil, **props, &handler)
      node = component(:action, id:, text: label.to_s, **props)
      @application.register_handler(node.id, :trigger, handler) if handler
      node
    end
    def action_group(actions, id: nil, checked: nil, **props)
      action_ids = Array(actions).map { |action_node| action_node.is_a?(Node) ? action_node.id : action_node.to_s }
      checked_id = checked.is_a?(Node) ? checked.id : checked&.to_s
      component(:action_group, id:, action_ids:, checked_action: checked_id, **props)
    end

    def button(label, id: nil, **props, &handler)
      action_component(:button, :text, label, id:, props:, handler:)
    end

    def round_button(label = "", id: nil, **props, &handler)
      action_component(:round_button, :text, label, id:, props:, handler:)
    end

    def tool_button(label = "", id: nil, **props, &handler)
      action_component(:tool_button, :text, label, id:, props:, handler:)
    end

    def delay_button(label, id: nil, **props, &handler)
      node = action_component(:delay_button, :text, label, id:, props: props, handler: nil)
      @application.register_handler(node.id, :activate, handler) if handler
      node
    end

    def action_button(icon, id: nil, **props, &handler)
      action_component(:action_button, :icon, icon, id:, props:, handler:)
    end

    def bar_icon_button(icon, id: nil, **props, &handler)
      action_component(:bar_icon_button, :icon, icon, id:, props:, handler:)
    end

    def bar_indicator(active_icon, id: nil, **props, &handler)
      action_component(:bar_indicator, :active_icon, active_icon, id:, props:, handler:)
    end

    def toggle(label = "", id: nil, checked: UNSET, **props, &handler)
      input_component(:toggle, :checked, checked, id:, props: props.merge(label: label.to_s), handler:)
    end

    def checkbox(label = "", id: nil, checked: UNSET, **props, &handler)
      input_component(:checkbox, :checked, checked, id:, props: props.merge(label: label.to_s), handler:)
    end

    def radio_button(label = "", id: nil, checked: UNSET, **props, &handler)
      input_component(:radio_button, :checked, checked, id:, props: props.merge(label: label.to_s), handler:)
    end

    def search_field(value = "", id: nil, **props, &handler)
      node = component(:search_field, id:, text: value.to_s, **props)
      @application.register_handler(node.id, :search, handler) if handler
      node
    end

    def toggle_switch(id: nil, checked: UNSET, **props, &handler)
      input_component(:toggle_switch, :checked, checked, id:, props:, handler:)
    end

    VALUE_INPUTS.each do |type, property|
      define_method(type) do |value = UNSET, id: nil, **props, &handler|
        input_component(type, property, value, id:, props:, handler:)
      end
    end

    def progress(value = UNSET, id: nil, **props)
      input_component(:progress, :value, value, id:, props:)
    end

    def range_slider(lower, upper, id: nil, **props, &handler)
      node = component(:range_slider, id:, lower:, upper:, **props)
      @application.register_handler(node.id, :change, handler) if handler
      node
    end

    def line_chart(values, id: nil, **props)
      component(:line_chart, id:, values:, **props)
    end

    def area_chart(values, id: nil, **props)
      component(:area_chart, id:, values:, **props)
    end

    def bar_chart(values, id: nil, **props)
      component(:bar_chart, id:, values:, **props)
    end

    def on_click(&handler)
      raise ArgumentError, "on_click must be inside a surface or control" if @stack.empty?
      on(@stack.last, :click, &handler)
    end

    def on(target_or_event, event = nil, &handler)
      raise ArgumentError, "on requires a block" unless handler
      if target_or_event.is_a?(Node)
        raise ArgumentError, "on(node, event) requires an event" unless event
        node, event_name = target_or_event, event
      else
        raise ArgumentError, "on must be inside a surface or control" if @stack.empty?
        node, event_name = @stack.last, target_or_event
      end
      @application.register_handler(node.id, event_name, handler)
    end

    def property(name, value = UNSET, &reader)
      raise ArgumentError, "property must be inside a control" if @stack.empty?
      bind_or_set(@stack.last, name.to_s, value, reader)
    end

    def bind(node, property, animation: nil, &reader)
      raise ArgumentError, "bind requires a node returned by a component method" unless node.is_a?(Node)
      raise ArgumentError, "bind requires a block" unless reader
      transition = normalize_animation(animation)
      @application.register_binding(node, property.to_s, reader, animation: transition)
      node
    end

    def animation(**options) = Animation.new(**options)

    def animate(node, properties, duration: 200, easing: :in_out_quad, delay: 0)
      transition = Animation.new(duration:, easing:, delay:)
      @application.animate(node, properties, transition)
      node
    end

    def animate_sequence(node, steps)
      elapsed = 0
      tracks = steps.flat_map do |step|
        options = step.transform_keys(&:to_sym)
        properties = options.fetch(:to)
        transition = Animation.new(
          duration: options.fetch(:duration, 200),
          easing: options.fetch(:easing, :in_out_quad),
          delay: elapsed + options.fetch(:delay, 0)
        )
        elapsed = transition.delay + transition.duration + options.fetch(:pause, 0)
        @application.animation_tracks(node, properties, transition)
      end
      @application.emit_animation(node, tracks)
      node
    end
    def transaction(&block) = @application.state.transaction { instance_eval(&block) }
    def after(seconds, &block) = @application.schedule(:after, interval: seconds, &block)
    def every(seconds, immediate: false, &block) = @application.schedule(:every, interval: seconds, immediate:, &block)
    def async(&block) = @application.schedule(:async, &block)
    def run_command(argv, **options) = Command.run(argv, **options)
    def rebuild(node, &renderer) = within_dynamic(node, &renderer)
    def open_panel(name) = @application.emit_effect("open_panel", "surface" => name.to_s)

    def close_panel(name = nil)
      @application.emit_effect("close_panel", name.nil? ? {} : { "surface" => name.to_s })
    end

    private

    def scoped_id(type)
      return nil if @dynamic_scopes.empty?
      scope = @dynamic_scopes.last
      scope[:sequence] += 1
      "#{scope.fetch(:id)}.#{type}.#{scope.fetch(:sequence)}"
    end

    def within_dynamic(node, &block)
      @dynamic_scopes.push({ id: node.id, sequence: 0 })
      within(node, &block)
    ensure
      @dynamic_scopes.pop
    end

    def surface(name, id:, options: {}, &block)
      raise ArgumentError, "surface requires a block" unless block
      node = @application.build_node(:container, explicit_id: id)
      @application.add_surface(name, node, options:)
      within(node, &block)
      node
    end

    def action_component(type, property, value, id:, props:, handler:)
      node = component(type, id:, **props.merge(property => value.to_s))
      @application.register_handler(node.id, :click, handler) if handler
      node
    end

    def input_component(type, property, value, id:, props:, handler: nil)
      props = props.merge(property => value) unless value.equal?(UNSET)
      node = component(type, id:, **props)
      event = %i[text_field password_field].include?(type) ? :input : :change
      @application.register_handler(node.id, event, handler) if handler
      node
    end

    def within(node, &block)
      @stack.push(node)
      instance_eval(&block)
    ensure
      @stack.pop
    end

    def append(node)
      raise ArgumentError, "#{node.type} must be inside a surface or container" if @stack.empty?
      @stack.last.children << node
    end

    def bind_or_set(node, property, value, reader)
      if reader
        raise ArgumentError, "pass a value or a reactive block, not both" unless value.equal?(UNSET)
        @application.register_binding(node, property, reader)
      else
        raise ArgumentError, "#{property} requires a value or block" if value.equal?(UNSET)
        node.props[property] = @application.normalize_value(value, property)
      end
    end

    def normalize_animation(animation)
      case animation
      when nil then nil
      when Animation then animation
      when Hash then Animation.new(**animation)
      else raise ArgumentError, "animation must be an OmarchyUI::Animation or options hash"
      end
    end
  end
end
