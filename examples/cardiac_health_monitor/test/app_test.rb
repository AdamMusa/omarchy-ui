# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"
require_relative "../app"

class CardiacHealthMonitorTest < Minitest::Test
  def all(node)
    [node] + node.fetch("children", []).flat_map { |child| all(child) }
  end

  def event(id, name = "click", payload = {})
    JSON.generate("v" => OmarchyUI::PROTOCOL_VERSION, "type" => "event", "surface" => "main",
                  "id" => id, "event" => name, "seq" => 1, "payload" => payload)
  end

  def test_builds_the_visual_health_surface
    app = CardiacHealthMonitor.build
    nodes = all(app.tree.fetch("main"))
    ids = nodes.map { |node| node["id"] }
    %w[heart_model_3d heart_render_mode heart_zoom_readout heart_reset heart_particles
       ecg_waveform bpm.gauge recovery_heatmap insight_dialog].each do |id|
      assert_includes ids, id
    end
    heart = nodes.find { |node| node["id"] == "heart_model_3d" }
    assert_equal "model_view_3d", heart.fetch("type")
    assert_equal "assets/hra-heart.glb", heart.dig("props", "source")
    assert_equal "assets/luminous-heart.png", heart.dig("props", "fallback_source")
    assert_equal true, heart.dig("props", "interactive")
    assert_equal true, heart.dig("props", "pulse")
  end

  def test_heart_can_zoom_rotate_and_reset_through_the_3d_view
    app = CardiacHealthMonitor.build
    app.start(output: StringIO.new, error: StringIO.new)
    app.receive(event("heart_model_3d", "zoom_change", "value" => 1.55))
    assert_in_delta 1.55, app.state.heart_zoom
    app.receive(event("heart_model_3d", "rotation_change", "x" => 18.125, "y" => -42.875, "z" => 0))
    assert_in_delta 18.13, app.state.heart_rotation_x
    assert_in_delta(-42.88, app.state.heart_rotation_y)
    assert_equal "+18.1° / -42.9°", app.state.heart_orientation
    app.receive(event("heart_model_3d", "double_click", "zoom" => 2.1))
    assert_equal "DETAIL FOCUS", app.state.heart_orientation
    app.receive(event("heart_reset"))
    assert_in_delta 1.0, app.state.heart_zoom
    assert_in_delta(-98.0, app.state.heart_rotation_x)
    assert_in_delta(-18.0, app.state.heart_rotation_y)
    assert_equal "CENTERED", app.state.heart_orientation
    assert_equal 1, app.state.heart_reset_revision
  ensure
    app&.stop
  end

  def test_breathing_and_insight_controls_are_stateful
    app = CardiacHealthMonitor.build
    app.start(output: StringIO.new, error: StringIO.new)
    app.receive(event("breathing_toggle"))
    app.receive(event("daily_insight"))
    assert_equal true, app.state.breathing
    assert_equal true, app.state.insight_dialog
  ensure
    app&.stop
  end
end
