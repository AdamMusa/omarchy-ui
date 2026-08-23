import QtQuick
import QtQuick.Controls as QQC
import qs.Commons

QQC.Dialog {
  id: alertRoot

  required property var renderer
  readonly property bool requestedOpen: renderer.prop("opened", false) === true
    && renderer.prop("visible", true) !== false
  readonly property string severity: String(renderer.prop("severity", "info"))

  function severityIcon() {
    if (severity === "success") return "circle_check"
    if (severity === "warning") return "warning"
    if (severity === "error" || severity === "critical") return "circle_xmark"
    return "circle_info"
  }

  function severityColor() {
    if (severity === "success") return renderer.prop("success_color", renderer.prop("accent", Color.accent))
    if (severity === "warning") return renderer.prop("warning_color", "#d8a657")
    if (severity === "error" || severity === "critical") return renderer.prop("error_color", Color.urgent)
    return renderer.prop("accent", Color.accent)
  }

  function standardButtonsValue(value) {
    var names = Array.isArray(value) ? value : (value === null || value === undefined ? [] : [value])
    var result = QQC.Dialog.NoButton
    for (var index = 0; index < names.length; index++) {
      var name = String(names[index])
      if (name === "ok") result |= QQC.Dialog.Ok
      else if (name === "save") result |= QQC.Dialog.Save
      else if (name === "yes") result |= QQC.Dialog.Yes
      else if (name === "no") result |= QQC.Dialog.No
      else if (name === "abort") result |= QQC.Dialog.Abort
      else if (name === "retry") result |= QQC.Dialog.Retry
      else if (name === "ignore") result |= QQC.Dialog.Ignore
      else if (name === "close") result |= QQC.Dialog.Close
      else if (name === "cancel") result |= QQC.Dialog.Cancel
      else if (name === "discard") result |= QQC.Dialog.Discard
      else if (name === "help") result |= QQC.Dialog.Help
      else if (name === "apply") result |= QQC.Dialog.Apply
      else if (name === "reset") result |= QQC.Dialog.Reset
    }
    return result
  }

  function closePolicyValue(value) {
    var names = Array.isArray(value) ? value : [value || "escape"]
    var result = 0
    for (var index = 0; index < names.length; index++) {
      var name = String(names[index])
      if (name === "escape") result |= QQC.Popup.CloseOnEscape
      if (name === "outside") result |= QQC.Popup.CloseOnPressOutside
      if (name === "outside_parent") result |= QQC.Popup.CloseOnPressOutsideParent
    }
    return result
  }

  function syncOpenState() {
    if (requestedOpen === opened) return
    if (requestedOpen) open()
    else close()
  }

  title: String(renderer.prop("title", ""))
  standardButtons: standardButtonsValue(renderer.prop("standard_buttons", ["ok"]))
  x: Number(renderer.prop("x", 0))
  y: Number(renderer.prop("y", 0))
  width: Number(renderer.prop("width", 500))
  height: Number(renderer.prop("height", 360))
  modal: renderer.prop("modal", true) !== false
  dim: renderer.prop("dim", modal) !== false
  focus: renderer.prop("focus", true) !== false
  closePolicy: closePolicyValue(renderer.prop("close_policy", "escape"))
  enabled: renderer.prop("enabled", true) !== false
  padding: Number(renderer.prop("padding", Style.spacing.lg))
  font.family: String(renderer.prop("font_family", renderer.fontFamily))
  font.pixelSize: Number(renderer.prop("font_size", Style.font.body))

  background: Rectangle {
    color: renderer.prop("background", Color.background)
    radius: Number(renderer.prop("radius", Style.cornerRadius))
    border.width: String(renderer.prop("border_color", "")).length > 0 ? Style.normalBorderWidth : 0
    border.color: renderer.prop("border_color", "transparent")
  }

  contentItem: Column {
    spacing: Number(renderer.prop("spacing", Style.spacing.md))

    Row {
      width: parent.width
      spacing: Number(renderer.prop("spacing", Style.spacing.md))
      Text {
        text: renderer.iconGlyph(alertRoot.severityIcon())
        color: alertRoot.severityColor()
        font.family: renderer.fontFamily
        font.pixelSize: Number(renderer.prop("message_size", 28))
      }
      Text {
        width: parent.width - x
        text: String(renderer.prop("message", ""))
        color: renderer.prop("foreground", renderer.foreground)
        font.family: String(renderer.prop("font_family", renderer.fontFamily))
        font.pixelSize: Number(renderer.prop("message_size", Style.font.heading))
        font.bold: true
        wrapMode: Text.Wrap
      }
    }

    Text {
      width: parent.width
      visible: text.length > 0
      text: String(renderer.prop("informative_text", ""))
      color: renderer.prop("muted", Color.muted)
      font.family: String(renderer.prop("font_family", renderer.fontFamily))
      font.pixelSize: Number(renderer.prop("font_size", Style.font.body))
      wrapMode: Text.Wrap
    }

    QQC.ScrollView {
      width: parent.width
      height: Number(renderer.prop("details_height", 120))
      visible: String(renderer.prop("detailed_text", "")).length > 0
      clip: true
      QQC.TextArea {
        text: String(renderer.prop("detailed_text", ""))
        readOnly: true
        selectByMouse: true
        wrapMode: TextEdit.Wrap
        color: renderer.prop("foreground", renderer.foreground)
        font.family: String(renderer.prop("font_family", renderer.fontFamily))
        font.pixelSize: Number(renderer.prop("details_size", Style.font.caption))
      }
    }
  }

  Component.onCompleted: syncOpenState()
  onRequestedOpenChanged: syncOpenState()
  onAccepted: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "accept", {})
  onRejected: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "reject", {})
  onApplied: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "apply", {})
  onReset: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "reset", {})
  onDiscarded: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "discard", {})
  onHelpRequested: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "help", {})
  onOpened: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "open", {})
  onClosed: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "close", {})
  onAboutToShow: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "about_to_show", {})
  onAboutToHide: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "about_to_hide", {})
  onVisibleChanged: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId,
    visible ? "show" : "hide", {})
  onActiveFocusChanged: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId,
    activeFocus ? "focus" : "blur", {})
}
