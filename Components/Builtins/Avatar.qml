import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

Rectangle {
  required property var renderer
      id: avatarRoot
      implicitWidth: Number(renderer.prop("size", 48))
      implicitHeight: implicitWidth
      radius: Number(renderer.prop("radius", width / 2))
      color: renderer.prop("background", Color.accent)
      clip: true
      readonly property string avatarSource: String(renderer.prop("source", ""))
      readonly property string displayName: String(renderer.prop("name", ""))
      Text {
        anchors.centerIn: parent
        visible: avatarImage.status !== Image.Ready
        text: {
          var words = avatarRoot.displayName.trim().split(/\s+/)
          if (words.length === 0 || words[0].length === 0) return "?"
          return (words[0].charAt(0) + (words.length > 1 ? words[words.length - 1].charAt(0) : "")).toUpperCase()
        }
        color: renderer.prop("foreground", Color.background)
        font.family: renderer.fontFamily
        font.bold: true
        font.pixelSize: Number(renderer.prop("font_size", avatarRoot.width * 0.38))
      }
      Image {
        id: avatarImage
        anchors.fill: parent
        source: avatarRoot.avatarSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: renderer.prop("asynchronous", true) !== false
        cache: renderer.prop("cache", true) !== false
        visible: status === Image.Ready
        onStatusChanged: {
          if (status === Image.Ready && renderer.subscribed("loaded")) renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "loaded", { width: sourceSize.width, height: sourceSize.height })
          if (status === Image.Error && renderer.subscribed("error")) renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "error", {})
        }
      }
      TapHandler { onTapped: renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "click", {}) }
    }
