import QtQuick

Item {
  id: root

  required property var renderer

  x: Number(renderer.prop("position_x", 0))
  y: Number(renderer.prop("position_y", 0))
  width: Math.max(1, Number(renderer.prop("item_width", 1)))
  height: Math.max(1, Number(renderer.prop("item_height", 1)))
  clip: renderer.prop("clip", false) === true

  Repeater {
    model: renderer.node && Array.isArray(renderer.node.children) ? renderer.node.children : []
    delegate: renderer.childDelegateComponent
  }
}
