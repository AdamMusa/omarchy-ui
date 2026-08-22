import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui as OmarchyUi

Loader {
  id: root

  required property var bridge
  required property string surfaceName
  required property string controlId
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  readonly property var node: {
    var currentRevision = bridge ? bridge.revision : 0
    return bridge ? bridge.nodeFor(controlId) : null
  }

  readonly property bool builtIn: ["text", "icon", "button", "row", "column", "container", "image", "spacer",
    "grid", "stack", "scroll", "rectangle", "action_button", "toggle", "toggle_switch", "text_field",
    "number_field", "slider", "dropdown", "multi_select", "button_group", "progress", "separator",
    "section_header"].indexOf(node ? node.type : "") >= 0

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
      reset: "\uf2f9"
    }
    var key = String(name || "")
    return icons[key] || key
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

  function runTransition() {
    var transition = node ? node.transition : null
    if (!item || !transition || !item.hasOwnProperty(transition.property)) return
    if (transition.from === undefined || transition.from === null) return
    patchAnimation.stop()
    patchAnimation.target = item
    patchAnimation.property = String(transition.property)
    patchAnimation.from = transition.from
    patchAnimation.to = transition.to
    patchAnimation.duration = Number(transition.duration)
    patchAnimation.easing.type = easingType(transition.easing)
    transitionTimer.interval = Number(transition.delay || 0)
    if (transitionTimer.interval > 0) transitionTimer.restart()
    else patchAnimation.restart()
  }

  visible: node !== null && prop("visible", true) !== false
  sourceComponent: {
    if (!node) return null
    if (node.type === "text") return textComponent
    if (node.type === "icon") return iconComponent
    if (node.type === "button") return buttonComponent
    if (node.type === "row") return rowComponent
    if (node.type === "column") return columnComponent
    if (node.type === "container") return containerComponent
    if (node.type === "image") return imageComponent
    if (node.type === "spacer") return spacerComponent
    if (node.type === "grid") return gridComponent
    if (node.type === "stack") return stackComponent
    if (node.type === "scroll") return scrollComponent
    if (node.type === "rectangle") return rectangleComponent
    if (node.type === "action_button") return actionButtonComponent
    if (node.type === "toggle") return toggleComponent
    if (node.type === "toggle_switch") return toggleSwitchComponent
    if (node.type === "text_field") return textFieldComponent
    if (node.type === "number_field") return numberFieldComponent
    if (node.type === "slider") return sliderComponent
    if (node.type === "dropdown") return dropdownComponent
    if (node.type === "multi_select") return multiSelectComponent
    if (node.type === "button_group") return buttonGroupComponent
    if (node.type === "progress") return progressComponent
    if (node.type === "separator") return separatorComponent
    if (node.type === "section_header") return sectionHeaderComponent
    return null
  }
  source: node && !builtIn ? bridge.componentSource(node.type) : ""
  onLoaded: {
    if (!item || builtIn) return
    if (item.hasOwnProperty("bridge")) item.bridge = bridge
    if (item.hasOwnProperty("surfaceName")) item.surfaceName = surfaceName
    if (item.hasOwnProperty("controlId")) item.controlId = controlId
    if (item.hasOwnProperty("node")) item.node = node
    runTransition()
  }
  onNodeChanged: {
    if (item && !builtIn && item.hasOwnProperty("node")) item.node = node
    Qt.callLater(runTransition)
  }

  Timer {
    id: transitionTimer
    repeat: false
    onTriggered: patchAnimation.restart()
  }

  PropertyAnimation { id: patchAnimation }
  implicitWidth: item ? item.implicitWidth : 0
  implicitHeight: item ? item.implicitHeight : 0

  Component {
    id: textComponent

    Text {
      text: String(root.prop("text", ""))
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
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Number(root.prop("size", Style.font.icon))
    }
  }

  Component {
    id: buttonComponent

    OmarchyUi.Button {
      text: String(root.prop("text", ""))
      iconText: root.iconGlyph(root.prop("icon", ""))
      tooltipText: String(root.prop("tooltip", ""))
      enabled: root.prop("enabled", true) !== false
      selected: root.prop("selected", false) === true
      bordered: root.prop("bordered", true) !== false
      focusable: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.bridge.sendEvent(root.surfaceName, root.controlId, "click", {})
    }
  }

  Component {
    id: rowComponent

    Row {
      spacing: Number(root.prop("spacing", Style.spacing.controlGap))

      Repeater {
        model: root.node && Array.isArray(root.node.children) ? root.node.children : []

        ControlNode {
          required property var modelData
          bridge: root.bridge
          surfaceName: root.surfaceName
          controlId: String(modelData.id)
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
      }
    }
  }

  Component {
    id: columnComponent

    Column {
      spacing: Number(root.prop("spacing", Style.spacing.panelGap))

      Repeater {
        model: root.node && Array.isArray(root.node.children) ? root.node.children : []

        ControlNode {
          required property var modelData
          bridge: root.bridge
          surfaceName: root.surfaceName
          controlId: String(modelData.id)
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
      }
    }
  }

  Component {
    id: containerComponent

    BorderSurface {
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

          ControlNode {
            required property var modelData
            bridge: root.bridge
            surfaceName: root.surfaceName
            controlId: String(modelData.id)
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
        }
      }
    }
  }

  Component {
    id: imageComponent

    Image {
      source: String(root.prop("source", ""))
      implicitWidth: Number(root.prop("width", 120))
      implicitHeight: Number(root.prop("height", 120))
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
    id: childDelegate
    ControlNode {
      required property var modelData
      bridge: root.bridge; surfaceName: root.surfaceName; controlId: String(modelData.id)
      foreground: root.foreground; fontFamily: root.fontFamily
    }
  }

  Component {
    id: actionButtonComponent
    OmarchyUi.PanelActionButton {
      iconText: root.iconGlyph(root.prop("icon", "")); tooltipText: String(root.prop("tooltip", ""))
      enabled: root.prop("enabled", true) !== false; bordered: root.prop("bordered", false) === true
      size: Number(root.prop("size", implicitHeight)); foreground: root.foreground; fontFamily: root.fontFamily
      onClicked: root.bridge.sendEvent(root.surfaceName, root.controlId, "click", {})
    }
  }

  Component {
    id: toggleComponent
    OmarchyUi.Toggle {
      label: String(root.prop("label", "")); description: String(root.prop("description", ""))
      checked: root.prop("checked", false) === true; enabled: root.prop("enabled", true) !== false
      foreground: root.foreground; fontFamily: root.fontFamily
      onClicked: root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: !checked })
    }
  }

  Component {
    id: toggleSwitchComponent
    OmarchyUi.ToggleSwitch {
      checked: root.prop("checked", false) === true; busy: root.prop("busy", false) === true
      interactive: root.prop("enabled", true) !== false; foreground: root.foreground
      onToggled: root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: !checked })
    }
  }

  Component {
    id: textFieldComponent
    OmarchyUi.TextField {
      text: String(root.prop("text", "")); placeholderText: String(root.prop("placeholder", ""))
      password: root.prop("password", false) === true; enabled: root.prop("enabled", true) !== false
      implicitWidth: Number(root.prop("width", 240)); foreground: root.foreground
      onEditingFinished: root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: text })
      onAccepted: root.bridge.sendEvent(root.surfaceName, root.controlId, "submit", { value: text })
    }
  }

  Component {
    id: numberFieldComponent
    OmarchyUi.NumberField {
      label: String(root.prop("label", "")); value: Number(root.prop("value", 0))
      from: Number(root.prop("from", 0)); to: Number(root.prop("to", 100)); stepSize: Number(root.prop("step", 1))
      enabled: root.prop("enabled", true) !== false; foreground: root.foreground; fontFamily: root.fontFamily
      onModified: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: value }) }
    }
  }

  Component {
    id: sliderComponent
    OmarchyUi.PanelSlider {
      value: Number(root.prop("value", 0)); minimum: Number(root.prop("minimum", 0)); maximum: Number(root.prop("maximum", 1))
      step: Number(root.prop("step", 0.05)); integer: root.prop("integer", false) === true; tickCount: Number(root.prop("ticks", 0))
      enabled: root.prop("enabled", true) !== false; implicitWidth: Number(root.prop("width", 200))
      onReleased: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: value }) }
    }
  }

  Component {
    id: dropdownComponent
    OmarchyUi.Dropdown {
      label: String(root.prop("label", "")); value: String(root.prop("value", "")); options: root.prop("options", [])
      enabled: root.prop("enabled", true) !== false; implicitWidth: Number(root.prop("width", 240))
      foreground: root.foreground; fontFamily: root.fontFamily
      onChanged: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: value }) }
    }
  }

  Component {
    id: multiSelectComponent
    OmarchyUi.MultiSelect {
      label: String(root.prop("label", "")); values: root.prop("values", []); options: root.prop("options", [])
      placeholderText: String(root.prop("placeholder", "Search...")); enabled: root.prop("enabled", true) !== false
      implicitWidth: Number(root.prop("width", 240)); foreground: root.foreground; fontFamily: root.fontFamily
      onChanged: function(values) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: values }) }
    }
  }

  Component {
    id: buttonGroupComponent
    OmarchyUi.ButtonGroup {
      value: String(root.prop("value", "")); options: root.prop("options", []); enabled: root.prop("enabled", true) !== false
      foreground: root.foreground; fontFamily: root.fontFamily
      onChanged: function(value) { root.bridge.sendEvent(root.surfaceName, root.controlId, "change", { value: value }) }
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
  Component { id: sectionHeaderComponent; OmarchyUi.PanelSectionHeader { text: String(root.prop("text", "")); foreground: root.foreground; fontFamily: root.fontFamily } }
}
