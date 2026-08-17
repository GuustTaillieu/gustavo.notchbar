import QtQuick
import QtQuick.Shapes

Item {
  id: notch

  property real radius: 8
  property real contentWidth: 100
  property real contentHeight: 32
  property color color: Qt.rgba(0.1, 0.1, 0.12, 0.95)
  property color borderColor: "transparent"
  property real borderWidth: 0
  property bool shadowEnabled: true

  // Total notch width is content width + 2 outer fillet wings
  implicitWidth: Math.ceil(contentWidth + radius * 2)
  implicitHeight: Math.ceil(contentHeight)
  width: implicitWidth
  height: implicitHeight

  // 1. Soft Ambient Drop Shadow underneath notch
  Shape {
    id: shadowShape
    anchors.fill: parent
    anchors.topMargin: 2
    visible: notch.shadowEnabled
    opacity: 0.3
    z: -1
    layer.enabled: true
    layer.samples: 4
    antialiasing: true

    ShapePath {
      strokeColor: "transparent"
      strokeWidth: 0
      fillColor: Qt.rgba(0, 0, 0, 0.5)

      startX: 0
      startY: 0

      PathCubic {
        x: notch.radius
        y: notch.radius
        control1X: notch.radius * 0.55
        control1Y: 0
        control2X: notch.radius
        control2Y: notch.radius * 0.45
      }

      PathLine {
        x: notch.radius
        y: Math.max(notch.radius, notch.height - notch.radius)
      }

      PathCubic {
        x: notch.radius * 2
        y: notch.height
        control1X: notch.radius
        control1Y: notch.height - notch.radius * 0.45
        control2X: notch.radius * 1.45
        control2Y: notch.height
      }

      PathLine {
        x: Math.max(notch.radius * 2, notch.width - notch.radius * 2)
        y: notch.height
      }

      PathCubic {
        x: notch.width - notch.radius
        y: Math.max(notch.radius, notch.height - notch.radius)
        control1X: notch.width - notch.radius * 1.45
        control1Y: notch.height
        control2X: notch.width - notch.radius
        control2Y: notch.height - notch.radius * 0.45
      }

      PathLine {
        x: notch.width - notch.radius
        y: notch.radius
      }

      PathCubic {
        x: notch.width
        y: 0
        control1X: notch.width - notch.radius
        control1Y: notch.radius * 0.45
        control2X: notch.width - notch.radius * 0.55
        control2Y: 0
      }

      PathLine {
        x: 0
        y: 0
      }
    }
  }

  // 2. Main Fill Shape
  Shape {
    id: fillShape
    anchors.fill: parent
    layer.enabled: true
    layer.samples: 4
    antialiasing: true

    ShapePath {
      strokeColor: "transparent"
      strokeWidth: 0
      fillColor: notch.color

      startX: 0
      startY: 0

      // Top-left concave outer fillet
      PathCubic {
        x: notch.radius
        y: notch.radius
        control1X: notch.radius * 0.55
        control1Y: 0
        control2X: notch.radius
        control2Y: notch.radius * 0.45
      }

      // Left vertical wall
      PathLine {
        x: notch.radius
        y: Math.max(notch.radius, notch.height - notch.radius)
      }

      // Bottom-left convex corner
      PathCubic {
        x: notch.radius * 2
        y: notch.height
        control1X: notch.radius
        control1Y: notch.height - notch.radius * 0.45
        control2X: notch.radius * 1.45
        control2Y: notch.height
      }

      // Bottom horizontal edge
      PathLine {
        x: Math.max(notch.radius * 2, notch.width - notch.radius * 2)
        y: notch.height
      }

      // Bottom-right convex corner
      PathCubic {
        x: notch.width - notch.radius
        y: Math.max(notch.radius, notch.height - notch.radius)
        control1X: notch.width - notch.radius * 1.45
        control1Y: notch.height
        control2X: notch.width - notch.radius
        control2Y: notch.height - notch.radius * 0.45
      }

      // Right vertical wall
      PathLine {
        x: notch.width - notch.radius
        y: notch.radius
      }

      // Top-right concave outer fillet
      PathCubic {
        x: notch.width
        y: 0
        control1X: notch.width - notch.radius
        control1Y: notch.radius * 0.45
        control2X: notch.width - notch.radius * 0.55
        control2Y: 0
      }

      // Close back along top bezel for fill
      PathLine {
        x: 0
        y: 0
      }
    }

    // 3. Optional Stroke Path (if borderWidth > 0)
    ShapePath {
      strokeColor: notch.borderWidth > 0 ? notch.borderColor : "transparent"
      strokeWidth: notch.borderWidth
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap

      startX: 0
      startY: 0

      PathCubic {
        x: notch.radius
        y: notch.radius
        control1X: notch.radius * 0.55
        control1Y: 0
        control2X: notch.radius
        control2Y: notch.radius * 0.45
      }

      PathLine {
        x: notch.radius
        y: Math.max(notch.radius, notch.height - notch.radius)
      }

      PathCubic {
        x: notch.radius * 2
        y: notch.height
        control1X: notch.radius
        control1Y: notch.height - notch.radius * 0.45
        control2X: notch.radius * 1.45
        control2Y: notch.height
      }

      PathLine {
        x: Math.max(notch.radius * 2, notch.width - notch.radius * 2)
        y: notch.height
      }

      PathCubic {
        x: notch.width - notch.radius
        y: Math.max(notch.radius, notch.height - notch.radius)
        control1X: notch.width - notch.radius * 1.45
        control1Y: notch.height
        control2X: notch.width - notch.radius
        control2Y: notch.height - notch.radius * 0.45
      }

      PathLine {
        x: notch.width - notch.radius
        y: notch.radius
      }

      PathCubic {
        x: notch.width
        y: 0
        control1X: notch.width - notch.radius
        control1Y: notch.radius * 0.45
        control2X: notch.width - notch.radius * 0.55
        control2Y: 0
      }
    }
  }
}
