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
  readonly property bool isFullscreen: root ? root.isFullscreenActive : false
  readonly property color islandForeground: (root && root.barForeground) ? root.barForeground : Color.bar.text
  readonly property color islandThemeForeground: (root && root.themeForeground) ? root.themeForeground : Color.foreground

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
    onExited: {
      if (!brightnessQueryProc.running) brightnessQueryProc.running = true
    }
  }

  // OSD mode management: "volume" | "brightness" | "media-action"
  property string osdMode: ""
  property bool isOsdActive: osdTimer.running
  property string mediaOsdMessage: ""
  property string mediaOsdIcon: "󰐊"

  function triggerOsd(mode) {
    if (centerIsland.isMenuOpen || centerIsland.isHistoryOpen) return
    osdMode = mode
    osdTimer.restart()
  }

  function handleExternalOsd(data) {
    if (!data || centerIsland.isMenuOpen || centerIsland.isHistoryOpen) return
    var key = String(data.iconKey || "").toLowerCase()
    var msg = String(data.message || "")
    var val = data.value
    var prog = data.hasProgress
    var med = data.mediaOsd

    if (key.indexOf("brightness") !== -1 || key.indexOf("display") !== -1) {
      if (val !== undefined && val !== null && !isNaN(val)) {
        centerIsland.currentBrightness = Math.min(100, Math.max(0, parseInt(val, 10)))
      }
      centerIsland.triggerOsd("brightness")
    } else if (key.indexOf("volume") !== -1 || key.indexOf("audio") !== -1 || (prog && !med)) {
      centerIsland.triggerOsd("volume")
    } else if (med || key.indexOf("media") !== -1 || key.indexOf("player") !== -1) {
      var glyph = "󰐊"
      if (key.indexOf("pause") !== -1) glyph = "󰏤"
      else if (key.indexOf("play") !== -1) glyph = "󰐊"
      else if (key.indexOf("next") !== -1) glyph = "󰒭"
      else if (key.indexOf("prev") !== -1) glyph = "󰒮"
      else if (key.indexOf("stop") !== -1) glyph = "󰓛"
      else if (key.indexOf("source") !== -1) glyph = "󰎆"
      else if (data.icon) glyph = data.icon

      mediaOsdIcon = glyph
      mediaOsdMessage = msg
      centerIsland.triggerOsd("media-action")
    } else {
      mediaOsdIcon = data.icon || "󰒓"
      mediaOsdMessage = msg
      centerIsland.triggerOsd("media-action")
    }
  }

  Timer {
    id: osdTimer
    interval: 1600
    repeat: false
    onTriggered: {
      centerIsland.osdMode = ""
    }
  }

  Component.onCompleted: {
    brightnessQueryProc.running = true
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

  property bool mediaInitialized: false
  property string lastObservedTrackTitle: ""
  property var lastObservedPlaybackState: null

  Connections {
    target: centerIsland.activePlayer
    ignoreUnknownSignals: true

    function onPlaybackStateChanged() {
      if (!centerIsland.activePlayer) return
      if (!centerIsland.mediaInitialized) {
        centerIsland.lastObservedPlaybackState = centerIsland.activePlayer.playbackState
        centerIsland.lastObservedTrackTitle = centerIsland.activePlayer.trackTitle || ""
        centerIsland.mediaInitialized = true
        return
      }

      var st = centerIsland.activePlayer.playbackState
      if (st !== centerIsland.lastObservedPlaybackState) {
        centerIsland.lastObservedPlaybackState = st
        var isPl = (st === MprisPlaybackState.Playing)
        centerIsland.mediaOsdIcon = isPl ? "󰐊" : "󰏤"
        var track = (centerIsland.activePlayer.trackTitle || "") + (centerIsland.activePlayer.trackArtist ? " • " + centerIsland.activePlayer.trackArtist : "")
        centerIsland.mediaOsdMessage = (isPl ? "Playing" : "Paused") + (track ? " • " + track : "")
        centerIsland.triggerOsd("media-action")
      }
    }

    function onTrackTitleChanged() {
      if (!centerIsland.activePlayer) return
      var t = centerIsland.activePlayer.trackTitle || ""
      if (!centerIsland.mediaInitialized) {
        centerIsland.lastObservedTrackTitle = t
        centerIsland.mediaInitialized = true
        return
      }
      if (t !== "" && t !== centerIsland.lastObservedTrackTitle) {
        centerIsland.lastObservedTrackTitle = t
        centerIsland.mediaOsdIcon = "󰒭"
        var track = t + (centerIsland.activePlayer.trackArtist ? " • " + centerIsland.activePlayer.trackArtist : "")
        centerIsland.mediaOsdMessage = track
        centerIsland.triggerOsd("media-action")
      }
    }
  }

  // =========================================================================
  // FULL OMARCHY MENU ENGINE & SUBMENU DRILLDOWN (Future-Proof Integration)
  // =========================================================================
  property string defaultMenuPath: (root && root.omarchyPath ? root.omarchyPath : "/usr/share/omarchy") + "/default/omarchy/omarchy-menu.jsonc"
  property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
  property var defaultMenuItems: []
  property var userMenuItems: []
  property var items: ({})
  property var itemOrder: []
  property bool rowsLoaded: false

  property string activeMenu: "root"
  property var navStack: []
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: true
  property bool menuOpenInternal: false
  readonly property bool isMenuOpen: (root && root.isMenuOpen) || menuOpenInternal || isSearchOpen

  property var whenResults: ({})
  property var checkedResults: ({})
  property bool guardsPending: false

  property var providersLoaded: ({})
  property var providerQueue: []
  property int providerRevision: 0

  property string dmenuMode: ""
  property string dmenuPrompt: ""
  property var dmenuOptions: []
  property real dmenuWidth: 600
  property real dmenuMaxHeight: 520
  property string selectionFile: ""
  property string doneFile: ""
  property bool requestActive: false
  property int requestSerial: 0
  property int applySerial: 0

  property bool deleteConfirmOpen: false
  property var deleteTarget: null
  property bool searchDivider: false

  readonly property var providers: ({
    "fonts": {
      script: "current=$(omarchy-font-current 2>/dev/null); omarchy-font-list 2>/dev/null | while read -r f; do [[ -z $f ]] && continue; printf '%s\\t%s\\t%s\\n' \"$f\" \"$f\" \"$current\"; done",
      icon: "",
      volatile: true,
      actionFor: function(value) { return "omarchy-font-set " + Util.shellQuote(value) }
    },
    "power-profiles": {
      script: "current=$(powerprofilesctl get 2>/dev/null); omarchy-powerprofiles-list 2>/dev/null | while read -r p; do [[ -z $p ]] && continue; printf '%s\\t%s\\t%s\\n' \"$p\" \"$p\" \"$current\"; done",
      icon: "\udb81\udc0b",
      actionFor: function(value) { return "omarchy-powerprofiles-set autodetect " + Util.shellQuote(value) }
    }
  })

  FileView {
    id: defaultMenuFile
    path: centerIsland.defaultMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      centerIsland.defaultMenuItems = MenuModel.parseMenuJsonc(text())
      centerIsland.rebuildItemsFromSources()
    }
    onFileChanged: reload()
  }

  FileView {
    id: userMenuFile
    path: centerIsland.userMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      centerIsland.userMenuItems = MenuModel.parseMenuJsonc(text())
      centerIsland.rebuildItemsFromSources()
    }
    onLoadFailed: {
      centerIsland.userMenuItems = []
      centerIsland.rebuildItemsFromSources()
    }
    onFileChanged: reload()
  }

  function rebuildItemsFromSources() {
    var merged = MenuModel.mergeMenuSources(centerIsland.defaultMenuItems, centerIsland.userMenuItems)
    centerIsland.providerRevision += 1
    centerIsland.providersLoaded = ({})
    centerIsland.providerQueue = []
    centerIsland.items = merged.items
    centerIsland.itemOrder = merged.itemOrder
    centerIsland.rowsLoaded = true
    centerIsland.evaluateGuards()
    if (centerIsland.isMenuOpen) {
      centerIsland.rebuildDisplay()
      if (!centerIsland.dmenuMode) {
        if (centerIsland.filterText.trim()) centerIsland.loadProvidersForSearch()
        else centerIsland.loadProviderForMenu(centerIsland.activeMenu)
      }
    }
  }

  function evaluateGuards() {
    if (guardProc.running) {
      centerIsland.guardsPending = true
      return
    }
    centerIsland.guardsPending = false

    var script = MenuModel.guardScript(centerIsland.items)
    if (!script) {
      centerIsland.whenResults = ({})
      centerIsland.checkedResults = ({})
      return
    }
    guardProc.collected = ""
    guardProc.command = ["bash", "-lc", script]
    guardProc.running = true
  }

  Process {
    id: guardProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function(data) { guardProc.collected += data + "\n" }
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || exitStatus !== 0) {
        if (centerIsland.guardsPending) Qt.callLater(function() { centerIsland.evaluateGuards() })
        return
      }

      var nextWhen = ({})
      var nextChecked = ({})
      var lines = guardProc.collected.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line) continue
        var colon = line.lastIndexOf(":")
        if (colon < 0) continue
        var value = line.substring(colon + 1) === "1"
        var rest = line.substring(0, colon)
        var tagAt = rest.lastIndexOf(":")
        if (tagAt < 0) continue
        var id = rest.substring(0, tagAt)
        var tag = rest.substring(tagAt + 1)
        if (tag === "w") nextWhen[id] = value
        else if (tag === "c") nextChecked[id] = value
      }
      centerIsland.whenResults = nextWhen
      centerIsland.checkedResults = nextChecked
      if (centerIsland.isMenuOpen) centerIsland.rebuildDisplay()
      if (centerIsland.guardsPending) Qt.callLater(function() { centerIsland.evaluateGuards() })
    }
  }

  function mergeAppRows() {
    if (!root || !root.shell || !root.shell.appLibrary) return
    var rows = root.shell.appLibrary.sortedEntries("")
    var appRows = []
    for (var j = 0; j < rows.length; j++) {
      var entry = (rows[j] && rows[j].entry) ? rows[j].entry : rows[j]
      if (!entry) continue
      var appId = String(entry.id || entry.appId || "")
      if (!appId) continue
      var subtext = root.shell.appLibrary.entrySubtext(entry) || entry.subtext || entry.description || "Application"
      var aliases = subtext ? [subtext] : []
      try {
        if (entry.keywords && typeof entry.keywords.join === "function") aliases = aliases.concat(entry.keywords)
      } catch (e) { }
      appRows.push({
        id: "apps." + appId,
        parent: "apps",
        kind: "app",
        icon: "",
        appIcon: String(entry.icon || entry.appIcon || ""),
        appId: appId,
        label: root.shell.appLibrary.entryName(entry) || entry.name || entry.label || appId,
        title: "",
        target: "",
        description: subtext,
        action: "",
        provider: "",
        aliases: aliases,
        when: "",
        checked: "",
        order: 0
      })
    }

    var merged = MenuModel.mergeAppRows(centerIsland.items, centerIsland.itemOrder, appRows)
    centerIsland.items = merged.items
    centerIsland.itemOrder = merged.itemOrder
    if (centerIsland.isMenuOpen) centerIsland.rebuildDisplay()
  }

  function startProviderForMenu(id) {
    var entry = MenuModel.item(centerIsland.items, id)
    if (!entry || !entry.provider || centerIsland.providersLoaded[id]) return
    if (entry.provider === "apps") {
      centerIsland.providersLoaded[id] = true
      centerIsland.mergeAppRows()
      return
    }
    var spec = centerIsland.providers[entry.provider]
    if (!spec) return

    centerIsland.providersLoaded[id] = true
    providerProc.menuId = id
    providerProc.providerKey = entry.provider
    providerProc.revision = centerIsland.providerRevision
    providerProc.collected = ""
    providerProc.command = ["bash", "-lc", spec.script]
    providerProc.running = true
  }

  function mergeProviderRows(rows, menuId, providerKey) {
    var spec = centerIsland.providers[providerKey]
    if (!spec) return
    var lines = String(rows || "").split("\n")
    var providerRows = []
    var takenIds = ({})
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var parts = line.split("\t")
      var label = parts[0] || ""
      var value = parts[1] || parts[0] || ""
      var current = parts[2] || ""
      if (!label) continue
      var rowId = menuId + "." + MenuModel.slugify(value)
      while (takenIds[rowId]) rowId += "-"
      takenIds[rowId] = true

      providerRows.push({
        id: rowId,
        parent: menuId,
        kind: "action",
        icon: (value === current) ? "✓" : (spec.icon || ""),
        label: label,
        title: "",
        target: "",
        description: "",
        action: spec.actionFor(value),
        provider: "",
        aliases: [],
        when: "",
        checked: "",
        order: 0
      })
    }
    var merged = MenuModel.swapProviderRows(centerIsland.items, centerIsland.itemOrder, menuId, providerRows)
    centerIsland.items = merged.items
    centerIsland.itemOrder = merged.itemOrder
    if (centerIsland.isMenuOpen) centerIsland.rebuildDisplay()
  }

  function startNextProvider() {
    if (providerProc.running) return
    while (centerIsland.providerQueue.length > 0) {
      var id = centerIsland.providerQueue.shift()
      var entry = MenuModel.item(centerIsland.items, id)
      if (!entry || !entry.provider || centerIsland.providersLoaded[id]) continue
      centerIsland.startProviderForMenu(id)
      return
    }
  }

  function invalidateVolatileProvider(id) {
    var entry = MenuModel.item(centerIsland.items, id)
    var spec = entry && entry.provider ? centerIsland.providers[entry.provider] : null
    if (spec && spec.volatile) centerIsland.providersLoaded[id] = false
  }

  function loadProviderForMenu(id) {
    var entry = MenuModel.item(centerIsland.items, id)
    if (!entry || !entry.provider || centerIsland.providersLoaded[id]) return
    if (entry.provider === "apps") {
      centerIsland.startProviderForMenu(id)
      return
    }
    if (providerProc.running) {
      if (centerIsland.providerQueue.indexOf(id) < 0) centerIsland.providerQueue = centerIsland.providerQueue.concat([id])
      return
    }
    centerIsland.startProviderForMenu(id)
  }

  function loadProvidersForSearch() {
    var active = MenuModel.item(centerIsland.items, centerIsland.activeMenu) ? centerIsland.activeMenu : "root"
    for (var i = 0; i < centerIsland.itemOrder.length; i++) {
      var entry = MenuModel.item(centerIsland.items, centerIsland.itemOrder[i])
      if (!entry || !entry.provider || centerIsland.providersLoaded[entry.id]) continue
      if (active !== "root" && entry.id !== active && !MenuModel.isDescendantOf(centerIsland.items, entry.id, active)) continue
      centerIsland.loadProviderForMenu(entry.id)
    }
  }

  Process {
    id: providerProc
    property string menuId: ""
    property string providerKey: ""
    property string collected: ""
    property int revision: 0
    stdout: SplitParser {
      onRead: function(data) { providerProc.collected += data + "\n" }
    }
    onExited: {
      if (providerProc.revision === centerIsland.providerRevision) {
        centerIsland.mergeProviderRows(providerProc.collected, providerProc.menuId, providerProc.providerKey)
        if (centerIsland.filterText.trim()) centerIsland.loadProvidersForSearch()
      }
      centerIsland.startNextProvider()
    }
  }

  Process {
    id: resultProc
    onExited: {
      if (centerIsland.applySerial === centerIsland.requestSerial)
        centerIsland.closeMenu()
    }
  }

  ListModel {
    id: menuDisplayModel
  }

  function rebuildDisplay() {
    menuDisplayModel.clear()
    centerIsland.searchDivider = false

    if (centerIsland.dmenuMode) {
      if (centerIsland.dmenuMode === "input") return
      var dquery = centerIsland.filterText.trim().toLowerCase()
      for (var i = 0; i < centerIsland.dmenuOptions.length; i++) {
        var parts = String(centerIsland.dmenuOptions[i] || "").split("\t")
        var icon = parts.length > 1 ? parts.shift() : ""
        var label = parts.shift() || ""
        var detail = parts.join("\t")
        if (dquery && label.toLowerCase().indexOf(dquery) < 0 && detail.toLowerCase().indexOf(dquery) < 0) continue
        menuDisplayModel.append({
          itemId: "dmenu." + i,
          kind: "dmenu",
          icon: icon,
          iconFont: "",
          appIcon: "",
          appId: "",
          label: label,
          target: "",
          detail: detail,
          path: "",
          childCount: 0,
          action: "",
          provider: "",
          score: i,
          section: ""
        })
      }
      centerIsland.clampSelectedIndex()
      return
    }

    if (!centerIsland.rowsLoaded) return

    var active = MenuModel.item(centerIsland.items, centerIsland.activeMenu) ? centerIsland.activeMenu : "root"
    centerIsland.activeMenu = active
    var rows = []
    var query = centerIsland.filterText.trim()

    if (query) {
      var currentRows = []
      var drilldownRows = []

      for (var i = 0; i < centerIsland.itemOrder.length; i++) {
        var entry = MenuModel.item(centerIsland.items, centerIsland.itemOrder[i])
        if (!entry || entry.id === "root") continue
        if (!MenuModel.isDescendantOf(centerIsland.items, entry.id, active)) continue
        if (!MenuModel.matchesQuery(entry, query, MenuModel.isVisible(centerIsland.items, centerIsland.itemOrder, centerIsland.whenResults, entry))) continue

        var detail = MenuModel.parentPathFor(centerIsland.items, entry.id)
        var row = MenuModel.displayRow(centerIsland.items, centerIsland.itemOrder, centerIsland.checkedResults, entry, detail, MenuModel.searchScore(centerIsland.items, entry, query))
        if (entry.parent === active) currentRows.push(row)
        else drilldownRows.push(row)
      }

      var searchSort = function(a, b) {
        if (a.score !== b.score) return a.score - b.score
        return a.path.localeCompare(b.path)
      }

      currentRows.sort(searchSort)
      drilldownRows.sort(searchSort)
      centerIsland.searchDivider = currentRows.length > 0 && drilldownRows.length > 0
      if (centerIsland.searchDivider) {
        for (var d = 0; d < drilldownRows.length; d++) drilldownRows[d].section = "drilldown"
      }
      rows = currentRows.concat(drilldownRows)
    } else {
      for (var j = 0; j < centerIsland.itemOrder.length; j++) {
        var child = MenuModel.item(centerIsland.items, centerIsland.itemOrder[j])
        if (!child || child.parent !== active) continue
        if (!MenuModel.isVisible(centerIsland.items, centerIsland.itemOrder, centerIsland.whenResults, child)) continue
        rows.push(MenuModel.displayRow(centerIsland.items, centerIsland.itemOrder, centerIsland.checkedResults, child, child.description, child.order))
      }

      if (active === "apps") {
        rows.sort(function(a, b) {
          var aLabel = String(a.label || "").toLowerCase()
          var bLabel = String(b.label || "").toLowerCase()
          if (aLabel < bLabel) return -1
          if (aLabel > bLabel) return 1
          return 0
        })
      }
    }

    for (var k = 0; k < rows.length; k++) {
      menuDisplayModel.append(rows[k])
    }
    centerIsland.clampSelectedIndex()
  }

  function clampSelectedIndex() {
    if (menuDisplayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= menuDisplayModel.count) selectedIndex = menuDisplayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (menuDisplayModel.count > 0 && menuListView) {
        menuListView.positionViewAtIndex(centerIsland.selectedIndex, ListView.Contain)
      }
    })
  }

  function select(delta) {
    if (menuDisplayModel.count === 0) return
    centerIsland.cursorActive = true
    centerIsland.selectedIndex = (centerIsland.selectedIndex + delta + menuDisplayModel.count) % menuDisplayModel.count
    if (menuListView) menuListView.positionViewAtIndex(centerIsland.selectedIndex, ListView.Contain)
  }

  function setFilter(text) {
    centerIsland.filterText = text
    centerIsland.selectedIndex = 0
    centerIsland.cursorActive = true
    if (!centerIsland.dmenuMode && centerIsland.filterText.trim()) centerIsland.loadProvidersForSearch()
    centerIsland.rebuildDisplay()
  }

  function setActiveMenu(id, pushHistory) {
    if (!MenuModel.item(centerIsland.items, id)) id = "root"
    if (pushHistory && id !== centerIsland.activeMenu) {
      centerIsland.navStack = centerIsland.navStack.concat([centerIsland.activeMenu])
    }
    centerIsland.activeMenu = id
    centerIsland.filterText = ""
    centerIsland.selectedIndex = 0
    centerIsland.cursorActive = true
    centerIsland.rebuildDisplay()
    centerIsland.invalidateVolatileProvider(id)
    centerIsland.loadProviderForMenu(id)
  }

  function goBack() {
    if (centerIsland.filterText) {
      centerIsland.setFilter("")
      return true
    }
    if (centerIsland.activeMenu === "root") {
      centerIsland.closeMenu()
      return false
    }
    if (centerIsland.navStack.length > 0) {
      var prev = centerIsland.navStack[centerIsland.navStack.length - 1]
      centerIsland.navStack = centerIsland.navStack.slice(0, centerIsland.navStack.length - 1)
      centerIsland.setActiveMenu(prev, false)
      return true
    }
    var entry = MenuModel.item(centerIsland.items, centerIsland.activeMenu)
    centerIsland.setActiveMenu((entry && entry.parent) ? entry.parent : "root", false)
    return true
  }

  function activateIndex(index) {
    if (centerIsland.deleteConfirmOpen) return
    if (centerIsland.dmenuMode) {
      if (centerIsland.dmenuMode === "input") {
        centerIsland.applyDmenuSelection(centerIsland.filterText)
        return
      }
      if (index < 0 || index >= menuDisplayModel.count) return
      var picked = menuDisplayModel.get(index)
      centerIsland.applyDmenuSelection(picked.detail ? picked.label + "\t" + picked.detail : picked.label)
      return
    }

    if (index < 0 || index >= menuDisplayModel.count) return
    var row = menuDisplayModel.get(index)
    if (row.kind === "menu" || row.kind === "link") {
      centerIsland.setActiveMenu(row.target || row.itemId, true)
    } else if (row.kind === "app") {
      var appId = row.appId
      var label = row.label
      centerIsland.closeMenu()
      if (root && root.shell && root.shell.appLibrary) {
        root.shell.appLibrary.launch(appId, label)
      }
    } else {
      centerIsland.applySelected(row.itemId, row.action)
    }
  }

  function applySelected(id, action) {
    centerIsland.closeMenu()
    if (action) {
      Util.execDetached(action)
    }
  }

  function applyDmenuSelection(val) {
    centerIsland.applySerial = centerIsland.requestSerial
    centerIsland.finishRequest(val)
    centerIsland.closeMenu()
  }

  function finishRequest(selection) {
    if (!centerIsland.requestActive || !centerIsland.doneFile) {
      centerIsland.closeMenu()
      return
    }
    var selFile = centerIsland.selectionFile
    var dnFile = centerIsland.doneFile
    centerIsland.requestActive = false
    centerIsland.selectionFile = ""
    centerIsland.doneFile = ""

    if (selection === null || selection === undefined) {
      resultProc.command = ["bash", "-c", ": > " + Util.shellQuote(dnFile)]
    } else {
      resultProc.command = ["bash", "-c", "printf '%s\\n' " + Util.shellQuote(selection) + " > " + Util.shellQuote(selFile) + "; : > " + Util.shellQuote(dnFile)]
    }
    resultProc.running = true
  }

  function openRoute(initialMenu) {
    var id = MenuModel.resolveRoute(centerIsland.items, centerIsland.itemOrder, initialMenu)
    var entry = MenuModel.item(centerIsland.items, id)
    if (entry && entry.kind === "action" && entry.action) {
      centerIsland.closeMenu()
      Util.execDetached(entry.action)
      return "ok"
    }
    if (entry && entry.kind === "link" && entry.target) id = entry.target

    centerIsland.dmenuMode = ""
    centerIsland.requestActive = false
    centerIsland.activeMenu = centerIsland.items[id] ? id : "root"
    centerIsland.navStack = []
    centerIsland.filterText = ""
    centerIsland.selectedIndex = 0
    centerIsland.cursorActive = true
    centerIsland.menuOpenInternal = true
    if (root) {
      root.isMenuOpen = true
      root.isSearchOpen = false
      root.isHistoryOpen = false
    }
    centerIsland.evaluateGuards()
    centerIsland.rebuildDisplay()
    centerIsland.invalidateVolatileProvider(centerIsland.activeMenu)
    centerIsland.loadProviderForMenu(centerIsland.activeMenu)
    if (root && root.shell && root.shell.appLibrary) {
      root.shell.appLibrary.refreshIcons()
    }
    Qt.callLater(function() {
      if (menuSearchInput) menuSearchInput.forceActiveFocus()
    })
    return "ok"
  }

  function openDmenu(payload) {
    centerIsland.requestSerial += 1
    centerIsland.dmenuMode = payload.mode === "input" ? "input" : "select"
    centerIsland.dmenuPrompt = String(payload.prompt || (centerIsland.dmenuMode === "input" ? "Input" : "Select"))
    centerIsland.dmenuOptions = Array.isArray(payload.options) ? payload.options : []
    centerIsland.dmenuWidth = Math.max(1, Number(payload.width || 600))
    centerIsland.dmenuMaxHeight = Math.max(0, Number(payload.maxHeight || 520))
    centerIsland.selectionFile = String(payload.selectionFile || "")
    centerIsland.doneFile = String(payload.doneFile || "")
    centerIsland.requestActive = !!centerIsland.doneFile
    centerIsland.activeMenu = "root"
    centerIsland.navStack = []
    centerIsland.filterText = ""
    centerIsland.selectedIndex = 0
    centerIsland.cursorActive = centerIsland.dmenuMode !== "input"
    centerIsland.menuOpenInternal = true
    if (root) {
      root.isMenuOpen = true
      root.isSearchOpen = false
      root.isHistoryOpen = false
    }
    centerIsland.rebuildDisplay()
    Qt.callLater(function() {
      if (menuSearchInput) menuSearchInput.forceActiveFocus()
    })
  }

  function toggleMenu(route) {
    var targetRoute = route || "root"
    var resolvedId = MenuModel.resolveRoute(centerIsland.items, centerIsland.itemOrder, targetRoute)
    if (centerIsland.isMenuOpen) {
      if (targetRoute === "root" || centerIsland.activeMenu === resolvedId || centerIsland.activeMenu === targetRoute) {
        centerIsland.closeMenu()
      } else {
        centerIsland.openRoute(targetRoute)
      }
    } else {
      centerIsland.openRoute(targetRoute)
    }
  }

  function closeMenu() {
    if (centerIsland.dmenuMode && centerIsland.requestActive) {
      centerIsland.finishRequest(null)
    }
    centerIsland.menuOpenInternal = false
    centerIsland.dmenuMode = ""
    centerIsland.filterText = ""
    centerIsland.deleteConfirmOpen = false
    centerIsland.deleteTarget = null
    if (root) {
      root.isMenuOpen = false
      root.isSearchOpen = false
    }
  }

  function refreshMenu() {
    defaultMenuFile.reload()
    userMenuFile.reload()
    return "ok"
  }

  function requestDeleteSelected() {
    if (centerIsland.selectedIndex < 0 || centerIsland.selectedIndex >= menuDisplayModel.count) return
    var row = menuDisplayModel.get(centerIsland.selectedIndex)
    if (!row || row.kind !== "app") return
    centerIsland.deleteTarget = { appId: row.appId, label: row.label }
    centerIsland.deleteConfirmOpen = true
  }

  function cancelDelete() {
    centerIsland.deleteConfirmOpen = false
    centerIsland.deleteTarget = null
    Qt.callLater(function() {
      if (menuSearchInput) menuSearchInput.forceActiveFocus()
    })
  }

  function confirmDelete() {
    var target = centerIsland.deleteTarget
    centerIsland.deleteConfirmOpen = false
    centerIsland.deleteTarget = null
    if (!target) return
    centerIsland.closeMenu()
    if (root && root.shell && root.shell.appLibrary) {
      root.shell.appLibrary.remove(target.appId, target.label)
    }
  }

  // Current display mode
  readonly property string currentMode: {
    if (centerIsland.isMenuOpen) return "menu"
    if (centerIsland.isHistoryOpen) return "history"
    if (isOsdActive && osdMode !== "") return osdMode
    if (isNotificationActive && currentNotification) return "notification"
    if (isMediaOpen && hasActiveMedia) return "media"
    return "clock"
  }

  // Dynamic adaptive sizing
  readonly property real targetContentWidth: {
    switch (currentMode) {
      case "menu":
        if (centerIsland.dmenuMode !== "") {
          return centerIsland.dmenuWidth > 0 ? centerIsland.dmenuWidth : 600
        }
        if (centerIsland.filterText.length > 0 || centerIsland.activeMenu === "style.font" || centerIsland.activeMenu === "trigger.capture.screenrecord" || centerIsland.activeMenu === "apps") {
          return 500
        }
        return 340
      case "history": return 480
      case "volume":
      case "brightness": return 300
      case "media-action": return Math.min(360, Math.max(180, mediaActionRow.implicitWidth + 32))
      case "notification": return 400
      case "media": return 440
      case "date-clock": return Math.max(230, centerModulesWidth + 24)
      case "clock": default: return Math.max(90, (centerModulesWidth > 0 ? centerModulesWidth : 70) + 20)
    }
  }

  readonly property real targetContentHeight: {
    switch (currentMode) {
      case "menu":
        if (centerIsland.dmenuMode === "input") return 76
        if (centerIsland.dmenuMode !== "") {
          var maxH = centerIsland.dmenuMaxHeight > 0 ? centerIsland.dmenuMaxHeight : 520
          return Math.min(maxH, Math.max(150, 56 + menuDisplayModel.count * 44))
        }
        if (menuDisplayModel.count === 0) return 130
        var isScrollableList = centerIsland.activeMenu === "apps" || centerIsland.activeMenu === "style.font" || centerIsland.filterText.length > 0
        if (isScrollableList) {
          // Large app list, fonts, or search results: capped at 520px with smooth scrolling
          return Math.min(520, Math.max(150, 56 + menuDisplayModel.count * 44 + (centerIsland.searchDivider ? 22 : 0)))
        } else {
          // Pure menu/submenu items (root, system, style, setup, etc.): full height without scrolling
          return Math.min(850, Math.max(150, 56 + menuDisplayModel.count * 44 + (centerIsland.searchDivider ? 22 : 0)))
        }
      case "history": return 400
      case "volume":
      case "brightness":
      case "media-action": return 36
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

      // ------------------------------------------------------------- Mode 3: Media Player
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

      // ------------------------------------------------------------- Mode 5.5: Media Action Status Pill
      Item {
        id: mediaActionView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "media-action" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        RowLayout {
          id: mediaActionRow
          anchors.fill: parent
          spacing: Style.space(10)

          Text {
            text: centerIsland.mediaOsdIcon
            font.family: Style.font.family
            font.pixelSize: 16
            color: Color.accent || centerIsland.islandForeground
          }

          Text {
            Layout.fillWidth: true
            text: centerIsland.mediaOsdMessage || (centerIsland.hasActiveMedia ? ((centerIsland.activePlayer.trackTitle || "") + (centerIsland.activePlayer.trackArtist ? " • " + centerIsland.activePlayer.trackArtist : "")) : "")
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.weight: Font.DemiBold
            color: centerIsland.islandForeground
            elide: Text.ElideRight
            maximumLineCount: 1
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

      // ------------------------------------------------------------- Mode 7: Unified Omarchy Island Menu & Submenu View
      Item {
        id: menuView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 12
        clip: true
        visible: opacity > 0.01
        opacity: centerIsland.currentMode === "menu" ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: Style.space(8)

          // 1. Search & Breadcrumbs Navigation Header
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 8
            color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.08)
            border.color: menuSearchInput.activeFocus ? (Color.accent || Qt.rgba(1,1,1,0.35)) : Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.18)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 10
              spacing: Style.space(8)

              // Back Navigation Button (visible when in a submenu and no active filter query)
              Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 6
                color: backMouse.containsMouse ? Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.15) : "transparent"
                visible: centerIsland.activeMenu !== "root" && !centerIsland.filterText

                Text {
                  anchors.centerIn: parent
                  text: "‹"
                  font.family: Style.font.family
                  font.pixelSize: 18
                  font.weight: Font.Bold
                  color: Color.accent || centerIsland.islandForeground
                }

                MouseArea {
                  id: backMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: centerIsland.goBack()
                }
              }

              // Search Glyph Icon
              Text {
                text: "󰍉"
                font.family: Style.font.family
                font.pixelSize: 15
                color: centerIsland.islandForeground
                opacity: 0.75
                visible: centerIsland.activeMenu === "root" || centerIsland.filterText.length > 0
              }

              // Real Interactive Search & Command Input
              TextInput {
                id: menuSearchInput
                Layout.fillWidth: true
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: centerIsland.islandForeground
                selectionColor: Color.accent || Qt.rgba(0.2, 0.6, 1.0, 0.6)
                clip: true
                text: centerIsland.filterText
                onTextChanged: {
                  if (text !== centerIsland.filterText) {
                    centerIsland.setFilter(text)
                  }
                }

                Text {
                  anchors.fill: parent
                  text: centerIsland.dmenuMode
                    ? (centerIsland.dmenuPrompt + "…")
                    : (centerIsland.activeMenu !== "root"
                        ? ("Search in " + (MenuModel.item(centerIsland.items, centerIsland.activeMenu) ? (MenuModel.item(centerIsland.items, centerIsland.activeMenu).label) : centerIsland.activeMenu) + "…")
                        : "Search applications, toggles, settings & commands...")
                  font.family: menuSearchInput.font.family
                  font.pixelSize: menuSearchInput.font.pixelSize
                  color: centerIsland.islandForeground
                  opacity: 0.4
                  visible: !menuSearchInput.text && !menuSearchInput.inputMethodComposing
                }

                // Complete Keyboard Navigation & Vim (hjkl) Controls
                Keys.onPressed: function(event) {
                  if (centerIsland.deleteConfirmOpen) {
                    if (menuDeleteConfirm.handleKey(event)) event.accepted = true
                    return
                  }

                  if (event.key === Qt.Key_Delete) {
                    centerIsland.requestDeleteSelected()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Escape) {
                    if (centerIsland.filterText) {
                      centerIsland.setFilter("")
                      menuSearchInput.text = ""
                    } else if (centerIsland.activeMenu !== "root") {
                      centerIsland.goBack()
                    } else {
                      centerIsland.closeMenu()
                    }
                    event.accepted = true
                  } else if ((event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier)) || (event.key === Qt.Key_Left && !centerIsland.filterText)) {
                    centerIsland.goBack()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Backspace && !centerIsland.filterText) {
                    centerIsland.goBack()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                    centerIsland.select(-1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                    centerIsland.select(1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_PageUp) {
                    centerIsland.select(-5)
                    event.accepted = true
                  } else if (event.key === Qt.Key_PageDown) {
                    centerIsland.select(5)
                    event.accepted = true
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) || (event.key === Qt.Key_Right && !centerIsland.filterText)) {
                    if (menuDisplayModel.count > 0) {
                      centerIsland.activateIndex(centerIsland.selectedIndex)
                    } else if (centerIsland.dmenuMode === "input") {
                      centerIsland.applyDmenuSelection(menuSearchInput.text)
                    }
                    event.accepted = true
                  }
                }
              }

              // Breadcrumb Navigation Badge
              Rectangle {
                Layout.preferredHeight: 20
                Layout.preferredWidth: breadcrumbText.implicitWidth + 12
                radius: 5
                color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.12)
                visible: centerIsland.activeMenu !== "root" && !centerIsland.filterText

                Text {
                  id: breadcrumbText
                  anchors.centerIn: parent
                  text: MenuModel.pathFor(centerIsland.items, centerIsland.activeMenu)
                  font.family: Style.font.family
                  font.pixelSize: 10
                  font.weight: Font.Bold
                  color: Color.accent || centerIsland.islandForeground
                  opacity: 0.9
                  elide: Text.ElideRight
                }
              }
            }
          }

          // 2. Menu Items / Search Results List
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
              id: menuListView
              anchors.fill: parent
              model: menuDisplayModel
              clip: true
              spacing: 2
              boundsBehavior: Flickable.StopAtBounds
              highlightFollowsCurrentItem: true
              highlightMoveDuration: 0
              highlightResizeDuration: 0

              section.property: "section"
              section.criteria: ViewSection.FullString
              section.delegate: Item {
                required property string section
                width: ListView.view.width
                height: section === "drilldown" ? 22 : 0
                visible: section === "drilldown"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 6
                  anchors.rightMargin: 6
                  spacing: 6

                  Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.15)
                  }

                  Text {
                    text: "Submenu Results"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Color.accent || centerIsland.islandForeground
                    opacity: 0.7
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.15)
                  }
                }
              }

              delegate: Rectangle {
                id: menuItemRow
                width: menuListView.width
                height: 44
                radius: 6
                color: isSelected ? Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.16) : (itemMouse.containsMouse ? Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.07) : "transparent")

                readonly property bool isSelected: centerIsland.cursorActive && centerIsland.selectedIndex === index
                readonly property bool isMenuOrLink: model.kind === "menu" || model.kind === "link"
                readonly property bool isApp: model.kind === "app"

                // Active Selection Left Bar Indicator
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.margins: 4
                  width: 3
                  radius: 2
                  color: Color.accent || Qt.rgba(0.2, 0.8, 0.7, 1.0)
                  visible: menuItemRow.isSelected
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 12
                  anchors.rightMargin: 10
                  spacing: Style.space(10)

                  // Icon Box: App Icon or Font/Glyph Icon
                  Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26

                    Image {
                      anchors.fill: parent
                      source: (menuItemRow.isApp && root && root.shell && root.shell.appLibrary) ? root.shell.appLibrary.iconSource(model.appIcon) : ""
                      fillMode: Image.PreserveAspectFit
                      visible: menuItemRow.isApp && source !== ""
                    }

                    Rectangle {
                      anchors.fill: parent
                      radius: 6
                      color: Qt.rgba(centerIsland.islandThemeForeground.r, centerIsland.islandThemeForeground.g, centerIsland.islandThemeForeground.b, 0.1)
                      visible: !menuItemRow.isApp || !model.appIcon

                      Text {
                        anchors.centerIn: parent
                        text: model.icon ? model.icon : (menuItemRow.isMenuOrLink ? "󰅂" : "󰒓")
                        font.family: model.iconFont ? model.iconFont : Style.font.family
                        font.pixelSize: 15
                        color: menuItemRow.isSelected ? (Color.accent || centerIsland.islandForeground) : centerIsland.islandForeground
                      }
                    }
                  }

                  // Label and Subtitle / Breadcrumb Path
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                      Layout.fillWidth: true
                      text: model.label || ""
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.weight: menuItemRow.isSelected ? Font.Bold : Font.Medium
                      color: centerIsland.islandForeground
                      elide: Text.ElideRight
                    }

                    Text {
                      Layout.fillWidth: true
                      text: model.detail || ""
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: centerIsland.islandForeground
                      opacity: 0.6
                      elide: Text.ElideRight
                      visible: text !== ""
                    }
                  }

                  // Right Chevron for Submenus
                  Text {
                    text: "›"
                    font.family: Style.font.family
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: centerIsland.islandForeground
                    opacity: menuItemRow.isSelected ? 0.9 : 0.4
                    visible: menuItemRow.isMenuOrLink
                  }
                }

                MouseArea {
                  id: itemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: {
                    centerIsland.cursorActive = true
                    centerIsland.selectedIndex = index
                  }
                  onClicked: {
                    centerIsland.cursorActive = true
                    centerIsland.selectedIndex = index
                    centerIsland.activateIndex(index)
                  }
                }
              }
            }

            // Top Fade Scrim
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: 14
              visible: menuListView.contentY > 0
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.9) }
                GradientStop { position: 1.0; color: "transparent" }
              }
            }

            // Bottom Fade Scrim
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: 14
              visible: (menuListView.contentY + menuListView.height) < menuListView.contentHeight
              gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.9) }
              }
            }

            // Empty Placeholder
            ColumnLayout {
              anchors.centerIn: parent
              visible: menuDisplayModel.count === 0 && centerIsland.dmenuMode !== "input"
              spacing: 6

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰍉"
                font.family: Style.font.family
                font.pixelSize: 28
                color: centerIsland.islandForeground
                opacity: 0.3
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: centerIsland.filterText ? ("No matches for \"" + centerIsland.filterText + "\"") : "Empty Menu"
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                color: centerIsland.islandForeground
                opacity: 0.6
              }
            }
          }
        }

        // Delete App Confirmation Dialog
        ConfirmDialog {
          id: menuDeleteConfirm
          anchors.fill: parent
          opened: centerIsland.deleteConfirmOpen
          z: 30
          message: "Do you want to uninstall " + ((centerIsland.deleteTarget && centerIsland.deleteTarget.label) || "this app") + "?"
          confirmText: "Uninstall"
          background: Color.bar.background
          foreground: centerIsland.islandForeground
          onCanceled: centerIsland.cancelDelete()
          onConfirmed: centerIsland.confirmDelete()
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
    visible: !centerIsland.isMenuOpen
    z: -1

    onWheel: function(wheel) {
      if (centerIsland.currentMode === "media") {
        if (wheel.angleDelta.y > 0) {
          centerIsland.isMediaOpen = false
          return
        }
      }

      if (centerIsland.currentMode === "clock" && wheel.angleDelta.y < 0 && centerIsland.hasActiveMedia) {
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
