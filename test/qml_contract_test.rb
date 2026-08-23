# frozen_string_literal: true

require "minitest/autorun"

class QmlContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def source(name)
    File.read(File.join(ROOT, name))
  end

  def test_service_uses_one_tracked_bidirectional_process_without_a_shell
    qml = source("Service.qml")
    assert_includes qml, "Process {"
    assert_includes qml, "stdinEnabled: true"
    assert_includes qml, "rubyProcess.write(JSON.stringify("
    assert_includes qml, "stdout: SplitParser"
    assert_includes qml, 'pluginDir + "/omarchy-ui-runtime"'
    refute_includes qml, '"ruby",'
    refute_includes qml, "execDetached"
    refute_includes qml, '["bash"'
  end

  def test_renderer_installs_the_ruby_component_registry
    qml = source("Service.qml")
    assert_includes qml, "function validateComponents(components)"
    assert_includes qml, "componentDefinitions = validated"
    assert_includes qml, "allowedTypes = dynamicTypes"
    assert_includes qml, "allowedProperties = dynamicProperties"
    assert_includes qml, "propertyMap: definition.property_map"
    assert_includes qml, "eventMap: definition.event_map"
  end

  def test_round_button_has_a_specific_native_checkable_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "round_button"'
    assert_includes renderer, "id: roundButtonComponent"
    assert_includes renderer, "QQC.RoundButton {"
    assert_includes renderer, '"change", { value: checked }'
  end

  def test_tool_button_has_a_specific_native_toolbar_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "tool_button"'
    assert_includes renderer, "id: toolButtonComponent"
    assert_includes renderer, "QQC.ToolButton {"
    assert_includes renderer, 'nativeToolButton.hovered ? Color.popups.background'
  end

  def test_delay_button_has_a_specific_native_hold_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "delay_button"'
    assert_includes renderer, "id: delayButtonComponent"
    assert_includes renderer, "QQC.DelayButton {"
    assert_includes renderer, '"activate", {}'
    assert_includes renderer, '"progress", { value: progress }'
  end

  def test_native_qml_bridge_maps_properties_events_children_and_animations
    qml = source("ControlNode.qml")
    assert_includes qml, "function syncNativeProperties()"
    assert_includes qml, "function connectNativeEvents()"
    assert_includes qml, "definition.propertyMap[transition.property]"
    assert_includes qml, 'hasOwnProperty("contentHost")'
    assert_includes qml, "delegate: childDelegate"
  end

  def test_panel_exposes_omarchy_loader_lifecycle
    qml = source("Panel.qml")
    assert_match(/function open\(payloadJson\)/, qml)
    assert_match(/function close\(\)/, qml)
    assert_includes qml, "property var service: null"
  end

  def test_application_surface_is_a_compositor_managed_floating_window
    qml = source("App.qml")
    assert_includes qml, "FloatingWindow {"
    assert_includes qml, "window.startSystemMove()"
    assert_includes qml, "Qt.quit()"
    refute_includes qml, "PanelWindow {"
    refute_includes qml, "WlrLayershell"
    assert_includes qml, 'root.option("title"'
    assert_includes qml, 'root.option("min_width"'
  end

  def test_renderer_supports_validated_native_property_animations
    renderer = source("ControlNode.qml")
    service = source("Service.qml")
    assert_includes renderer, "id: propertyAnimationFactory"
    assert_includes renderer, "function easingType(name)"
    assert_includes service, 'return reject("patch animation rejected")'
    assert_includes service, "replacement.transition"
  end

  def test_component_lifecycle_events_require_explicit_subscriptions
    renderer = source("ControlNode.qml")
    service = source("Service.qml")
    assert_includes renderer, 'subscribed("mount")'
    assert_includes renderer, 'subscribed("unmount")'
    assert_includes service, "subscriptions.indexOf(eventName) < 0"
  end

  def test_renderer_uses_runtime_recursion_and_qualified_omarchy_types
    renderer = source("ControlNode.qml")
    panel = source("Panel.qml")
    refute_match(/^\s+ControlNode \{$/, renderer)
    assert_includes renderer, 'source: Qt.resolvedUrl("ControlNode.qml")'
    assert_includes renderer, "OmarchyUi.BorderSurface {"
    assert_includes panel, "OmarchyUi.BorderSurface {"
  end

  def test_aspect_ratio_has_a_specific_reactive_container_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "aspect_ratio"'
    assert_includes renderer, "id: aspectRatioComponent"
    assert_includes renderer, 'Number(requestedWidth) / aspect'
    assert_includes renderer, "Repeater { model: root.node.children || []; delegate: childDelegate }"
  end

  def test_constrained_box_has_a_specific_bounded_container_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "constrained_box"'
    assert_includes renderer, "id: constrainedBoxComponent"
    assert_includes renderer, 'root.prop("min_width", 0)'
    assert_includes renderer, 'root.prop("max_height", Number.MAX_VALUE)'
  end

  def test_fitted_box_has_a_specific_scaling_container_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "fitted_box"'
    assert_includes renderer, "id: fittedBoxComponent"
    assert_includes renderer, 'fitMode === "cover"'
    assert_includes renderer, "Scale { xScale: fittedXScale; yScale: fittedYScale }"
  end

  def test_wrap_has_a_specific_responsive_flow_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "wrap"'
    assert_includes renderer, "id: wrapComponent"
    assert_includes renderer, 'root.prop("layout_direction", "left_to_right")'
    assert_includes renderer, "Flow.TopToBottom : Flow.LeftToRight"
  end

  def test_split_view_has_a_specific_native_resizable_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "split_view"'
    assert_includes renderer, "id: splitViewComponent"
    assert_includes renderer, "QQC.SplitView {"
    assert_includes renderer, '"resize", { sizes: currentSizes() }'
    assert_includes renderer, "QQC.SplitView.preferredWidth"
  end

  def test_stack_layout_has_a_specific_native_indexed_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "stack_layout"'
    assert_includes renderer, "id: stackLayoutComponent"
    assert_includes renderer, "StackLayout {"
    assert_includes renderer, 'root.prop("current_index", 0)'
  end

  def test_loader_has_a_specific_lazy_native_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "loader"'
    assert_includes renderer, "id: lazyLoaderComponent"
    assert_includes renderer, 'source: active ? Qt.resolvedUrl("ControlNode.qml") : ""'
    assert_includes renderer, 'root.subscribed("loaded")'
  end

  def test_flickable_has_a_specific_native_kinetic_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "flickable"'
    assert_includes renderer, "id: flickableComponent"
    assert_includes renderer, "Flickable.HorizontalAndVerticalFlick"
    assert_includes renderer, '"flick_end", positionPayload()'
  end

  def test_focus_scope_has_a_specific_native_focus_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "focus_scope"'
    assert_includes renderer, "id: focusScopeComponent"
    assert_includes renderer, "FocusScope {"
    assert_includes renderer, "forceActiveFocus()"
  end

  def test_flipable_has_a_specific_native_two_face_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "flipable"'
    assert_includes renderer, "id: flipableComponent"
    assert_includes renderer, "Flipable {"
    assert_includes renderer, "Behavior on angle"
    assert_includes renderer, "root.configureFace(item, root.node.children[1])"
  end

  def test_border_image_has_a_specific_native_nine_slice_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "border_image"'
    assert_includes renderer, "id: borderImageComponent"
    assert_includes renderer, "BorderImage {"
    assert_includes renderer, 'border.left: Number(root.prop("border_left", 0))'
    assert_includes renderer, "BorderImage.Round"
  end

  def test_label_has_a_specific_native_styled_text_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "label"'
    assert_includes renderer, "id: labelComponent"
    assert_includes renderer, "QQC.Label {"
    assert_includes renderer, "Text.MarkdownText"
    assert_includes renderer, '"link", { value: link }'
  end

  def test_rich_text_has_an_explicit_native_markup_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "rich_text"'
    assert_includes renderer, "id: richTextComponent"
    assert_includes renderer, "textFormat: Text.RichText"
    assert_includes renderer, "linkColor: root.prop"
  end

  def test_markdown_has_a_specific_native_document_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "markdown"'
    assert_includes renderer, "id: markdownComponent"
    assert_includes renderer, "textFormat: Text.MarkdownText"
    assert_includes renderer, 'baseUrl: String(root.prop("base_url", ""))'
  end

  def test_selectable_text_has_a_specific_native_selection_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "selectable_text"'
    assert_includes renderer, "id: selectableTextComponent"
    assert_includes renderer, "selectByMouse: true"
    assert_includes renderer, '"selection", {'
  end

  def test_animated_image_has_a_specific_native_playback_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "animated_image"'
    assert_includes renderer, "id: animatedImageComponent"
    assert_includes renderer, "AnimatedImage {"
    assert_includes renderer, 'root.prop("speed", 1)'
    assert_includes renderer, '"frame", { value: currentFrame, count: frameCount }'
  end

  def test_vector_image_has_a_specific_native_svg_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, "import QtQuick.VectorImage"
    assert_includes renderer, 'node.type === "vector_image"'
    assert_includes renderer, "id: vectorImageComponent"
    assert_includes renderer, "VectorImage.CurveRenderer"
    assert_includes renderer, "animations.paused"
  end

  def test_font_loader_has_a_specific_native_resource_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "font_loader"'
    assert_includes renderer, "id: fontLoaderComponent"
    assert_includes renderer, "FontLoader {"
    assert_includes renderer, '"loaded", { name: name }'
  end

  def test_text_metrics_has_a_specific_native_measurement_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "text_metrics"'
    assert_includes renderer, "id: textMetricsComponent"
    assert_includes renderer, "TextMetrics {"
    assert_includes renderer, "advance_width: advanceWidth"
    assert_includes renderer, "tight_bounding_rect:"
  end

  def test_video_has_a_specific_native_multimedia_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, "import QtMultimedia"
    assert_includes renderer, 'node.type === "video"'
    assert_includes renderer, "id: videoComponent"
    assert_includes renderer, "VideoOutput.PreserveAspectCrop"
    assert_includes renderer, '"position", { value: position, duration: duration }'
  end

  def test_audio_has_a_specific_native_media_player_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "audio"'
    assert_includes renderer, "id: audioComponent"
    assert_includes renderer, "MediaPlayer {"
    assert_includes renderer, "audioOutput: AudioOutput {"
    assert_includes renderer, 'requested === "pause"'
  end

  def test_avatar_has_a_specific_image_and_initials_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "avatar"'
    assert_includes renderer, "id: avatarComponent"
    assert_includes renderer, "id: avatarImage"
    assert_includes renderer, "Image.PreserveAspectCrop"
    assert_includes renderer, ").toUpperCase()"
  end

  def test_badge_has_a_specific_value_and_dot_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "badge"'
    assert_includes renderer, "id: badgeComponent"
    assert_includes renderer, 'String(maximum) + "+"'
    assert_includes renderer, 'root.prop("dot", false)'
  end

  def test_chip_has_a_specific_selectable_and_deletable_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "chip"'
    assert_includes renderer, "id: chipComponent"
    assert_includes renderer, 'root.prop("deletable", false)'
    assert_includes renderer, '"delete", {}'
    assert_includes renderer, '"change", { value: !chipRoot.selected }'
  end

  def test_divider_has_a_specific_oriented_line_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "divider"'
    assert_includes renderer, "id: dividerComponent"
    assert_includes renderer, 'root.prop("end_indent", 0)'
    assert_includes renderer, "parent.vertical ? parent.lineThickness"
  end

  def test_service_validates_structural_child_patches
    service = source("Service.qml")
    assert_includes service, 'message.op === "replace_children"'
    assert_includes service, 'return reject("invalid children patch")'
    assert_includes service, "validateNode(message.children[childIndex]"
  end

  def test_service_and_renderer_support_composed_animation_tracks
    service = source("Service.qml")
    renderer = source("ControlNode.qml")
    assert_includes service, 'message.op === "animate"'
    assert_includes service, "message.tracks.length > 64"
    assert_includes renderer, "propertyAnimationFactory.createObject"
    assert_includes renderer, "delayedAnimationFactory.createObject"
  end

  def test_reactive_patch_preserves_event_subscriptions
    service = File.read(File.join(ROOT, "Service.qml"))

    assert_includes service, "if (node.events !== undefined) replacement.events = node.events"
  end

  def test_rows_and_columns_apply_cross_axis_alignment
    renderer = source("ControlNode.qml")

    assert_includes renderer, "delegate: rowChildDelegate"
    assert_includes renderer, 'root.prop("alignment", "center")'
    assert_includes renderer, "anchors.verticalCenter"
    assert_includes renderer, "delegate: columnChildDelegate"
    assert_includes renderer, "anchors.horizontalCenter"
  end

  def test_responsive_layouts_and_named_icons_are_native_built_ins
    renderer = source("ControlNode.qml")

    assert_includes renderer, "import QtQuick.Layouts"
    assert_includes renderer, 'node.type === "row_layout"'
    assert_includes renderer, 'node.type === "column_layout"'
    assert_includes renderer, 'node.type === "grid_layout"'
    assert_includes renderer, 'node.type === "flow"'
    assert_includes renderer, 'node.type === "card"'
    assert_includes renderer, "Layout.fillWidth"
    assert_includes renderer, 'root.structuralContainer && root.subscribed("click")'
    assert_includes renderer, 'phone: "\\uf3cd"'
    assert_includes renderer, 'android: "\\uf17b"'
    assert_includes renderer, 'color: root.prop("color", root.foreground)'
  end

  def test_tooltip_uses_the_native_omarchy_panel_tooltip
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "tooltip"'
    assert_includes renderer, "OmarchyUi.PanelToolTip"
    assert_includes renderer, 'panelBackground: root.prop("background", Color.tooltip.background)'
  end

  def test_bar_icon_button_uses_native_optical_bar_control
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "bar_icon_button"'
    assert_includes renderer, "OmarchyUi.BarIconButton"
    assert_includes renderer, 'slotSize: Number(root.prop("slot_size", Style.bar.iconSlot))'
    assert_includes renderer, '"middle_click"'
    assert_includes renderer, "onWheelMoved: function(delta)"
    assert_includes renderer, "onPressed: function(button)"
    refute_match(/OmarchyUi\.(?:BarIconButton|BarIndicator)\s*\{[^}]*on(?:Wheel|Clicked|RightClicked|MiddleClicked):/m, renderer)
  end

  def test_bar_indicator_uses_native_active_inactive_control
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "bar_indicator"'
    assert_includes renderer, "OmarchyUi.BarIndicator"
    assert_includes renderer, 'activeText: root.iconGlyph(root.prop("active_icon", ""))'
    assert_includes renderer, 'indicatorBlock: String(root.prop("indicator_block", "single"))'
  end

  def test_border_overlay_uses_native_gradient_border_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "border_overlay"'
    assert_includes renderer, "OmarchyUi.BorderOverlay"
    assert_includes renderer, 'gradient: { colors: colors, angle: Number(root.prop("gradient_angle", 0)), enabled: true }'
  end

  def test_key_catcher_maps_all_native_keyboard_signals
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "key_catcher"'
    assert_includes renderer, "OmarchyUi.PanelKeyCatcher"
    assert_includes renderer, '"move", { dx: dx, dy: dy }'
    assert_includes renderer, '"tab", { direction: direction }'
    assert_includes renderer, '"text", { text: text }'
  end

  def test_checkbox_has_omarchy_styling_and_value_event
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "checkbox"'
    assert_includes renderer, "QQC.CheckBox"
    assert_includes renderer, 'root.iconGlyph("check")'
    assert_includes renderer, '"change", { value: checked }'
  end

  def test_radio_button_has_a_specific_native_selection_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "radio_button"'
    assert_includes renderer, "id: radioButtonComponent"
    assert_includes renderer, "QQC.RadioButton {"
    assert_includes renderer, 'option: root.prop("value", null)'
  end

  def test_radio_group_has_a_specific_native_exclusive_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "radio_group"'
    assert_includes renderer, "id: radioGroupComponent"
    assert_includes renderer, "QQC.ButtonGroup { id: exclusiveRadioGroup }"
    assert_includes renderer, "QQC.ButtonGroup.group: exclusiveRadioGroup"
    assert_includes renderer, '"change", { value: optionValue, index: index }'
  end

  def test_line_chart_has_a_specific_canvas_renderer_and_events
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "line_chart"'
    assert_includes renderer, "id: lineChartComponent"
    assert_includes renderer, 'root.prop("fill_color", "")'
    assert_includes renderer, '"select", payload(mouse)'
    assert_includes renderer, '"hover", payload(mouse)'
  end

  def test_bar_chart_has_a_specific_canvas_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "bar_chart"'
    assert_includes renderer, "id: barChartComponent"
    assert_includes renderer, 'ctx.fillRect(left, top, Math.max(1, slot - gap), barHeight)'
  end

  def test_area_chart_has_a_specific_canvas_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "area_chart"'
    assert_includes renderer, "id: areaChartComponent"
    assert_includes renderer, 'ctx.fillStyle = root.prop("fill_color", root.prop("color", Color.accent))'
  end

  def test_bridge_bounds_values_and_renders_external_text_as_plain_text
    service = source("Service.qml")
    renderer = source("ControlNode.qml")

    assert_includes service, "function boundedValue(value, depth)"
    assert_includes service, "maxStringLength: 16384"
    assert_operator renderer.scan("textFormat: Text.PlainText").length, :>=, 2
    assert_includes renderer, "function escapeAutoText(value)"
    assert_includes renderer, 'tooltipText: root.escapeAutoText(root.prop("tooltip", ""))'
  end

  def test_text_area_has_a_specific_native_multiline_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "text_area"'
    assert_includes renderer, "id: textAreaComponent"
    assert_includes renderer, "QQC.TextArea {"
    assert_includes renderer, '"selection", { start: selectionStart'
  end

  def test_search_field_has_a_specific_native_suggestion_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "search_field"'
    assert_includes renderer, "id: searchFieldComponent"
    assert_includes renderer, "QQC.SearchField {"
    assert_includes renderer, 'suggestionModel: root.prop("suggestions", [])'
    assert_includes renderer, '"search", { value: text }'
  end

  def test_password_field_has_a_specific_masked_reveal_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "password_field"'
    assert_includes renderer, "id: passwordFieldComponent"
    assert_includes renderer, "password: !passwordRoot.revealState"
    assert_includes renderer, '"reveal", { value: passwordRoot.revealState }'
  end

  def test_range_slider_has_a_specific_native_two_handle_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "range_slider"'
    assert_includes renderer, "id: rangeSliderComponent"
    assert_includes renderer, "QQC.RangeSlider {"
    assert_includes renderer, "first.onMoved:"
    assert_includes renderer, "return { lower: first.value, upper: second.value }"
  end
end
