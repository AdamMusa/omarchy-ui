# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"
require "timeout"
require_relative "../lib/omarchy_ui"

class OmarchyUITest < Minitest::Test
  def test_embedded_runtime_version_matches_framework
    bootstrap = File.read(File.expand_path("../runtime/mrbgem/mrblib/bootstrap.rb", __dir__))
    assert_includes bootstrap, %(VERSION = "#{OmarchyUI::VERSION}")
  end

  def test_embedded_runtime_supports_conventional_ruby_loading
    bootstrap = File.read(File.expand_path("../runtime/mrbgem/mrblib/bootstrap.rb", __dir__))

    assert_includes bootstrap, 'feature == "omarchy_ui"'
    assert_includes bootstrap, "def require_relative(feature)"
    assert_includes bootstrap, 'ENV["OMARCHY_UI_PROJECT_DIR"]'
    refute_includes bootstrap, "PhoneBackend"
  end

  def test_responsive_layouts_and_icon_catalog_are_built_in
    application = OmarchyUI::Application.new do
      app do
        card padding: 20 do
          column_layout spacing: 12 do
            row_layout fill_width: true do
              icon :phone, color: "#7aa2f7"
              text "Devices", fill_width: true
            end
            flow width: 480 do
              button "Android", icon: :android
              button "iPhone", icon: :apple
            end
          end
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    render = messages(output).find { |message| message["type"] == "render" }
    card_node = render.dig("surfaces", "main", "children", 0)
    column = card_node.dig("children", 0)
    row = column.dig("children", 0)

    assert_equal "card", card_node.fetch("type")
    assert_equal "column_layout", column.fetch("type")
    assert_equal true, row.dig("props", "fill_width")
    assert_equal "phone", row.dig("children", 0, "props", "name")
    assert_includes OmarchyUI::ICON_NAMES, :android
    assert_includes OmarchyUI::ICON_NAMES, :apple
  ensure
    application&.stop
  end

  def test_aspect_ratio_is_a_typed_container
    application = OmarchyUI::Application.new do
      app do
        aspect_ratio ratio: 16.0 / 9, width: 320 do
          image "preview.png"
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "aspect_ratio", node.fetch("type")
    assert_in_delta 16.0 / 9, node.dig("props", "ratio")
    assert_equal 320, node.dig("props", "width")
    assert_equal "image", node.dig("children", 0, "type")
  ensure
    application&.stop
  end

  def test_constrained_box_is_a_typed_container
    application = OmarchyUI::Application.new do
      app do
        constrained_box min_width: 200, max_width: 600, min_height: 100 do
          text "Bounded content"
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "constrained_box", node.fetch("type")
    assert_equal 200, node.dig("props", "min_width")
    assert_equal 600, node.dig("props", "max_width")
    assert_equal "text", node.dig("children", 0, "type")
  ensure
    application&.stop
  end

  def test_fitted_box_is_a_typed_container
    application = OmarchyUI::Application.new do
      app do
        fitted_box width: 300, height: 180, fit: :cover, alignment: :top_left do
          image "hero.png", width: 640, height: 480
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "fitted_box", node.fetch("type")
    assert_equal "cover", node.dig("props", "fit")
    assert_equal "top_left", node.dig("props", "alignment")
    assert_equal "image", node.dig("children", 0, "type")
  ensure
    application&.stop
  end

  def test_wrap_is_a_typed_responsive_container
    application = OmarchyUI::Application.new do
      app do
        wrap width: 360, spacing: 12, layout_direction: :right_to_left do
          button "One"
          button "Two"
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "wrap", node.fetch("type")
    assert_equal 360, node.dig("props", "width")
    assert_equal "right_to_left", node.dig("props", "layout_direction")
    assert_equal %w[button button], node.fetch("children").map { |child| child.fetch("type") }
  ensure
    application&.stop
  end

  def test_split_view_is_a_typed_resizable_container
    application = OmarchyUI::Application.new do
      app do
        split_view width: 640, height: 360, orientation: :horizontal do
          rectangle preferred_width: 220
          rectangle fill_width: true
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "split_view", node.fetch("type")
    assert_equal "horizontal", node.dig("props", "orientation")
    assert_equal 220, node.dig("children", 0, "props", "preferred_width")
    assert_equal true, node.dig("children", 1, "props", "fill_width")
  ensure
    application&.stop
  end

  def test_stack_layout_is_a_typed_indexed_container
    application = OmarchyUI::Application.new do
      app do
        stack_layout current_index: 1, width: 480 do
          text "First"
          text "Second"
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "stack_layout", node.fetch("type")
    assert_equal 1, node.dig("props", "current_index")
    assert_equal %w[First Second], node.fetch("children").map { |child| child.dig("props", "text") }
  ensure
    application&.stop
  end

  def test_loader_is_a_typed_lazy_container
    application = OmarchyUI::Application.new do
      app do
        loader active: true, asynchronous: true do
          card { text "Loaded later" }
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "loader", node.fetch("type")
    assert_equal true, node.dig("props", "active")
    assert_equal true, node.dig("props", "asynchronous")
    assert_equal "card", node.dig("children", 0, "type")
  ensure
    application&.stop
  end

  def test_flickable_is_a_typed_kinetic_scroll_container
    application = OmarchyUI::Application.new do
      app do
        flickable width: 400, height: 260, direction: :both, bounds_behavior: :overshoot do
          column { text "Scrollable" }
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "flickable", node.fetch("type")
    assert_equal "both", node.dig("props", "direction")
    assert_equal "overshoot", node.dig("props", "bounds_behavior")
    assert_equal "column", node.dig("children", 0, "type")
  ensure
    application&.stop
  end

  def test_focus_scope_is_a_typed_focus_container
    application = OmarchyUI::Application.new do
      app do
        focus_scope active_focus: true do
          text_field "ready"
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "focus_scope", node.fetch("type")
    assert_equal true, node.dig("props", "active_focus")
    assert_equal "text_field", node.dig("children", 0, "type")
  ensure
    application&.stop
  end

  def test_flipable_is_a_typed_two_face_container
    application = OmarchyUI::Application.new do
      app do
        flipable flipped: true, axis: :horizontal, duration: 450 do
          card { text "Front" }
          card { text "Back" }
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "flipable", node.fetch("type")
    assert_equal true, node.dig("props", "flipped")
    assert_equal "horizontal", node.dig("props", "axis")
    assert_equal %w[card card], node.fetch("children").map { |child| child.fetch("type") }
  ensure
    application&.stop
  end

  def test_border_image_is_a_typed_nine_slice_container
    application = OmarchyUI::Application.new do
      app do
        border_image "frame.png", border_left: 12, border_top: 10, horizontal_tile: :repeat do
          text "Framed"
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "border_image", node.fetch("type")
    assert_equal "frame.png", node.dig("props", "source")
    assert_equal 12, node.dig("props", "border_left")
    assert_equal "repeat", node.dig("props", "horizontal_tile")
    assert_equal "text", node.dig("children", 0, "type")
  ensure
    application&.stop
  end

  def test_tooltip_is_a_typed_builtin_component
    application = OmarchyUI::Application.new do
      app do
        tooltip "Refresh devices", visible: true, delay: 250
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "tooltip", node.fetch("type")
    assert_equal "Refresh devices", node.dig("props", "text")
    assert_equal 250, node.dig("props", "delay")
  ensure
    application&.stop
  end

  def test_label_is_a_typed_styled_text_control
    application = OmarchyUI::Application.new do
      app { label "Documentation", bold: true, elide: :right, maximum_lines: 2 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "label", node.fetch("type")
    assert_equal "Documentation", node.dig("props", "text")
    assert_equal "right", node.dig("props", "elide")
    assert_equal 2, node.dig("props", "maximum_lines")
  ensure
    application&.stop
  end

  def test_rich_text_is_an_explicit_typed_markup_component
    application = OmarchyUI::Application.new do
      app { rich_text '<b>Omarchy</b> <a href="docs">docs</a>', link_color: "#7aa2f7" }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "rich_text", node.fetch("type")
    assert_includes node.dig("props", "text"), "<b>Omarchy</b>"
    assert_equal "#7aa2f7", node.dig("props", "link_color")
  ensure
    application&.stop
  end

  def test_markdown_is_a_dedicated_typed_document_component
    application = OmarchyUI::Application.new do
      app { markdown "# Omarchy UI\n\n[Guide](guide.md)", base_url: "file:///docs/" }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "markdown", node.fetch("type")
    assert_includes node.dig("props", "text"), "# Omarchy UI"
    assert_equal "file:///docs/", node.dig("props", "base_url")
  ensure
    application&.stop
  end

  def test_selectable_text_is_a_typed_read_only_selection_component
    application = OmarchyUI::Application.new do
      app { selectable_text "Copy this value", selection_color: "#7aa2f7", wrap: false }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "selectable_text", node.fetch("type")
    assert_equal "Copy this value", node.dig("props", "text")
    assert_equal "#7aa2f7", node.dig("props", "selection_color")
    assert_equal false, node.dig("props", "wrap")
  ensure
    application&.stop
  end

  def test_animated_image_is_a_typed_native_playback_component
    application = OmarchyUI::Application.new do
      app { animated_image "spinner.gif", playing: true, speed: 1.5, fill_mode: :cover }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "animated_image", node.fetch("type")
    assert_equal "spinner.gif", node.dig("props", "source")
    assert_equal 1.5, node.dig("props", "speed")
    assert_equal "cover", node.dig("props", "fill_mode")
  ensure
    application&.stop
  end

  def test_vector_image_is_a_typed_native_svg_component
    application = OmarchyUI::Application.new do
      app { vector_image "logo.svg", renderer: :curve, fill_mode: :contain, animation_loops: 3 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "vector_image", node.fetch("type")
    assert_equal "logo.svg", node.dig("props", "source")
    assert_equal "curve", node.dig("props", "renderer")
    assert_equal 3, node.dig("props", "animation_loops")
  ensure
    application&.stop
  end

  def test_font_loader_is_a_typed_native_font_resource
    application = OmarchyUI::Application.new do
      app { font_loader "fonts/Inter.woff2" }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "font_loader", node.fetch("type")
    assert_equal "fonts/Inter.woff2", node.dig("props", "source")
  ensure
    application&.stop
  end

  def test_text_metrics_is_a_typed_native_measurement_component
    application = OmarchyUI::Application.new do
      app { text_metrics "Measure me", font_size: 18, bold: true, elide: :right, elide_width: 100 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "text_metrics", node.fetch("type")
    assert_equal "Measure me", node.dig("props", "text")
    assert_equal 18, node.dig("props", "font_size")
    assert_equal "right", node.dig("props", "elide")
  ensure
    application&.stop
  end

  def test_video_is_a_typed_native_multimedia_component
    application = OmarchyUI::Application.new do
      app { video "intro.mp4", auto_play: true, volume: 0.7, fill_mode: :cover }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "video", node.fetch("type")
    assert_equal "intro.mp4", node.dig("props", "source")
    assert_equal true, node.dig("props", "auto_play")
    assert_equal 0.7, node.dig("props", "volume")
  ensure
    application&.stop
  end

  def test_audio_is_a_typed_native_media_player_component
    application = OmarchyUI::Application.new do
      app { audio "alert.ogg", playback: :play, loops: 2, volume: 0.5 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "audio", node.fetch("type")
    assert_equal "alert.ogg", node.dig("props", "source")
    assert_equal "play", node.dig("props", "playback")
    assert_equal 0.5, node.dig("props", "volume")
  ensure
    application&.stop
  end

  def test_avatar_is_a_typed_image_with_initials_fallback
    application = OmarchyUI::Application.new do
      app { avatar "profile.png", name: "Ada Lovelace", size: 64 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "avatar", node.fetch("type")
    assert_equal "profile.png", node.dig("props", "source")
    assert_equal "Ada Lovelace", node.dig("props", "name")
    assert_equal 64, node.dig("props", "size")
  ensure
    application&.stop
  end

  def test_badge_is_a_typed_value_or_dot_component
    application = OmarchyUI::Application.new do
      app { badge 120, maximum: 99, background: "#f7768e" }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "badge", node.fetch("type")
    assert_equal 120, node.dig("props", "value")
    assert_equal 99, node.dig("props", "maximum")
    assert_equal "#f7768e", node.dig("props", "background")
  ensure
    application&.stop
  end

  def test_chip_is_a_typed_selectable_and_deletable_component
    application = OmarchyUI::Application.new do
      app { chip "Ruby", icon: :ruby, selected: true, deletable: true }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "chip", node.fetch("type")
    assert_equal "Ruby", node.dig("props", "text")
    assert_equal "ruby", node.dig("props", "icon")
    assert_equal true, node.dig("props", "deletable")
  ensure
    application&.stop
  end

  def test_divider_is_a_typed_oriented_line_component
    application = OmarchyUI::Application.new do
      app { divider orientation: :vertical, length: 120, thickness: 2, indent: 8 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "divider", node.fetch("type")
    assert_equal "vertical", node.dig("props", "orientation")
    assert_equal 120, node.dig("props", "length")
    assert_equal 2, node.dig("props", "thickness")
  ensure
    application&.stop
  end

  def test_bar_icon_button_registers_click_handler_and_optical_properties
    application = OmarchyUI::Application.new do
      bar_widget do
        bar_icon_button :wifi, slot_size: 30, optical_size: 20 do
          state.clicked = true
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    render = messages(output).find { |message| message["type"] == "render" }
    node = render.dig("surfaces", "bar", "children", 0)

    assert_equal "bar_icon_button", node.fetch("type")
    assert_equal "wifi", node.dig("props", "icon")
    assert_equal 30, node.dig("props", "slot_size")
    assert_includes node.fetch("events"), "click"
  ensure
    application&.stop
  end

  def test_round_button_is_a_typed_native_checkable_control
    application = OmarchyUI::Application.new do
      app { round_button "", icon: :plus, diameter: 48, checkable: true, checked: true }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "round_button", node.fetch("type")
    assert_equal "plus", node.dig("props", "icon")
    assert_equal 48, node.dig("props", "diameter")
    assert_equal true, node.dig("props", "checked")
  ensure
    application&.stop
  end

  def test_tool_button_is_a_typed_native_toolbar_control
    application = OmarchyUI::Application.new do
      app { tool_button "", icon: :edit, width: 42, checkable: true }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "tool_button", node.fetch("type")
    assert_equal "edit", node.dig("props", "icon")
    assert_equal 42, node.dig("props", "width")
    assert_equal true, node.dig("props", "checkable")
  ensure
    application&.stop
  end

  def test_delay_button_is_a_typed_hold_to_activate_control
    application = OmarchyUI::Application.new do
      app { delay_button "Delete", delay: 1500, width: 160 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "delay_button", node.fetch("type")
    assert_equal "Delete", node.dig("props", "text")
    assert_equal 1500, node.dig("props", "delay")
    assert_equal 160, node.dig("props", "width")
  ensure
    application&.stop
  end

  def test_bar_indicator_serializes_active_and_inactive_states
    application = OmarchyUI::Application.new do
      bar_widget do
        bar_indicator :wifi, active: true, inactive_icon: :xmark,
                             active_tooltip: "Online", inactive_tooltip: "Offline"
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "bar", "children", 0)

    assert_equal "bar_indicator", node.fetch("type")
    assert_equal true, node.dig("props", "active")
    assert_equal "wifi", node.dig("props", "active_icon")
    assert_equal "xmark", node.dig("props", "inactive_icon")
  ensure
    application&.stop
  end

  def test_border_overlay_accepts_gradient_border_data
    application = OmarchyUI::Application.new do
      app do
        border_overlay width: 240, height: 120, width_spec: 2,
                       gradient_colors: ["#7aa2f7", "#bb9af7"], gradient_angle: 45
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "border_overlay", node.fetch("type")
    assert_equal ["#7aa2f7", "#bb9af7"], node.dig("props", "gradient_colors")
    assert_equal 45, node.dig("props", "gradient_angle")
  ensure
    application&.stop
  end

  def test_key_catcher_is_a_container_with_semantic_keyboard_events
    application = OmarchyUI::Application.new do
      app do
        key_catcher blocked: false do
          text "Keyboard content"
          on(:move) { |_event| }
          on(:text) { |_event| }
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "key_catcher", node.fetch("type")
    assert_equal "text", node.dig("children", 0, "type")
    assert_includes node.fetch("events"), "move"
    assert_includes node.fetch("events"), "text"
  ensure
    application&.stop
  end

  def test_checkbox_is_a_value_input_with_change_handler
    application = OmarchyUI::Application.new do
      state :enabled, false
      app do
        checkbox "Enable Wi-Fi", checked: state.enabled do |event|
          state.enabled = event.fetch("value")
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "checkbox", node.fetch("type")
    assert_equal "Enable Wi-Fi", node.dig("props", "label")
    assert_equal false, node.dig("props", "checked")
    assert_includes node.fetch("events"), "change"
  ensure
    application&.stop
  end

  def test_radio_button_is_a_typed_native_selection_control
    application = OmarchyUI::Application.new do
      app { radio_button "Ruby", value: :ruby, checked: true, indicator_size: 22 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "radio_button", node.fetch("type")
    assert_equal "Ruby", node.dig("props", "label")
    assert_equal "ruby", node.dig("props", "value")
    assert_equal true, node.dig("props", "checked")
  ensure
    application&.stop
  end

  def test_radio_group_is_a_typed_mutually_exclusive_options_control
    application = OmarchyUI::Application.new do
      app { radio_group :ruby, options: [{ label: "Ruby", value: :ruby }, { label: "QML", value: :qml }], orientation: :horizontal }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "radio_group", node.fetch("type")
    assert_equal "ruby", node.dig("props", "value")
    assert_equal "Ruby", node.dig("props", "options", 0, "label")
    assert_equal "horizontal", node.dig("props", "orientation")
  ensure
    application&.stop
  end

  def test_line_chart_is_a_specific_reactive_data_component
    application = OmarchyUI::Application.new do
      state :samples, [12, 18, 15, 27]
      app do
        chart = line_chart state.samples, labels: %w[Mon Tue Wed Thu], fill_color: "#337aa2f7"
        bind(chart, :values) { state.samples }
        on(chart, :select) { |_event| }
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "line_chart", node.fetch("type")
    assert_equal [12, 18, 15, 27], node.dig("props", "values")
    assert_equal %w[Mon Tue Wed Thu], node.dig("props", "labels")
    assert_includes node.fetch("events"), "select"
  ensure
    application&.stop
  end

  def test_bar_chart_is_a_specific_data_component
    application = OmarchyUI::Application.new do
      app { bar_chart [4, 8, 6], labels: %w[A B C], colors: ["#7aa2f7", "#bb9af7"] }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "bar_chart", node.fetch("type")
    assert_equal [4, 8, 6], node.dig("props", "values")
    assert_equal %w[A B C], node.dig("props", "labels")
  ensure
    application&.stop
  end

  def test_area_chart_is_a_specific_data_component
    application = OmarchyUI::Application.new do
      app { area_chart [3, 7, 5], labels: %w[Jan Feb Mar], fill_color: "#447aa2f7" }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "area_chart", node.fetch("type")
    assert_equal [3, 7, 5], node.dig("props", "values")
    assert_equal "#447aa2f7", node.dig("props", "fill_color")
  ensure
    application&.stop
  end

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

  def test_app_surface_serializes_window_options_separately_from_controls
    application = OmarchyUI::Application.new do
      app :main, title: "Dashboard", width: 900, height: 600, min_width: 480 do
        text "Ready"
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    render = output.string.lines.map { |line| JSON.parse(line) }.find { |message| message["type"] == "render" }

    assert_equal({ "title" => "Dashboard", "width" => 900, "height" => 600, "min_width" => 480 },
                 render.dig("surface_options", "main"))
    refute_includes(render.dig("surfaces", "main").fetch("props", {}), "title")
  ensure
    application&.stop
  end

  def test_app_surface_rejects_unknown_window_options
    error = assert_raises(ArgumentError) do
      OmarchyUI::Application.new { app(:main, decorations: false) { text "No" } }
    end
    assert_includes error.message, "unsupported app options"
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
    typed = nil
    application = OmarchyUI::Application.new do
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
        text_field "hello", id: :name, placeholder: "Name" do |event|
          typed = event.fetch("value")
        end
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)

    props = application.tree.dig("settings", "children")
    assert_equal [{ "value" => "dark", "label" => "Dark" }, { "value" => "light", "label" => "Light" }], props[0].dig("props", "options")
    assert_equal %w[wifi bluetooth], props[1].dig("props", "values")

    application.receive(event("theme", surface: "settings", name: "change", payload: { "value" => "light" }))
    assert_equal "light", selected
    application.receive(event("name", surface: "settings", name: "input", payload: { "value" => "Ada" }))
    assert_equal "Ada", typed
  end

  def test_arbitrary_properties_can_be_reactively_bound
    application = OmarchyUI::Application.new do
      state :enabled, false
      panel :settings do
        control = toggle "Feature", id: :feature
        bind(control, :checked) { state.enabled }
        button("Enable", id: :enable) { state.enabled = true }
      end
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    application.receive(event("enable", surface: "settings"))
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

  def test_native_component_protocol_includes_property_and_event_maps
    application = OmarchyUI::Application.new do
      register_component :dial, qml: "Dial.qml", properties: %i[current_value],
                         property_map: { current_value: :value }, events: %i[change],
                         event_map: { change: :moved }
      app { component :dial, current_value: 42 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    render = messages(output).find { |message| message["type"] == "render" }
    schema = render.dig("components", "dial")
    assert_equal "value", schema.dig("property_map", "current_value")
    assert_equal "moved", schema.dig("event_map", "change")
    assert schema.fetch("auto_bind")
  ensure
    application&.stop
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

  def test_dynamic_containers_reconcile_conditionals_and_event_handlers
    clicked = []
    app = OmarchyUI::Application.new do
      state :items, [{ id: "one", label: "One" }]
      panel :main do
        dynamic id: :content do
          state.items.each do |item|
            button item.fetch(:label), id: "item.#{item.fetch(:id)}" do
              clicked << item.fetch(:id)
            end
          end
          text "Empty", id: :empty if state.items.empty?
        end
        button("Replace", id: :replace) do
          state.items = [{ id: "two", label: "Two" }]
        end
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("replace", surface: "main"))
    patch = messages(output).find { |message| message["op"] == "replace_children" }
    assert_equal "content", patch.fetch("id")
    assert_equal ["item.two"], patch.fetch("children").map { |node| node.fetch("id") }

    app.receive(event("item.two", surface: "main"))
    assert_equal ["two"], clicked
    app.receive(event("item.one", surface: "main"))
    assert_equal "protocol_error", messages(output).last.fetch("type")
  end

  def test_dynamic_container_does_not_patch_an_unchanged_subtree
    app = OmarchyUI::Application.new do
      state :unrelated, 0
      panel :main do
        dynamic(id: :stable) { text "Same", id: :same }
        button("Change", id: :change) { state.unrelated += 1 }
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind
    app.receive(event("change", surface: "main"))
    refute messages(output).any? { |message| message["op"] == "replace_children" }
  end

  def test_dynamic_container_preserves_input_when_only_its_value_changes
    app = OmarchyUI::Application.new do
      state :name, ""
      panel :main do
        dynamic id: :form do
          column do
            field = text_field "", id: :name do |payload|
              state.name = payload.fetch("value")
            end
            bind(field, :text) { state.name }
          end
        end
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind

    app.receive(event("name", surface: "main", name: "input", payload: { "value" => "A" }))
    refute messages(output).any? { |message| message["type"] == "patch" }
    assert_equal "A", app.state.name
  end

  def test_dynamic_regions_use_independent_generated_id_scopes_when_they_grow
    app = OmarchyUI::Application.new do
      state :items, ["one"]
      panel :main do
        dynamic(id: :first) { state.items.each { |item| text item } }
        dynamic(id: :second) { text "Stable" }
        button("Grow", id: :grow) { state.items = %w[one two three four] }
      end
    end
    output = StringIO.new
    error = StringIO.new
    app.start(output:, error:)
    output.truncate(0)
    output.rewind

    app.receive(event("grow", surface: "main"))
    assert_empty error.string
    assert_equal 4, app.tree.dig("main", "children", 0, "children").length
    assert_equal "second.text.1", app.tree.dig("main", "children", 1, "children", 0, "id")
  end

  def test_imperative_animation_emits_parallel_tracks
    app = OmarchyUI::Application.new do
      panel :main do
        label = text "Animate", id: :label
        button("Go", id: :go) do
          animate label, { opacity: 0.25, scale: 1.2 }, duration: 280, easing: :out_cubic
        end
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind
    app.receive(event("go", surface: "main"))

    patch = messages(output).first
    assert_equal "animate", patch.fetch("op")
    assert_equal %w[opacity scale], patch.fetch("tracks").map { |track| track.fetch("property") }
    assert_equal [1.0, 1.0], patch.fetch("tracks").map { |track| track.fetch("from") }
    assert_equal [0.25, 1.2], patch.fetch("tracks").map { |track| track.fetch("to") }
  end

  def test_text_area_is_a_typed_multiline_value_input
    application = OmarchyUI::Application.new do
      app { text_area "First line\nSecond line", width: 360, height: 160, wrap: :word }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "text_area", node.fetch("type")
    assert_includes node.dig("props", "text"), "Second line"
    assert_equal 360, node.dig("props", "width")
    assert_equal "word", node.dig("props", "wrap")
  ensure
    application&.stop
  end

  def test_search_field_is_a_typed_native_suggestion_input
    application = OmarchyUI::Application.new do
      app { search_field "oma", suggestions: %w[omarchy omarchy-ui], live: true, current_index: 0 }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "search_field", node.fetch("type")
    assert_equal "oma", node.dig("props", "text")
    assert_equal %w[omarchy omarchy-ui], node.dig("props", "suggestions")
    assert_equal true, node.dig("props", "live")
  ensure
    application&.stop
  end

  def test_password_field_is_a_typed_masked_revealable_input
    application = OmarchyUI::Application.new do
      app { password_field "secret", placeholder: "Password", revealable: true, revealed: false }
    end
    output = StringIO.new
    application.start(output: output, error: StringIO.new)
    node = messages(output).find { |message| message["type"] == "render" }.dig("surfaces", "main", "children", 0)

    assert_equal "password_field", node.fetch("type")
    assert_equal "secret", node.dig("props", "text")
    assert_equal true, node.dig("props", "revealable")
    assert_equal false, node.dig("props", "revealed")
  ensure
    application&.stop
  end

  def test_animation_sequences_accumulate_track_delays
    app = OmarchyUI::Application.new do
      panel :main do
        label = text "Pulse", id: :label
        button("Pulse", id: :pulse) do
          animate_sequence label, [
            { to: { scale: 1.2 }, duration: 100, easing: :out_quad },
            { to: { scale: 1.0 }, duration: 150, easing: :in_quad, pause: 25 }
          ]
        end
      end
    end
    output = StringIO.new
    app.start(output: output, error: StringIO.new)
    output.truncate(0)
    output.rewind
    app.receive(event("pulse", surface: "main"))
    tracks = messages(output).first.fetch("tracks")
    assert_equal [0, 100], tracks.map { |track| track.fetch("delay") }
    assert_equal [1.0, 1.2], tracks.map { |track| track.fetch("from") }
  end
end
