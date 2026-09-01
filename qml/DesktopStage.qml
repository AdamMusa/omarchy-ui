import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: window

  required property var renderer
  readonly property real requestedX: Number(renderer.prop("stage_x", 48))
  readonly property real requestedY: Number(renderer.prop("stage_y", 220))
  property real sceneX: requestedX
  property real sceneY: requestedY

  function boundedX(value) {
    return Math.max(0, Math.min(width - stage.width, Number(value)))
  }

  function boundedY(value) {
    return Math.max(0, Math.min(height - stage.height, Number(value)))
  }

  function send(name, payload) {
    if (renderer.subscribed(name))
      renderer.bridge.sendEvent(renderer.surfaceName, renderer.controlId, name, payload || {})
  }

  onRequestedXChanged: if (!sceneDrag.active) sceneX = boundedX(requestedX)
  onRequestedYChanged: if (!sceneDrag.active) sceneY = boundedY(requestedY)

  visible: renderer.prop("pinned", false) === true
  anchors { top: true; right: true; bottom: true; left: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: renderer.bridge && renderer.bridge.manifest && renderer.bridge.manifest.id
    ? String(renderer.bridge.manifest.id) + "-desktop"
    : "omarchy-ui-desktop"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  // The rest of the full-screen surface remains click-through.
  mask: Region { item: stage }

  Item {
    id: stage
    x: window.boundedX(window.sceneX)
    y: window.boundedY(window.sceneY)
    width: Math.max(1, Number(renderer.prop("stage_width", 420)))
    height: Math.max(1, Number(renderer.prop("stage_height", 420)))

    DragHandler {
      id: sceneDrag
      target: null
      enabled: renderer.prop("draggable", true) !== false
      dragThreshold: 3
      property real originX: 0
      property real originY: 0

      onActiveChanged: {
        if (active) {
          originX = stage.x
          originY = stage.y
          window.send("drag_start", { target_x: stage.x, target_y: stage.y })
        } else {
          window.sceneX = stage.x
          window.sceneY = stage.y
          window.send("drag_end", { target_x: stage.x, target_y: stage.y })
        }
      }

      onTranslationChanged: {
        if (!active) return
        window.sceneX = window.boundedX(originX + translation.x)
        window.sceneY = window.boundedY(originY + translation.y)
        window.send("drag", { target_x: stage.x, target_y: stage.y })
      }
    }

    HoverHandler {
      enabled: sceneDrag.enabled
      cursorShape: sceneDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    Repeater {
      model: renderer.node && Array.isArray(renderer.node.children) ? renderer.node.children : []
      delegate: renderer.childDelegateComponent
    }
  }
}
