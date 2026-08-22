# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"
require "timeout"
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

  def test_events_are_explicitly_subscribed_per_node
    received = nil
    app = OmarchyUI::Application.new do
      panel :actions do
        control = button "Menu", id: :menu
        on(control, :right_click) { |payload| received = payload.fetch("button") }
        on(control, :mount) {}
      end
    end
    node = app.tree.dig("actions", "children", 0)
    assert_equal %w[right_click mount], node.fetch("events")

    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    app.receive(event("menu", surface: "actions", name: "right_click", payload: { "button" => 2 }))
    assert_equal 2, received
  end

  def test_undeclared_component_event_is_rejected_at_build_time
    assert_raises(ArgumentError) do
      OmarchyUI::Application.new do
        panel :main do
          label = text "No clicks", id: :label
          on(label, :clicked_twice) {}
        end
      end
    end
  end

  def test_reactive_list_models_preserve_typed_rows_and_activation_payloads
    activated = nil
    app = OmarchyUI::Application.new do
      state :rows, [{ id: 1, label: "One" }]
      panel :items do
        list = component :list_view, id: :items, items: state.rows, selected: 1
        bind(list, :items) { state.rows }
        on(list, :activate) { |payload| activated = payload.fetch("item") }
        button("Add", id: :add) { state.rows = state.rows + [{ id: 2, label: "Two" }] }
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("add", surface: "items"))
    patch = messages(output).first
    assert_equal [{ "id" => 1, "label" => "One" }, { "id" => 2, "label" => "Two" }], patch.fetch("value")

    app.receive(event("items", surface: "items", name: "activate", payload: {
      "value" => 2, "index" => 1, "item" => { "id" => 2, "label" => "Two" }
    }))
    assert_equal({ "id" => 2, "label" => "Two" }, activated)
  end

  def test_transactions_emit_only_final_reactive_values
    app = OmarchyUI::Application.new do
      state :first, 0
      state :second, 0
      panel :main do
        label = text "", id: :total
        bind(label, :text) { "Total: #{state.first + state.second}" }
        button("Batch", id: :batch) do
          transaction do
            state.first = 2
            state.second = 3
          end
        end
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind
    app.receive(event("batch", surface: "main"))

    patches = messages(output).select { |message| message["type"] == "patch" }
    assert_equal 1, patches.length
    assert_equal "Total: 5", patches.first.fetch("value")
  end

  def test_values_reject_cycles_nonfinite_numbers_and_excessive_depth
    cyclic = []
    cyclic << cyclic
    assert_raises(ArgumentError) { OmarchyUI::Value.normalize(cyclic, property: :items) }
    assert_raises(ArgumentError) { OmarchyUI::Value.normalize(Float::INFINITY, property: :value) }
    deep = 34.times.reduce("end") { |value| [value] }
    assert_raises(ArgumentError) { OmarchyUI::Value.normalize(deep, property: :items) }
  end

  def test_state_update_is_atomic_across_threads
    store = OmarchyUI::StateStore.new(->(*) {})
    store.define(:count, 0)
    threads = 8.times.map { Thread.new { 250.times { store.update(:count) { |value| value + 1 } } } }
    threads.each(&:join)
    assert_equal 2_000, store.count
  end

  def test_managed_tasks_update_state_and_stop_with_the_application
    app = OmarchyUI::Application.new do
      state :status, "waiting"
      panel :main do
        label = text "", id: :status
        bind(label, :text) { state.status }
      end
      after(0.01) { state.status = "ready" }
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    Timeout.timeout(1) do
      sleep(0.005) until messages(output).any? { |message| message["type"] == "patch" }
    end
    assert_equal "ready", messages(output).find { |message| message["type"] == "patch" }.fetch("value")
    app.stop
  end

  def test_periodic_tasks_are_cooperatively_cancelled
    ticks = Queue.new
    app = OmarchyUI::Application.new do
      panel(:main) { text "timer" }
      every(0.005, immediate: true) { ticks << true }
    end
    app.start(output: StringIO.new, error: StringIO.new)
    Timeout.timeout(1) { sleep(0.002) while ticks.empty? }
    app.stop
    count = ticks.size
    sleep(0.02)
    assert_equal count, ticks.size
  end
end
