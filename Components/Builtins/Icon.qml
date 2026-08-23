import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

Text {
  required property var renderer
      text: renderer.iconGlyph(renderer.prop("name", renderer.prop("text", "")))
      textFormat: Text.PlainText
      color: renderer.prop("color", renderer.foreground)
      font.family: renderer.fontFamily
      font.pixelSize: Number(renderer.prop("size", Style.font.icon))
    }
