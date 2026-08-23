import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

Row {
  required property var renderer
      spacing: Number(renderer.prop("spacing", Style.spacing.controlGap))

      Repeater {
        model: renderer.node && Array.isArray(renderer.node.children) ? renderer.node.children : []
        delegate: renderer.rowChildDelegateComponent
      }
    }
