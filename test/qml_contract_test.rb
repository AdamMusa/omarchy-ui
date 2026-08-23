# frozen_string_literal: true

require "minitest/autorun"

class QmlContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def source(name)
    contents = File.read(File.join(ROOT, name))
    return contents unless name == "ControlNode.qml"

    extracted = Dir[File.join(ROOT, "Components", "Builtins", "*.qml")].sort.map do |path|
      File.read(path)
        .gsub(/\brenderer\./, "root.")
        .gsub("root.childDelegateComponent", "childDelegate")
        .gsub("root.rowChildDelegateComponent", "rowChildDelegate")
        .gsub("root.columnChildDelegateComponent", "columnChildDelegate")
        .gsub("root.layoutChildDelegateComponent", "layoutChildDelegate")
        .gsub("root.splitChildDelegateComponent", "splitChildDelegate")
        .gsub('../../ControlNode.qml', 'ControlNode.qml')
    end
    ([contents] + extracted).join("\n")
  end

  def test_each_builtin_renderer_lives_in_its_own_qml_file
    router = File.read(File.join(ROOT, "ControlNode.qml"))
    renderer_names = router.scan(/Builtins\.(\w+) \{ renderer: root \}/).flatten

    assert_equal 114, renderer_names.length
    assert_equal renderer_names.uniq.sort, renderer_names.sort
    renderer_names.each do |name|
      path = File.join(ROOT, "Components", "Builtins", "#{name}.qml")
      assert File.file?(path), "missing #{path}"
      assert_includes File.read(path), "required property var renderer"
    end
    refute_includes router, "QQC.Button {"
    refute_includes router, "OmarchyUi.WidgetButton {"
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

  def test_layout_item_proxy_has_a_specific_native_layout_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "layout_item_proxy"'
    assert_includes renderer, "id: layoutItemProxyComponent"
    assert_includes renderer, "LayoutItemProxy {"
    assert_includes renderer, "root.findRenderedItem(targetId)"
    assert_includes renderer, "Layout.preferredWidth"
    assert_includes renderer, '"target_change", {'
  end

  def test_window_has_a_specific_native_secondary_window_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "window"'
    assert_includes renderer, "id: windowComponent"
    assert_includes renderer, "Window {"
    assert_includes renderer, 'root.prop("modality", "none")'
    assert_includes renderer, 'root.prop("flags", "window")'
    assert_includes renderer, '"close", {'
    assert_includes renderer, "delegate: childDelegate"
  end

  def test_application_window_has_a_specific_controls_window_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "application_window"'
    assert_includes renderer, "id: applicationWindowComponent"
    assert_includes renderer, "QQC.ApplicationWindow {"
    assert_includes renderer, 'root.prop("background", "transparent")'
    assert_includes renderer, "onActiveFocusControlChanged"
    assert_includes renderer, '"focus_change", {'
    assert_includes renderer, "delegate: childDelegate"
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

  def test_dial_has_a_specific_native_angular_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "dial"'
    assert_includes renderer, "id: dialComponent"
    assert_includes renderer, "QQC.Dial {"
    assert_includes renderer, "QQC.Dial.Circular"
    assert_includes renderer, '"input", { value: value, angle: angle }'
  end

  def test_spin_box_has_a_specific_native_integer_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "spin_box"'
    assert_includes renderer, "id: spinBoxComponent"
    assert_includes renderer, "QQC.SpinBox {"
    assert_includes renderer, "textFromValue: function(value, locale)"
    assert_includes renderer, '"increase", { value: value }'
  end

  def test_double_spin_box_has_a_specific_native_floating_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "double_spin_box"'
    assert_includes renderer, "id: doubleSpinBoxComponent"
    assert_includes renderer, "QQC.DoubleSpinBox {"
    assert_includes renderer, 'root.prop("decimals", 2)'
    assert_includes renderer, 'Number(value).toLocaleString(locale, "f", decimals)'
  end

  def test_color_picker_has_a_specific_native_dialog_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "color_picker"'
    assert_includes renderer, "id: colorPickerComponent"
    assert_includes renderer, "ColorDialog {"
    assert_includes renderer, 'selectedColor: root.prop("color", "#ffffff")'
    assert_includes renderer, "ColorDialog.ShowAlphaChannel"
    assert_includes renderer, '"input", {'
    assert_includes renderer, '"change", { value: value }'
    assert_includes renderer, '"accept", { value: value }'
    assert_includes renderer, '"reject", {'
  end

  def test_date_picker_has_a_specific_native_calendar_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "date_picker"'
    assert_includes renderer, "id: datePickerComponent"
    assert_includes renderer, "Basic.MonthGrid {"
    assert_includes renderer, 'root.prop("minimum", "")'
    assert_includes renderer, 'root.prop("maximum", "")'
    assert_includes renderer, '"input", { value: value }'
    assert_includes renderer, '"change", { value: value }'
    assert_includes renderer, '"navigate", {'
  end

  def test_time_picker_has_a_specific_native_spin_control_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "time_picker"'
    assert_includes renderer, "id: timePickerComponent"
    assert_includes renderer, "QQC.SpinBox {"
    assert_includes renderer, 'root.prop("use_24_hour", true)'
    assert_includes renderer, 'root.prop("show_seconds", false)'
    assert_includes renderer, '"input", { value: value }'
    assert_includes renderer, '"change", { value: value }'
    assert_includes renderer, '"accept", { value: value }'
    assert_includes renderer, '"reject", {'
    assert_includes renderer, "value: picker.formattedTime()"
  end

  def test_file_picker_has_specific_native_file_and_folder_dialog_renderers
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "file_picker"'
    assert_includes renderer, "id: filePickerComponent"
    assert_includes renderer, "FileDialog {"
    assert_includes renderer, "FolderDialog {"
    assert_includes renderer, "FileDialog.OpenFiles"
    assert_includes renderer, "FileDialog.SaveFile"
    assert_includes renderer, 'root.prop("filters", [])'
    assert_includes renderer, '"change", payload'
    assert_includes renderer, '"folder_change", { value: value }'
  end

  def test_folder_picker_has_a_specific_native_directory_dialog_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "folder_picker"'
    assert_includes renderer, "id: folderPickerComponent"
    assert_includes renderer, "FolderDialog {"
    assert_includes renderer, 'root.prop("current_folder", root.prop("path", ""))'
    assert_includes renderer, "FolderDialog.DontUseNativeDialog"
    assert_includes renderer, '"input", payload'
    assert_includes renderer, '"change", payload'
    assert_includes renderer, '"folder_change", { value: value }'
  end

  def test_font_picker_has_a_specific_native_font_dialog_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "font_picker"'
    assert_includes renderer, "id: fontPickerComponent"
    assert_includes renderer, "FontDialog {"
    assert_includes renderer, "Qt.font(specification)"
    assert_includes renderer, "family: value.family"
    assert_includes renderer, 'root.prop("point_size", -1)'
    assert_includes renderer, '"input", picker.fontPayload(selectedFont)'
    assert_includes renderer, '"change", payload'
    assert_includes renderer, '"accept", payload'
  end

  def test_dialog_button_box_has_a_specific_native_role_aware_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "dialog_button_box"'
    assert_includes renderer, "id: dialogButtonBoxComponent"
    assert_includes renderer, "QQC.DialogButtonBox {"
    assert_includes renderer, "standardButtons: standardButtonsValue"
    assert_includes renderer, "QQC.DialogButtonBox.buttonRole: box.roleValue"
    assert_includes renderer, "ListView.Vertical : ListView.Horizontal"
    assert_includes renderer, 'root.prop("custom_buttons", [])'
    assert_includes renderer, '"click", box.buttonPayload(button)'
    assert_includes renderer, '"accept", {}'
    assert_includes renderer, '"reject", {}'
    assert_includes renderer, '"help", {}'
  end

  def test_action_has_a_specific_native_nonvisual_command_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "action"'
    assert_includes renderer, "id: actionComponent"
    assert_includes renderer, "QQC.Action {"
    assert_includes renderer, "property alias nativeAction: nativeAction"
    assert_includes renderer, 'shortcut: root.prop("shortcut", "")'
    assert_includes renderer, 'icon.name: String(root.prop("icon", ""))'
    assert_includes renderer, '"trigger", actionRoot.payload()'
    assert_includes renderer, '"toggle", actionRoot.payload()'
    assert_includes renderer, '"change", actionRoot.payload()'
  end

  def test_action_group_resolves_ruby_action_nodes_into_a_native_group
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "action_group"'
    assert_includes renderer, "id: actionGroupComponent"
    assert_includes renderer, "QQC.ActionGroup {"
    assert_includes renderer, 'root.prop("action_ids", [])'
    assert_includes renderer, "root.findRenderedItem(actionId)"
    assert_includes renderer, "nativeGroup.addAction(rendered.nativeAction)"
    assert_includes renderer, "nativeGroup.removeAction(attached[index].action)"
    assert_includes renderer, '"trigger", groupRoot.actionPayload(action)'
    assert_includes renderer, '"change", groupRoot.actionPayload(checkedAction)'
    assert_includes renderer, '"actions_change", {'
    assert_includes renderer, "values: attachedIds()"
  end

  def test_page_has_a_specific_native_navigation_container_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "page"'
    assert_includes renderer, "id: pageComponent"
    assert_includes renderer, "QQC.Page {"
    assert_includes renderer, 'title: String(root.prop("title", ""))'
    assert_includes renderer, 'root.prop("header_text", pageRoot.title)'
    assert_includes renderer, 'root.prop("footer_text", "")'
    assert_includes renderer, "delegate: childDelegate"
    assert_includes renderer, 'visible ? "show" : "hide"'
    assert_includes renderer, 'activeFocus ? "focus" : "blur"'
    assert_includes renderer, '"title_change", { value: title }'
  end

  def test_pane_has_a_specific_native_content_surface_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "pane"'
    assert_includes renderer, "id: paneComponent"
    assert_includes renderer, "QQC.Pane {"
    assert_includes renderer, 'root.prop("left_padding", padding)'
    assert_includes renderer, 'root.prop("right_padding", padding)'
    assert_includes renderer, 'root.prop("top_padding", padding)'
    assert_includes renderer, 'root.prop("bottom_padding", padding)'
    assert_includes renderer, 'root.prop("layout_direction", "left_to_right")'
    assert_includes renderer, "delegate: childDelegate"
    assert_includes renderer, 'visible ? "show" : "hide"'
    assert_includes renderer, 'activeFocus ? "focus" : "blur"'
  end

  def test_frame_has_a_specific_native_bordered_container_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "frame"'
    assert_includes renderer, "id: frameComponent"
    assert_includes renderer, "QQC.Frame {"
    assert_includes renderer, 'root.prop("border_width", Style.normalBorderWidth)'
    assert_includes renderer, 'root.prop("border_color", Color.border)'
    assert_includes renderer, 'root.prop("left_padding", padding)'
    assert_includes renderer, 'root.prop("layout_direction", "left_to_right")'
    assert_includes renderer, "delegate: childDelegate"
    assert_includes renderer, 'visible ? "show" : "hide"'
    assert_includes renderer, 'activeFocus ? "focus" : "blur"'
  end

  def test_group_box_has_a_specific_native_titled_container_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "group_box"'
    assert_includes renderer, "id: groupBoxComponent"
    assert_includes renderer, "QQC.GroupBox {"
    assert_includes renderer, 'title: String(root.prop("title", ""))'
    assert_includes renderer, 'root.prop("title_alignment", "left")'
    assert_includes renderer, 'root.prop("top_padding", padding + titleLabel.implicitHeight + Style.spacing.sm)'
    assert_includes renderer, 'root.prop("border_color", Color.border)'
    assert_includes renderer, "delegate: childDelegate"
    assert_includes renderer, '"title_change", { value: title }'
  end

  def test_tabs_has_a_specific_native_bar_and_stack_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "tabs"'
    assert_includes renderer, "id: tabsComponent"
    assert_includes renderer, "QQC.TabBar {"
    assert_includes renderer, "QQC.TabButton {"
    assert_includes renderer, "StackLayout {"
    assert_includes renderer, 'root.prop("labels", [])'
    assert_includes renderer, 'root.prop("current_index", 0)'
    assert_includes renderer, 'root.prop("position", "top")'
    assert_includes renderer, "delegate: layoutChildDelegate"
    assert_includes renderer, '"tab_click", { value: index, label: text }'
    assert_includes renderer, '"input", { value: currentIndex }'
    assert_includes renderer, '"change", { value: currentIndex }'
  end

  def test_tab_bar_has_a_specific_native_selection_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "tab_bar"'
    assert_includes renderer, "id: tabBarComponent"
    assert_includes renderer, "QQC.TabBar {"
    assert_includes renderer, "QQC.TabButton {"
    assert_includes renderer, 'root.prop("items", [])'
    assert_includes renderer, 'root.prop("current_index", 0)'
    assert_includes renderer, 'root.prop("position", "top")'
    assert_includes renderer, 'itemValue(index, "enabled", true)'
    assert_includes renderer, 'itemValue(index, "icon", "")'
    assert_includes renderer, '"tab_click", { value: index, label: text }'
    assert_includes renderer, '"input", { value: currentIndex }'
    assert_includes renderer, '"change", { value: currentIndex }'
  end

  def test_tab_button_has_a_specific_native_button_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "tab_button"'
    assert_includes renderer, "id: tabButtonComponent"
    assert_includes renderer, "QQC.TabButton {"
    assert_includes renderer, 'checked: root.prop("checked", false) === true'
    assert_includes renderer, 'autoExclusive: root.prop("auto_exclusive", true) !== false'
    assert_includes renderer, "Shortcut {"
    assert_includes renderer, 'sequence: String(root.prop("shortcut", ""))'
    assert_includes renderer, 'root.iconGlyph(root.prop("icon", ""))'
    assert_includes renderer, '"click",'
    assert_includes renderer, '"toggle", payload'
    assert_includes renderer, '"change", payload'
    assert_includes renderer, '"hover", { value: hovered }'
  end

  def test_page_indicator_has_a_specific_native_paging_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "page_indicator"'
    assert_includes renderer, "id: pageIndicatorComponent"
    assert_includes renderer, "QQC.PageIndicator {"
    assert_includes renderer, 'count: Math.max(0, Number(root.prop("count", 0)))'
    assert_includes renderer, 'root.prop("current_index", 0)'
    assert_includes renderer, 'interactive: root.prop("interactive", false) === true'
    assert_includes renderer, 'root.prop("dot_size", 8)'
    assert_includes renderer, 'index === indicatorRoot.currentIndex'
    assert_includes renderer, '"input", { value: currentIndex }'
    assert_includes renderer, '"change", { value: currentIndex }'
  end

  def test_stack_view_has_a_specific_native_push_pop_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "stack_view"'
    assert_includes renderer, "id: stackViewComponent"
    assert_includes renderer, "QQC.StackView {"
    assert_includes renderer, 'root.prop("current_index", 0)'
    assert_includes renderer, "childDelegate.createObject"
    assert_includes renderer, "push(page, {}, operationFor(target))"
    assert_includes renderer, "pop(operationFor(target)"
    assert_includes renderer, "clear(QQC.StackView.Immediate)"
    assert_includes renderer, '"push",'
    assert_includes renderer, '"pop",'
    assert_includes renderer, '"depth_change",'
    assert_includes renderer, '"busy_change", { value: busy }'
    assert_includes renderer, '"change",'
  end

  def test_swipe_view_has_a_specific_native_gesture_paging_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "swipe_view"'
    assert_includes renderer, "id: swipeViewComponent"
    assert_includes renderer, "QQC.SwipeView {"
    assert_includes renderer, 'root.prop("current_index", 0)'
    assert_includes renderer, 'interactive: root.prop("interactive", true) !== false'
    assert_includes renderer, 'root.prop("orientation", "horizontal")'
    assert_includes renderer, "delegate: childDelegate"
    assert_includes renderer, '"input", { value: currentIndex }'
    assert_includes renderer, '"change", { value: currentIndex }'
    assert_includes renderer, '"count_change", { value: count }'
  end

  def test_drawer_has_a_specific_native_edge_popup_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "drawer"'
    assert_includes renderer, "id: drawerComponent"
    assert_includes renderer, "QQC.Drawer {"
    assert_includes renderer, 'root.prop("opened", false) === true'
    assert_includes renderer, 'edgeValue(root.prop("edge", "left"))'
    assert_includes renderer, 'modal: root.prop("modal", true) !== false'
    assert_includes renderer, 'interactive: root.prop("interactive", true) !== false'
    assert_includes renderer, 'closePolicyValue(root.prop("close_policy", "escape_and_outside"))'
    assert_includes renderer, "delegate: childDelegate"
    assert_includes renderer, '"open",'
    assert_includes renderer, '"close",'
    assert_includes renderer, '"about_to_show", {}'
    assert_includes renderer, '"about_to_hide", {}'
    assert_includes renderer, '"position_change", { value: position }'
  end

  def test_navigation_rail_has_a_specific_native_destination_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "navigation_rail"'
    assert_includes renderer, "id: navigationRailComponent"
    assert_includes renderer, "QQC.Pane {"
    assert_includes renderer, "QQC.ToolButton {"
    assert_includes renderer, 'root.prop("items", [])'
    assert_includes renderer, 'root.prop("current_index", 0)'
    assert_includes renderer, 'root.prop("extended", false) === true'
    assert_includes renderer, 'itemValue(index, "enabled", true)'
    assert_includes renderer, 'itemValue(index, "icon_source", "")'
    assert_includes renderer, '"select",'
    assert_includes renderer, '"input", { value: currentIndex }'
    assert_includes renderer, '"change", { value: currentIndex }'
  end

  def test_breadcrumb_has_a_specific_native_trail_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "breadcrumb"'
    assert_includes renderer, "id: breadcrumbComponent"
    assert_includes renderer, "QQC.Pane {"
    assert_includes renderer, "QQC.ToolButton {"
    assert_includes renderer, 'root.prop("items", [])'
    assert_includes renderer, 'root.prop("current_index",'
    assert_includes renderer, 'itemValue(index, "value", itemLabel(index))'
    assert_includes renderer, 'itemValue(index, "enabled", true)'
    assert_includes renderer, 'root.prop("separator", "chevron_right")'
    assert_includes renderer, '"select", breadcrumbRoot.itemPayload(index)'
    assert_includes renderer, '"input", payload'
    assert_includes renderer, '"change", payload'
  end

  def test_pagination_has_a_specific_native_bounded_page_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "pagination"'
    assert_includes renderer, "id: paginationComponent"
    assert_includes renderer, "QQC.Pane {"
    assert_includes renderer, "QQC.ToolButton {"
    assert_includes renderer, 'root.prop("count", 0)'
    assert_includes renderer, 'root.prop("page", 1)'
    assert_includes renderer, 'root.prop("sibling_count", 1)'
    assert_includes renderer, "result.push(0)"
    assert_includes renderer, 'root.prop("show_previous_next", true)'
    assert_includes renderer, 'root.prop("show_first_last", false)'
    assert_includes renderer, '"previous"'
    assert_includes renderer, '"next"'
    assert_includes renderer, '"select", payload'
    assert_includes renderer, '"change", payload'
  end

  def test_expansion_panel_has_a_specific_native_reveal_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "expansion_panel"'
    assert_includes renderer, "id: expansionPanelComponent"
    assert_includes renderer, "QQC.Control {"
    assert_includes renderer, "QQC.ToolButton {"
    assert_includes renderer, 'root.prop("expanded", false) === true'
    assert_includes renderer, 'root.prop("title", "")'
    assert_includes renderer, 'root.prop("subtitle", "")'
    assert_includes renderer, "Behavior on height"
    assert_includes renderer, 'root.easingType(root.prop("easing", "in_out_quad"))'
    assert_includes renderer, "delegate: childDelegate"
    assert_includes renderer, '"toggle", payload'
    assert_includes renderer, '"change", payload'
    assert_includes renderer, 'expanded ? "expand" : "collapse"'
  end

  def test_accordion_has_a_specific_native_multi_section_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "accordion"'
    assert_includes renderer, "id: accordionComponent"
    assert_includes renderer, "QQC.Control {"
    assert_includes renderer, "QQC.ToolButton {"
    assert_includes renderer, 'root.prop("titles", [])'
    assert_includes renderer, 'root.prop("expanded_indices", [])'
    assert_includes renderer, 'root.prop("multiple", false)'
    assert_includes renderer, 'source: Qt.resolvedUrl("ControlNode.qml")'
    assert_includes renderer, 'item.controlId = String(root.node.children[sectionRoot.index].id)'
    assert_includes renderer, "Behavior on height"
    assert_includes renderer, '"toggle", payload'
    assert_includes renderer, '"change", payload'
    assert_includes renderer, 'opening ? "expand" : "collapse"'
  end

  def test_tool_bar_has_a_specific_native_container_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "tool_bar"'
    assert_includes renderer, "id: toolBarComponent"
    assert_includes renderer, "QQC.ToolBar {"
    assert_includes renderer, 'root.prop("position", "header")'
    assert_includes renderer, "QQC.ToolBar.Footer"
    assert_includes renderer, 'root.prop("layout", "row")'
    assert_includes renderer, "delegate: childDelegate"
    assert_includes renderer, '"position_change",'
    assert_includes renderer, '"footer" : "header"'
    assert_includes renderer, '"click", {}'
  end

  def test_tool_separator_has_a_specific_native_separator_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "tool_separator"'
    assert_includes renderer, "id: toolSeparatorComponent"
    assert_includes renderer, "QQC.ToolSeparator {"
    assert_includes renderer, 'root.prop("orientation", "vertical")'
    assert_includes renderer, 'orientation: String(root.prop("orientation", "vertical")) === "vertical"'
    assert_includes renderer, 'root.prop("thickness", 1)'
    assert_includes renderer, 'root.prop("length", 32)'
    assert_includes renderer, 'root.prop("padding", 8)'
    assert_includes renderer, 'root.prop("color", root.foreground)'
    assert_includes renderer, 'visible ? "show" : "hide"'
  end

  def test_menu_has_a_specific_native_popup_entry_renderer
    renderer = source("ControlNode.qml")

    assert_includes renderer, 'node.type === "menu"'
    assert_includes renderer, "id: menuComponent"
    assert_includes renderer, "QQC.Menu {"
    assert_includes renderer, "QQC.MenuItem {"
    assert_includes renderer, "QQC.MenuSeparator {"
    assert_includes renderer, 'root.prop("items", [])'
    assert_includes renderer, 'root.prop("opened", false) === true'
    assert_includes renderer, "Instantiator {"
    assert_includes renderer, "DelegateChooser {"
    assert_includes renderer, "menuRoot.insertItem(index, object)"
    assert_includes renderer, "menuRoot.removeItem(object)"
    assert_includes renderer, 'entryValue(modelData, "checkable", false)'
    assert_includes renderer, 'entryValue(modelData, "checked", false)'
    assert_includes renderer, '"trigger", menuRoot.entryPayload(index, modelData, this)'
    assert_includes renderer, '"toggle", menuRoot.entryPayload(index, modelData, this)'
    assert_includes renderer, '"highlight", menuRoot.entryPayload(index, modelData, this)'
    assert_includes renderer, '"about_to_show", {}'
    assert_includes renderer, '"about_to_hide", {}'
  end
end
