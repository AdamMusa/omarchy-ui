import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

QQC.ScrollView {
  required property var renderer
      implicitWidth: Number(renderer.prop("width", 320))
      implicitHeight: Number(renderer.prop("height", 240))
      clip: renderer.prop("clip", true) !== false
      Column {
        spacing: Style.spacing.panelGap
        Repeater { model: renderer.node.children || []; delegate: renderer.childDelegateComponent }
      }
    }
