import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

OmarchyUi.OpticalGlyph {
  required property var renderer
  text: renderer.iconGlyph(renderer.prop("text", ""))
  fontSize: Number(renderer.prop("size", Style.font.body))
  color: renderer.prop("color", renderer.foreground)
  debugBounds: renderer.prop("debug_bounds", false) === true
  fontFamily: renderer.fontFamily
}
