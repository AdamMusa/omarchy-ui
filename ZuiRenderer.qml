import QtQuick

Loader {
  id: root

  property var bridge: null
  property string surfaceName: ""
  property string controlId: ""
  property color foreground: "white"
  property string fontFamily: ""
  readonly property bool renderReady: status === Loader.Ready && item !== null
    && String(item.iconFontFamily || "") !== ""
    && String(item.brandIconFontFamily || "") !== ""

  active: bridge !== null && bridge.zuiReady && controlId !== ""
  source: active ? bridge.zuiRoot + "/ControlNode.qml" : ""

  function syncRenderer() {
    if (!item) return
    item.bridge = bridge
    item.surfaceName = surfaceName
    item.controlId = controlId
    item.foreground = foreground
    item.fontFamily = fontFamily
  }

  onLoaded: syncRenderer()
  onBridgeChanged: syncRenderer()
  onSurfaceNameChanged: syncRenderer()
  onControlIdChanged: syncRenderer()
  onForegroundChanged: syncRenderer()
  onFontFamilyChanged: syncRenderer()
  onStatusChanged: {
    if (status === Loader.Error && bridge)
      bridge.lastError = "Could not load Zui " + bridge.requiredZuiVersion + " renderer from its gem"
  }
}
