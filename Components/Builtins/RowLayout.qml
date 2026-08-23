import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

RowLayout {
  required property var renderer
      spacing: Number(renderer.prop("spacing", Style.spacing.controlGap))
      Repeater { model: renderer.node.children || []; delegate: renderer.layoutChildDelegateComponent }
    }
