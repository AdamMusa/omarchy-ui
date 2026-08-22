import QtQuick

Canvas {
  property var bridge: null
  property string surfaceName: ""
  property string controlId: ""
  property var node: ({})

  readonly property var values: node.props && Array.isArray(node.props.values) ? node.props.values : []
  readonly property color strokeColor: node.props && node.props.color ? node.props.color : "white"
  implicitWidth: 160
  implicitHeight: 48

  onValuesChanged: requestPaint()
  onStrokeColorChanged: requestPaint()
  onPaint: {
    var context = getContext("2d")
    context.reset()
    if (values.length < 2) return
    var minimum = Math.min.apply(Math, values)
    var maximum = Math.max.apply(Math, values)
    var span = Math.max(0.000001, maximum - minimum)
    context.strokeStyle = strokeColor
    context.lineWidth = 2
    context.beginPath()
    for (var i = 0; i < values.length; i++) {
      var x = i * width / (values.length - 1)
      var y = height - ((Number(values[i]) - minimum) / span) * height
      if (i === 0) context.moveTo(x, y)
      else context.lineTo(x, y)
    }
    context.stroke()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: bridge.sendEvent(surfaceName, controlId, "click", {})
  }
}
