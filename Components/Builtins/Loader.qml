import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

Loader {
  required property var renderer
      readonly property var childNode: renderer.node && Array.isArray(renderer.node.children) && renderer.node.children.length > 0
        ? renderer.node.children[0] : null
      active: renderer.prop("active", true) !== false && childNode !== null
      asynchronous: renderer.prop("asynchronous", false) === true
      source: active ? Qt.resolvedUrl("../../ControlNode.qml") : ""
      width: Number(renderer.prop("width", item ? item.implicitWidth : 0))
      height: Number(renderer.prop("height", item ? item.implicitHeight : 0))
      onLoaded: {
        item.bridge = renderer.bridge
        item.surfaceName = renderer.surfaceName
        item.controlId = String(childNode.id)
        item.foreground = renderer.foreground
        item.fontFamily = renderer.fontFamily
        if (renderer.subscribed("loaded")) renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "loaded", {})
      }
      onStatusChanged: {
        if (renderer.subscribed("status"))
          renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "status", { value: status })
      }
    }
