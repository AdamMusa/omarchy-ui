# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"
require_relative "../lib/omarchy_ui"

class OmarchyUITest < Minitest::Test
  def build_counter
    OmarchyUI::Application.new do
      state :count, 0

      bar_widget do
        text "Ruby UI"
        on_click { open_panel :counter }
      end

      panel :counter do
        column do
          text(id: :count) { "Count: #{state.count}" }
          button "Increment", id: :increment do
            state.count += 1
          end
          button "Reset", id: :reset do
            state.count = 0
          end
        end
      end
    end
  end

  def messages(output)
    output.string.lines.map { |line| JSON.parse(line) }
  end

  def event(id, seq: 1, surface: "counter", name: "click", payload: {})
    JSON.generate(
      "v" => 1,
      "type" => "event",
      "surface" => surface,
      "id" => id,
      "event" => name,
      "seq" => seq,
      "payload" => payload
    )
  end

  def test_initial_render_contains_named_surfaces_and_controls
    app = build_counter
    output = StringIO.new
    app.start(output: output, error: StringIO.new)

    ready, render = messages(output)
    assert_equal "ready", ready.fetch("type")
    assert_equal %w[bar counter], ready.fetch("surfaces")
    assert_equal "render", render.fetch("type")
    assert_equal "Count: 0", render.dig("surfaces", "counter", "children", 0, "children", 0, "props", "text")
  end

  def test_click_executes_ruby_handler_and_emits_only_set_patch_plus_ack
    app = build_counter
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("increment", seq: 7))

    patch, ack = messages(output)
    assert_equal({
      "v" => 1,
      "type" => "patch",
      "op" => "set",
      "id" => "count",
      "property" => "text",
      "value" => "Count: 1"
    }, patch)
    assert_equal "ack", ack.fetch("type")
    assert_equal 7, ack.fetch("seq")
  end

  def test_reset_does_not_emit_a_patch_when_value_is_already_zero
    app = build_counter
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("reset"))

    assert_equal ["ack"], messages(output).map { |message| message.fetch("type") }
  end

  def test_bar_click_emits_only_the_whitelisted_open_panel_effect
    app = build_counter
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("bar", surface: "bar"))

    effect, ack = messages(output)
    assert_equal "effect", effect.fetch("type")
    assert_equal "open_panel", effect.fetch("name")
    assert_equal({ "surface" => "counter" }, effect.fetch("payload"))
    assert_equal "ack", ack.fetch("type")
  end

  def test_unknown_events_and_invalid_json_are_rejected
    app = build_counter
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("missing"))
    app.receive("{not json}\n")

    types = messages(output).map { |message| message.fetch("type") }
    assert_equal ["protocol_error", "protocol_error"], types
  end

  def test_control_must_belong_to_the_claimed_surface
    app = build_counter
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("increment", surface: "bar"))

    message = messages(output).fetch(0)
    assert_equal "protocol_error", message.fetch("type")
    assert_match(/does not belong/, message.fetch("message"))
  end

  def test_duplicate_ids_are_rejected
    error = assert_raises(ArgumentError) do
      OmarchyUI::Application.new do
        panel :main do
          text "one", id: :same
          text "two", id: :same
        end
      end
    end

    assert_match(/duplicate control id/, error.message)
  end


  def test_form_widgets_keep_typed_properties_and_deliver_change_payloads
    selected = nil
    app = OmarchyUI::Application.new do
      panel :settings do
        dropdown "dark", id: :theme, options: [
          { value: :dark, label: "Dark" },
          { value: :light, label: "Light" }
        ] do |event|
          selected = event.fetch("value")
        end
        multi_select %w[wifi bluetooth], options: %w[wifi bluetooth audio]
        slider 0.5, minimum: 0, maximum: 1
        toggle "Notifications", checked: true
        text_field "hello", placeholder: "Name"
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)

    props = app.tree.dig("settings", "children")
    assert_equal [{ "value" => "dark", "label" => "Dark" }, { "value" => "light", "label" => "Light" }], props[0].dig("props", "options")
    assert_equal %w[wifi bluetooth], props[1].dig("props", "values")

    app.receive(event("theme", surface: "settings", name: "change", payload: { "value" => "light" }))
    assert_equal "light", selected
  end

  def test_arbitrary_properties_can_be_reactively_bound
    app = OmarchyUI::Application.new do
      state :enabled, false
      panel :settings do
        control = toggle "Feature", id: :feature
        bind(control, :checked) { state.enabled }
        button("Enable", id: :enable) { state.enabled = true }
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("enable", surface: "settings"))
    patch = messages(output).first
    assert_equal "checked", patch.fetch("property")
    assert_equal true, patch.fetch("value")
  end

  def test_qml_components_are_registered_with_a_validated_schema
    app = OmarchyUI::Application.new do
      register_component :sparkline, qml: "Sparkline.qml", properties: %i[values color], events: %i[click]
      app do
        component :sparkline, id: :history, values: [1, 3, 2], color: "#ff0000"
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    render = messages(output).last

    assert_equal "Sparkline.qml", render.dig("components", "sparkline", "qml")
    assert_equal [1, 3, 2], render.dig("surfaces", "main", "children", 0, "props", "values")
  end

  def test_component_schema_rejects_unknown_properties_and_unsafe_paths
    assert_raises(ArgumentError) do
      OmarchyUI::Application.new do
        register_component :unsafe, qml: "../Unsafe.qml", properties: [:value]
        app { component :unsafe, value: 1 }
      end
    end

    assert_raises(ArgumentError) do
      OmarchyUI::Application.new do
        app { component :text, executable: "oops" }
      end
    end
  end

  def test_reactive_binding_emits_a_validated_animation_descriptor
    app = OmarchyUI::Application.new do
      state :level, 0.0
      panel :meter do
        meter = progress 0.0, id: :meter
        bind(meter, :value, animation: animation(duration: 320, easing: :out_cubic, delay: 10)) { state.level }
        button("Fill", id: :fill) { state.level = 1.0 }
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("fill", surface: "meter"))
    patch = messages(output).first
    assert_equal({ "duration" => 320, "easing" => "out_cubic", "delay" => 10 }, patch.fetch("animation"))
    assert_equal 1.0, patch.fetch("value")
  end

  def test_animation_rejects_unbounded_values_and_unknown_easing
    assert_raises(ArgumentError) { OmarchyUI::Animation.new(duration: 60_001) }
    assert_raises(ArgumentError) { OmarchyUI::Animation.new(easing: :javascript) }
  end
end
