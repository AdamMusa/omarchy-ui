import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi
import "Components/Builtins" as Builtins

Loader {
  id: root

  property var bridge: null
  property string surfaceName: ""
  property string controlId: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  // Shared recursive delegates are framework infrastructure. Individual built-in
  // renderers consume these without duplicating ControlNode's lifecycle wiring.
  readonly property Component childDelegateComponent: childDelegate
  readonly property Component rowChildDelegateComponent: rowChildDelegate
  readonly property Component columnChildDelegateComponent: columnChildDelegate
  readonly property Component layoutChildDelegateComponent: layoutChildDelegate
  readonly property Component splitChildDelegateComponent: splitChildDelegate

  readonly property var node: {
    var currentRevision = bridge ? bridge.revision : 0
    return bridge ? bridge.nodeFor(controlId) : null
  }

  readonly property bool builtIn: ["text", "label", "rich_text", "markdown", "selectable_text", "icon", "tooltip", "button", "round_button", "tool_button", "delay_button", "row", "column", "container", "image", "vector_image", "font_loader", "text_metrics", "animated_image", "video", "audio", "avatar", "badge", "chip", "spacer",
    "grid", "row_layout", "column_layout", "grid_layout", "flow", "center", "card", "border_overlay", "aspect_ratio", "constrained_box", "fitted_box", "wrap", "split_view", "stack_layout", "layout_item_proxy", "loader", "flickable", "focus_scope", "flipable", "border_image", "window", "application_window",
    "stack", "scroll", "rectangle", "action_button", "bar_icon_button", "bar_indicator", "toggle", "checkbox", "radio_button", "radio_group", "toggle_switch", "text_field",
    "number_field", "text_area", "search_field", "password_field", "slider", "range_slider", "dial", "spin_box", "double_spin_box", "color_picker", "date_picker", "time_picker", "file_picker", "folder_picker", "font_picker", "dialog_button_box", "dropdown", "multi_select", "button_group", "progress", "line_chart", "area_chart", "bar_chart", "separator", "divider",
    "section_header", "searchable_dropdown", "confirm_dialog", "panel_hero", "optical_glyph",
    "cursor_surface", "widget_button", "list_view", "key_catcher"].indexOf(node ? node.type : "") >= 0
  readonly property bool structuralContainer: ["row", "column", "container", "grid", "row_layout",
    "column_layout", "grid_layout", "flow", "center", "card", "stack", "scroll", "rectangle", "aspect_ratio", "constrained_box", "fitted_box", "wrap", "split_view", "stack_layout", "loader", "flickable", "focus_scope", "flipable", "border_image", "key_catcher"]
    .indexOf(node ? node.type : "") >= 0

  function prop(name, fallback) {
    var props = node && node.props ? node.props : null
    var value = props ? props[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function iconGlyph(name) {
    var icons = {
      ruby: "\ue23e",
      phone: "\uf3cd",
      plus: "\uf067",
      minus: "\uf068",
      reset: "\uf2f9", refresh: "\uf2f9",
      house: "\uf015", gear: "\uf013", search: "\uf002", xmark: "\uf00d", check: "\uf00c",
      menu: "\uf0c9", user: "\uf007", bell: "\uf0f3", wifi: "\uf1eb", bluetooth: "\uf293",
      volume_high: "\uf028", volume_low: "\uf027", volume_off: "\uf026",
      play: "\uf04b", pause: "\uf04c", stop: "\uf04d", trash: "\uf1f8", edit: "\uf044",
      folder: "\uf07b", file: "\uf15b", download: "\uf019", upload: "\uf093", link: "\uf0c1",
      lock: "\uf023", unlock: "\uf09c", eye: "\uf06e", eye_slash: "\uf070",
      star: "\uf005", heart: "\uf004", info: "\uf129", warning: "\uf071",
      circle_info: "\uf05a", circle_check: "\uf058", circle_xmark: "\uf057",
      arrow_left: "\uf060", arrow_right: "\uf061", arrow_up: "\uf062", arrow_down: "\uf063",
      chevron_left: "\uf053", chevron_right: "\uf054", chevron_up: "\uf077", chevron_down: "\uf078",
      calendar: "\uf133", clock: "\uf017", camera: "\uf030", image: "\uf03e", music: "\uf001",
      terminal: "\uf120", code: "\uf121", copy: "\uf0c5", save: "\uf0c7", power: "\uf011",
      globe: "\uf0ac", location: "\uf3c5", pin: "\uf08d", android: "\uf17b", apple: "\uf179"
    }
    var key = String(name || "")
    return icons[key] || key
  }

  function escapeAutoText(value) {
    return String(value === undefined || value === null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }

  function easingType(name) {
    var easings = {
      linear: Easing.Linear,
      in_quad: Easing.InQuad, out_quad: Easing.OutQuad, in_out_quad: Easing.InOutQuad,
      in_cubic: Easing.InCubic, out_cubic: Easing.OutCubic, in_out_cubic: Easing.InOutCubic,
      in_back: Easing.InBack, out_back: Easing.OutBack, in_out_back: Easing.InOutBack,
      in_elastic: Easing.InElastic, out_elastic: Easing.OutElastic, in_out_elastic: Easing.InOutElastic,
      in_bounce: Easing.InBounce, out_bounce: Easing.OutBounce, in_out_bounce: Easing.InOutBounce
    }
    return easings[String(name || "")] === undefined ? Easing.InOutQuad : easings[String(name)]
  }

  function layoutAlignment(name, fallback) {
    var value = String(name || fallback || "center")
    if (value === "start" || value === "left" || value === "top") return Qt.AlignLeft | Qt.AlignTop
    if (value === "end" || value === "right" || value === "bottom") return Qt.AlignRight | Qt.AlignBottom
    if (value === "left_center") return Qt.AlignLeft | Qt.AlignVCenter
    if (value === "right_center") return Qt.AlignRight | Qt.AlignVCenter
    if (value === "top_center") return Qt.AlignTop | Qt.AlignHCenter
    if (value === "bottom_center") return Qt.AlignBottom | Qt.AlignHCenter
    return Qt.AlignCenter
  }

  function findRenderedItem(targetId) {
    var ancestor = root
    while (ancestor.parent) ancestor = ancestor.parent
    return findRenderedItemBelow(ancestor, String(targetId || ""))
  }

  function findRenderedItemBelow(object, targetId) {
    if (!object || targetId === "") return null
    if (object !== root && object.controlId !== undefined && String(object.controlId) === targetId)
      return object.item || object
    var descendants = object.children || []
    for (var index = 0; index < descendants.length; index++) {
      var result = findRenderedItemBelow(descendants[index], targetId)
      if (result) return result
    }
    return null
  }

  function subscribed(eventName) {
    return node && Array.isArray(node.events) && node.events.indexOf(eventName) >= 0
  }

  function configureFace(face, childNode) {
    if (!face || !childNode) return
    face.bridge = bridge
    face.surfaceName = surfaceName
    face.controlId = String(childNode.id)
    face.foreground = foreground
    face.fontFamily = fontFamily
  }

  function borderImageTileMode(value) {
    var mode = String(value || "stretch")
    if (mode === "repeat") return BorderImage.Repeat
    if (mode === "round") return BorderImage.Round
    return BorderImage.Stretch
  }

  function nativeDefinition() {
    return bridge && node ? bridge.componentDefinition(node.type) : null
  }

  function optionValue(option) {
    return option !== null && typeof option === "object" && option.value !== undefined ? option.value : option
  }

  function optionLabel(option) {
    return option !== null && typeof option === "object" && option.label !== undefined ? option.label : optionValue(option)
  }

  function syncNativeProperties() {
    var definition = nativeDefinition()
    if (!item || !definition || !definition.autoBind) return
    var props = node && node.props ? node.props : ({})
    var common = { visible: true, enabled: true, opacity: true, scale: true, rotation: true, z: true, width: true, height: true }
    for (var protocolName in props) {
      if (common[protocolName]) continue
      var qmlName = definition.propertyMap[protocolName] || protocolName
      if (item.hasOwnProperty(qmlName)) item[qmlName] = props[protocolName]
    }
  }

  function nativeEventPayload(args) {
    if (args.length === 0) return ({})
    if (args.length === 1 && args[0] !== null && typeof args[0] === "object" && !Array.isArray(args[0])) return args[0]
    var values = []
    for (var i = 0; i < args.length; i++) {
      var value = args[i]
      if (value === null || typeof value === "string" || typeof value === "number" || typeof value === "boolean"
          || Array.isArray(value)) values.push(value)
      else values.push(String(value))
    }
    return values.length === 1 ? { value: values[0] } : { arguments: values }
  }

  function connectNativeEvents() {
    var definition = nativeDefinition()
    if (!item || !definition || !definition.autoBind || !node || !Array.isArray(node.events)) return
    for (let i = 0; i < node.events.length; i++) {
      let protocolName = String(node.events[i])
      if (protocolName === "mount" || protocolName === "unmount") continue
      let qmlName = definition.eventMap[protocolName] || protocolName
      let signal = item[qmlName]
      if (signal && typeof signal.connect === "function") {
        signal.connect(function() {
          root.bridge.sendEvent(root.surfaceName, root.controlId, protocolName, root.nativeEventPayload(arguments))
        })
      }
    }
  }

  function runTransition() {
    var transitions = node && Array.isArray(node.transitions)
      ? node.transitions
      : (node && node.transition ? [node.transition] : [])
    if (!item || transitions.length === 0) return
    for (var transitionIndex = 0; transitionIndex < transitions.length; transitionIndex++)
      runTrack(transitions[transitionIndex])
  }

  function runTrack(transition) {
    var commonProperties = ["opacity", "scale", "rotation", "z", "width", "height"]
    var definition = nativeDefinition()
    var animationProperty = definition && definition.propertyMap[transition.property]
      ? definition.propertyMap[transition.property] : transition.property
    var animationTarget = commonProperties.indexOf(transition.property) >= 0 ? root : item
    if (!animationTarget.hasOwnProperty(animationProperty)) return
    if (transition.from === undefined || transition.from === null) return
    var animation = propertyAnimationFactory.createObject(root, {
      target: animationTarget,
      property: String(animationProperty),
      from: transition.from,
      to: transition.to,
      duration: Number(transition.duration)
    })
    animation.easing.type = easingType(transition.easing)
    var delay = Number(transition.delay || 0)
    if (delay > 0) delayedAnimationFactory.createObject(root, { interval: delay, animation: animation }).start()
    else animation.start()
  }

  visible: node !== null && prop("visible", true) !== false
  enabled: prop("enabled", true) !== false
  opacity: Number(prop("opacity", 1))
  scale: Number(prop("scale", 1))
  rotation: Number(prop("rotation", 0))
  z: Number(prop("z", 0))
  sourceComponent: {
    if (!node) return null
    if (node.type === "text") return textComponent
    if (node.type === "label") return labelComponent
    if (node.type === "rich_text") return richTextComponent
    if (node.type === "markdown") return markdownComponent
    if (node.type === "selectable_text") return selectableTextComponent
    if (node.type === "icon") return iconComponent
    if (node.type === "tooltip") return tooltipComponent
    if (node.type === "button") return buttonComponent
    if (node.type === "round_button") return roundButtonComponent
    if (node.type === "tool_button") return toolButtonComponent
    if (node.type === "delay_button") return delayButtonComponent
    if (node.type === "row") return rowComponent
    if (node.type === "column") return columnComponent
    if (node.type === "container") return containerComponent
    if (node.type === "image") return imageComponent
    if (node.type === "vector_image") return vectorImageComponent
    if (node.type === "font_loader") return fontLoaderComponent
    if (node.type === "text_metrics") return textMetricsComponent
    if (node.type === "animated_image") return animatedImageComponent
    if (node.type === "video") return videoComponent
    if (node.type === "audio") return audioComponent
    if (node.type === "avatar") return avatarComponent
    if (node.type === "badge") return badgeComponent
    if (node.type === "chip") return chipComponent
    if (node.type === "spacer") return spacerComponent
    if (node.type === "grid") return gridComponent
    if (node.type === "row_layout") return rowLayoutComponent
    if (node.type === "column_layout") return columnLayoutComponent
    if (node.type === "grid_layout") return gridLayoutComponent
    if (node.type === "flow") return flowComponent
    if (node.type === "center") return centerComponent
    if (node.type === "card") return cardComponent
    if (node.type === "border_overlay") return borderOverlayComponent
    if (node.type === "aspect_ratio") return aspectRatioComponent
    if (node.type === "constrained_box") return constrainedBoxComponent
    if (node.type === "fitted_box") return fittedBoxComponent
    if (node.type === "wrap") return wrapComponent
    if (node.type === "split_view") return splitViewComponent
    if (node.type === "stack_layout") return stackLayoutComponent
    if (node.type === "layout_item_proxy") return layoutItemProxyComponent
    if (node.type === "loader") return lazyLoaderComponent
    if (node.type === "flickable") return flickableComponent
    if (node.type === "focus_scope") return focusScopeComponent
    if (node.type === "flipable") return flipableComponent
    if (node.type === "border_image") return borderImageComponent
    if (node.type === "window") return windowComponent
    if (node.type === "application_window") return applicationWindowComponent
    if (node.type === "stack") return stackComponent
    if (node.type === "scroll") return scrollComponent
    if (node.type === "rectangle") return rectangleComponent
    if (node.type === "action_button") return actionButtonComponent
    if (node.type === "bar_icon_button") return barIconButtonComponent
    if (node.type === "bar_indicator") return barIndicatorComponent
    if (node.type === "toggle") return toggleComponent
    if (node.type === "checkbox") return checkboxComponent
    if (node.type === "radio_button") return radioButtonComponent
    if (node.type === "radio_group") return radioGroupComponent
    if (node.type === "toggle_switch") return toggleSwitchComponent
    if (node.type === "text_field") return textFieldComponent
    if (node.type === "number_field") return numberFieldComponent
    if (node.type === "text_area") return textAreaComponent
    if (node.type === "search_field") return searchFieldComponent
    if (node.type === "password_field") return passwordFieldComponent
    if (node.type === "slider") return sliderComponent
    if (node.type === "range_slider") return rangeSliderComponent
    if (node.type === "dial") return dialComponent
    if (node.type === "spin_box") return spinBoxComponent
    if (node.type === "double_spin_box") return doubleSpinBoxComponent
    if (node.type === "color_picker") return colorPickerComponent
    if (node.type === "date_picker") return datePickerComponent
    if (node.type === "time_picker") return timePickerComponent
    if (node.type === "file_picker") return filePickerComponent
    if (node.type === "folder_picker") return folderPickerComponent
    if (node.type === "font_picker") return fontPickerComponent
    if (node.type === "dialog_button_box") return dialogButtonBoxComponent
    if (node.type === "dropdown") return dropdownComponent
    if (node.type === "multi_select") return multiSelectComponent
    if (node.type === "button_group") return buttonGroupComponent
    if (node.type === "progress") return progressComponent
    if (node.type === "line_chart") return lineChartComponent
    if (node.type === "area_chart") return areaChartComponent
    if (node.type === "bar_chart") return barChartComponent
    if (node.type === "separator") return separatorComponent
    if (node.type === "divider") return dividerComponent
    if (node.type === "section_header") return sectionHeaderComponent
    if (node.type === "searchable_dropdown") return searchableDropdownComponent
    if (node.type === "confirm_dialog") return confirmDialogComponent
    if (node.type === "panel_hero") return panelHeroComponent
    if (node.type === "optical_glyph") return opticalGlyphComponent
    if (node.type === "cursor_surface") return cursorSurfaceComponent
    if (node.type === "widget_button") return widgetButtonComponent
    if (node.type === "list_view") return listViewComponent
    if (node.type === "key_catcher") return keyCatcherComponent
    return null
  }
  source: node && !builtIn ? bridge.componentSource(node.type) : ""
  onLoaded: {
    if (!item) return
    if (!builtIn) {
      if (item.hasOwnProperty("bridge")) item.bridge = bridge
      if (item.hasOwnProperty("surfaceName")) item.surfaceName = surfaceName
      if (item.hasOwnProperty("controlId")) item.controlId = controlId
      if (item.hasOwnProperty("node")) item.node = node
      syncNativeProperties()
      connectNativeEvents()
    }
    runTransition()
    if (subscribed("mount")) bridge.sendEvent(surfaceName, controlId, "mount", {})
  }
  onNodeChanged: {
    if (item && !builtIn && item.hasOwnProperty("node")) item.node = node
    if (!builtIn) syncNativeProperties()
    Qt.callLater(runTransition)
  }

  TapHandler {
    enabled: root.structuralContainer && root.subscribed("click")
    onTapped: root.bridge.sendEvent(root.surfaceName, root.controlId, "click", {})
  }

  Repeater {
    id: nativeChildren
    parent: root.item && root.item.hasOwnProperty("contentHost") && root.item.contentHost
      ? root.item.contentHost
      : root
    model: !root.builtIn && root.node && root.nativeDefinition() && root.nativeDefinition().container
      && Array.isArray(root.node.children) ? root.node.children : []
    delegate: childDelegate
  }

  Component {
    id: propertyAnimationFactory
    PropertyAnimation { onStopped: destroy() }
  }

  Component {
    id: delayedAnimationFactory
    Timer {
      required property var animation
      repeat: false
      onTriggered: { animation.start(); destroy() }
    }
  }

  Component.onDestruction: {
    if (bridge && subscribed("unmount")) bridge.sendEvent(surfaceName, controlId, "unmount", {})
  }
  Component {
    id: textComponent
    Builtins.Text { renderer: root }
  }

  Component {
    id: labelComponent
    Builtins.Label { renderer: root }
  }

  Component {
    id: richTextComponent
    Builtins.RichText { renderer: root }
  }

  Component {
    id: markdownComponent
    Builtins.Markdown { renderer: root }
  }

  Component {
    id: selectableTextComponent
    Builtins.SelectableText { renderer: root }
  }

  Component {
    id: iconComponent
    Builtins.Icon { renderer: root }
  }

  Component {
    id: tooltipComponent
    Builtins.Tooltip { renderer: root }
  }

  Component {
    id: buttonComponent
    Builtins.Button { renderer: root }
  }

  Component {
    id: roundButtonComponent
    Builtins.RoundButton { renderer: root }
  }

  Component {
    id: toolButtonComponent
    Builtins.ToolButton { renderer: root }
  }

  Component {
    id: delayButtonComponent
    Builtins.DelayButton { renderer: root }
  }

  Component {
    id: rowComponent
    Builtins.Row { renderer: root }
  }

  Component {
    id: columnComponent
    Builtins.Column { renderer: root }
  }

  Component {
    id: containerComponent
    Builtins.Container { renderer: root }
  }

  Component {
    id: imageComponent
    Builtins.Image { renderer: root }
  }

  Component {
    id: vectorImageComponent
    Builtins.VectorImage { renderer: root }
  }

  Component {
    id: fontLoaderComponent
    Builtins.FontLoader { renderer: root }
  }

  Component {
    id: textMetricsComponent
    Builtins.TextMetrics { renderer: root }
  }

  Component {
    id: animatedImageComponent
    Builtins.AnimatedImage { renderer: root }
  }

  Component {
    id: videoComponent
    Builtins.Video { renderer: root }
  }

  Component {
    id: audioComponent
    Builtins.Audio { renderer: root }
  }

  Component {
    id: avatarComponent
    Builtins.Avatar { renderer: root }
  }

  Component {
    id: badgeComponent
    Builtins.Badge { renderer: root }
  }

  Component {
    id: chipComponent
    Builtins.Chip { renderer: root }
  }

  Component {
    id: spacerComponent
    Builtins.Spacer { renderer: root }
  }

  Component {
    id: gridComponent
    Builtins.Grid { renderer: root }
  }

  Component {
    id: rowLayoutComponent
    Builtins.RowLayout { renderer: root }
  }

  Component {
    id: columnLayoutComponent
    Builtins.ColumnLayout { renderer: root }
  }

  Component {
    id: gridLayoutComponent
    Builtins.GridLayout { renderer: root }
  }

  Component {
    id: flowComponent
    Builtins.Flow { renderer: root }
  }

  Component {
    id: centerComponent
    Builtins.Center { renderer: root }
  }

  Component {
    id: cardComponent
    Builtins.Card { renderer: root }
  }

  Component {
    id: aspectRatioComponent
    Builtins.AspectRatio { renderer: root }
  }

  Component {
    id: constrainedBoxComponent
    Builtins.ConstrainedBox { renderer: root }
  }

  Component {
    id: fittedBoxComponent
    Builtins.FittedBox { renderer: root }
  }

  Component {
    id: wrapComponent
    Builtins.Wrap { renderer: root }
  }

  Component {
    id: splitViewComponent
    Builtins.SplitView { renderer: root }
  }

  Component {
    id: stackLayoutComponent
    Builtins.StackLayout { renderer: root }
  }

  Component {
    id: layoutItemProxyComponent
    Builtins.LayoutItemProxy { renderer: root }
  }

  Component {
    id: lazyLoaderComponent
    Builtins.Loader { renderer: root }
  }

  Component {
    id: flickableComponent
    Builtins.Flickable { renderer: root }
  }

  Component {
    id: focusScopeComponent
    Builtins.FocusScope { renderer: root }
  }

  Component {
    id: flipableComponent
    Builtins.Flipable { renderer: root }
  }

  Component {
    id: borderImageComponent
    Builtins.BorderImage { renderer: root }
  }

  Component {
    id: windowComponent
    Builtins.Window { renderer: root }
  }

  Component {
    id: applicationWindowComponent
    Builtins.ApplicationWindow { renderer: root }
  }

  Component {
    id: borderOverlayComponent
    Builtins.BorderOverlay { renderer: root }
  }

  Component {
    id: keyCatcherComponent
    Builtins.KeyCatcher { renderer: root }
  }

  Component {
    id: stackComponent
    Builtins.Stack { renderer: root }
  }

  Component {
    id: scrollComponent
    Builtins.Scroll { renderer: root }
  }

  Component {
    id: rectangleComponent
    Builtins.Rectangle { renderer: root }
  }

  Component {
    id: splitChildDelegate
    Loader {
      required property var modelData
      QQC.SplitView.minimumWidth: Number(modelData.props && modelData.props.minimum_width !== undefined ? modelData.props.minimum_width : 0)
      QQC.SplitView.minimumHeight: Number(modelData.props && modelData.props.minimum_height !== undefined ? modelData.props.minimum_height : 0)
      QQC.SplitView.preferredWidth: Number(modelData.props && modelData.props.preferred_width !== undefined ? modelData.props.preferred_width : implicitWidth)
      QQC.SplitView.preferredHeight: Number(modelData.props && modelData.props.preferred_height !== undefined ? modelData.props.preferred_height : implicitHeight)
      QQC.SplitView.fillWidth: modelData.props && modelData.props.fill_width === true
      QQC.SplitView.fillHeight: modelData.props && modelData.props.fill_height === true
      source: Qt.resolvedUrl("ControlNode.qml")
      onLoaded: {
        item.bridge = root.bridge
        item.surfaceName = root.surfaceName
        item.controlId = String(modelData.id)
        item.foreground = root.foreground
        item.fontFamily = root.fontFamily
      }
    }
  }

  Component {
    id: childDelegate
    Loader {
      required property var modelData
      source: Qt.resolvedUrl("ControlNode.qml")
      onLoaded: {
        item.bridge = root.bridge
        item.surfaceName = root.surfaceName
        item.controlId = String(modelData.id)
        item.foreground = root.foreground
        item.fontFamily = root.fontFamily
      }
    }
  }

  Component {
    id: rowChildDelegate
    Loader {
      required property var modelData
      readonly property string crossAlignment: String(root.prop("alignment", "center"))
      anchors.top: crossAlignment === "start" || crossAlignment === "top" ? parent.top : undefined
      anchors.verticalCenter: crossAlignment === "center" ? parent.verticalCenter : undefined
      anchors.bottom: crossAlignment === "end" || crossAlignment === "bottom" ? parent.bottom : undefined
      source: Qt.resolvedUrl("ControlNode.qml")
      onLoaded: {
        item.bridge = root.bridge
        item.surfaceName = root.surfaceName
        item.controlId = String(modelData.id)
        item.foreground = root.foreground
        item.fontFamily = root.fontFamily
      }
    }
  }

  Component {
    id: layoutChildDelegate
    Loader {
      required property var modelData
      readonly property var layoutProps: modelData && modelData.props ? modelData.props : ({})
      Layout.fillWidth: layoutProps.fill_width === true
      Layout.fillHeight: layoutProps.fill_height === true
      Layout.preferredWidth: layoutProps.preferred_width === undefined ? -1 : Number(layoutProps.preferred_width)
      Layout.preferredHeight: layoutProps.preferred_height === undefined ? -1 : Number(layoutProps.preferred_height)
      Layout.minimumWidth: layoutProps.minimum_width === undefined ? 0 : Number(layoutProps.minimum_width)
      Layout.minimumHeight: layoutProps.minimum_height === undefined ? 0 : Number(layoutProps.minimum_height)
      Layout.maximumWidth: layoutProps.maximum_width === undefined ? Infinity : Number(layoutProps.maximum_width)
      Layout.maximumHeight: layoutProps.maximum_height === undefined ? Infinity : Number(layoutProps.maximum_height)
      Layout.alignment: root.layoutAlignment(layoutProps.layout_alignment, root.prop("alignment", "center"))
      source: Qt.resolvedUrl("ControlNode.qml")
      onLoaded: {
        item.bridge = root.bridge
        item.surfaceName = root.surfaceName
        item.controlId = String(modelData.id)
        item.foreground = root.foreground
        item.fontFamily = root.fontFamily
      }
    }
  }

  Component {
    id: columnChildDelegate
    Loader {
      required property var modelData
      readonly property string crossAlignment: String(root.prop("alignment", "start"))
      anchors.left: crossAlignment === "start" || crossAlignment === "left" ? parent.left : undefined
      anchors.horizontalCenter: crossAlignment === "center" ? parent.horizontalCenter : undefined
      anchors.right: crossAlignment === "end" || crossAlignment === "right" ? parent.right : undefined
      source: Qt.resolvedUrl("ControlNode.qml")
      onLoaded: {
        item.bridge = root.bridge
        item.surfaceName = root.surfaceName
        item.controlId = String(modelData.id)
        item.foreground = root.foreground
        item.fontFamily = root.fontFamily
      }
    }
  }

  Component {
    id: actionButtonComponent
    Builtins.ActionButton { renderer: root }
  }

  Component {
    id: barIconButtonComponent
    Builtins.BarIconButton { renderer: root }
  }

  Component {
    id: barIndicatorComponent
    Builtins.BarIndicator { renderer: root }
  }

  Component {
    id: toggleComponent
    Builtins.Toggle { renderer: root }
  }

  Component {
    id: checkboxComponent
    Builtins.Checkbox { renderer: root }
  }

  Component {
    id: radioButtonComponent
    Builtins.RadioButton { renderer: root }
  }

  Component {
    id: radioGroupComponent
    Builtins.RadioGroup { renderer: root }
  }

  Component {
    id: lineChartComponent
    Builtins.LineChart { renderer: root }
  }

  Component {
    id: areaChartComponent
    Builtins.AreaChart { renderer: root }
  }

  Component {
    id: barChartComponent
    Builtins.BarChart { renderer: root }
  }

  Component {
    id: toggleSwitchComponent
    Builtins.ToggleSwitch { renderer: root }
  }

  Component {
    id: textFieldComponent
    Builtins.TextField { renderer: root }
  }

  Component {
    id: numberFieldComponent
    Builtins.NumberField { renderer: root }
  }

  Component {
    id: textAreaComponent
    Builtins.TextArea { renderer: root }
  }

  Component {
    id: searchFieldComponent
    Builtins.SearchField { renderer: root }
  }

  Component {
    id: passwordFieldComponent
    Builtins.PasswordField { renderer: root }
  }

  Component {
    id: sliderComponent
    Builtins.Slider { renderer: root }
  }

  Component {
    id: rangeSliderComponent
    Builtins.RangeSlider { renderer: root }
  }

  Component {
    id: dialComponent
    Builtins.Dial { renderer: root }
  }

  Component {
    id: spinBoxComponent
    Builtins.SpinBox { renderer: root }
  }

  Component {
    id: doubleSpinBoxComponent
    Builtins.DoubleSpinBox { renderer: root }
  }

  Component {
    id: colorPickerComponent
    Builtins.ColorPicker { renderer: root }
  }

  Component {
    id: datePickerComponent
    Builtins.DatePicker { renderer: root }
  }

  Component {
    id: timePickerComponent
    Builtins.TimePicker { renderer: root }
  }

  Component {
    id: filePickerComponent
    Builtins.FilePicker { renderer: root }
  }

  Component {
    id: folderPickerComponent
    Builtins.FolderPicker { renderer: root }
  }

  Component {
    id: fontPickerComponent
    Builtins.FontPicker { renderer: root }
  }

  Component {
    id: dialogButtonBoxComponent
    Builtins.DialogButtonBox { renderer: root }
  }

  Component {
    id: dropdownComponent
    Builtins.Dropdown { renderer: root }
  }

  Component {
    id: multiSelectComponent
    Builtins.MultiSelect { renderer: root }
  }

  Component {
    id: buttonGroupComponent
    Builtins.ButtonGroup { renderer: root }
  }

  Component {
    id: progressComponent
    Builtins.Progress { renderer: root }
  }

  Component {
    id: separatorComponent
    Builtins.Separator { renderer: root }
  }
  Component {
    id: dividerComponent
    Builtins.Divider { renderer: root }
  }
  Component {
    id: sectionHeaderComponent
    Builtins.SectionHeader { renderer: root }
  }

  Component {
    id: searchableDropdownComponent
    Builtins.SearchableDropdown { renderer: root }
  }

  Component {
    id: confirmDialogComponent
    Builtins.ConfirmDialog { renderer: root }
  }

  Component {
    id: panelHeroComponent
    Builtins.PanelHero { renderer: root }
  }

  Component {
    id: opticalGlyphComponent
    Builtins.OpticalGlyph { renderer: root }
  }

  Component {
    id: cursorSurfaceComponent
    Builtins.CursorSurface { renderer: root }
  }

  Component {
    id: widgetButtonComponent
    Builtins.WidgetButton { renderer: root }
  }

  Component {
    id: listViewComponent
    Builtins.ListView { renderer: root }
  }
}
