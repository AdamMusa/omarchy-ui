import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtMultimedia
import QtQuick.VectorImage
import qs.Commons
import qs.Ui as OmarchyUi

OmarchyUi.PanelSectionHeader {
  required property var renderer
  text: renderer.escapeAutoText(renderer.prop("text", ""))
  foreground: renderer.foreground
  fontFamily: renderer.fontFamily
}
