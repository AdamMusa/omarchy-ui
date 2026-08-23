import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

Item {
  required property var renderer
      implicitWidth: childrenRect.width
      implicitHeight: childrenRect.height
      Repeater { model: renderer.node.children || []; delegate: renderer.childDelegateComponent }
    }
