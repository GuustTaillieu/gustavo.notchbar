import QtQuick
import QtQuick.Shapes

Item {
  id: notch

  property real radius: 8
  property real contentWidth: 100
  property real contentHeight: 32
  property color color: Qt.rgba(0.1, 0.1, 0.12, 0.50)
  property color borderColor: Qt.rgba(1, 1, 1, 0.18)
  property real borderWidth: 1
  property bool shadowEnabled: true
  property string attachSide: "none" // "none" | "left" | "right"

  // Total notch width is content width + fillet wings
  implicitWidth: {
    if (attachSide === "left" || attachSide === "right") {
      return Math.ceil(contentWidth + radius)
    }
    return Math.ceil(contentWidth + radius * 2)
  }
  implicitHeight: Math.ceil(contentHeight + (attachSide !== "none" ? radius : 0))
  width: implicitWidth
  height: implicitHeight

  // 1. Soft Ambient Drop Shadow underneath notch
  Shape {
    id: shadowShape
    anchors.fill: parent
    anchors.topMargin: 3
    visible: notch.shadowEnabled
    opacity: 0.35
    z: -1
    layer.enabled: true
    layer.samples: 4
    antialiasing: true

    ShapePath {
      strokeColor: "transparent"
      strokeWidth: 0
      fillColor: Qt.rgba(0, 0, 0, 0.55)

      startX: 0
      startY: 0

      // --- Left side ---
      PathLine {
        x: 0
        y: notch.attachSide === "left" ? (notch.contentHeight + notch.radius) : 0
      }

      // Top-left fillet (when floating or attached right)
      PathCubic {
        x: notch.attachSide === "left" ? notch.radius : notch.radius
        y: notch.attachSide === "left" ? notch.contentHeight : notch.radius
        control1X: notch.attachSide === "left" ? 0 : notch.radius * 0.55
        control1Y: notch.attachSide === "left" ? (notch.contentHeight + notch.radius * 0.45) : 0
        control2X: notch.attachSide === "left" ? notch.radius * 0.45 : notch.radius
        control2Y: notch.attachSide === "left" ? notch.contentHeight : notch.radius * 0.45
      }

      // Left vertical wall (when floating or attached right)
      PathLine {
        x: notch.attachSide === "left" ? notch.radius : notch.radius
        y: notch.attachSide === "left" ? notch.contentHeight : Math.max(notch.radius, notch.contentHeight - notch.radius)
      }

      // Bottom-left corner (when floating or attached right)
      PathCubic {
        x: notch.attachSide === "left" ? notch.radius : notch.radius * 2
        y: notch.contentHeight
        control1X: notch.attachSide === "left" ? notch.radius : notch.radius
        control1Y: notch.attachSide === "left" ? notch.contentHeight : (notch.contentHeight - notch.radius * 0.45)
        control2X: notch.attachSide === "left" ? notch.radius : notch.radius * 1.45
        control2Y: notch.contentHeight
      }

      // --- Bottom edge ---
      PathLine {
        x: notch.attachSide === "right" ? Math.max(notch.radius * 2, notch.width - notch.radius) : Math.max(notch.radius * 2, notch.width - notch.radius * 2)
        y: notch.contentHeight
      }

      // --- Right side ---
      // Bottom-right corner or outward right fillet
      PathCubic {
        x: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        y: notch.attachSide === "right" ? (notch.contentHeight + notch.radius) : Math.max(notch.radius, notch.contentHeight - notch.radius)
        control1X: notch.attachSide === "right" ? (notch.width - notch.radius * 0.45) : (notch.width - notch.radius * 1.45)
        control1Y: notch.attachSide === "right" ? notch.contentHeight : notch.contentHeight
        control2X: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        control2Y: notch.attachSide === "right" ? (notch.contentHeight + notch.radius * 0.45) : (notch.contentHeight - notch.radius * 0.45)
      }

      // Right vertical wall
      PathLine {
        x: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        y: notch.attachSide === "right" ? 0 : notch.radius
      }

      // Top-right fillet (when floating or attached left)
      PathCubic {
        x: notch.width
        y: 0
        control1X: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        control1Y: notch.attachSide === "right" ? 0 : (notch.radius * 0.45)
        control2X: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius * 0.55)
        control2Y: 0
      }

      PathLine {
        x: 0
        y: 0
      }
    }
  }

  // 2. Translucent Frosted Glass Base Fill
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

      // --- Left side ---
      PathLine {
        x: 0
        y: notch.attachSide === "left" ? (notch.contentHeight + notch.radius) : 0
      }

      PathCubic {
        x: notch.attachSide === "left" ? notch.radius : notch.radius
        y: notch.attachSide === "left" ? notch.contentHeight : notch.radius
        control1X: notch.attachSide === "left" ? 0 : notch.radius * 0.55
        control1Y: notch.attachSide === "left" ? (notch.contentHeight + notch.radius * 0.45) : 0
        control2X: notch.attachSide === "left" ? notch.radius * 0.45 : notch.radius
        control2Y: notch.attachSide === "left" ? notch.contentHeight : notch.radius * 0.45
      }

      PathLine {
        x: notch.attachSide === "left" ? notch.radius : notch.radius
        y: notch.attachSide === "left" ? notch.contentHeight : Math.max(notch.radius, notch.contentHeight - notch.radius)
      }

      PathCubic {
        x: notch.attachSide === "left" ? notch.radius : notch.radius * 2
        y: notch.contentHeight
        control1X: notch.attachSide === "left" ? notch.radius : notch.radius
        control1Y: notch.attachSide === "left" ? notch.contentHeight : (notch.contentHeight - notch.radius * 0.45)
        control2X: notch.attachSide === "left" ? notch.radius : notch.radius * 1.45
        control2Y: notch.contentHeight
      }

      // --- Bottom edge ---
      PathLine {
        x: notch.attachSide === "right" ? Math.max(notch.radius * 2, notch.width - notch.radius) : Math.max(notch.radius * 2, notch.width - notch.radius * 2)
        y: notch.contentHeight
      }

      // --- Right side ---
      PathCubic {
        x: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        y: notch.attachSide === "right" ? (notch.contentHeight + notch.radius) : Math.max(notch.radius, notch.contentHeight - notch.radius)
        control1X: notch.attachSide === "right" ? (notch.width - notch.radius * 0.45) : (notch.width - notch.radius * 1.45)
        control1Y: notch.attachSide === "right" ? notch.contentHeight : notch.contentHeight
        control2X: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        control2Y: notch.attachSide === "right" ? (notch.contentHeight + notch.radius * 0.45) : (notch.contentHeight - notch.radius * 0.45)
      }

      PathLine {
        x: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        y: notch.attachSide === "right" ? 0 : notch.radius
      }

      PathCubic {
        x: notch.width
        y: 0
        control1X: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        control1Y: notch.attachSide === "right" ? 0 : (notch.radius * 0.45)
        control2X: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius * 0.55)
        control2Y: 0
      }

      PathLine {
        x: 0
        y: 0
      }
    }

    // 3. Glass Refraction Rim / Optical Border
    ShapePath {
      strokeColor: notch.borderWidth > 0 ? notch.borderColor : "transparent"
      strokeWidth: notch.borderWidth
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap

      startX: 0
      startY: 0

      // --- Left side ---
      PathLine {
        x: 0
        y: notch.attachSide === "left" ? (notch.contentHeight + notch.radius) : 0
      }

      PathCubic {
        x: notch.attachSide === "left" ? notch.radius : notch.radius
        y: notch.attachSide === "left" ? notch.contentHeight : notch.radius
        control1X: notch.attachSide === "left" ? 0 : notch.radius * 0.55
        control1Y: notch.attachSide === "left" ? (notch.contentHeight + notch.radius * 0.45) : 0
        control2X: notch.attachSide === "left" ? notch.radius * 0.45 : notch.radius
        control2Y: notch.attachSide === "left" ? notch.contentHeight : notch.radius * 0.45
      }

      PathLine {
        x: notch.attachSide === "left" ? notch.radius : notch.radius
        y: notch.attachSide === "left" ? notch.contentHeight : Math.max(notch.radius, notch.contentHeight - notch.radius)
      }

      PathCubic {
        x: notch.attachSide === "left" ? notch.radius : notch.radius * 2
        y: notch.contentHeight
        control1X: notch.attachSide === "left" ? notch.radius : notch.radius
        control1Y: notch.attachSide === "left" ? notch.contentHeight : (notch.contentHeight - notch.radius * 0.45)
        control2X: notch.attachSide === "left" ? notch.radius : notch.radius * 1.45
        control2Y: notch.contentHeight
      }

      // --- Bottom edge ---
      PathLine {
        x: notch.attachSide === "right" ? Math.max(notch.radius * 2, notch.width - notch.radius) : Math.max(notch.radius * 2, notch.width - notch.radius * 2)
        y: notch.contentHeight
      }

      // --- Right side ---
      PathCubic {
        x: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        y: notch.attachSide === "right" ? (notch.contentHeight + notch.radius) : Math.max(notch.radius, notch.contentHeight - notch.radius)
        control1X: notch.attachSide === "right" ? (notch.width - notch.radius * 0.45) : (notch.width - notch.radius * 1.45)
        control1Y: notch.attachSide === "right" ? notch.contentHeight : notch.contentHeight
        control2X: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        control2Y: notch.attachSide === "right" ? (notch.contentHeight + notch.radius * 0.45) : (notch.contentHeight - notch.radius * 0.45)
      }

      PathLine {
        x: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        y: notch.attachSide === "right" ? 0 : notch.radius
      }

      PathCubic {
        x: notch.width
        y: 0
        control1X: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius)
        control1Y: notch.attachSide === "right" ? 0 : (notch.radius * 0.45)
        control2X: notch.attachSide === "right" ? notch.width : (notch.width - notch.radius * 0.55)
        control2Y: 0
      }
    }
  }
}
