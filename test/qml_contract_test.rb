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
end
