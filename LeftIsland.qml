import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: leftIsland

  required property var root
  required property var barWindow

  property bool isHovered: leftMouseArea.containsMouse
  readonly property real contentWidth: Math.max(80, leftModules.implicitWidth + Style.space(14))
  readonly property real contentHeight: root.islandHeight

  implicitWidth: notchSurface.implicitWidth
  implicitHeight: notchSurface.implicitHeight
  width: implicitWidth
  height: implicitHeight

  NotchSurface {
    id: notchSurface
    radius: 12
    color: root.transparent ? Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.94) : Color.bar.background
    borderColor: Qt.rgba(root.themeForeground.r, root.themeForeground.g, root.themeForeground.b, 0.22)
    borderWidth: 1
    contentWidth: leftIsland.contentWidth
    contentHeight: leftIsland.contentHeight

    Behavior on contentWidth {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    Item {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: notchSurface.contentWidth

      Row {
        id: leftContentRow
        anchors.centerIn: parent

        Repeater {
          model: root.layoutEntries("left")

          delegate: root.moduleSlotComponent ? null : null
        }
      }
    }
  }

  MouseArea {
    id: leftMouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }
}
