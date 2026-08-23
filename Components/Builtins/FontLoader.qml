import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

Item {
  required property var renderer
      implicitWidth: 0
      implicitHeight: 0
      FontLoader {
        source: String(renderer.prop("source", ""))
        onStatusChanged: {
          if (renderer.subscribed("status")) renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "status", { value: status, name: name })
          if (status === FontLoader.Ready && renderer.subscribed("loaded")) renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "loaded", { name: name })
          if (status === FontLoader.Error && renderer.subscribed("error")) renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, "error", {})
        }
      }
    }
