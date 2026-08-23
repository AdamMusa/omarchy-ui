import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

Image {
  required property var renderer
      source: String(renderer.prop("source", ""))
      width: Number(renderer.prop("width", 120))
      height: Number(renderer.prop("height", 120))
      asynchronous: true
      fillMode: Image.PreserveAspectFit
    }
