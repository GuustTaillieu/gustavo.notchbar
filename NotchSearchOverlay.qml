import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
  id: searchOverlay

  property var root: null

  readonly property bool isSearchOpen: root ? root.isSearchOpen : false
  readonly property color searchForeground: (root && root.barForeground) ? root.barForeground : Color.bar.text
  readonly property color searchThemeForeground: (root && root.themeForeground) ? root.themeForeground : Color.foreground
  readonly property bool searchTransparent: root ? root.transparent : false

  visible: root ? root.isSearchOpen : false
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "omarchy-notch-search"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: (root && root.isSearchOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  onVisibleChanged: {
    if (visible) {
      searchInput.text = ""
      if (root && root.shell && root.shell.appLibrary) {
        root.shell.appLibrary.refreshIcons()
      }
      Qt.callLater(function() { searchInput.forceActiveFocus() })
    }
  }

  // Full-screen click-outside dismissal scrim
  MouseArea {
    anchors.fill: parent
    onClicked: if (root) root.isSearchOpen = false
  }

  // Notch Search Card at Top Center
  NotchSurface {
    id: searchNotchCard
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    radius: 14
    color: searchOverlay.searchTransparent ? Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.96) : Color.bar.background
    borderColor: Qt.rgba(searchOverlay.searchThemeForeground.r, searchOverlay.searchThemeForeground.g, searchOverlay.searchThemeForeground.b, 0.25)
    borderWidth: 1
    contentWidth: 480
    contentHeight: 380

    // Eat clicks on the card so it doesn't trigger dismissal
    MouseArea {
      anchors.fill: parent
      onClicked: {}
    }

    Item {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: searchNotchCard.contentWidth
      anchors.margins: Style.space(12)

      ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(8)

        // Search Input Field
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 38
          radius: 8
          color: Qt.rgba(searchOverlay.searchThemeForeground.r, searchOverlay.searchThemeForeground.g, searchOverlay.searchThemeForeground.b, 0.08)
          border.color: searchInput.activeFocus ? (Color.accent || Qt.rgba(1,1,1,0.3)) : Qt.rgba(searchOverlay.searchThemeForeground.r, searchOverlay.searchThemeForeground.g, searchOverlay.searchThemeForeground.b, 0.15)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Text {
              text: "🔍"
              font.pixelSize: 13
              color: searchOverlay.searchForeground
              opacity: 0.7
            }

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              color: searchOverlay.searchForeground
              selectionColor: Color.accent || Qt.rgba(0.2, 0.6, 1.0, 0.6)
              clip: true
              focus: true

              Text {
                anchors.fill: parent
                text: "Search applications & commands..."
                font.family: searchInput.font.family
                font.pixelSize: searchInput.font.pixelSize
                color: searchOverlay.searchForeground
                opacity: 0.4
                visible: !searchInput.text && !searchInput.inputMethodComposing
              }

              Keys.onEscapePressed: if (root) root.isSearchOpen = false
              Keys.onDownPressed: {
                if (appList.count > 0) {
                  appList.currentIndex = Math.min(appList.count - 1, appList.currentIndex + 1)
                }
              }
              Keys.onUpPressed: {
                if (appList.count > 0) {
                  appList.currentIndex = Math.max(0, appList.currentIndex - 1)
                }
              }
              Keys.onReturnPressed: {
                if (appList.currentItem && appList.currentItem.launchEntry) {
                  appList.currentItem.launchEntry()
                }
              }
            }
          }
        }

        // Search Results ListView
        ListView {
          id: appList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds

          model: {
            if (!root || !root.shell || !root.shell.appLibrary) return []
            return root.shell.appLibrary.sortedEntries(searchInput.text)
          }

          delegate: Rectangle {
            id: appRow
            width: appList.width
            height: 44
            radius: 6
            color: isSelected ? Qt.rgba(searchOverlay.searchThemeForeground.r, searchOverlay.searchThemeForeground.g, searchOverlay.searchThemeForeground.b, 0.14) : (rowMouse.containsMouse ? Qt.rgba(searchOverlay.searchThemeForeground.r, searchOverlay.searchThemeForeground.g, searchOverlay.searchThemeForeground.b, 0.06) : "transparent")

            readonly property bool isSelected: appList.currentIndex === index
            readonly property var rawData: modelData
            readonly property var entry: (rawData && rawData.entry) ? rawData.entry : rawData

            function launchEntry() {
              if (!entry) return
              var appId = String(entry.id || entry.appId || "")
              var appName = root && root.shell && root.shell.appLibrary ? root.shell.appLibrary.entryName(entry) : (entry.name || entry.label || appId)
              if (root && root.shell && root.shell.appLibrary) {
                root.shell.appLibrary.launch(appId, appName)
              }
              if (root) root.isSearchOpen = false
            }

            // Accent Left Bar
            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.margins: 4
              width: 3
              radius: 2
              color: Color.accent || Qt.rgba(0.2, 0.8, 0.7, 1.0)
              visible: appRow.isSelected
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 10
              spacing: Style.space(10)

              Image {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                source: (root && root.shell && root.shell.appLibrary && entry) ? root.shell.appLibrary.iconSource(entry.icon || entry.appIcon) : ""
                fillMode: Image.PreserveAspectFit
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  Layout.fillWidth: true
                  text: (root && root.shell && root.shell.appLibrary && entry) ? root.shell.appLibrary.entryName(entry) : ((entry && (entry.name || entry.label || entry.id)) || "")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.weight: Font.DemiBold
                  color: searchOverlay.searchForeground
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  text: (root && root.shell && root.shell.appLibrary && entry) ? root.shell.appLibrary.entrySubtext(entry) : ((entry && (entry.subtext || entry.description || entry.comment)) || "")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: searchOverlay.searchForeground
                  opacity: 0.6
                  elide: Text.ElideRight
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                appList.currentIndex = index
                appRow.launchEntry()
              }
            }
          }
        }
      }
    }
  }
}
