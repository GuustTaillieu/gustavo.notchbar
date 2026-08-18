import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "MenuModel.js" as MenuModel

Item {
  id: centerIsland

  property var root: null
  property var barWindow: null
  property Component centerModulesComponent: null
  property Item centerModulesItem: null
  readonly property real centerModulesWidth: centerModulesItem ? Math.ceil(centerModulesItem.implicitWidth) : 0

  readonly property bool isSearchOpen: root ? root.isSearchOpen : false
  readonly property bool isHistoryOpen: root ? root.isHistoryOpen : false
  readonly property color islandForeground: (root && root.barForeground) ? root.barForeground : Color.bar.text
  readonly property color islandThemeForeground: (root && root.themeForeground) ? root.themeForeground : Color.foreground



  function toggleSearch() {
    if (root) root.isSearchOpen = !root.isSearchOpen
  }

  function openSearch() {
    if (root) root.isSearchOpen = true
  }

  function closeSearch() {
    if (root) root.isSearchOpen = false
  }

  property bool isMediaOpen: false

  function toggleMedia() {
    if (hasActiveMedia) {
      isMediaOpen = !isMediaOpen
    }
  }

  DragHandler {
    id: pullDownHandler
    target: null
    xAxis.enabled: false
    yAxis.minimum: -50
    yAxis.maximum: 100
    onActiveChanged: {
      if (!active) {
        var dy = centroid.position.y - centroid.pressPosition.y
        if (dy > 12) {
          // Swiped down -> Pull down media player
          if (hasActiveMedia) {
            centerIsland.isMediaOpen = true
          }
        } else if (dy < -12) {
          // Swiped up -> Collapse media player
          centerIsland.isMediaOpen = false
        }
      }
    }
  }

  readonly property bool isHovered: islandHoverHandler.hovered

  HoverHandler {
    id: islandHoverHandler
    onHoveredChanged: {
      if (hovered) {
        mediaLeaveTimer.stop()
      } else {
        if (isMediaOpen) {
          mediaLeaveTimer.restart()
        }
      }
    }
  }

  Timer {
    id: mediaLeaveTimer
    interval: 1500
    repeat: false
    onTriggered: {
      centerIsland.isMediaOpen = false
    }
  }

  readonly property var currentNotification: root ? root.currentNotification : null
  readonly property bool isNotificationActive: currentNotification !== null

  // Volume & Audio tracking
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real currentVolume: (sink && sink.audio) ? sink.audio.volume : 1.0
  readonly property bool isMuted: (sink && sink.audio) ? sink.audio.muted : false
  property bool audioInitialized: false

  onCurrentVolumeChanged: {
    if (!audioInitialized) { audioInitialized = true; return }
    triggerOsd("volume")
  }
  onIsMutedChanged: {
    if (!audioInitialized) { audioInitialized = true; return }
    triggerOsd("volume")
  }

  // Brightness tracking
  property int currentBrightness: 100
  property bool brightnessInitialized: false

  Process {
    id: brightnessQueryProc
    command: ["brightnessctl", "-m"]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = String(line).trim().split(",")
        if (parts.length >= 4) {
          var pctStr = parts[3].replace("%", "").trim()
          var pct = parseInt(pctStr, 10)
          if (!isNaN(pct)) {
            if (centerIsland.brightnessInitialized && pct !== centerIsland.currentBrightness) {
              centerIsland.currentBrightness = pct
              centerIsland.triggerOsd("brightness")
            } else {
              centerIsland.currentBrightness = pct
              centerIsland.brightnessInitialized = true
            }
          }
        }
      }
    }
  }

  Process {
    id: brightnessSetProc
  }

  Timer {
    interval: 1500
    repeat: true
    running: true
    onTriggered: {
      if (!brightnessQueryProc.running) brightnessQueryProc.running = true
    }
  }

  // OSD mode management
  property string osdMode: "" // "volume" | "brightness"
  property bool isOsdActive: osdTimer.running

  function triggerOsd(mode) {
    if (centerIsland.isSearchOpen) return
    osdMode = mode
    osdTimer.restart()
  }

  Timer {
    id: osdTimer
    interval: 1800
    repeat: false
    onTriggered: {
      centerIsland.osdMode = ""
    }
  }

  function isDedicatedMusicPlayer(player) {
    if (!player) return false
    var id = String(player.identity || player.desktopEntry || player.name || "").toLowerCase()
    return id.indexOf("spotify") >= 0 ||
           id.indexOf("music") >= 0 ||
           id.indexOf("cider") >= 0 ||
           id.indexOf("apple") >= 0 ||
           id.indexOf("tidal") >= 0 ||
           id.indexOf("amberol") >= 0 ||
           id.indexOf("feishin") >= 0 ||
           id.indexOf("rhythmbox") >= 0 ||
           id.indexOf("cmus") >= 0 ||
           id.indexOf("mpd") >= 0 ||
           id.indexOf("vlc") >= 0
  }

  // Active Mpris media player with Spotify/Music priority
  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var activePlayer: {
    if (!mprisPlayers || mprisPlayers.length === 0) return null

    // 1. Playing dedicated music player (Spotify)
    for (var i = 0; i < mprisPlayers.length; i++) {
      var p1 = mprisPlayers[i]
      if (p1 && (p1.isPlaying || p1.playbackState === MprisPlaybackState.Playing) && isDedicatedMusicPlayer(p1)) {
        return p1
      }
    }

    // 2. Any other playing player
    for (var j = 0; j < mprisPlayers.length; j++) {
      var p2 = mprisPlayers[j]
      if (p2 && (p2.isPlaying || p2.playbackState === MprisPlaybackState.Playing)) {
        return p2
      }
    }

    // 3. Paused dedicated music player (Keep Spotify instead of falling back to browser)
    for (var k = 0; k < mprisPlayers.length; k++) {
      var p3 = mprisPlayers[k]
      if (p3 && isDedicatedMusicPlayer(p3) && (p3.trackTitle || p3.trackArtist)) {
        return p3
      }
    }

    // 4. Any other player with metadata
    for (var l = 0; l < mprisPlayers.length; l++) {
      var p4 = mprisPlayers[l]
      if (p4 && (p4.trackTitle || p4.trackArtist)) {
        return p4
      }
    }

    return mprisPlayers[0] || null
  }
  readonly property bool hasActiveMedia: activePlayer !== null && (activePlayer.trackTitle !== "" || activePlayer.trackArtist !== "")

  // ------------------------------------------------------------- Menu Model & Search Integration
  property string defaultMenuPath: (root && root.omarchyPath ? root.omarchyPath : "/usr/share/omarchy") + "/default/omarchy/omarchy-menu.jsonc"
  property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
  property var defaultMenuItems: []
  property var userMenuItems: []
  property var menuSource: MenuModel.mergeMenuSources(defaultMenuItems, userMenuItems)

  FileView {
    id: defaultMenuFile
    path: centerIsland.defaultMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: centerIsland.defaultMenuItems = MenuModel.parseMenuJsonc(text())
  }

  FileView {
    id: userMenuFile
    path: centerIsland.userMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: centerIsland.userMenuItems = MenuModel.parseMenuJsonc(text())
  }

  // Unified Search Results Provider (Apps + System Toggles + Settings + Actions)
  function getSearchResults(query) {
    var results = []
    var cleanQuery = String(query || "").trim().toLowerCase()

    // 1. Applications from AppLibrary
    if (root && root.shell && root.shell.appLibrary) {
      var appEntries = root.shell.appLibrary.sortedEntries(query)
      for (var a = 0; a < appEntries.length; a++) {
        var raw = appEntries[a]
        var entry = (raw && raw.entry) ? raw.entry : raw
        if (!entry) continue
        var appId = String(entry.id || entry.appId || "")
        var appName = root.shell.appLibrary.entryName(entry) || entry.name || entry.label || appId
        var appSubtext = root.shell.appLibrary.entrySubtext(entry) || entry.subtext || entry.description || "Application"
        var appIcon = root.shell.appLibrary.iconSource(entry.icon || entry.appIcon) || ""

        results.push({
          isApp: true,
          appId: appId,
          name: appName,
          detail: appSubtext,
          iconSource: appIcon,
          iconGlyph: "",
          action: "",
          score: (raw && typeof raw.score === "number") ? raw.score : a
        })
      }
    }

    // 2. Menu Items from omarchy-menu (Settings, Toggles, Actions, Submenus)
    if (centerIsland.menuSource && centerIsland.menuSource.items) {
      var items = centerIsland.menuSource.items
      var order = centerIsland.menuSource.itemOrder || Object.keys(items)

      for (var m = 0; m < order.length; m++) {
        var id = order[m]
        var item = items[id]
        if (!item || id === "root" || id === "apps") continue

        var label = String(item.label || id)
        var desc = String(item.description || item.title || "")
        var aliases = item.aliases || []
        var action = String(item.action || "")

        // Filter based on query
        var match = false
        var score = 100
        if (!cleanQuery) {
          // When no query, show root-level or top helpful actions
          if (item.parent === "root" || item.parent === "system" || item.parent === "trigger.capture") {
            match = true
            score = m + 20
          }
        } else {
          var labelLower = label.toLowerCase()
          var idLower = id.toLowerCase()
          var descLower = desc.toLowerCase()

          if (labelLower.indexOf(cleanQuery) === 0) {
            match = true
            score = 10
          } else if (labelLower.indexOf(cleanQuery) > 0) {
            match = true
            score = 25
          } else if (idLower.indexOf(cleanQuery) >= 0) {
            match = true
            score = 30
          } else if (descLower.indexOf(cleanQuery) >= 0) {
            match = true
            score = 40
          } else {
            for (var al = 0; al < aliases.length; al++) {
              if (String(aliases[al]).toLowerCase().indexOf(cleanQuery) >= 0) {
                match = true
                score = 20
                break
              }
            }
          }
        }

        if (match) {
          var parentPath = id.indexOf(".") >= 0 ? id.split(".").slice(0, -1).join(" › ") : "Omarchy"
          results.push({
            isApp: false,
            appId: "",
            name: label,
            detail: desc ? desc : (action ? ("Command: " + action) : parentPath),
            iconSource: "",
            iconGlyph: item.icon || "󰒓",
            action: action ? action : ("omarchy-menu toggle " + id),
            score: score
          })
        }
      }
    }

    // Sort results by score
    results.sort(function(x, y) {
      if (x.score !== y.score) return x.score - y.score
      return x.name.localeCompare(y.name)
    })

    return results
  }

  // Current display mode: "search" | "history" | "volume" | "brightness" | "notification" | "media" | "date-clock" | "clock"
  readonly property string currentMode: {
    if (centerIsland.isSearchOpen) return "search"
    if (centerIsland.isHistoryOpen) return "history"
    if (isOsdActive && osdMode !== "") return osdMode
    if (isNotificationActive && currentNotification) return "notification"
    if (isMediaOpen && hasActiveMedia) return "media"
    return "clock"
  }

  // Dimensions driven by mode with spacious airy padding
  readonly property real targetContentWidth: {
    switch (currentMode) {
      case "search": return 520
      case "history": return 480
      case "volume":
      case "brightness": return 300
      case "notification": return 400
      case "media": return 440
      case "date-clock": return Math.max(230, centerModulesWidth + 24)
      case "clock": default: return Math.max(90, (centerModulesWidth > 0 ? centerModulesWidth : 70) + 20)
    }
  }

  readonly property real targetContentHeight: {
    switch (currentMode) {
      case "search": return 420
      case "history": return 400
      case "volume":
      case "brightness": return 36
      case "notification": return 68
      case "media": return 80
      case "date-clock": return 40
      case "clock": default: return 30
    }
  }

  implicitWidth: notchSurface.implicitWidth
  implicitHeight: notchSurface.implicitHeight
  width: implicitWidth
  height: implicitHeight

  ListModel {
    id: historyModel
  }

  Process {
    id: historyLoaderProc
    command: ["bash", "-c", "python3 -c \"import os, glob, json; hdir=os.path.expanduser('~/.local/state/omarchy/notifications'); files=glob.glob(hdir+'/*.json') + glob.glob(hdir+'/history/*.json'); res=[]; seen=set();\nfor f in files:\n try:\n  d=json.load(open(f)); key=str(d.get('id',''))+'-'+str(d.get('timestamp',''))+'-'+str(d.get('summary',''));\n  if key not in seen:\n   seen.add(key); d['filePath']=f; res.append(d)\n except: pass\nres.sort(key=lambda x: x.get('timestamp', 0), reverse=True); print(json.dumps(res))\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var list = JSON.parse(text)
          historyModel.clear()
          for (var i = 0; i < list.length; i++) {
            historyModel.append(list[i])
          }
        } catch (e) {
          console.warn("Error parsing notification history:", e)
        }
      }
    }
  }

  function reloadHistory() {
    if (!historyLoaderProc.running) {
      historyLoaderProc.running = true
    }
  }

  Connections {
    target: centerIsland
    function onIsHistoryOpenChanged() {
      if (centerIsland.isHistoryOpen) {
        centerIsland.reloadHistory()
      }
    }
  }

  function formatRelativeTime(timestamp) {
    if (!timestamp) return ""
    var now = Date.now()
    var diff = Math.max(0, Math.floor((now - timestamp) / 1000))
    if (diff < 60) return "Just now"
    var mins = Math.floor(diff / 60)
    if (mins < 60) return mins + "m ago"
    var hours = Math.floor(mins / 60)
    if (hours < 24) return hours + "h ago"
    var days = Math.floor(hours / 24)
    if (days < 7) return days + "d ago"
    var d = new Date(timestamp)
    return (d.getMonth() + 1) + "/" + d.getDate()
  }

  function resolveIconSource(notif) {
    return root ? root.resolveNotificationIcon(notif) : ""
  }

  function resolveGlyph(notif) {
    return root ? root.resolveNotificationGlyph(notif) : ""
  }

  function handleNotificationClick(isRightClick) {
    if (root) root.handleNotificationClick(isRightClick)
  }

  NotchSurface {
    id: notchSurface
    radius: 8
    clip: true
    color: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.50)
    borderColor: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.18)
    borderWidth: 1
    contentWidth: centerIsland.targetContentWidth
    contentHeight: centerIsland.targetContentHeight

    Behavior on contentWidth {
      NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    Behavior on contentHeight {
      NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    // Inner content area between fillets
    Item {
      id: contentArea
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: notchSurface.contentWidth
      clip: true

      // ------------------------------------------------------------- Mode 1: Compact Clock & Center Modules (Idle)
      Item {
        id: clockView
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "clock" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Row {
          id: idleRow
          anchors.centerIn: parent
          spacing: 6

          Loader {
            id: centerModulesLoader
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: centerIsland.centerModulesComponent
            onLoaded: {
              centerIsland.centerModulesItem = item
            }
          }

          Text {
            id: fallbackClockText
            anchors.verticalCenter: parent.verticalCenter
            visible: !centerModulesLoader.item || centerModulesLoader.item.implicitWidth <= 0
            text: Qt.formatTime(new Date(), "HH:mm")
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
            color: centerIsland.islandForeground
          }
        }

        Timer {
          interval: 1000
          running: fallbackClockText.visible
          repeat: true
          onTriggered: fallbackClockText.text = Qt.formatTime(new Date(), "HH:mm")
        }
      }

      // ------------------------------------------------------------- Mode 2: Date & Clock Expander
      Item {
        id: dateClockView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "date-clock" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Row {
          anchors.centerIn: parent
          spacing: Style.space(14)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(new Date(), "HH:mm")
            font.family: Style.font.family
            font.pixelSize: Style.font.title + 2
            font.weight: Font.Bold
            color: centerIsland.islandForeground
          }

          Rectangle {
            width: 1
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            color: centerIsland.islandForeground
            opacity: 0.25
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
              text: Qt.formatDateTime(new Date(), "dddd").toUpperCase()
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.Bold
              color: Color.accent || centerIsland.islandForeground
              opacity: 0.95
            }

            Text {
              text: Qt.formatDateTime(new Date(), "d MMMM")
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: centerIsland.islandForeground
              opacity: 0.85
            }
          }
        }
      }

      // ------------------------------------------------------------- Mode 3: Media Player (Airy & Balanced with generous bottom space)
      Item {
        id: mediaView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 12
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "media" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        RowLayout {
          anchors.fill: parent
          spacing: Style.space(14)

          // Album Art Thumbnail
          Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: 10
            color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.12)
            clip: true

            Image {
              anchors.fill: parent
              source: centerIsland.activePlayer ? (centerIsland.activePlayer.trackArtUrl || "") : ""
              fillMode: Image.PreserveAspectCrop
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              text: "󰎆"
              font.family: Style.font.family
              font.pixelSize: 18
              color: centerIsland.islandForeground
              opacity: 0.6
              visible: !centerIsland.activePlayer || !centerIsland.activePlayer.trackArtUrl
            }
          }

          // Track Title, Artist & Controls
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
              Layout.fillWidth: true
              text: centerIsland.activePlayer ? (centerIsland.activePlayer.trackTitle || "Playing Audio") : "Music"
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.weight: Font.DemiBold
              color: centerIsland.islandForeground
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              text: centerIsland.activePlayer ? (centerIsland.activePlayer.trackArtist || "") : ""
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: centerIsland.islandForeground
              opacity: 0.7
              elide: Text.ElideRight
              visible: text !== ""
            }

            Row {
              spacing: 14

              // Previous Track Button
              Item {
                width: 24
                height: 24

                Text {
                  anchors.centerIn: parent
                  text: "⏮"
                  font.pixelSize: 15
                  color: prevMouse.containsMouse ? (Color.accent || "#ffffff") : centerIsland.islandForeground
                  opacity: prevMouse.containsMouse ? 1.0 : 0.75
                  scale: prevMouse.containsMouse ? 1.15 : 1.0

                  Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                  Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                  Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                  id: prevMouse
                  anchors.fill: parent
                  anchors.margins: -6
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (centerIsland.activePlayer && typeof centerIsland.activePlayer.previous === "function") {
                      centerIsland.activePlayer.previous()
                    }
                    Util.execDetached("playerctl previous")
                  }
                }
              }

              // Play / Pause Button
              Item {
                width: 24
                height: 24

                Text {
                  anchors.centerIn: parent
                  text: (centerIsland.activePlayer && (centerIsland.activePlayer.isPlaying || centerIsland.activePlayer.playbackState === MprisPlaybackState.Playing)) ? "⏸" : "▶"
                  font.pixelSize: 16
                  color: playMouse.containsMouse ? (Color.accent || "#ffffff") : centerIsland.islandForeground
                  opacity: playMouse.containsMouse ? 1.0 : 0.85
                  scale: playMouse.containsMouse ? 1.15 : 1.0

                  Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                  Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                  Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                  id: playMouse
                  anchors.fill: parent
                  anchors.margins: -6
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (centerIsland.activePlayer) {
                      if (typeof centerIsland.activePlayer.togglePlaying === "function") {
                        centerIsland.activePlayer.togglePlaying()
                      } else if (typeof centerIsland.activePlayer.playPause === "function") {
                        centerIsland.activePlayer.playPause()
                      } else if (centerIsland.activePlayer.isPlaying) {
                        centerIsland.activePlayer.pause()
                      } else {
                        centerIsland.activePlayer.play()
                      }
                    }
                    Util.execDetached("playerctl play-pause")
                  }
                }
              }

              // Next Track Button
              Item {
                width: 24
                height: 24

                Text {
                  anchors.centerIn: parent
                  text: "⏭"
                  font.pixelSize: 15
                  color: nextMouse.containsMouse ? (Color.accent || "#ffffff") : centerIsland.islandForeground
                  opacity: nextMouse.containsMouse ? 1.0 : 0.75
                  scale: nextMouse.containsMouse ? 1.15 : 1.0

                  Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                  Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                  Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                  id: nextMouse
                  anchors.fill: parent
                  anchors.margins: -6
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (centerIsland.activePlayer && typeof centerIsland.activePlayer.next === "function") {
                      centerIsland.activePlayer.next()
                    }
                    Util.execDetached("playerctl next")
                  }
                }
              }
            }
          }

          // Right Clock & Date
          Column {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 2

            Text {
              anchors.right: parent.right
              text: Qt.formatTime(new Date(), "HH:mm")
              font.family: Style.font.family
              font.pixelSize: Style.font.title + 1
              font.weight: Font.Bold
              color: centerIsland.islandForeground
            }

            Text {
              anchors.right: parent.right
              text: Qt.formatDateTime(new Date(), "ddd dd").toUpperCase()
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.Bold
              color: Color.accent || centerIsland.islandForeground
              opacity: 0.9
            }
          }
        }
      }

      // ------------------------------------------------------------- Mode 4: Volume OSD Slider Pill
      Item {
        id: volumeView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "volume" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        RowLayout {
          anchors.fill: parent
          spacing: Style.space(12)

          Text {
            text: centerIsland.isMuted ? "󰝟" : (centerIsland.currentVolume > 0.5 ? "󰕾" : (centerIsland.currentVolume > 0.0 ? "󰖀" : "󰕿"))
            font.family: Style.font.family
            font.pixelSize: 16
            color: centerIsland.islandForeground
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.18)

            Rectangle {
              height: parent.height
              width: parent.width * Math.min(1.0, Math.max(0.0, centerIsland.isMuted ? 0 : centerIsland.currentVolume))
              radius: 3
              color: Color.accent || Qt.rgba(0.2, 0.8, 0.7, 1.0)

              Behavior on width {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
              }
            }
          }

          Text {
            Layout.preferredWidth: 42
            horizontalAlignment: Text.AlignRight
            text: centerIsland.isMuted ? "Muted" : Math.round(centerIsland.currentVolume * 100) + "%"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.Bold
            color: centerIsland.islandForeground
          }
        }
      }

      // ------------------------------------------------------------- Mode 5: Brightness OSD Slider Pill
      Item {
        id: brightnessView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "brightness" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        RowLayout {
          anchors.fill: parent
          spacing: Style.space(12)

          Text {
            text: "󰃠"
            font.family: Style.font.family
            font.pixelSize: 16
            color: centerIsland.islandForeground
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.18)

            Rectangle {
              height: parent.height
              width: parent.width * Math.min(1.0, Math.max(0.0, centerIsland.currentBrightness / 100.0))
              radius: 3
              color: Color.accent || Qt.rgba(1.0, 0.8, 0.2, 1.0)

              Behavior on width {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
              }
            }
          }

          Text {
            Layout.preferredWidth: 42
            horizontalAlignment: Text.AlignRight
            text: centerIsland.currentBrightness + "%"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.Bold
            color: centerIsland.islandForeground
          }
        }
      }

      // ------------------------------------------------------------- Mode 6: Notification Banner
      Item {
        id: notificationView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "notification" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        RowLayout {
          anchors.fill: parent
          spacing: Style.space(12)

          // Dynamic Icon Box
          Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 10
            color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.15)
            clip: true

            readonly property string iconSrc: centerIsland.resolveIconSource(centerIsland.currentNotification)
            readonly property string glyphText: centerIsland.resolveGlyph(centerIsland.currentNotification)

            Image {
              id: notifImg
              anchors.fill: parent
              anchors.margins: 4
              source: parent.iconSrc ? parent.iconSrc : ""
              sourceSize.width: 32 * Screen.devicePixelRatio
              sourceSize.height: 32 * Screen.devicePixelRatio
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              smooth: true
              visible: parent.iconSrc !== "" && status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: !notifImg.visible && parent.glyphText !== ""
              text: parent.glyphText
              font.family: Style.font.family
              font.pixelSize: 18
              color: centerIsland.islandForeground
            }

            Text {
              anchors.centerIn: parent
              visible: !notifImg.visible && parent.glyphText === ""
              text: "󰂚"
              font.family: Style.font.family
              font.pixelSize: 18
              color: centerIsland.islandForeground
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
              Layout.fillWidth: true
              text: centerIsland.currentNotification ? (centerIsland.currentNotification.appName || "") : ""
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
              color: Color.accent || centerIsland.islandForeground
              opacity: 0.85
              elide: Text.ElideRight
              visible: text !== ""
            }

            Text {
              Layout.fillWidth: true
              text: centerIsland.currentNotification ? (centerIsland.currentNotification.summary || "") : ""
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.weight: Font.Bold
              color: centerIsland.islandForeground
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            Text {
              Layout.fillWidth: true
              text: centerIsland.currentNotification ? (centerIsland.currentNotification.body || "") : ""
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: centerIsland.islandForeground
              opacity: 0.8
              elide: Text.ElideRight
              maximumLineCount: 1
              visible: text !== ""
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: function(mouse) {
            centerIsland.handleNotificationClick(mouse.button === Qt.RightButton)
          }
        }
      }

      // ------------------------------------------------------------- Mode 7: Seamless Integrated Morphing Search
      Item {
        id: searchView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 12
        anchors.bottomMargin: 14
        clip: true
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "search" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        focus: centerIsland.isSearchOpen
        Keys.onEscapePressed: {
          centerIsland.closeSearch()
          if (root) root.isSearchOpen = false
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: Style.space(10)

          // Search Input Box
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 8
            color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.08)
            border.color: searchInput.activeFocus ? (Color.accent || Qt.rgba(1,1,1,0.35)) : Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.18)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: Style.space(10)

              Text {
                text: "󰍉"
                font.family: Style.font.family
                font.pixelSize: 16
                color: centerIsland.islandForeground
                opacity: 0.75
              }

              TextInput {
                id: searchInput
                Layout.fillWidth: true
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: centerIsland.islandForeground
                selectionColor: Color.accent || Qt.rgba(0.2, 0.6, 1.0, 0.6)
                clip: true
                focus: centerIsland.isSearchOpen

                Connections {
                  target: centerIsland
                  function onIsSearchOpenChanged() {
                    if (centerIsland.isSearchOpen) {
                      searchInput.text = ""
                      if (root && root.shell && root.shell.appLibrary) {
                        root.shell.appLibrary.refreshIcons()
                      }
                      Qt.callLater(function() { searchInput.forceActiveFocus() })
                    }
                  }
                }

                Text {
                  anchors.fill: parent
                  text: "Search applications, toggles, settings & commands..."
                  font.family: searchInput.font.family
                  font.pixelSize: searchInput.font.pixelSize
                  color: centerIsland.islandForeground
                  opacity: 0.4
                  visible: !searchInput.text && !searchInput.inputMethodComposing
                }

                Keys.onEscapePressed: centerIsland.closeSearch()
                Keys.onDownPressed: {
                  if (appList.count > 0) {
                    appList.currentIndex = (appList.currentIndex + 1) % appList.count
                    appList.positionViewAtIndex(appList.currentIndex, ListView.Contain)
                  }
                }
                Keys.onUpPressed: {
                  if (appList.count > 0) {
                    appList.currentIndex = (appList.currentIndex - 1 + appList.count) % appList.count
                    appList.positionViewAtIndex(appList.currentIndex, ListView.Contain)
                  }
                }
                Keys.onReturnPressed: {
                  if (appList.currentItem && appList.currentItem.launchEntry) {
                    appList.currentItem.launchEntry()
                  }
                }
                onTextChanged: {
                  appList.currentIndex = 0
                  appList.positionViewAtBeginning()
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
            spacing: 3
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0
            highlightResizeDuration: 0
            preferredHighlightBegin: 0
            preferredHighlightEnd: height
            highlightRangeMode: ListView.ApplyRange

            model: centerIsland.getSearchResults(searchInput.text)

            delegate: Rectangle {
              id: resultRow
              width: appList.width
              height: 48
              radius: 6
              color: isSelected ? Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.15) : (rowMouse.containsMouse ? Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.06) : "transparent")

              readonly property bool isSelected: appList.currentIndex === index
              readonly property var itemData: modelData

              function launchEntry() {
                if (!itemData) return
                if (itemData.isApp) {
                  if (root && root.shell && root.shell.appLibrary) {
                    root.shell.appLibrary.launch(itemData.appId, itemData.name)
                  }
                } else if (itemData.action) {
                  Util.execDetached(itemData.action)
                }
                centerIsland.closeSearch()
              }

              // Active Accent Bar
              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 4
                width: 3
                radius: 2
                color: Color.accent || Qt.rgba(0.2, 0.8, 0.7, 1.0)
                visible: resultRow.isSelected
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: Style.space(12)

                // App Icon or System Glyph
                Item {
                  Layout.preferredWidth: 30
                  Layout.preferredHeight: 30

                  Image {
                    anchors.fill: parent
                    source: itemData.iconSource || ""
                    fillMode: Image.PreserveAspectFit
                    visible: itemData.iconSource !== ""
                  }

                  Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.1)
                    visible: !itemData.iconSource

                    Text {
                      anchors.centerIn: parent
                      text: itemData.iconGlyph || "󰒓"
                      font.family: Style.font.family
                      font.pixelSize: 16
                      color: centerIsland.islandForeground
                    }
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    Layout.fillWidth: true
                    text: itemData.name || ""
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.weight: Font.DemiBold
                    color: centerIsland.islandForeground
                    elide: Text.ElideRight
                  }

                  Text {
                    Layout.fillWidth: true
                    text: itemData.detail || ""
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: centerIsland.islandForeground
                    opacity: 0.65
                    elide: Text.ElideRight
                    visible: text !== ""
                  }
                }

                // Type Badge (App vs System Action)
                Rectangle {
                  Layout.preferredHeight: 18
                  Layout.preferredWidth: badgeText.implicitWidth + 10
                  radius: 4
                  color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.08)
                  visible: !itemData.isApp

                  Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: "Action"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Color.accent || centerIsland.islandForeground
                    opacity: 0.8
                  }
                }
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  appList.currentIndex = index
                  resultRow.launchEntry()
                }
              }
            }
          }
        }
      }

      // ------------------------------------------------------------- Mode 8: Notification History View
      Item {
        id: historyView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        clip: true
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "history" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        focus: centerIsland.isHistoryOpen
        Keys.onEscapePressed: {
          if (root) root.closeHistory()
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: Style.space(12)

          // Header Row
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "󰂚"
              font.family: Style.font.family
              font.pixelSize: 16
              color: Color.accent || centerIsland.islandForeground
            }

            Text {
              text: "Notifications"
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.weight: Font.Bold
              color: centerIsland.islandForeground
            }

            Rectangle {
              visible: historyModel.count > 0
              Layout.preferredHeight: 18
              Layout.preferredWidth: countLabel.implicitWidth + 10
              radius: 9
              color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.15)

              Text {
                id: countLabel
                anchors.centerIn: parent
                text: String(historyModel.count)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                color: centerIsland.islandForeground
              }
            }

            Item { Layout.fillWidth: true }

            // "Clear All" button
            Rectangle {
              visible: historyModel.count > 0
              Layout.preferredHeight: 26
              Layout.preferredWidth: clearRow.implicitWidth + 16
              radius: 6
              color: clearArea.containsMouse ? Qt.rgba(Color.red.r, Color.red.g, Color.red.b, 0.22) : Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.08)

              RowLayout {
                id: clearRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                  text: "󰆴"
                  font.family: Style.font.family
                  font.pixelSize: 13
                  color: clearArea.containsMouse ? Color.red : centerIsland.islandForeground
                  opacity: clearArea.containsMouse ? 1.0 : 0.7
                }

                Text {
                  text: "Clear All"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  color: clearArea.containsMouse ? Color.red : centerIsland.islandForeground
                  opacity: clearArea.containsMouse ? 1.0 : 0.85
                }
              }

              MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  Util.execDetached("rm -f " + (root ? root.home : Quickshell.env("HOME")) + "/.local/state/omarchy/notifications/*.json " + (root ? root.home : Quickshell.env("HOME")) + "/.local/state/omarchy/notifications/history/*.json")
                  historyModel.clear()
                }
              }
            }
          }

          // Content Area: Empty State or History List
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty placeholder
            ColumnLayout {
              anchors.centerIn: parent
              visible: historyModel.count === 0
              spacing: 8

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰂚"
                font.family: Style.font.family
                font.pixelSize: 42
                color: centerIsland.islandForeground
                opacity: 0.25
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No Notifications"
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.weight: Font.DemiBold
                color: centerIsland.islandForeground
                opacity: 0.6
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "You're all caught up"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: centerIsland.islandForeground
                opacity: 0.4
              }
            }

            // Scrollable List
            ListView {
              id: historyListView
              anchors.fill: parent
              visible: historyModel.count > 0
              model: historyModel
              clip: true
              spacing: 6
              boundsBehavior: Flickable.StopAtBounds

              delegate: Item {
                id: cardItem
                width: historyListView.width
                implicitHeight: cardBox.implicitHeight

                property real swipeX: 0

                // Background red swipe layer
                Rectangle {
                  anchors.fill: parent
                  radius: 8
                  color: Qt.rgba(0.9, 0.2, 0.2, 0.8)
                  visible: Math.abs(cardItem.swipeX) > 10

                  Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰆴 Delete"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: "white"
                    visible: cardItem.swipeX > 10
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Delete 󰆴"
                    font.family: Style.font.family
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: "white"
                    visible: cardItem.swipeX < -10
                  }
                }

                // Front card container
                Rectangle {
                  id: cardBox
                  x: cardItem.swipeX
                  width: parent.width
                  implicitHeight: Math.max(54, innerRow.implicitHeight + 16)
                  radius: 8
                  color: cardMouse.containsMouse ? Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.12) : Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.06)
                  border.color: cardMouse.containsMouse ? Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.18) : Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.08)
                  border.width: 1

                  Behavior on x {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                  }

                  RowLayout {
                    id: innerRow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    // Icon Box
                    Rectangle {
                      Layout.preferredWidth: 34
                      Layout.preferredHeight: 34
                      Layout.alignment: Qt.AlignTop
                      radius: 8
                      color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.10)
                      clip: true

                      readonly property string cardIconSrc: centerIsland.resolveIconSource(model)
                      readonly property string cardGlyph: centerIsland.resolveGlyph(model)

                      Image {
                        id: cardImg
                        anchors.fill: parent
                        anchors.margins: 3
                        source: parent.cardIconSrc ? parent.cardIconSrc : ""
                        sourceSize.width: 28 * Screen.devicePixelRatio
                        sourceSize.height: 28 * Screen.devicePixelRatio
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        visible: parent.cardIconSrc !== "" && status === Image.Ready
                      }

                      Text {
                        anchors.centerIn: parent
                        visible: !cardImg.visible && parent.cardGlyph !== ""
                        text: parent.cardGlyph
                        font.family: Style.font.family
                        font.pixelSize: 16
                        color: centerIsland.islandForeground
                      }

                      Text {
                        anchors.centerIn: parent
                        visible: !cardImg.visible && parent.cardGlyph === ""
                        text: "󰂚"
                        font.family: Style.font.family
                        font.pixelSize: 16
                        color: centerIsland.islandForeground
                      }
                    }

                    // Text Content Column
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 2

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                          Layout.fillWidth: true
                          text: model.app || model.appName || ""
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.weight: Font.DemiBold
                          color: Color.accent || centerIsland.islandForeground
                          opacity: 0.9
                          elide: Text.ElideRight
                          visible: text !== ""
                        }

                        Text {
                          text: centerIsland.formatRelativeTime(model.timestamp)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: centerIsland.islandForeground
                          opacity: 0.5
                          visible: text !== ""
                        }
                      }

                      Text {
                        Layout.fillWidth: true
                        text: model.summary || ""
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.weight: Font.Bold
                        color: centerIsland.islandForeground
                        elide: Text.ElideRight
                        maximumLineCount: 1
                      }

                      Text {
                        Layout.fillWidth: true
                        text: model.body || ""
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: centerIsland.islandForeground
                        opacity: 0.75
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        visible: text !== ""
                      }
                    }
                  }

                  MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    drag.target: cardBox
                    drag.axis: Drag.XAxis
                    drag.minimumX: -250
                    drag.maximumX: 250

                    onPositionChanged: {
                      if (drag.active) {
                        cardItem.swipeX = cardBox.x
                      }
                    }

                    onReleased: {
                      if (Math.abs(cardItem.swipeX) > 70) {
                        deleteNotification(index, model.filePath)
                      } else {
                        cardItem.swipeX = 0
                        cardBox.x = 0
                      }
                    }

                    onClicked: function(mouse) {
                      if (Math.abs(cardItem.swipeX) > 10) return
                      if (mouse.button === Qt.RightButton) {
                        deleteNotification(index, model.filePath)
                      } else {
                        // Left click -> Execute or Focus
                        if (model.exec) {
                          Util.execDetached(model.exec)
                        } else if (model.app && model.app !== "notify-send" && model.app !== "omarchy-action") {
                          var omPath = (root && root.omarchyPath) ? root.omarchyPath : "/usr/share/omarchy"
                          Util.execDetached(omPath + "/bin/omarchy-hyprland-focus-app " + model.app)
                        }
                        deleteNotification(index, model.filePath)
                        if (root) root.closeHistory()
                      }
                    }
                  }
                }

                function deleteNotification(idx, filePath) {
                  if (filePath) {
                    Util.execDetached("rm -f " + filePath)
                  }
                  historyModel.remove(idx)
                }
              }
            }
          }
        }
      }
    }
  }

  MouseArea {
    id: centerMouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    visible: !centerIsland.isSearchOpen
    z: -1

    onWheel: function(wheel) {
      if (centerIsland.currentMode === "media") {
        if (wheel.angleDelta.y > 0) {
          // Swiping up over expanded media player collapses it
          centerIsland.isMediaOpen = false
          return
        }
      }

      if (centerIsland.currentMode === "clock" && wheel.angleDelta.y < 0 && centerIsland.hasActiveMedia) {
        // Swiping down over idle middle island pulls down media player
        centerIsland.isMediaOpen = true
        return
      }

      if (centerIsland.currentMode === "brightness") {
        if (wheel.angleDelta.y > 0) {
          brightnessSetProc.command = ["brightnessctl", "set", "5%+"]
          brightnessSetProc.running = true
        } else {
          brightnessSetProc.command = ["brightnessctl", "set", "5%-"]
          brightnessSetProc.running = true
        }
        centerIsland.triggerOsd("brightness")
      } else {
        if (centerIsland.sink && centerIsland.sink.audio) {
          if (wheel.angleDelta.y > 0) {
            centerIsland.sink.audio.volume = Math.min(1.5, centerIsland.sink.audio.volume + 0.05)
          } else {
            centerIsland.sink.audio.volume = Math.max(0.0, centerIsland.sink.audio.volume - 0.05)
          }
          centerIsland.triggerOsd("volume")
        }
      }
    }
  }
}
