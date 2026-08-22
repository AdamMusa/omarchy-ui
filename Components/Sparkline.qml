import QtQuick

Canvas {
  property var values: []
  property color strokeColor: "white"
  property real lineWidth: 2
  signal click(var payload)
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
    context.lineWidth = lineWidth
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
    onClicked: parent.click({ button: button })
  }
}
