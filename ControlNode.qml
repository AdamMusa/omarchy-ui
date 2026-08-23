import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import qs.Commons
import qs.Ui as OmarchyUi

Loader {
  id: root

  property var bridge: null
  property string surfaceName: ""
  property string controlId: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  readonly property var node: {
    var currentRevision = bridge ? bridge.revision : 0
    return bridge ? bridge.nodeFor(controlId) : null
  }

  readonly property bool builtIn: ["text", "icon", "tooltip", "button", "row", "column", "container", "image", "spacer",
    "grid", "row_layout", "column_layout", "grid_layout", "flow", "center", "card", "border_overlay", "aspect_ratio", "constrained_box", "fitted_box", "wrap", "split_view", "stack_layout", "loader", "flickable", "focus_scope",
    "stack", "scroll", "rectangle", "action_button", "bar_icon_button", "bar_indicator", "toggle", "checkbox", "toggle_switch", "text_field",
    "number_field", "slider", "dropdown", "multi_select", "button_group", "progress", "line_chart", "area_chart", "bar_chart", "separator",
    "section_header", "searchable_dropdown", "confirm_dialog", "panel_hero", "optical_glyph",
    "cursor_surface", "widget_button", "list_view", "key_catcher"].indexOf(node ? node.type : "") >= 0
  readonly property bool structuralContainer: ["row", "column", "container", "grid", "row_layout",
    "column_layout", "grid_layout", "flow", "center", "card", "stack", "scroll", "rectangle", "aspect_ratio", "constrained_box", "fitted_box", "wrap", "split_view", "stack_layout", "loader", "flickable", "focus_scope", "key_catcher"]
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

  function subscribed(eventName) {
    return node && Array.isArray(node.events) && node.events.indexOf(eventName) >= 0
  }

  function nativeDefinition() {
    return bridge && node ? bridge.componentDefinition(node.type) : null
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
    if (node.type === "icon") return iconComponent
    if (node.type === "tooltip") return tooltipComponent
    if (node.type === "button") return buttonComponent
    if (node.type === "row") return rowComponent
    if (node.type === "column") return columnComponent
    if (node.type === "container") return containerComponent
    if (node.type === "image") return imageComponent
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
    if (node.type === "loader") return lazyLoaderComponent
    if (node.type === "flickable") return flickableComponent
    if (node.type === "focus_scope") return focusScopeComponent
    if (node.type === "stack") return stackComponent
    if (node.type === "scroll") return scrollComponent
    if (node.type === "rectangle") return rectangleComponent
    if (node.type === "action_button") return actionButtonComponent
    if (node.type === "bar_icon_button") return barIconButtonComponent
    if (node.type === "bar_indicator") return barIndicatorComponent
    if (node.type === "toggle") return toggleComponent
    if (node.type === "checkbox") return checkboxComponent
    if (node.type === "toggle_switch") return toggleSwitchComponent
    if (node.type === "text_field") return textFieldComponent
    if (node.type === "number_field") return numberFieldComponent
    if (node.type === "slider") return sliderComponent
    if (node.type === "dropdown") return dropdownComponent
    if (node.type === "multi_select") return multiSelectComponent
    if (node.type === "button_group") return buttonGroupComponent
    if (node.type === "progress") return progressComponent
    if (node.type === "line_chart") return lineChartComponent
    if (node.type === "area_chart") return areaChartComponent
    if (node.type === "bar_chart") return barChartComponent
    if (node.type === "separator") return separatorComponent
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

    Text {
      text: String(root.prop("text", ""))
      textFormat: Text.PlainText
      color: root.prop("color", root.foreground)
      font.family: root.fontFamily
      font.pixelSize: {
        var style = String(root.prop("style", "body"))
        if (style === "heading") return Style.font.heading
        if (style === "caption") return Style.font.caption
        return Number(root.prop("size", Style.font.body))
      }
      font.bold: root.prop("bold", false) || String(root.prop("style", "body")) === "heading"
      wrapMode: root.prop("wrap", true) ? Text.Wrap : Text.NoWrap
      width: Number(root.prop("width", implicitWidth))
    }
  }

  Component {
    id: iconComponent

    Text {
      text: root.iconGlyph(root.prop("name", root.prop("text", "")))
      textFormat: Text.PlainText
      color: root.prop("color", root.foreground)
      font.family: root.fontFamily
      font.pixelSize: Number(root.prop("size", Style.font.icon))
    }
  }

  Component {
    id: tooltipComponent
    OmarchyUi.PanelToolTip {
      text: root.escapeAutoText(root.prop("text", ""))
      visible: root.prop("visible", false) === true
      delay: Number(root.prop("delay", 400))
      timeout: Number(root.prop("timeout", -1))
      panelForeground: root.prop("foreground", Color.tooltip.text)
      panelBackground: root.prop("background", Color.tooltip.background)
      panelBorder: root.prop("border", Color.tooltip.border)
      fontFamily: String(root.prop("font_family", root.fontFamily))
      fontSize: Number(root.prop("font_size", Style.font.bodySmall))
    }
  }

  Component {
    id: buttonComponent

    OmarchyUi.Button {
      text: root.escapeAutoText(root.prop("text", ""))
      iconText: root.iconGlyph(root.prop("icon", ""))
      tooltipText: root.escapeAutoText(root.prop("tooltip", ""))
      selected: root.prop("selected", false) === true
      active: root.prop("active", false) === true
      hasCursor: root.prop("cursor", false) === true
      focusable: root.prop("focusable", true) !== false
      bordered: root.prop("bordered", true) !== false
      foreground: root.prop("foreground", root.foreground)
      background: root.prop("background", "transparent")
      accent: root.prop("accent", Color.accent)
      fontFamily: String(root.prop("font_family", root.fontFamily))
      fontSize: Number(root.prop("font_size", Style.font.body))
      iconSize: Number(root.prop("icon_size", Style.font.icon))
      iconRotation: Number(root.prop("icon_rotation", 0))
      iconSpinning: root.prop("icon_spinning", false) === true
      horizontalPadding: Number(root.prop("horizontal_padding", Style.spacing.controlPaddingX))
      verticalPadding: Number(root.prop("vertical_padding", Style.spacing.controlPaddingY))
      leftAlign: root.prop("left_align", false) === true
      tooltipBackground: root.prop("tooltip_background", Color.tooltip.background)
      tooltipForeground: root.prop("tooltip_foreground", Color.tooltip.text)
      tooltipBorder: root.prop("tooltip_border", Color.tooltip.border)
      onClicked: root.bridge.sendEvent(root.surfaceName, root.controlId, "click", {})
      onRightClicked: root.bridge.sendEvent(root.surfaceName, root.controlId, "right_click", {})
      onHovered: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { value: value }) }
    }
  }

  Component {
    id: rowComponent

    Row {
      spacing: Number(root.prop("spacing", Style.spacing.controlGap))

      Repeater {
        model: root.node && Array.isArray(root.node.children) ? root.node.children : []
        delegate: rowChildDelegate
      }
    }
  }

  Component {
    id: columnComponent

    Column {
      spacing: Number(root.prop("spacing", Style.spacing.panelGap))

      Repeater {
        model: root.node && Array.isArray(root.node.children) ? root.node.children : []
        delegate: columnChildDelegate
      }
    }
  }

  Component {
    id: containerComponent

    OmarchyUi.BorderSurface {
      readonly property int innerPadding: Number(root.prop("padding", 0))
      implicitWidth: content.implicitWidth + innerPadding * 2
      implicitHeight: content.implicitHeight + innerPadding * 2
      color: "transparent"
      borderSpec: root.prop("bordered", false)
        ? Border.controlSpec("normal", root.foreground, Color.accent)
        : Border.none()
      radius: Style.cornerRadius

      Column {
        id: content
        anchors.centerIn: parent
        spacing: Number(root.prop("spacing", Style.spacing.panelGap))

        Repeater {
          model: root.node && Array.isArray(root.node.children) ? root.node.children : []
          delegate: childDelegate
        }
      }
    }
  }

  Component {
    id: imageComponent

    Image {
      source: String(root.prop("source", ""))
      width: Number(root.prop("width", 120))
      height: Number(root.prop("height", 120))
      asynchronous: true
      fillMode: Image.PreserveAspectFit
    }
  }

  Component {
    id: spacerComponent

    Item {
      implicitWidth: Number(root.prop("width", 0))
      implicitHeight: Number(root.prop("height", Style.space(8)))
    }
  }

  Component {
    id: gridComponent
    Grid {
      columns: Number(root.prop("columns", 2))
      rows: Number(root.prop("rows", -1))
      rowSpacing: Number(root.prop("row_spacing", root.prop("spacing", Style.spacing.controlGap)))
      columnSpacing: Number(root.prop("column_spacing", root.prop("spacing", Style.spacing.controlGap)))
      Repeater { model: root.node.children || []; delegate: childDelegate }
    }
  }

  Component {
    id: rowLayoutComponent
    RowLayout {
      spacing: Number(root.prop("spacing", Style.spacing.controlGap))
      Repeater { model: root.node.children || []; delegate: layoutChildDelegate }
    }
  }

  Component {
    id: columnLayoutComponent
    ColumnLayout {
      spacing: Number(root.prop("spacing", Style.spacing.panelGap))
      Repeater { model: root.node.children || []; delegate: layoutChildDelegate }
    }
  }

  Component {
    id: gridLayoutComponent
    GridLayout {
      columns: Number(root.prop("columns", 2))
      rows: Number(root.prop("rows", -1))
      rowSpacing: Number(root.prop("row_spacing", root.prop("spacing", Style.spacing.controlGap)))
      columnSpacing: Number(root.prop("column_spacing", root.prop("spacing", Style.spacing.controlGap)))
      Repeater { model: root.node.children || []; delegate: layoutChildDelegate }
    }
  }

  Component {
    id: flowComponent
    Flow {
      width: Number(root.prop("width", 420))
      height: root.prop("height", null) === null ? childrenRect.height : Number(root.prop("height", childrenRect.height))
      spacing: Number(root.prop("spacing", Style.spacing.controlGap))
      flow: String(root.prop("orientation", "horizontal")) === "vertical" ? Flow.TopToBottom : Flow.LeftToRight
      Repeater { model: root.node.children || []; delegate: childDelegate }
    }
  }

  Component {
    id: centerComponent
    Item {
      readonly property int pad: Number(root.prop("padding", 0))
      implicitWidth: centeredContent.implicitWidth + pad * 2
      implicitHeight: centeredContent.implicitHeight + pad * 2
      Column {
        id: centeredContent
        anchors.centerIn: parent
        spacing: Number(root.prop("spacing", Style.spacing.panelGap))
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
  }

  Component {
    id: cardComponent
    OmarchyUi.BorderSurface {
      readonly property int pad: Number(root.prop("padding", Style.space(16)))
      implicitWidth: cardContent.implicitWidth + pad * 2
      implicitHeight: cardContent.implicitHeight + pad * 2
      color: root.prop("color", Color.popups.background)
      radius: Number(root.prop("radius", Style.cornerRadius))
      borderSpec: Border.controlSpec("normal", root.prop("border_color", root.foreground), root.prop("accent", Color.accent))
      Column {
        id: cardContent
        anchors.centerIn: parent
        spacing: Number(root.prop("spacing", Style.spacing.panelGap))
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
  }

  Component {
    id: aspectRatioComponent
    Item {
      readonly property real aspect: Math.max(0.000001, Number(root.prop("ratio", 1)))
      readonly property var requestedWidth: root.prop("width", null)
      readonly property var requestedHeight: root.prop("height", null)
      readonly property real naturalWidth: aspectContent.implicitWidth
      readonly property real naturalHeight: aspectContent.implicitHeight
      implicitWidth: requestedWidth !== null
        ? Number(requestedWidth)
        : (requestedHeight !== null ? Number(requestedHeight) * aspect : Math.max(naturalWidth, naturalHeight * aspect))
      implicitHeight: requestedHeight !== null
        ? Number(requestedHeight)
        : (requestedWidth !== null ? Number(requestedWidth) / aspect : implicitWidth / aspect)
      clip: root.prop("clip", false) === true
      Item {
        id: aspectContent
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
  }

  Component {
    id: constrainedBoxComponent
    Item {
      function bounded(value, minimum, maximum) {
        return Math.max(Number(minimum), Math.min(Number(maximum), Number(value)))
      }
      readonly property real naturalWidth: constrainedContent.implicitWidth
      readonly property real naturalHeight: constrainedContent.implicitHeight
      readonly property real desiredWidth: Number(root.prop("width", naturalWidth))
      readonly property real desiredHeight: Number(root.prop("height", naturalHeight))
      implicitWidth: bounded(desiredWidth, root.prop("min_width", 0), root.prop("max_width", Number.MAX_VALUE))
      implicitHeight: bounded(desiredHeight, root.prop("min_height", 0), root.prop("max_height", Number.MAX_VALUE))
      clip: root.prop("clip", false) === true
      Item {
        id: constrainedContent
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
  }

  Component {
    id: fittedBoxComponent
    Item {
      implicitWidth: Number(root.prop("width", fittedContent.implicitWidth))
      implicitHeight: Number(root.prop("height", fittedContent.implicitHeight))
      clip: root.prop("clip", true) !== false

      readonly property real sourceWidth: Math.max(0.000001, fittedContent.implicitWidth)
      readonly property real sourceHeight: Math.max(0.000001, fittedContent.implicitHeight)
      readonly property real availableXScale: width / sourceWidth
      readonly property real availableYScale: height / sourceHeight
      readonly property string fitMode: String(root.prop("fit", "contain"))
      readonly property real fittedXScale: fitMode === "fill" ? availableXScale
        : (fitMode === "none" ? 1
        : (fitMode === "cover" ? Math.max(availableXScale, availableYScale)
        : (fitMode === "scale_down" ? Math.min(1, Math.min(availableXScale, availableYScale))
        : Math.min(availableXScale, availableYScale))))
      readonly property real fittedYScale: fitMode === "fill" ? availableYScale : fittedXScale
      readonly property string contentAlignment: String(root.prop("alignment", "center"))

      Item {
        id: fittedContent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        x: contentAlignment.indexOf("left") >= 0 || contentAlignment === "start" ? 0
          : (contentAlignment.indexOf("right") >= 0 || contentAlignment === "end" ? parent.width - implicitWidth * fittedXScale : (parent.width - implicitWidth * fittedXScale) / 2)
        y: contentAlignment.indexOf("top") >= 0 || contentAlignment === "start" ? 0
          : (contentAlignment.indexOf("bottom") >= 0 || contentAlignment === "end" ? parent.height - implicitHeight * fittedYScale : (parent.height - implicitHeight * fittedYScale) / 2)
        transformOrigin: Item.TopLeft
        transform: Scale { xScale: fittedXScale; yScale: fittedYScale }
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
  }

  Component {
    id: wrapComponent
    Flow {
      implicitWidth: Number(root.prop("width", 420))
      implicitHeight: root.prop("height", null) === null ? childrenRect.height : Number(root.prop("height", childrenRect.height))
      spacing: Number(root.prop("spacing", Style.spacing.controlGap))
      flow: String(root.prop("orientation", "horizontal")) === "vertical" ? Flow.TopToBottom : Flow.LeftToRight
      layoutDirection: String(root.prop("layout_direction", "left_to_right")) === "right_to_left"
        ? Qt.RightToLeft : Qt.LeftToRight
      Repeater { model: root.node.children || []; delegate: childDelegate }
    }
  }

  Component {
    id: splitViewComponent
    QQC.SplitView {
      implicitWidth: Number(root.prop("width", 560))
      implicitHeight: Number(root.prop("height", 320))
      orientation: String(root.prop("orientation", "horizontal")) === "vertical" ? Qt.Vertical : Qt.Horizontal
      function currentSizes() {
        var sizes = []
        for (var index = 0; index < splitChildren.count; index++) {
          var child = splitChildren.itemAt(index)
          sizes.push(orientation === Qt.Horizontal ? child.width : child.height)
        }
        return sizes
      }
      onResizingChanged: {
        if (!resizing && root.subscribed("resize"))
          root.bridge.sendEvent(root.surfaceName, root.controlId, "resize", { sizes: currentSizes() })
      }
      Repeater {
        id: splitChildren
        model: root.node.children || []
        delegate: splitChildDelegate
      }
    }
  }

  Component {
    id: stackLayoutComponent
    StackLayout {
      implicitWidth: Number(root.prop("width", 420))
      implicitHeight: Number(root.prop("height", 280))
      currentIndex: Math.max(0, Math.min(count - 1, Number(root.prop("current_index", 0))))
      onCurrentIndexChanged: {
        if (root.subscribed("change"))
          root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: currentIndex })
      }
      Repeater { model: root.node.children || []; delegate: layoutChildDelegate }
    }
  }

  Component {
    id: lazyLoaderComponent
    Loader {
      readonly property var childNode: root.node && Array.isArray(root.node.children) && root.node.children.length > 0
        ? root.node.children[0] : null
      active: root.prop("active", true) !== false && childNode !== null
      asynchronous: root.prop("asynchronous", false) === true
      source: active ? Qt.resolvedUrl("ControlNode.qml") : ""
      implicitWidth: Number(root.prop("width", item ? item.implicitWidth : 0))
      implicitHeight: Number(root.prop("height", item ? item.implicitHeight : 0))
      onLoaded: {
        item.bridge = root.bridge
        item.surfaceName = root.surfaceName
        item.controlId = String(childNode.id)
        item.foreground = root.foreground
        item.fontFamily = root.fontFamily
        if (root.subscribed("loaded")) root.bridge.sendEvent(root.surfaceName, root.controlId, "loaded", {})
      }
      onStatusChanged: {
        if (root.subscribed("status"))
          root.bridge.sendEvent(root.surfaceName, root.controlId, "status", { value: status })
      }
    }
  }

  Component {
    id: flickableComponent
    Flickable {
      implicitWidth: Number(root.prop("width", 320))
      implicitHeight: Number(root.prop("height", 240))
      contentWidth: Number(root.prop("content_width", flickContent.implicitWidth))
      contentHeight: Number(root.prop("content_height", flickContent.implicitHeight))
      flickableDirection: {
        var direction = String(root.prop("direction", "vertical"))
        if (direction === "horizontal") return Flickable.HorizontalFlick
        if (direction === "both") return Flickable.HorizontalAndVerticalFlick
        if (direction === "auto") return Flickable.AutoFlickDirection
        return Flickable.VerticalFlick
      }
      boundsBehavior: String(root.prop("bounds_behavior", "stop")) === "overshoot"
        ? Flickable.DragAndOvershootBounds : Flickable.StopAtBounds
      interactive: root.prop("interactive", true) !== false
      clip: root.prop("clip", true) !== false
      function positionPayload() { return { x: contentX, y: contentY } }
      onContentXChanged: {
        if (root.subscribed("scroll")) root.bridge.sendEvent(root.surfaceName, root.controlId, "scroll", positionPayload())
      }
      onContentYChanged: {
        if (root.subscribed("scroll")) root.bridge.sendEvent(root.surfaceName, root.controlId, "scroll", positionPayload())
      }
      onMovementStarted: root.bridge.sendEvent(root.surfaceName, root.controlId, "flick_start", positionPayload())
      onMovementEnded: root.bridge.sendEvent(root.surfaceName, root.controlId, "flick_end", positionPayload())
      Column {
        id: flickContent
        spacing: Style.spacing.panelGap
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
  }

  Component {
    id: focusScopeComponent
    FocusScope {
      id: nativeFocusScope
      implicitWidth: Number(root.prop("width", focusContent.implicitWidth))
      implicitHeight: Number(root.prop("height", focusContent.implicitHeight))
      focus: root.prop("focus", false) === true
      function syncRequestedFocus() {
        if (root.prop("active_focus", false) === true) forceActiveFocus()
      }
      onActiveFocusChanged: {
        root.bridge.sendEvent(root.surfaceName, root.controlId, activeFocus ? "focus" : "blur", { value: activeFocus })
      }
      Component.onCompleted: syncRequestedFocus()
      Connections { target: root; function onNodeChanged() { nativeFocusScope.syncRequestedFocus() } }
      Item {
        id: focusContent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
  }

  Component {
    id: borderOverlayComponent
    OmarchyUi.BorderOverlay {
      width: Number(root.prop("width", 120))
      height: Number(root.prop("height", 80))
      radius: Number(root.prop("radius", Style.cornerRadius))
      borderSpec: {
        var colors = root.prop("gradient_colors", [])
        if (Array.isArray(colors) && colors.length > 1) {
          return {
            color: colors[0],
            widths: Border.flat(colors[0], root.prop("width_spec", Style.normalBorderWidth)).widths,
            gradient: { colors: colors, angle: Number(root.prop("gradient_angle", 0)), enabled: true }
          }
        }
        return Border.flat(root.prop("color", root.foreground), root.prop("width_spec", Style.normalBorderWidth))
      }
    }
  }

  Component {
    id: keyCatcherComponent
    OmarchyUi.PanelKeyCatcher {
      blocked: root.prop("blocked", false) === true
      implicitWidth: keyContent.implicitWidth
      implicitHeight: keyContent.implicitHeight
      onMoveRequested: function(dx, dy) { root.bridge.sendEvent(root.surfaceName, root.controlId, "move", { dx: dx, dy: dy }) }
      onActivateRequested: root.bridge.sendEvent(root.surfaceName, root.controlId, "activate", {})
      onReturnRequested: root.bridge.sendEvent(root.surfaceName, root.controlId, "return", {})
      onCloseRequested: root.bridge.sendEvent(root.surfaceName, root.controlId, "close", {})
      onDeleteRequested: root.bridge.sendEvent(root.surfaceName, root.controlId, "delete", {})
      onTabRequested: function(direction) { root.bridge.sendEvent(root.surfaceName, root.controlId, "tab", { direction: direction }) }
      onTextKey: function(text) { root.bridge.sendEvent(root.surfaceName, root.controlId, "text", { text: text }) }
      Column {
        id: keyContent
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
  }

  Component {
    id: stackComponent
    Item {
      implicitWidth: childrenRect.width
      implicitHeight: childrenRect.height
      Repeater { model: root.node.children || []; delegate: childDelegate }
    }
  }

  Component {
    id: scrollComponent
    QQC.ScrollView {
      implicitWidth: Number(root.prop("width", 320))
      implicitHeight: Number(root.prop("height", 240))
      clip: root.prop("clip", true) !== false
      Column {
        spacing: Style.spacing.panelGap
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
  }

  Component {
    id: rectangleComponent
    Rectangle {
      readonly property int pad: Number(root.prop("padding", 0))
      implicitWidth: Number(root.prop("width", contentColumn.implicitWidth + pad * 2))
      implicitHeight: Number(root.prop("height", contentColumn.implicitHeight + pad * 2))
      color: root.prop("color", "transparent")
      radius: Number(root.prop("radius", 0))
      border.color: root.prop("border_color", "transparent")
      border.width: Number(root.prop("border_width", 0))
      Column {
        id: contentColumn
        anchors.centerIn: parent
        Repeater { model: root.node.children || []; delegate: childDelegate }
      }
    }
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
    OmarchyUi.PanelActionButton {
      iconText: root.iconGlyph(root.prop("icon", "")); tooltipText: root.escapeAutoText(root.prop("tooltip", ""))
      bordered: root.prop("bordered", false) === true; focusable: root.prop("focusable", false) === true
      hasCursor: root.prop("cursor", false) === true
      size: Number(root.prop("size", 28)); foreground: root.prop("foreground", root.foreground)
      hoverColor: root.prop("hover_color", foreground); fontFamily: String(root.prop("font_family", root.fontFamily))
      fontSize: Number(root.prop("font_size", Style.font.icon))
      onClicked: root.bridge.sendEvent(root.surfaceName, root.controlId, "click", {})
      onHovered: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { value: value }) }
    }
  }

  Component {
    id: barIconButtonComponent
    OmarchyUi.BarIconButton {
      text: root.iconGlyph(root.prop("icon", ""))
      tooltipText: root.escapeAutoText(root.prop("tooltip", ""))
      active: root.prop("active", false) === true
      foreground: root.prop("foreground", root.foreground)
      activeColor: root.prop("active_color", Color.accent)
      slotSize: Number(root.prop("slot_size", Style.bar.iconSlot))
      opticalSize: Number(root.prop("optical_size", Style.bar.iconCanvas))
      fontFamily: String(root.prop("font_family", root.fontFamily))
      fontSize: Number(root.prop("font_size", Style.bar.iconFont))
      textRotation: Number(root.prop("text_rotation", 0))
      keepSpace: root.prop("keep_space", false) === true
      dimmed: root.prop("dimmed", false) === true
      concealed: root.prop("concealed", false) === true
      interactive: root.prop("interactive", true) !== false
      onPressed: function(button) {
        var eventName = button === Qt.RightButton ? "right_click" : (button === Qt.MiddleButton ? "middle_click" : "click")
        root.bridge.sendEvent(root.surfaceName, root.controlId, eventName, { button: button })
      }
      onWheelMoved: function(delta) { root.bridge.sendEvent(root.surfaceName, root.controlId, "wheel", { delta: delta }) }
    }
  }

  Component {
    id: barIndicatorComponent
    OmarchyUi.BarIndicator {
      active: root.prop("active", false) === true
      activeText: root.iconGlyph(root.prop("active_icon", ""))
      inactiveText: root.iconGlyph(root.prop("inactive_icon", root.prop("active_icon", "")))
      activeTooltipText: root.escapeAutoText(root.prop("active_tooltip", ""))
      inactiveTooltipText: root.escapeAutoText(root.prop("inactive_tooltip", root.prop("active_tooltip", "")))
      indicatorBlock: String(root.prop("indicator_block", "single"))
      foreground: root.prop("foreground", root.foreground)
      activeColor: root.prop("active_color", Color.accent)
      fontFamily: String(root.prop("font_family", root.fontFamily))
      fontSize: Number(root.prop("font_size", Style.font.caption))
      onPressed: function(button) {
        var eventName = button === Qt.RightButton ? "right_click" : (button === Qt.MiddleButton ? "middle_click" : "click")
        root.bridge.sendEvent(root.surfaceName, root.controlId, eventName, { button: button })
      }
      onWheelMoved: function(delta) { root.bridge.sendEvent(root.surfaceName, root.controlId, "wheel", { delta: delta }) }
    }
  }

  Component {
    id: toggleComponent
    OmarchyUi.Toggle {
      label: root.escapeAutoText(root.prop("label", "")); description: root.escapeAutoText(root.prop("description", ""))
      checked: root.prop("checked", false) === true; hasCursor: root.prop("cursor", false) === true
      rounded: root.prop("rounded", Style.cornerRadius > 0) === true
      foreground: root.prop("foreground", root.foreground); accent: root.prop("accent", Color.accent)
      fontFamily: String(root.prop("font_family", root.fontFamily)); titleSize: Number(root.prop("title_size", Style.font.subtitle))
      descriptionSize: Number(root.prop("description_size", Style.font.caption))
      onClicked: root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: !checked })
      onHovered: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { value: value }) }
    }
  }

  Component {
    id: checkboxComponent
    QQC.CheckBox {
      id: checkControl
      text: root.escapeAutoText(root.prop("label", ""))
      checked: root.prop("checked", false) === true
      hoverEnabled: true
      spacing: Number(root.prop("spacing", Style.spacing.controlGap))
      leftPadding: 0
      rightPadding: 0
      indicator: Rectangle {
        implicitWidth: Number(root.prop("indicator_size", Style.space(20)))
        implicitHeight: implicitWidth
        x: checkControl.leftPadding
        y: checkControl.topPadding + (checkControl.availableHeight - height) / 2
        radius: Math.min(Style.cornerRadius, width / 4)
        color: checkControl.checked ? root.prop("accent", Color.accent) : root.prop("background", "transparent")
        border.width: Style.normalBorderWidth
        border.color: checkControl.checked ? root.prop("accent", Color.accent) : root.prop("foreground", root.foreground)
        Text {
          anchors.centerIn: parent
          text: checkControl.checked ? root.iconGlyph("check") : ""
          textFormat: Text.PlainText
          color: Color.background
          font.family: String(root.prop("font_family", root.fontFamily))
          font.pixelSize: parent.width * 0.7
        }
      }
      contentItem: Text {
        leftPadding: checkControl.indicator.width + checkControl.spacing
        text: checkControl.text
        textFormat: Text.PlainText
        color: root.prop("foreground", root.foreground)
        font.family: String(root.prop("font_family", root.fontFamily))
        font.pixelSize: Number(root.prop("font_size", Style.font.body))
        verticalAlignment: Text.AlignVCenter
      }
      onToggled: root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: checked })
      onHoveredChanged: root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { value: hovered })
    }
  }

  Component {
    id: lineChartComponent
    Item {
      implicitWidth: Number(root.prop("width", 420))
      implicitHeight: Number(root.prop("height", 220))

      Canvas {
        id: lineCanvas
        anchors.fill: parent
        antialiasing: true
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var raw = root.prop("values", [])
          if (!Array.isArray(raw) || raw.length === 0) return
          var values = raw.map(function(value) { return Number(value) })
          var pad = Math.max(8, Number(root.prop("point_size", 5)) + 3)
          var chartWidth = Math.max(1, width - pad * 2)
          var chartHeight = Math.max(1, height - pad * 2)
          var low = root.prop("minimum", null)
          var high = root.prop("maximum", null)
          if (low === null) low = Math.min.apply(Math, values)
          if (high === null) high = Math.max.apply(Math, values)
          low = Number(low); high = Number(high)
          if (high === low) { high += 1; low -= 1 }

          if (root.prop("show_grid", true) !== false) {
            ctx.strokeStyle = root.prop("grid_color", Color.muted)
            ctx.lineWidth = 1
            for (var grid = 0; grid <= 4; grid++) {
              var gy = pad + chartHeight * grid / 4
              ctx.beginPath(); ctx.moveTo(pad, gy); ctx.lineTo(width - pad, gy); ctx.stroke()
            }
          }

          var points = []
          for (var index = 0; index < values.length; index++) {
            var x = pad + (values.length === 1 ? chartWidth / 2 : chartWidth * index / (values.length - 1))
            var y = pad + chartHeight * (1 - (values[index] - low) / (high - low))
            points.push({ x: x, y: y })
          }
          var fill = String(root.prop("fill_color", ""))
          if (fill.length > 0 && points.length > 1) {
            ctx.beginPath(); ctx.moveTo(points[0].x, height - pad)
            for (var fillIndex = 0; fillIndex < points.length; fillIndex++) ctx.lineTo(points[fillIndex].x, points[fillIndex].y)
            ctx.lineTo(points[points.length - 1].x, height - pad); ctx.closePath()
            ctx.fillStyle = fill; ctx.fill()
          }
          ctx.beginPath(); ctx.moveTo(points[0].x, points[0].y)
          for (var lineIndex = 1; lineIndex < points.length; lineIndex++) ctx.lineTo(points[lineIndex].x, points[lineIndex].y)
          ctx.strokeStyle = root.prop("color", Color.accent)
          ctx.lineWidth = Number(root.prop("line_width", 2)); ctx.stroke()
          if (root.prop("show_points", true) !== false) {
            ctx.fillStyle = root.prop("color", Color.accent)
            var pointSize = Number(root.prop("point_size", 5))
            for (var pointIndex = 0; pointIndex < points.length; pointIndex++) {
              ctx.beginPath(); ctx.arc(points[pointIndex].x, points[pointIndex].y, pointSize, 0, Math.PI * 2); ctx.fill()
            }
          }
        }
      }

      Connections {
        target: root
        function onNodeChanged() { lineCanvas.requestPaint() }
      }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: root.subscribed("hover")
        function payload(mouse) {
          var values = root.prop("values", [])
          if (!Array.isArray(values) || values.length === 0) return ({ index: -1 })
          var index = Math.max(0, Math.min(values.length - 1, Math.round(mouse.x / Math.max(1, width) * (values.length - 1))))
          var labels = root.prop("labels", [])
          return { index: index, value: values[index], label: Array.isArray(labels) ? labels[index] : null }
        }
        onClicked: function(mouse) { root.bridge.sendEvent(root.surfaceName, root.controlId, "select", payload(mouse)) }
        onPositionChanged: function(mouse) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", payload(mouse)) }
      }
    }
  }

  Component {
    id: areaChartComponent
    Item {
      implicitWidth: Number(root.prop("width", 420))
      implicitHeight: Number(root.prop("height", 220))
      Canvas {
        id: areaCanvas
        anchors.fill: parent
        antialiasing: true
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var raw = root.prop("values", [])
          if (!Array.isArray(raw) || raw.length === 0) return
          var values = raw.map(function(value) { return Number(value) })
          var low = root.prop("minimum", null)
          var high = root.prop("maximum", null)
          if (low === null) low = Math.min.apply(Math, values)
          if (high === null) high = Math.max.apply(Math, values)
          low = Number(low); high = Number(high)
          if (high === low) { high += 1; low -= 1 }
          var pad = 10
          var chartWidth = Math.max(1, width - pad * 2)
          var chartHeight = Math.max(1, height - pad * 2)
          if (root.prop("show_grid", true) !== false) {
            ctx.strokeStyle = root.prop("grid_color", Color.muted); ctx.lineWidth = 1
            for (var grid = 0; grid <= 4; grid++) {
              var gy = pad + chartHeight * grid / 4
              ctx.beginPath(); ctx.moveTo(pad, gy); ctx.lineTo(width - pad, gy); ctx.stroke()
            }
          }
          var points = []
          for (var index = 0; index < values.length; index++) {
            points.push({
              x: pad + (values.length === 1 ? chartWidth / 2 : chartWidth * index / (values.length - 1)),
              y: pad + chartHeight * (1 - (values[index] - low) / (high - low))
            })
          }
          ctx.beginPath(); ctx.moveTo(points[0].x, height - pad)
          for (var fillIndex = 0; fillIndex < points.length; fillIndex++) ctx.lineTo(points[fillIndex].x, points[fillIndex].y)
          ctx.lineTo(points[points.length - 1].x, height - pad); ctx.closePath()
          ctx.fillStyle = root.prop("fill_color", root.prop("color", Color.accent)); ctx.fill()
          ctx.beginPath(); ctx.moveTo(points[0].x, points[0].y)
          for (var lineIndex = 1; lineIndex < points.length; lineIndex++) ctx.lineTo(points[lineIndex].x, points[lineIndex].y)
          ctx.strokeStyle = root.prop("color", Color.accent)
          ctx.lineWidth = Number(root.prop("line_width", 2)); ctx.stroke()
        }
      }
      Connections { target: root; function onNodeChanged() { areaCanvas.requestPaint() } }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: root.subscribed("hover")
        function payload(mouse) {
          var values = root.prop("values", [])
          if (!Array.isArray(values) || values.length === 0) return ({ index: -1 })
          var index = Math.max(0, Math.min(values.length - 1, Math.round(mouse.x / Math.max(1, width) * (values.length - 1))))
          var labels = root.prop("labels", [])
          return { index: index, value: values[index], label: Array.isArray(labels) ? labels[index] : null }
        }
        onClicked: function(mouse) { root.bridge.sendEvent(root.surfaceName, root.controlId, "select", payload(mouse)) }
        onPositionChanged: function(mouse) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", payload(mouse)) }
      }
    }
  }

  Component {
    id: barChartComponent
    Item {
      implicitWidth: Number(root.prop("width", 420))
      implicitHeight: Number(root.prop("height", 220))
      Canvas {
        id: barCanvas
        anchors.fill: parent
        antialiasing: true
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var raw = root.prop("values", [])
          if (!Array.isArray(raw) || raw.length === 0) return
          var values = raw.map(function(value) { return Number(value) })
          var low = root.prop("minimum", null)
          var high = root.prop("maximum", null)
          if (low === null) low = Math.min(0, Math.min.apply(Math, values))
          if (high === null) high = Math.max(0, Math.max.apply(Math, values))
          low = Number(low); high = Number(high)
          if (high === low) high = low + 1
          var pad = 10
          var chartWidth = Math.max(1, width - pad * 2)
          var chartHeight = Math.max(1, height - pad * 2)
          if (root.prop("show_grid", true) !== false) {
            ctx.strokeStyle = root.prop("grid_color", Color.muted); ctx.lineWidth = 1
            for (var grid = 0; grid <= 4; grid++) {
              var gy = pad + chartHeight * grid / 4
              ctx.beginPath(); ctx.moveTo(pad, gy); ctx.lineTo(width - pad, gy); ctx.stroke()
            }
          }
          var slot = chartWidth / values.length
          var gap = Math.max(0, Number(root.prop("bar_spacing", 6)))
          var colors = root.prop("colors", [Color.accent])
          var zeroY = pad + chartHeight * (1 - (0 - low) / (high - low))
          for (var index = 0; index < values.length; index++) {
            var valueY = pad + chartHeight * (1 - (values[index] - low) / (high - low))
            var left = pad + slot * index + gap / 2
            var top = Math.min(zeroY, valueY)
            var barHeight = Math.max(1, Math.abs(valueY - zeroY))
            ctx.fillStyle = Array.isArray(colors) && colors.length > 0 ? colors[index % colors.length] : Color.accent
            ctx.fillRect(left, top, Math.max(1, slot - gap), barHeight)
          }
        }
      }
      Connections { target: root; function onNodeChanged() { barCanvas.requestPaint() } }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: root.subscribed("hover")
        function payload(mouse) {
          var values = root.prop("values", [])
          if (!Array.isArray(values) || values.length === 0) return ({ index: -1 })
          var index = Math.max(0, Math.min(values.length - 1, Math.floor(mouse.x / Math.max(1, width) * values.length)))
          var labels = root.prop("labels", [])
          return { index: index, value: values[index], label: Array.isArray(labels) ? labels[index] : null }
        }
        onClicked: function(mouse) { root.bridge.sendEvent(root.surfaceName, root.controlId, "select", payload(mouse)) }
        onPositionChanged: function(mouse) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", payload(mouse)) }
      }
    }
  }

  Component {
    id: toggleSwitchComponent
    OmarchyUi.ToggleSwitch {
      checked: root.prop("checked", false) === true; busy: root.prop("busy", false) === true
      interactive: root.prop("interactive", root.prop("enabled", true)) !== false
      hasCursor: root.prop("cursor", false) === true; cursorRing: root.prop("cursor_ring", true) !== false
      cursorPad: Number(root.prop("cursor_pad", Style.space(6))); rounded: root.prop("rounded", Style.cornerRadius > 0) === true
      foreground: root.prop("foreground", root.foreground); accent: root.prop("accent", Color.accent)
      trackHeight: Number(root.prop("track_height", Math.max(22, Math.round(Style.spacing.controlHeight * 0.55))))
      trackWidth: Number(root.prop("track_width", Math.round(trackHeight * 1.9)))
      knobSize: Number(root.prop("knob_size", Math.max(6, Math.round(trackHeight * 0.72))))
      knobInset: Number(root.prop("knob_inset", Math.max(1, Math.round((trackHeight - knobSize) / 2))))
      onToggled: root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: !checked })
      onHovered: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { value: value }) }
    }
  }

  Component {
    id: textFieldComponent
    OmarchyUi.TextField {
      text: String(root.prop("text", "")); placeholderText: String(root.prop("placeholder", ""))
      password: root.prop("password", false) === true
      implicitWidth: Number(root.prop("width", 240)); foreground: root.prop("foreground", root.foreground)
      accent: root.prop("accent", Color.accent); selectionTint: root.prop("selection_tint", Style.selectionFillFor(foreground, accent))
      horizontalPadding: Number(root.prop("horizontal_padding", Style.spacing.controlPaddingX))
      verticalPadding: Number(root.prop("vertical_padding", Style.spacing.inputPaddingY)); hasCursor: root.prop("cursor", false) === true
      onTextEdited: root.bridge.sendEvent(root.surfaceName, root.controlId, "input", { value: text })
      onEditingFinished: root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: text })
      onAccepted: root.bridge.sendEvent(root.surfaceName, root.controlId, "submit", { value: text })
      onActiveFocusChanged: root.bridge.sendEvent(root.surfaceName, root.controlId, activeFocus ? "focus" : "blur", { value: text })
    }
  }

  Component {
    id: numberFieldComponent
    OmarchyUi.NumberField {
      label: root.escapeAutoText(root.prop("label", "")); value: Number(root.prop("value", 0))
      from: Number(root.prop("from", 0)); to: Number(root.prop("to", 100)); stepSize: Number(root.prop("step", 1))
      foreground: root.prop("foreground", root.foreground); accent: root.prop("accent", Color.accent)
      fontFamily: String(root.prop("font_family", root.fontFamily)); fontSize: Number(root.prop("font_size", Style.font.body))
      fieldWidth: Number(root.prop("field_width", Style.spacing.numberFieldWidth)); hasCursor: root.prop("cursor", false) === true
      onModified: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: value }) }
      onHovered: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { value: value }) }
    }
  }

  Component {
    id: sliderComponent
    OmarchyUi.PanelSlider {
      value: Number(root.prop("value", 0)); minimum: Number(root.prop("minimum", 0)); maximum: Number(root.prop("maximum", 1))
      step: Number(root.prop("step", 0.05)); integer: root.prop("integer", false) === true; tickCount: Number(root.prop("ticks", 0))
      implicitWidth: Number(root.prop("width", 200)); trackColor: root.prop("track_color", "#333")
      fillColor: root.prop("fill_color", root.foreground); knobColor: root.prop("knob_color", root.foreground)
      trackHeight: Number(root.prop("track_height", Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))))
      knobSize: Number(root.prop("knob_size", Math.max(14, Math.round(Style.spacing.controlHeight * 0.38))))
      tickColor: root.prop("tick_color", Color.background)
      onReleased: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: value }) }
      onMoved: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "input", { value: value }) }
      onRightClicked: root.bridge.sendEvent(root.surfaceName, root.controlId, "right_click", {})
    }
  }

  Component {
    id: dropdownComponent
    OmarchyUi.Dropdown {
      label: root.escapeAutoText(root.prop("label", "")); value: String(root.prop("value", "")); options: root.prop("options", [])
      implicitWidth: Number(root.prop("width", 240)); foreground: root.prop("foreground", root.foreground)
      background: root.prop("background", Color.popups.background); popupBorder: root.prop("popup_border", Color.popups.border)
      accent: root.prop("accent", Color.accent); fontFamily: String(root.prop("font_family", root.fontFamily))
      rowHeight: Number(root.prop("row_height", Style.spacing.controlHeight)); popupRowHeight: Number(root.prop("popup_row_height", Style.spacing.popupRowHeight))
      showLabel: root.prop("show_label", true) !== false; hasCursor: root.prop("cursor", false) === true
      onChanged: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: value }) }
      onHovered: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { value: value }) }
    }
  }

  Component {
    id: multiSelectComponent
    OmarchyUi.MultiSelect {
      label: root.escapeAutoText(root.prop("label", "")); values: root.prop("values", []); options: root.prop("options", [])
      placeholderText: String(root.prop("placeholder", "Search...")); enabled: root.prop("enabled", true) !== false
      optionsCommand: root.prop("options_command", []); optionsCommandCwd: String(root.prop("options_command_cwd", ""))
      emptyText: String(root.prop("empty_text", "No options")); noSelectionText: String(root.prop("no_selection_text", "None selected"))
      triggerLabel: String(root.prop("trigger_label", "")); showLabel: root.prop("show_label", true) !== false
      implicitWidth: Number(root.prop("width", 240)); foreground: root.prop("foreground", root.foreground)
      background: root.prop("background", Color.popups.background); popupBorder: root.prop("popup_border", Color.popups.border)
      accent: root.prop("accent", Color.accent); fontFamily: String(root.prop("font_family", root.fontFamily))
      rowHeight: Number(root.prop("row_height", Style.spacing.controlHeight)); popupRowHeight: Number(root.prop("popup_row_height", Style.spacing.popupRowHeight))
      popupMinHeight: Number(root.prop("popup_min_height", Style.spacing.searchablePopupMinHeight)); hasCursor: root.prop("cursor", false) === true
      onChanged: function(values) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: values }) }
      onHovered: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { value: value }) }
    }
  }

  Component {
    id: buttonGroupComponent
    OmarchyUi.ButtonGroup {
      value: String(root.prop("value", "")); options: root.prop("options", [])
      foreground: root.prop("foreground", root.foreground); background: root.prop("background", Color.background)
      accent: root.prop("accent", Color.accent); fontFamily: String(root.prop("font_family", root.fontFamily))
      fontSize: Number(root.prop("font_size", Style.font.body)); focusable: root.prop("focusable", true) !== false
      cursorIndex: Number(root.prop("cursor_index", -1))
      onChanged: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: value }) }
      onHovered: function(index, value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { index: index, value: value }) }
    }
  }

  Component {
    id: progressComponent
    Rectangle {
      property real minimum: Number(root.prop("minimum", 0)); property real maximum: Number(root.prop("maximum", 1))
      implicitWidth: Number(root.prop("width", 200)); implicitHeight: Number(root.prop("height", 6)); radius: height / 2
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
      Rectangle { width: parent.width * Math.max(0, Math.min(1, (Number(root.prop("value", 0)) - parent.minimum) / Math.max(0.000001, parent.maximum - parent.minimum))); height: parent.height; radius: parent.radius; color: root.prop("color", root.foreground) }
    }
  }

  Component { id: separatorComponent; OmarchyUi.PanelSeparator { foreground: root.foreground; strength: Number(root.prop("strength", 0.12)) } }
  Component { id: sectionHeaderComponent; OmarchyUi.PanelSectionHeader { text: root.escapeAutoText(root.prop("text", "")); foreground: root.foreground; fontFamily: root.fontFamily } }

  Component {
    id: searchableDropdownComponent
    OmarchyUi.SearchableDropdown {
      label: root.escapeAutoText(root.prop("label", "")); value: String(root.prop("value", "")); options: root.prop("options", [])
      placeholderText: String(root.prop("placeholder", "Search...")); emptyText: String(root.prop("empty_text", "No matches"))
      triggerLabel: String(root.prop("trigger_label", "")); implicitWidth: Number(root.prop("width", 240))
      foreground: root.prop("foreground", root.foreground); background: root.prop("background", Color.popups.background)
      popupBorder: root.prop("popup_border", Color.popups.border); accent: root.prop("accent", Color.accent)
      fontFamily: String(root.prop("font_family", root.fontFamily)); rowHeight: Number(root.prop("row_height", Style.spacing.controlHeight))
      popupRowHeight: Number(root.prop("popup_row_height", Style.spacing.popupRowHeight)); popupMinHeight: Number(root.prop("popup_min_height", Style.spacing.searchablePopupMinHeight))
      showLabel: root.prop("show_label", true) !== false; hasCursor: root.prop("cursor", false) === true
      onChanged: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: value }) }
      onHovered: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "hover", { value: value }) }
    }
  }

  Component {
    id: confirmDialogComponent
    OmarchyUi.ConfirmDialog {
      opened: root.prop("opened", false) === true; message: String(root.prop("message", ""))
      cancelText: String(root.prop("cancel_text", "Cancel")); confirmText: String(root.prop("confirm_text", "Confirm"))
      selectedIndex: Number(root.prop("selected_index", 1)); visible: root.prop("visible", true) !== false
      background: root.prop("background", Color.background); foreground: root.prop("foreground", root.foreground)
      scrim: root.prop("scrim", Util.alpha(Color.background, 0.7)); selectedBackground: root.prop("selected_background", Util.alpha(root.foreground, 0.08))
      selectedText: root.prop("selected_text", Color.accent); fontFamily: String(root.prop("font_family", root.fontFamily))
      cornerRadius: Number(root.prop("corner_radius", Style.cornerRadius))
      onCanceled: root.bridge.sendEvent(root.surfaceName, root.controlId, "cancel", {})
      onConfirmed: root.bridge.sendEvent(root.surfaceName, root.controlId, "confirm", {})
    }
  }

  Component {
    id: panelHeroComponent
    OmarchyUi.PanelHero {
      title: root.escapeAutoText(root.prop("title", "")); meta: root.escapeAutoText(root.prop("meta", "")); detail: root.escapeAutoText(root.prop("detail", ""))
      iconSize: Number(root.prop("icon_size", Style.font.display)); iconOpacity: Number(root.prop("icon_opacity", 1))
      metaOpacity: Number(root.prop("meta_opacity", 1)); foreground: root.prop("foreground", root.foreground)
      fontFamily: String(root.prop("font_family", root.fontFamily))
    }
  }

  Component { id: opticalGlyphComponent; OmarchyUi.OpticalGlyph { text: root.iconGlyph(root.prop("text", "")); fontSize: Number(root.prop("size", Style.font.body)); color: root.prop("color", root.foreground); debugBounds: root.prop("debug_bounds", false) === true; fontFamily: root.fontFamily } }

  Component {
    id: cursorSurfaceComponent
    OmarchyUi.CursorSurface {
      implicitWidth: Number(root.prop("width", contentItem.implicitWidth)); implicitHeight: Number(root.prop("height", contentItem.implicitHeight))
      current: root.prop("current", false) === true; outline: root.prop("outline", false) === true; bordered: root.prop("bordered", false) === true
      hasCursor: root.prop("cursor", false) === true; foreground: root.prop("foreground", root.foreground)
      accent: root.prop("accent", Color.accent); fill: root.prop("fill", Style.hoverFillFor(foreground, accent))
      currentFill: root.prop("current_fill", Style.selectedFillFor(foreground, accent))
      Column { id: contentItem; anchors.centerIn: parent; Repeater { model: root.node.children || []; delegate: childDelegate } }
      MouseArea { anchors.fill: parent; onClicked: root.bridge.sendEvent(root.surfaceName, root.controlId, "click", {}) }
    }
  }

  Component {
    id: widgetButtonComponent
    OmarchyUi.WidgetButton {
      text: root.escapeAutoText(root.prop("text", "")); tooltipText: root.escapeAutoText(root.prop("tooltip", "")); active: root.prop("active", false) === true
      dimmed: root.prop("dimmed", false) === true; concealed: root.prop("concealed", false) === true
      interactive: root.prop("interactive", true) !== false; pressable: root.prop("pressable", true) !== false
      fontFamily: String(root.prop("font_family", root.fontFamily)); fontSize: Number(root.prop("font_size", Style.font.body))
      foreground: root.prop("foreground", root.foreground); activeColor: root.prop("active_color", Color.urgent)
      horizontalMargin: Number(root.prop("horizontal_margin", 8.5)); verticalPadding: Number(root.prop("vertical_padding", 6))
      fixedWidth: Number(root.prop("fixed_width", -1)); fixedHeight: Number(root.prop("fixed_height", -1)); textRotation: Number(root.prop("text_rotation", 0))
      keepSpace: root.prop("keep_space", false) === true; useActiveColor: root.prop("use_active_color", true) !== false
      maintainIndicatorReveal: root.prop("maintain_indicator_reveal", false) === true
      labelVisible: root.prop("label_visible", true) !== false; hasVisualContent: root.prop("has_visual_content", text !== "") === true
      onPressed: function(button) {
        var eventName = button === Qt.RightButton ? "right_click" : (button === Qt.MiddleButton ? "middle_click" : "click")
        root.bridge.sendEvent(root.surfaceName, root.controlId, eventName, { button: button })
      }
      onWheelMoved: function(delta) { root.bridge.sendEvent(root.surfaceName, root.controlId, "wheel", { delta: delta }) }
    }
  }

  Component {
    id: listViewComponent
    ListView {
      id: listControl
      readonly property var sourceItems: root.prop("items", [])
      readonly property string keyField: String(root.prop("key_field", "id"))
      readonly property string labelField: String(root.prop("label_field", "label"))
      readonly property string descriptionField: String(root.prop("description_field", "description"))
      readonly property string iconField: String(root.prop("icon_field", "icon"))
      implicitWidth: Number(root.prop("width", 280)); implicitHeight: Number(root.prop("height", 240))
      orientation: String(root.prop("orientation", "vertical")) === "horizontal" ? ListView.Horizontal : ListView.Vertical
      spacing: Number(root.prop("spacing", Style.spacing.labelGap)); clip: true; model: sourceItems
      currentIndex: {
        var selected = root.prop("selected", null)
        for (var i = 0; i < sourceItems.length; i++) {
          var item = sourceItems[i]
          var key = typeof item === "object" ? item[keyField] : item
          if (key === selected) return i
        }
        return -1
      }
      onContentXChanged: if (moving) root.bridge.sendEvent(root.surfaceName, root.controlId, "scroll", { x: contentX, y: contentY })
      onContentYChanged: if (moving) root.bridge.sendEvent(root.surfaceName, root.controlId, "scroll", { x: contentX, y: contentY })

      delegate: OmarchyUi.CursorSurface {
        required property var modelData
        required property int index
        readonly property var value: typeof modelData === "object" ? modelData[listControl.keyField] : modelData
        width: listControl.orientation === ListView.Vertical ? listControl.width : implicitWidth
        implicitWidth: rowContent.implicitWidth + Style.spacing.rowPaddingX * 2
        implicitHeight: Math.max(Style.spacing.controlHeight, rowContent.implicitHeight + Style.spacing.controlPaddingY * 2)
        current: index === listControl.currentIndex
        foreground: root.foreground
        Row {
          id: rowContent
          anchors.centerIn: parent
          spacing: Style.spacing.controlGap
          Text { visible: text !== ""; text: root.iconGlyph(typeof modelData === "object" ? modelData[listControl.iconField] : ""); textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily }
          Column {
            Text { text: String(typeof modelData === "object" ? (modelData[listControl.labelField] ?? value) : modelData); textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily }
            Text { visible: text !== ""; text: String(typeof modelData === "object" ? (modelData[listControl.descriptionField] || "") : ""); textFormat: Text.PlainText; color: Qt.darker(root.foreground, 1.4); font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          }
        }
        MouseArea {
          anchors.fill: parent
          onClicked: {
            listControl.currentIndex = index
            root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: parent.value, index: index, item: modelData })
            root.bridge.sendEvent(root.surfaceName, root.controlId, "activate", { value: parent.value, index: index, item: modelData })
          }
        }
      }

      Text {
        anchors.centerIn: parent; visible: listControl.count === 0
        text: String(root.prop("empty_text", "No items")); textFormat: Text.PlainText; color: Qt.darker(root.foreground, 1.4); font.family: root.fontFamily
      }
    }
  }
}
