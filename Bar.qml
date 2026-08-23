import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "BarModel.js" as BarModel

Item {
  id: root

  // The omarchy-shell host injects omarchyPath from OMARCHY_PATH.
  property string omarchyPath: ""
  // Injected by the host shell so bar slots can resolve enabled widgets.
  property var barWidgetRegistry: null
  // Injected by the host shell every time shell.json is reloaded. Holds the
  // `bar:` subtree: position, centerAnchor, layout. The host owns file IO;
  // the bar just renders whatever it's handed. The bar font follows the
  // OS-level fontconfig monospace binding — it is not stored in shell.json.
  property var barConfig: null
  // Injected by the host shell. Used for shell-wide actions such as opening
  // settings and persisting inline widget state.
  property var shell: null
  // Manifest for the active bar option. Present for custom bars and useful for
  // diagnostics; the built-in bar does not otherwise need it.
  property var manifest: null
  // Mirrors the on-disk `bar-off` flag so the user can hide the bar without
  // killing the entire shell. Hidden panels stay mapped but park off-screen
  property bool barHidden: false
  property bool manualReveal: false
  property bool isSearchOpen: false
  property bool isMenuOpen: false
  property var centerIslandRef: null
  property real leftIslandX: 0
  property string leftIslandAttach: "left" // "left" | "none"

  property real rightIslandX: -1 // -1 means default right
  property string rightIslandAttach: "right" // "right" | "none"

  property real centerIslandOffset: 0
  property string centerIslandAttach: "none" // "none" | "left" | "right"

  function applyStylePreset(preset) {
    if (preset === "edge") {
      root.leftIslandAttach = "left"
      root.leftIslandX = 0
      root.rightIslandAttach = "right"
      root.rightIslandX = -1
      root.centerIslandAttach = "none"
      root.centerIslandOffset = 0
    } else if (preset === "island") {
      root.leftIslandAttach = "none"
      root.leftIslandX = 12
      root.rightIslandAttach = "none"
      root.rightIslandX = -1
      root.centerIslandAttach = "none"
      root.centerIslandOffset = 0
    }
    root.saveIslandLayout()
  }

  function toggleStylePreset() {
    if (root.leftIslandAttach === "left" && root.rightIslandAttach === "right") {
      root.applyStylePreset("island")
    } else {
      root.applyStylePreset("edge")
    }
  }

  property bool isDraggingIsland: false
  property string activeSuperDragRegion: ""
  property real superDragStartWindowX: 0
  property real superDragStartIslandX: 0

  function startIslandDrag(slot, mouse) {
    var region = slot.region || "center"
    root.activeSuperDragRegion = region
    var pt = slot.mapToItem(null, mouse.x, mouse.y)
    root.superDragStartWindowX = pt.x
    var win = root.targetWindow(slot.activeItem) || root.targetWindow(slot) || root.barWindow
    var screenW = win ? win.width : 1920

    if (region === "left") {
      root.superDragStartIslandX = root.leftIslandAttach === "left" ? 0 : root.leftIslandX
    } else if (region === "right") {
      root.superDragStartIslandX = root.rightIslandAttach === "right" ? (screenW - 100) : (root.rightIslandX < 0 ? (screenW - 100) : root.rightIslandX)
    } else {
      root.superDragStartIslandX = root.centerIslandOffset
    }
    root.isDraggingIsland = true
  }

  function updateIslandDrag(mouseWindowX, screenWidth, leftW, centerW, rightW) {
    if (!root.isDraggingIsland || !root.activeSuperDragRegion) return
    var delta = mouseWindowX - root.superDragStartWindowX
    var region = root.activeSuperDragRegion

    if (region === "left") {
      var targetX = root.superDragStartIslandX + delta
      if (targetX <= 8) {
        root.leftIslandAttach = "left"
        root.leftIslandX = 0
      } else if (targetX >= screenWidth - leftW - 16) {
        root.leftIslandAttach = "right"
        root.leftIslandX = screenWidth - leftW
      } else {
        root.leftIslandAttach = "none"
        root.leftIslandX = Math.max(0, Math.min(screenWidth - leftW, targetX))
      }
    } else if (region === "right") {
      var targetX = root.superDragStartIslandX + delta
      if (targetX >= screenWidth - rightW - 16) {
        root.rightIslandAttach = "right"
        root.rightIslandX = screenWidth - rightW
      } else if (targetX <= 8) {
        root.rightIslandAttach = "left"
        root.rightIslandX = 0
      } else {
        root.rightIslandAttach = "none"
        root.rightIslandX = Math.max(0, Math.min(screenWidth - rightW, targetX))
      }
    } else {
      var targetOffset = root.superDragStartIslandX + delta
      var base = Math.round((screenWidth - centerW) / 2)
      var targetX = base + targetOffset
      if (targetX <= 8) {
        root.centerIslandAttach = "left"
        root.centerIslandOffset = -base
      } else if (targetX >= screenWidth - centerW - 16) {
        root.centerIslandAttach = "right"
        root.centerIslandOffset = base
      } else {
        root.centerIslandAttach = "none"
        root.centerIslandOffset = Math.max(-base, Math.min(base, targetOffset))
      }
    }
  }

  function finishIslandDrag(screenWidth, leftW, centerW, rightW) {
    if (!root.isDraggingIsland) return
    root.isDraggingIsland = false
    root.activeSuperDragRegion = ""
    root.resolveIslandCollisions(screenWidth, leftW, centerW, rightW)
    root.saveIslandLayout()
  }

  function resolveIslandCollisions(screenWidth, leftW, centerW, rightW) {
    var lX = root.leftIslandAttach === "left" ? 0 : Math.max(0, Math.min(screenWidth - leftW, root.leftIslandX))
    var rX = root.rightIslandAttach === "right" ? Math.max(0, screenWidth - rightW) : Math.max(0, Math.min(screenWidth - rightW, root.rightIslandX < 0 ? screenWidth - rightW : root.rightIslandX))
    var cX = Math.round((screenWidth - centerW) / 2 + root.centerIslandOffset)
    cX = Math.max(0, Math.min(screenWidth - centerW, cX))

    if (leftW > 0 && lX + leftW > cX) {
      if (root.leftIslandAttach === "left") {
        cX = Math.min(screenWidth - centerW, lX + leftW + 8)
      } else {
        lX = Math.max(0, cX - leftW - 8)
      }
    }

    if (rightW > 0 && cX + centerW > rX) {
      if (root.rightIslandAttach === "right") {
        cX = Math.max(lX + leftW + 8, rX - centerW - 8)
      } else {
        rX = Math.min(screenWidth - rightW, cX + centerW + 8)
      }
    }

    root.leftIslandX = lX
    root.rightIslandX = rX
    root.centerIslandOffset = cX - Math.round((screenWidth - centerW) / 2)
  }

  FileView {
    id: islandConfigFile
    path: root.stateHome + "/omarchy/notchbar-layout.json"
    onLoaded: {
      try {
        var raw = islandConfigFile.text()
        if (!raw) return
        var data = JSON.parse(raw)
        if (data.left) {
          root.leftIslandX = Number(data.left.x || 0)
          root.leftIslandAttach = String(data.left.attach || "left")
        }
        if (data.right) {
          root.rightIslandX = Number(data.right.x !== undefined ? data.right.x : -1)
          root.rightIslandAttach = String(data.right.attach || "right")
        }
        if (data.center) {
          root.centerIslandOffset = Number(data.center.offset || 0)
          root.centerIslandAttach = String(data.center.attach || "none")
        }
      } catch(e) {}
    }
  }

  function saveIslandLayout() {
    var data = {
      left: { x: root.leftIslandX, attach: root.leftIslandAttach },
      right: { x: root.rightIslandX, attach: root.rightIslandAttach },
      center: { offset: root.centerIslandOffset, attach: root.centerIslandAttach }
    }
    islandConfigFile.setText(JSON.stringify(data, null, 2))
  }

  function openMenu(route) {
    root.isMenuOpen = true
    root.isSearchOpen = false
    root.isHistoryOpen = false
    if (root.centerIslandRef) {
      root.centerIslandRef.openRoute(route || "root")
    }
  }

  function closeMenu() {
    root.isMenuOpen = false
    root.isSearchOpen = false
    if (root.centerIslandRef) {
      root.centerIslandRef.closeMenu()
    }
  }

  function toggleMenu(route) {
    if (root.centerIslandRef) {
      root.centerIslandRef.toggleMenu(route || "root")
    } else {
      if (root.isMenuOpen) {
        root.closeMenu()
      } else {
        root.openMenu(route || "root")
      }
    }
  }



  function popoutBelongsToRegion(region) {
    if (!activePopout) return false
    var entries = layoutEntries(region)
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      if (activePopout.moduleName === id) return true
    }
    return false
  }

  IpcHandler {
    target: "island"

    function toggle(): string {
      root.manualReveal = !root.manualReveal
      return root.manualReveal ? "revealed" : "hidden"
    }

    function show(): string {
      root.manualReveal = true
      return "revealed"
    }

    function hide(): string {
      root.manualReveal = false
      root.closeMenu()
      return "hidden"
    }

    function search(): string {
      root.openMenu("root")
      return "search-opened"
    }

    function menu(route: string): string {
      root.openMenu(route || "root")
      return "menu-opened"
    }

    function style(preset: string): string {
      if (preset === "edge" || preset === "island") {
        root.applyStylePreset(preset)
      } else {
        root.toggleStylePreset()
      }
      return root.leftIslandAttach === "left" && root.rightIslandAttach === "right" ? "edge" : "island"
    }
  }

  IpcHandler {
    target: "gustavo.bar"

    function toggle(): string {
      root.manualReveal = !root.manualReveal
      return root.manualReveal ? "revealed" : "hidden"
    }

    function show(): string {
      root.manualReveal = true
      return "revealed"
    }

    function hide(): string {
      root.manualReveal = false
      root.closeMenu()
      return "hidden"
    }

    function search(): string {
      root.openMenu("root")
      return "search-opened"
    }

    function menu(route: string): string {
      root.openMenu(route || "root")
      return "menu-opened"
    }

    function style(preset: string): string {
      if (preset === "edge" || preset === "island") {
        root.applyStylePreset(preset)
      } else {
        root.toggleStylePreset()
      }
      return root.leftIslandAttach === "left" && root.rightIslandAttach === "right" ? "edge" : "island"
    }
  }

  IpcHandler {
    target: "omarchy.menu"

    function toggle(payloadJson: string): string {
      var payload = ({})
      try { payload = JSON.parse(payloadJson || "{}") } catch(e) {}
      var route = payload.menu || payload.initialMenu || "root"
      if (payload.mode === "select" || payload.mode === "input") {
        if (root.centerIslandRef) root.centerIslandRef.openDmenu(payload)
      } else {
        root.toggleMenu(route)
      }
      return "ok"
    }

    function summon(payloadJson: string): string {
      var payload = ({})
      try { payload = JSON.parse(payloadJson || "{}") } catch(e) {}
      var route = payload.menu || payload.initialMenu || "root"
      if (payload.mode === "select" || payload.mode === "input") {
        if (root.centerIslandRef) root.centerIslandRef.openDmenu(payload)
      } else {
        root.openMenu(route)
      }
      return "ok"
    }

    function close(): string {
      root.closeMenu()
      return "ok"
    }

    function refresh(): string {
      if (root.centerIslandRef) root.centerIslandRef.refreshMenu()
      return "ok"
    }

    function ping(): string {
      return "ok"
    }
  }
  property string home: Quickshell.env("HOME")
  property string stateHome: home + "/.local/state"
  property string omarchyConfigDir: home + "/.config/omarchy"
  property var fallbackBarConfig: ({
    position: "top",
    transparent: false,
    centerAnchor: "omarchy.clock",
    layout: { left: [], center: [], right: [] }
  })
  property var layoutConfig: fallbackBarConfig.layout
  property string centerAnchor: ""
  property bool requestedTransparent: false
  property bool useTransparentForeground: false
  property bool transparent: false
  property bool centerSectionHovered: false
  // One bar surface exists per monitor and each reports into this count, so a
  // pointer crossing from one monitor's bar to another's stays counted however
  // the enter and leave interleave. A single shared bool would be left false by
  // whichever event landed last.
  property int barHoverCount: 0
  // True while the pointer is over any bar, widgets included.
  readonly property bool barHovered: barHoverCount > 0
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false
  property int barConfigSerial: 0
  property string position: "top"
  // Resolves through fontconfig at paint time (Style.font.family defaults
  // to "monospace"), so changing the system font (via `omarchy-font-set`)
  // updates the bar without a reload.
  property string fontFamily: Style.font.family
  // Bound to the central Color singleton so the bar tracks shell.toml's
  // [bar] section. Property names kept for the rest of this file's bindings.
  property color themeForeground: Color.bar.text
  property color themeContrastForeground: Color.background
  property color transparentForeground: Color.bar.text
  property color foreground: themeForeground
  property color barForeground: useTransparentForeground ? transparentForeground : themeForeground
  property bool foregroundAnimationEnabled: true
  property color background: Color.bar.background
  property color urgent: Color.bar.active

  Behavior on barForeground { enabled: root.foregroundAnimationEnabled; ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on background { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on urgent { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0
  property var activePopout: null
  property var barDragSource: null
  property var barDragTarget: null
  property var barDragTargetGeometry: null
  property bool barDragAfter: false
  property var barDragWindow: null
  property var barDragScreen: null
  property url barDragImageUrl: ""
  property real barDragSceneX: 0
  property real barDragSceneY: 0
  property real barDragScreenX: 0
  property real barDragScreenY: 0
  property real barDragOffsetX: 0
  property real barDragOffsetY: 0
  property bool barMoveActive: false
  property string barMoveCandidate: ""
  property var barMoveWindow: null
  property var barMoveScreen: null
  property var clickTargets: []
  property var moduleSlots: []

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    var next = clickTargets.filter(function(item) { return item !== target })
    clickTargets = next
  }

  function registerModuleSlot(slot) {
    if (!slot || moduleSlots.indexOf(slot) !== -1) return
    var next = moduleSlots.slice()
    next.push(slot)
    moduleSlots = next
  }

  function unregisterModuleSlot(slot) {
    var next = moduleSlots.filter(function(item) { return item !== slot })
    moduleSlots = next
  }

  function debugBarGeometry() {
    var out = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      var point = { x: slot.x, y: slot.y }
      try {
        point = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }
      out.push({
        id: slot.moduleName,
        section: slot.region,
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: Math.round(slot.width),
        height: Math.round(slot.height),
        visible: slot.visible === true && slot.width > 0 && slot.height > 0,
        itemVisible: slot.activeItem.visible === true,
        itemWidth: Math.round(slot.activeItem.implicitWidth || 0),
        itemHeight: Math.round(slot.activeItem.implicitHeight || 0)
      })
    }
    return out
  }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  function slotWindow(slot) {
    if (!slot) return null
    return targetWindow(slot.activeItem) || targetWindow(slot)
  }

  function sameWindow(left, right) {
    if (!left || !right) return false
    if (left === right) return true
    return !!left.screen && !!right.screen && !!left.screen.name && !!right.screen.name && left.screen.name === right.screen.name
  }

  function targetTooltipHovered(target) {
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  function clearTooltip() {
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function clearBarDrag() {
    barDragSource = null
    barDragWindow = null
    barDragScreen = null
    barDragImageUrl = ""
    barDragTarget = null
    barDragTargetGeometry = null
    barDragAfter = false
    barDragSceneX = 0
    barDragSceneY = 0
    barDragScreenX = 0
    barDragScreenY = 0
    barDragOffsetX = 0
    barDragOffsetY = 0
  }

  function windowScreenPoint(scenePoint, window) {
    var x = scenePoint ? scenePoint.x : 0
    var y = scenePoint ? scenePoint.y : 0
    if (!window || !window.screen) return { x: x, y: y }

    if (root.position === "bottom")
      y += Math.max(0, window.screen.height - window.height)
    else if (root.position === "right")
      x += Math.max(0, window.screen.width - window.width)

    return { x: x, y: y }
  }

  function barDragScreenPoint(scenePoint) {
    return windowScreenPoint(scenePoint, barDragWindow)
  }

  function dropMarkerRect(slot, after) {
    if (!slot) return null

    try {
      var slotPoint = slot.mapToItem(null, 0, 0)
      var screenPoint = barDragScreenPoint(slotPoint)
      var thickness = Style.spacing.xs
      if (vertical) {
        return {
          x: screenPoint.x,
          y: screenPoint.y + (after ? slot.height : 0) - thickness / 2,
          width: slot.width,
          height: thickness
        }
      }

      return {
        x: screenPoint.x + (after ? slot.width : 0) - thickness / 2,
        y: screenPoint.y,
        width: thickness,
        height: slot.height
      }
    } catch (e) {
      return null
    }
  }

  // Split the screen along its diagonals (in normalized space, so widescreens
  // don't bias toward left/right): whichever triangle holds the cursor names
  // the candidate edge.
  function nearestScreenEdge(point, screen) {
    var nx = screen.width > 0 ? Util.clamp(point.x / screen.width, 0, 1) : 0.5
    var ny = screen.height > 0 ? Util.clamp(point.y / screen.height, 0, 1) : 0.5

    var edge = "top"
    var best = ny
    if (1 - ny < best) { edge = "bottom"; best = 1 - ny }
    if (nx < best) { edge = "left"; best = nx }
    if (1 - nx < best) { edge = "right"; best = 1 - nx }
    return edge
  }

  function beginBarMove(window) {
    barMoveWindow = window
    barMoveScreen = window ? window.screen : null
    barMoveCandidate = position
    barMoveActive = true
  }

  function updateBarMove(screenPoint) {
    if (!barMoveActive || !barMoveScreen) return
    barMoveCandidate = nearestScreenEdge(screenPoint, barMoveScreen)
  }

  function clearBarMove() {
    barMoveActive = false
    barMoveCandidate = ""
    barMoveWindow = null
    barMoveScreen = null
  }

  function finishBarMove() {
    var edge = barMoveCandidate
    if (!barMoveActive || !edge || edge === position) {
      clearBarMove()
      return
    }

    clearBarMove()
    setBarPosition(edge)
  }

  function setBarPosition(value) {
    var next = normalizePosition(value)
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.position = next
      })
    } else {
      root.position = next
    }
  }

  function captureBarDragGhost(slot) {
    var item = slot && slot.activeItem ? slot.activeItem : null
    barDragImageUrl = ""
    if (!item || typeof item.grabToImage !== "function") return

    var grabWidth = Math.max(1, Math.ceil(item.width || item.implicitWidth || slot.width || 1))
    var grabHeight = Math.max(1, Math.ceil(item.height || item.implicitHeight || slot.height || 1))
    item.grabToImage(function(result) {
      if (root.barDragSource !== slot || !result || !result.url) return
      root.barDragImageUrl = result.url
    }, Qt.size(grabWidth, grabHeight))
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  property int islandHeight: 30
  property int islandTopMargin: 4
  property int islandRadius: 10
  property int islandAutoHideDelayMs: 1000
  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: islandHeight

  function normalizePosition(value) {
    return BarModel.normalizePosition(value)
  }

  // Apply tray-pinning on top of the shared layout normalization so the
  // bar host and scriptable config helpers can't drift on entry shape.
  function normalizeLayout(layout) {
    var normalized = Util.normalizeLayout(Util.isPlainObject(layout) ? layout : fallbackBarConfig.layout)
    return {
      left:   pinTrayToInner(normalized.left,   "left"),
      center: pinTrayToInner(normalized.center, "center"),
      right:  pinTrayToInner(normalized.right,  "right")
    }
  }

  // The tray drawer reveals inward (away from the bar edge). Place it at the
  // section's inner edge: start of the right section, end of the left/center
  // sections. The drawer's reserved space then sits next to the bar center,
  // not stranded mid-section.
  function pinTrayToInner(entries, section) {
    return BarModel.pinTrayToInner(entries, section)
  }

  function applyBarConfig() {
    var config = Util.isPlainObject(barConfig) ? barConfig : fallbackBarConfig

    position = normalizePosition(config.position)
    setRequestedTransparency(config.transparent === true)
    centerAnchor = Util.canonicalWidgetId(config.centerAnchor || "")

    // layoutEntries feeds plain JS arrays to the module Repeaters, and QML
    // cannot diff those: reassigning layoutConfig rebuilds every widget on
    // every monitor. When a shell.json write only changed inline widget
    // settings, patch the live layout and running widgets in place instead.
    var next = normalizeLayout(config.layout)
    var delta = BarModel.inlineSettingsDelta(layoutConfig, next)
    if (delta) {
      applySettingsDelta(delta)
      return
    }
    layoutConfig = next
    barConfigSerial++
  }

  function applySettingsDelta(delta) {
    for (var i = 0; i < delta.length; i++) {
      var change = delta[i]
      layoutConfig[change.region][change.index] = change.entry
      var settings = entrySettings(change.entry)
      for (var s = 0; s < moduleSlots.length; s++) {
        var slot = moduleSlots[s]
        if (!slot || slot.region !== change.region || slot.moduleName !== entryId(change.entry)) continue
        var item = slot.activeItem
        if (item && "settings" in item) item.settings = settings
      }
    }
  }

  onBarConfigChanged: applyBarConfig()

  function layoutEntries(region) {
    var serial = barConfigSerial
    var entries = layoutConfig ? layoutConfig[region] : null
    return Array.isArray(entries) ? entries : []
  }

  // Tab order for the panels in one bar region. Scoped to a single bar surface
  // so tabbing walks the bar the open panel belongs to instead of hopping the
  // panel to another monitor's copy of the same widget.
  function panelNavigationSlots(region, window) {
    var entries = layoutEntries(region)
    var slots = []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      for (var j = 0; j < moduleSlots.length; j++) {
        var slot = moduleSlots[j]
        if (!slot || slot.region !== region || slot.moduleName !== id) continue
        if (window && !sameWindow(slotWindow(slot), window)) continue
        var item = slot.activeItem
        if (!item || item.visible !== true || slot.visible !== true || slot.width <= 0 || slot.height <= 0) continue
        if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
        slots.push(slot)
        break
      }
    }
    return slots
  }

  // The Nth panel in a bar region, counted the way the bar reads: layout order,
  // and only the panels actually on screen. A widget with no panel (the tray)
  // and one that is hiding itself are passed over, so the number lands on the
  // Nth panel icon the user can see rather than the Nth layout entry.
  // One-based, because it exists for hotkeys; anything else lands on no slot.
  //
  // Counting any bar surface is enough: every monitor lays its bar out from the
  // one layout, and summoning the id routes through pickPanelSlot, which opens
  // the focused monitor's copy whichever surface was counted.
  function panelWidgetIdAt(region, index) {
    var slots = panelNavigationSlots(String(region || ""), null)
    var slot = slots[Math.round(Number(index)) - 1]
    return slot ? String(slot.moduleName || "") : ""
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false

    var currentSlot = null
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.activeItem === owner) {
        currentSlot = slot
        break
      }
    }
    if (!currentSlot) return false

    var slots = panelNavigationSlots(currentSlot.region, slotWindow(currentSlot))
    if (slots.length < 2) return false

    var currentIndex = -1
    for (var j = 0; j < slots.length; j++) {
      if (slots[j] === currentSlot) {
        currentIndex = j
        break
      }
    }
    if (currentIndex < 0) return false

    var step = direction < 0 ? -1 : 1
    var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
    if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false

    nextSlot.activeItem.open()
    return true
  }

  // Every live instance of a widget id. A bar surface is built per monitor, so
  // a widget that appears once in the layout is still live once per screen.
  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var items = []
    if (!id) return items
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem || slot.moduleName !== id) continue
      items.push(slot.activeItem)
    }
    return items
  }

  function slotScreenName(slot) {
    var window = slotWindow(slot)
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // The output Hyprland has focused, which is where a keyboard-summoned panel
  // belongs. Empty until Hyprland reports one, which leaves panel routing on
  // its per-monitor fallback rather than guessing at an output.
  function focusedScreenName() {
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }

  // Resolve the live bar-widget instance for a plugin id (e.g. "omarchy.bluetooth").
  // Only widgets that expose popup open/close methods count; plain indicators
  // (clock, workspaces, tray) return null. Used by shell.summon/toggle so
  // panel hotkeys route through the bar instead of a per-target IPC handler
  // that only reaches whichever per-monitor instance claimed the target.
  function findPanelWidget(pluginId) {
    var id = String(pluginId || "")
    if (!id) return null
    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      if (slot.moduleName !== id) continue
      var item = slot.activeItem
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      candidates.push({ slot: slot, screenName: slotScreenName(slot), opened: item.opened === true })
    }
    // One copy per monitor, plus a zero-size placeholder for anchored center
    // modules. See BarModel.pickPanelSlot for which one a hotkey acts on.
    var chosen = BarModel.pickPanelSlot(candidates, focusedScreenName())
    return chosen ? chosen.activeItem : null
  }

  function summonBarWidget(pluginId) {
    if (pluginId === "omarchy.menu" || pluginId === "gustavo.notchbar" || pluginId === "gustavo.bar") {
      root.openMenu("root")
      return true
    }
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.open !== "function") return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    if (pluginId === "omarchy.menu" || pluginId === "gustavo.notchbar" || pluginId === "gustavo.bar") {
      root.closeMenu()
      return true
    }
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.close !== "function") return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    if (pluginId === "omarchy.menu" || pluginId === "gustavo.notchbar" || pluginId === "gustavo.bar") {
      return root.isMenuOpen
    }
    var item = findPanelWidget(pluginId)
    return !!item && item.opened === true
  }

  function entrySettings(entry) {
    return BarModel.entrySettings(entry)
  }

  function entryId(entry) {
    return BarModel.entryId(entry)
  }

  function moduleString(entry, key, fallback) {
    return BarModel.moduleString(entry, key, fallback)
  }

  function entryIndex(entries, name) {
    return BarModel.entryIndex(entries, name)
  }

  function entriesBefore(entries, name) {
    return BarModel.entriesBefore(entries, name)
  }

  function entriesAfter(entries, name) {
    return BarModel.entriesAfter(entries, name)
  }

  function canonicalWidgetId(name) {
    return Util.canonicalWidgetId(name)
  }

  function expandPath(path) {
    return BarModel.expandPath(path, home)
  }

  function customModuleSafeName(name) {
    return BarModel.customModuleSafeName(name)
  }

  function customModuleType(entry) {
    return BarModel.customModuleType(entry)
  }

  function customModuleSource(entry) {
    var source = BarModel.customModulePath(entry, home, omarchyConfigDir)
    return source ? Util.fileUrl(source) : ""
  }

  property var currentNotification: null
  property bool isHistoryOpen: false

  function toggleHistory() {
    isHistoryOpen = !isHistoryOpen
    dismissNotification()
    if (isHistoryOpen) isSearchOpen = false
  }

  function openHistory() {
    isHistoryOpen = true
    isSearchOpen = false
    dismissNotification()
  }

  function closeHistory() {
    isHistoryOpen = false
    dismissNotification()
  }

  readonly property var notifService: shell ? shell.serviceFor("omarchy.notifications") : null
  readonly property var notifPopupModel: notifService ? notifService.popupModel : null

  IpcHandler {
    target: "gustavo.bar"

    function toggleHistory(): string {
      root.toggleHistory()
      return "ok"
    }

    function openHistory(): string {
      root.openHistory()
      return "ok"
    }

    function closeHistory(): string {
      root.closeHistory()
      return "ok"
    }
  }

  Connections {
    target: root.notifService
    ignoreUnknownSignals: true
    function onHistoryReadQueuedChanged() {
      if (root.notifService && root.notifService.historyReadQueued) {
        root.toggleHistory()
      }
    }
  }

  readonly property var defaultMenuLoader: (shell && shell.panelLoaders) ? shell.panelLoaders["omarchy.menu"] : null
  readonly property var defaultMenuItem: defaultMenuLoader ? defaultMenuLoader.item : null

  Connections {
    target: root.defaultMenuItem
    ignoreUnknownSignals: true
    function onOpenedChanged() {
      if (root.defaultMenuItem && root.defaultMenuItem.opened) {
        var item = root.defaultMenuItem
        item.opened = false
        if (item.mode === "select" || item.mode === "input") {
          var payload = {
            mode: item.mode,
            prompt: item.dmenuPrompt,
            options: item.dmenuOptions,
            selectionFile: item.selectionFile,
            doneFile: item.doneFile,
            width: item.dmenuWidth,
            maxHeight: item.dmenuMaxHeight
          }
          if (root.centerIslandRef) {
            root.centerIslandRef.openDmenu(payload)
          }
        } else {
          var requestedRoute = item.pendingInitialMenu || item.activeMenu || "root"
          root.toggleMenu(requestedRoute)
        }
      }
    }
  }

  readonly property var osdLoader: (shell && shell.panelLoaders) ? shell.panelLoaders["omarchy.osd"] : null
  readonly property var osdItem: osdLoader ? osdLoader.item : null



  Connections {
    target: root.osdItem
    ignoreUnknownSignals: true
    function onOpenedChanged() {
      if (root.osdItem && root.osdItem.opened) {
        var key = root.osdItem.iconKey || ""
        var msg = root.osdItem.message || ""
        var val = root.osdItem.value
        var maxV = root.osdItem.maxValue || 100
        var prog = root.osdItem.hasProgress
        var med = root.osdItem.mediaOsd
        var ic = root.osdItem.icon || ""

        // Instantly suppress default center popup so it never renders
        root.osdItem.opened = false

        if (root.centerIslandRef && typeof root.centerIslandRef.handleExternalOsd === "function") {
          root.centerIslandRef.handleExternalOsd({
            iconKey: key,
            message: msg,
            value: val,
            maxValue: maxV,
            hasProgress: prog,
            mediaOsd: med,
            icon: ic
          })
        }
      }
    }
  }

  Connections {
    target: root.notifPopupModel
    ignoreUnknownSignals: true
    function onRowsInserted(parent, first, last) {
      if (!root.isHistoryOpen) {
        for (var i = first; i <= last; i++) {
          var item = root.notifPopupModel.get(i)
          if (item && item.originalId > 0 && root.notifService && root.notifService.liveRefs && root.notifService.liveRefs[item.originalId]) {
            root.showNotificationData(item)
          }
        }
      }
      // Immediately clear popupModel so top-right window never renders, while archiving the files into history
      if (root.notifService && typeof root.notifService.clearPopups === "function") {
        root.notifService.clearPopups()
      } else {
        root.notifPopupModel.clear()
      }
    }
  }

  function showNotificationData(data) {
    if (!data) return
    root.currentNotification = {
      id: data.id || 0,
      originalId: data.originalId || 0,
      app: data.app || data.appName || "",
      appName: data.app || data.appName || "",
      appIcon: data.appIcon || "",
      summary: data.summary || "",
      body: data.body || "",
      image: data.image || "",
      glyph: data.glyph || "",
      exec: data.exec || "",
      expireTimeout: data.expireTimeout || 0
    }

    var expireMs = Number(data.expireTimeout || 0)
    if (!isFinite(expireMs) || expireMs <= 0) expireMs = 5000
    else expireMs = Math.min(30000, Math.max(3000, expireMs))
    rootNotificationTimer.interval = expireMs
    rootNotificationTimer.restart()
  }

  function resolveNotificationIcon(notif) {
    if (!notif) return ""
    function formatUrl(pathOrUrl) {
      var s = String(pathOrUrl || "")
      if (!s) return ""
      if (s.indexOf("file://") === 0 || s.indexOf("image://") === 0) return s
      if (s.charAt(0) === "/") return Util.fileUrl(s)
      return s
    }

    var img = String(notif.image || "")
    if (img.length > 0) return formatUrl(img)

    var appIcon = String(notif.appIcon || "")
    if (appIcon.length > 0) {
      if (appIcon.indexOf("file://") === 0 || appIcon.indexOf("image://") === 0 || appIcon.charAt(0) === "/") {
        return formatUrl(appIcon)
      }
      var themed = Quickshell.iconPath(appIcon, true)
      if (themed && themed.length > 0) return formatUrl(themed)
    }

    var appName = String(notif.appName || notif.app || "")
    if (appName.length > 0 && appName !== "notify-send" && appName !== "omarchy-action") {
      var appThemed = Quickshell.iconPath(appName.toLowerCase(), true)
      if (appThemed && appThemed.length > 0) return formatUrl(appThemed)
      if (root.shell && root.shell.appLibrary) {
        var libIcon = root.shell.appLibrary.iconSource(appName.toLowerCase())
        if (libIcon && libIcon.length > 0) return formatUrl(libIcon)
      }
    }

    var summaryName = String(notif.summary || "")
    if (summaryName.length > 0) {
      var summaryThemed = Quickshell.iconPath(summaryName.toLowerCase(), true)
      if (summaryThemed && summaryThemed.length > 0) return formatUrl(summaryThemed)
    }
    return ""
  }

  function resolveNotificationGlyph(notif) {
    if (!notif) return ""
    if (notif.glyph) return String(notif.glyph)
    try {
      if (notif.hints && notif.hints["omarchy-glyph"]) return String(notif.hints["omarchy-glyph"])
    } catch (e) {}
    return ""
  }

  function handleNotificationClick(isRightClick) {
    if (isRightClick) {
      dismissNotification()
    } else {
      invokeNotificationAction()
    }
  }

  function invokeNotificationAction() {
    var notif = root.currentNotification
    if (!notif) return

    var execCmd = String(notif.exec || "")
    if (execCmd) {
      Util.execDetached(execCmd)
      dismissNotification()
      return
    }

    var invoked = false
    try {
      if (root.notifService && root.notifService.liveRefs) {
        var live = root.notifService.liveRefs[notif.originalId]
        if (live && live.actions && live.actions.length > 0) {
          for (var a = 0; a < live.actions.length; a++) {
            var act = live.actions[a]
            if (act && (act.identifier === "default" || a === 0)) {
              if (typeof act.invoke === "function") {
                act.invoke()
                invoked = true
                break
              }
            }
          }
        }
      }
    } catch (e) {
      console.warn("Notification action invoke error:", e)
    }

    if (!invoked) {
      var app = String(notif.appName || notif.app || "")
      if (app && app !== "notify-send" && app !== "omarchy-action") {
        var path = root.omarchyPath || "/usr/share/omarchy"
        Util.execDetached(path + "/bin/omarchy-hyprland-focus-app " + app)
      }
    }

    dismissNotification()
  }

  function dismissNotification() {
    rootNotificationTimer.stop()
    root.currentNotification = null
  }

  Timer {
    id: rootNotificationTimer
    interval: 5000
    repeat: false
    onTriggered: root.dismissNotification()
  }

  Component.onCompleted: applyBarConfig()

  // Revealing the indicators widens their section, which can slide a neighbour
  // under a stationary pointer. Collapsing on that un-hover would move it back
  // out and re-open the peek, so hold until the pointer leaves the bar.
  function setCenterSectionHovered(hovered) {
    centerSectionHovered = hovered
    if (hovered) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  function setBarHovered(hovered) {
    barHoverCount = Math.max(0, barHoverCount + (hovered ? 1 : -1))
    if (barHoverCount === 0) centerSectionRevealTimer.restart()
  }

  Timer {
    id: centerSectionRevealTimer
    interval: 120
    // Collapse only. Opening the peek is the center section's own gesture, done
    // in setCenterSectionHovered, so a timer left pending by a pointer that dipped
    // off the bar and came back cannot reveal indicators it never pointed at.
    onTriggered: if (!root.centerSectionHovered && !root.barHovered) root.centerSectionRevealHeld = false
  }

  function run(command) {
    if (!command) return

    Util.execDetached(command)
  }

  function toggleTransparency() {
    var nextTransparent = !(root.requestedTransparent === true)
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.transparent = nextTransparent
      })
    } else {
      root.setRequestedTransparency(nextTransparent)
    }
  }

  function rawLayoutSection(config, region) {
    if (!Util.isPlainObject(config.bar)) config.bar = {}
    if (!Util.isPlainObject(config.bar.layout)) config.bar.layout = {}
    if (!Array.isArray(config.bar.layout[region])) config.bar.layout[region] = []

    return config.bar.layout[region]
  }

  function rawEntryIndex(entries, name) {
    for (var i = 0; i < entries.length; i++) {
      if (root.entryId(entries[i]) === name) return i
    }

    return -1
  }

  function moveModuleInConfig(config, fromRegion, fromName, toRegion, beforeName) {
    var fromEntries = rawLayoutSection(config, fromRegion)
    var toEntries = rawLayoutSection(config, toRegion)
    var fromIndex = rawEntryIndex(fromEntries, fromName)
    if (fromIndex < 0) return false

    var toIndex = beforeName ? rawEntryIndex(toEntries, beforeName) : toEntries.length
    if (toIndex < 0) toIndex = toEntries.length

    if (fromRegion === toRegion && fromIndex === toIndex) return false

    var movedEntry = fromEntries[fromIndex]
    fromEntries.splice(fromIndex, 1)

    if (fromRegion === toRegion && fromIndex < toIndex) toIndex -= 1
    if (toIndex < 0) toIndex = 0
    if (toIndex > toEntries.length) toIndex = toEntries.length
    if (fromRegion === toRegion && fromIndex === toIndex) {
      fromEntries.splice(fromIndex, 0, movedEntry)
      return false
    }

    toEntries.splice(toIndex, 0, movedEntry)
    return true
  }

  function dropBarModule(source, toRegion, beforeName) {
    if (!source || !source.region || !source.moduleName || !toRegion) return false
    if (source.region === toRegion && source.moduleName === beforeName) return false
    if (!root.shell || typeof root.shell.mutateShellConfig !== "function") return false

    var changed = false
    root.shell.mutateShellConfig(function(config) {
      changed = moveModuleInConfig(config, source.region, source.moduleName, toRegion, beforeName)
    })
    return changed
  }

  function moduleDropAtScene(scenePoint, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    if (sourceWindow && sourceWindow.contentItem) {
      var barPoint = sourceWindow.contentItem.mapFromItem(null, scenePoint.x, scenePoint.y)
      if (barPoint.x < 0 || barPoint.x > sourceWindow.contentItem.width ||
          barPoint.y < 0 || barPoint.y > sourceWindow.contentItem.height)
        return null
    }

    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue

      var slotPoint = { x: slot.x, y: slot.y }
      try {
        slotPoint = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }

      candidates.push({
        slot: slot,
        x: slotPoint.x,
        y: slotPoint.y,
        width: slot.width,
        height: slot.height
      })
    }

    return BarModel.nearestDropTarget(candidates, scenePoint, root.vertical)
  }

  function visibleModuleSlot(region, name, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || slot.region !== region || slot.moduleName !== name ||
          !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue
      return slot
    }

    return null
  }

  function nextVisibleModuleName(region, afterName, sourceSlot) {
    var entries = layoutEntries(region)
    var found = false
    for (var i = 0; i < entries.length; i++) {
      var name = entryId(entries[i])
      if (!found) {
        found = name === afterName
        continue
      }

      if (visibleModuleSlot(region, name, sourceSlot)) return name
    }

    return ""
  }

  function dropBarModuleAtTarget(sourceSlot, targetSlot, afterTarget) {
    if (!sourceSlot || !targetSlot) return false

    var beforeName = (targetSlot.moduleName === "" || targetSlot.moduleName === undefined) ? "" : (afterTarget ? nextVisibleModuleName(targetSlot.region, targetSlot.moduleName, sourceSlot) : targetSlot.moduleName)
    return dropBarModule(sourceSlot, targetSlot.region, beforeName)
  }

  function moduleTargetClickable(target) {
    return target
      && target.visible !== false
      && target.opacity !== 0
      && target.interactive !== false
      && target.pressable !== false
      && target.concealed !== true
      && typeof target.triggerPress === "function"
  }

  function moduleClickTargetAt(slot, localX, localY) {
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
      if (!moduleTargetClickable(target)) continue

      var targetPoint = { x: localX, y: localY }
      try {
        targetPoint = slot.mapToItem(target, localX, localY)
      } catch (e) {
        continue
      }

      if (targetPoint.x >= 0 && targetPoint.x <= target.width &&
          targetPoint.y >= 0 && targetPoint.y <= target.height) {
        return target
      }
    }

    if (moduleTargetClickable(slot.activeItem)) return slot.activeItem
    return null
  }

  function pressModuleClickTarget(slot, button, localX, localY) {
    var target = moduleClickTargetAt(slot, localX, localY)
    if (!target) return false

    target.triggerPress(button)
    return true
  }

  function colorHex(colorValue) {
    var c = colorValue
    if (typeof c === "string") c = Qt.color(c)
    function hexChannel(value) {
      var s = Math.round(Util.clamp(value, 0, 1) * 255).toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b)
  }

  function setRequestedTransparency(value) {
    var nextTransparent = value === true
    requestedTransparent = nextTransparent
    if (!nextTransparent) {
      foregroundAnimationEnabled = false
      useTransparentForeground = false
      transparent = false
      transparentForeground = themeForeground
      restoreForegroundAnimation()
      return
    }
    scheduleTransparentForegroundRefresh()
  }

  function restoreForegroundAnimation() {
    Qt.callLater(function() {
      Qt.callLater(function() { root.foregroundAnimationEnabled = true })
    })
  }

  function scheduleTransparentForegroundRefresh() {
    if (!requestedTransparent) {
      transparentForeground = themeForeground
      return
    }
    transparentForegroundTimer.restart()
  }

  function refreshTransparentForeground() {
    if (!requestedTransparent || transparentForegroundProc.running) return

    transparentForegroundProc.command = [
      "omarchy-bar-text-color",
      root.position,
      String(root.barSize),
      colorHex(root.themeForeground),
      colorHex(root.themeContrastForeground)
    ]
    transparentForegroundProc.running = true
  }

  onRequestedTransparentChanged: scheduleTransparentForegroundRefresh()
  onPositionChanged: scheduleTransparentForegroundRefresh()
  onThemeForegroundChanged: scheduleTransparentForegroundRefresh()
  onThemeContrastForegroundChanged: scheduleTransparentForegroundRefresh()

  Timer {
    id: transparentForegroundTimer
    interval: 120
    repeat: false
    onTriggered: root.refreshTransparentForeground()
  }

  Process {
    id: transparentForegroundProc
    stdout: SplitParser {
      onRead: function(line) {
        var value = String(line || "").trim()
        if (!/^#[0-9A-Fa-f]{6}$/.test(value)) return

        root.foregroundAnimationEnabled = false
        root.transparentForeground = value
        if (root.requestedTransparent) {
          root.useTransparentForeground = true
          root.transparent = true
        }
        root.restoreForegroundAnimation()
      }
    }
  }

  FileView {
    path: root.stateHome + "/omarchy/current"
    watchChanges: true
    printErrors: false
    onFileChanged: root.scheduleTransparentForegroundRefresh()
  }

  function runProcess(process) {
    if (!process.running)
      process.running = true
  }

  function showTooltip(target, text) {
    clearTooltip()

    if (!targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }

    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text

    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return

    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarPanel {
        required property var modelData
        screen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      CenterPanel {
        required property var modelData
        screen: modelData
        barPluginRoot: root
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      DragGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarMoveGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  component BarPanel: PanelWindow {
    id: barWindow

    readonly property bool isPopoutActive: root.activePopout !== null
    readonly property bool isTooltipActive: root.tooltipShown && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
    readonly property bool isDragActive: (root.barDragSource !== null && root.sameWindow(root.barDragWindow, barWindow)) || root.barMoveActive

    visible: !remapGuard.remapping
    exclusionMode: ExclusionMode.Auto
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
      top: true
      left: true
      right: true
    }

    implicitHeight: root.islandHeight + 12

    ScreenMoveRemap {
      id: remapGuard
      window: barWindow
    }

    readonly property real effectiveLeftX: {
      if (root.leftIslandAttach === "left") return 0
      if (root.leftIslandAttach === "right") return Math.max(0, barWindow.width - leftNotch.width)
      return Math.max(0, Math.min(barWindow.width - leftNotch.width, root.leftIslandX))
    }

    readonly property real effectiveRightX: {
      if (root.rightIslandAttach === "right") return Math.max(0, barWindow.width - rightNotch.width)
      if (root.rightIslandAttach === "left") return 0
      var targetX = root.rightIslandX < 0 ? (barWindow.width - rightNotch.width) : root.rightIslandX
      return Math.max(0, Math.min(barWindow.width - rightNotch.width, targetX))
    }

    mask: Region {
      // 1. Left Notch body
      Region {
        x: leftNotch.contentWidth > 0 ? Math.floor(leftNotch.x) : 0
        y: 0
        width: leftNotch.contentWidth > 0 ? Math.ceil(leftNotch.width + 4) : 0
        height: leftNotch.contentWidth > 0 ? Math.ceil(leftNotch.height + 4) : 0
      }

      // 2. Right Notch body
      Region {
        intersection: Intersection.Combine
        x: rightNotch.contentWidth > 0 ? Math.floor(rightNotch.x) : 0
        y: 0
        width: rightNotch.contentWidth > 0 ? Math.ceil(rightNotch.width + 4) : 0
        height: rightNotch.contentWidth > 0 ? Math.ceil(rightNotch.height + 4) : 0
      }
    }

    // ------------------------------------------------------------- 1. Left Island Notch (Auto-collapses when empty)
    NotchSurface {
      id: leftNotch
      z: 10
      anchors.top: parent.top
      anchors.left: root.leftIslandAttach === "left" && !root.isDraggingIsland ? parent.left : undefined
      x: root.leftIslandAttach === "left" ? 0 : (root.leftIslandAttach === "right" ? Math.max(0, barWindow.width - leftNotch.width) : Math.max(0, Math.min(barWindow.width - leftNotch.width, root.leftIslandX)))
      y: 0
      attachSide: root.leftIslandAttach
      radius: 8
      visible: contentWidth > 0
      opacity: contentWidth > 0 ? 1.0 : 0.0
      color: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.50)
      borderColor: Qt.rgba(root.themeForeground.r, root.themeForeground.g, root.themeForeground.b, 0.18)
      borderWidth: 1
      contentWidth: {
        var hasWidgets = leftModules.entries && leftModules.entries.length > 0
        var isDragging = root.barDragSource !== null
        if (!hasWidgets && !isDragging) return 0
        return Math.max(hasWidgets ? 60 : 76, leftModules.implicitWidth + Style.space(12))
      }
      contentHeight: root.islandHeight

      Behavior on x {
        enabled: !root.isDraggingIsland && root.leftIslandAttach !== "left"
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
      Behavior on contentWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
      Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }

      MouseArea {
        id: leftIslandDragArea
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.SizeHorCursor

        property real startPressWindowX: 0
        property real startIslandX: 0

        onPressed: function(mouse) {
          startPressWindowX = mapToItem(null, mouse.x, mouse.y).x
          startIslandX = root.leftIslandAttach === "left" ? 0 : root.leftIslandX
          root.isDraggingIsland = true
        }

        onPositionChanged: function(mouse) {
          if (!root.isDraggingIsland) return
          var currentWindowX = mapToItem(null, mouse.x, mouse.y).x
          var delta = currentWindowX - startPressWindowX
          var targetX = startIslandX + delta
          if (targetX <= 8) {
            root.leftIslandAttach = "left"
            root.leftIslandX = 0
          } else if (targetX >= barWindow.width - leftNotch.width - 16) {
            root.leftIslandAttach = "right"
            root.leftIslandX = barWindow.width - leftNotch.width
          } else {
            root.leftIslandAttach = "none"
            root.leftIslandX = Math.max(0, Math.min(barWindow.width - leftNotch.width, targetX))
          }
        }

        onReleased: function(mouse) {
          root.isDraggingIsland = false
          root.resolveIslandCollisions(barWindow.width, leftNotch.width, 100, rightNotch.width)
          root.saveIslandLayout()
        }
      }

      Item {
        anchors.top: parent.top
        height: root.islandHeight
        anchors.left: leftNotch.attachSide === "left" ? parent.left : undefined
        anchors.right: leftNotch.attachSide === "right" ? parent.right : undefined
        anchors.horizontalCenter: leftNotch.attachSide === "none" ? parent.horizontalCenter : undefined
        width: leftNotch.contentWidth

        LeftModules {
          id: leftModules
          anchors.left: leftNotch.attachSide === "left" ? parent.left : undefined
          anchors.leftMargin: leftNotch.attachSide === "left" ? 6 : 0
          anchors.right: leftNotch.attachSide === "right" ? parent.right : undefined
          anchors.rightMargin: leftNotch.attachSide === "right" ? 6 : 0
          anchors.horizontalCenter: leftNotch.attachSide === "none" ? parent.horizontalCenter : undefined
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -2
        }
      }
    }

    // ------------------------------------------------------------- 2. Right Island Notch (Auto-collapses when empty)
    NotchSurface {
      id: rightNotch
      z: 10
      anchors.top: parent.top
      anchors.right: root.rightIslandAttach === "right" && !root.isDraggingIsland ? parent.right : undefined
      x: root.rightIslandAttach === "right" ? Math.max(0, barWindow.width - rightNotch.width) : (root.rightIslandAttach === "left" ? 0 : Math.max(0, Math.min(barWindow.width - rightNotch.width, root.rightIslandX < 0 ? (barWindow.width - rightNotch.width) : root.rightIslandX)))
      y: 0
      attachSide: root.rightIslandAttach
      radius: 8
      visible: contentWidth > 0
      opacity: contentWidth > 0 ? 1.0 : 0.0
      color: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.50)
      borderColor: Qt.rgba(root.themeForeground.r, root.themeForeground.g, root.themeForeground.b, 0.18)
      borderWidth: 1
      contentWidth: {
        var hasWidgets = rightModules.entries && rightModules.entries.length > 0
        var isDragging = root.barDragSource !== null
        if (!hasWidgets && !isDragging) return 0
        return Math.max(hasWidgets ? 60 : 76, rightModules.implicitWidth + Style.space(12))
      }
      contentHeight: root.islandHeight

      Behavior on x {
        enabled: !root.isDraggingIsland && root.rightIslandAttach !== "right"
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
      Behavior on contentWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
      Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }

      MouseArea {
        id: rightIslandDragArea
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.SizeHorCursor

        property real startPressWindowX: 0
        property real startIslandX: 0

        onPressed: function(mouse) {
          startPressWindowX = mapToItem(null, mouse.x, mouse.y).x
          startIslandX = root.rightIslandAttach === "right" ? (barWindow.width - rightNotch.width) : (root.rightIslandX < 0 ? (barWindow.width - rightNotch.width) : root.rightIslandX)
          root.isDraggingIsland = true
        }

        onPositionChanged: function(mouse) {
          if (!root.isDraggingIsland) return
          var currentWindowX = mapToItem(null, mouse.x, mouse.y).x
          var delta = currentWindowX - startPressWindowX
          var targetX = startIslandX + delta
          if (targetX >= barWindow.width - rightNotch.width - 16) {
            root.rightIslandAttach = "right"
            root.rightIslandX = barWindow.width - rightNotch.width
          } else if (targetX <= 8) {
            root.rightIslandAttach = "left"
            root.rightIslandX = 0
          } else {
            root.rightIslandAttach = "none"
            root.rightIslandX = Math.max(0, Math.min(barWindow.width - rightNotch.width, targetX))
          }
        }

        onReleased: function(mouse) {
          root.isDraggingIsland = false
          root.resolveIslandCollisions(barWindow.width, leftNotch.width, 100, rightNotch.width)
          root.saveIslandLayout()
        }
      }

      Item {
        anchors.top: parent.top
        height: root.islandHeight
        anchors.left: rightNotch.attachSide === "left" ? parent.left : undefined
        anchors.right: rightNotch.attachSide === "right" ? parent.right : undefined
        anchors.horizontalCenter: rightNotch.attachSide === "none" ? parent.horizontalCenter : undefined
        width: rightNotch.contentWidth

        RightModules {
          id: rightModules
          anchors.right: rightNotch.attachSide === "right" ? parent.right : undefined
          anchors.rightMargin: rightNotch.attachSide === "right" ? 6 : 0
          anchors.left: rightNotch.attachSide === "left" ? parent.left : undefined
          anchors.leftMargin: rightNotch.attachSide === "left" ? 6 : 0
          anchors.horizontalCenter: rightNotch.attachSide === "none" ? parent.horizontalCenter : undefined
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -2
        }
      }
    }

    PopupWindow {
      id: tooltipWindow

      visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
          var target = root.tooltipTarget
          if (!root.targetBelongsToWindow(target, barWindow)) return

          var popupWidth = tooltipWindow.implicitWidth
          var popupHeight = tooltipWindow.implicitHeight
          var localX = target.width / 2 - popupWidth / 2
          var localY = target.height + 6

          if (root.position === "bottom") {
            localY = -popupHeight - 6
          } else if (root.position === "left") {
            localX = target.width + 6
            localY = target.height / 2 - popupHeight / 2
          } else if (root.position === "right") {
            localX = -popupWidth - 6
            localY = target.height / 2 - popupHeight / 2
          }

          var point = barWindow.contentItem.mapFromItem(target, localX, localY)
          tooltipAnchor.rect.x = Math.round(point.x)
          tooltipAnchor.rect.y = Math.round(point.y)
        }
      }

      BorderSurface {
        id: tooltipBubble
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: Color.tooltip.background
        borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
        radius: Style.cornerRadius

        Text {
          id: tooltipLabel
          anchors.centerIn: parent
          text: root.tooltipText
          color: Color.tooltip.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
  }

  // ------------------------------------------------------------- 3. Center Island Floating Panel (Seamless Morphing & Full Search)
  component CenterPanel: PanelWindow {
    id: centerWindow

    property var barPluginRoot: null
    readonly property bool isSearchOpen: barPluginRoot ? barPluginRoot.isSearchOpen : false
    readonly property bool isMenuOpen: barPluginRoot ? barPluginRoot.isMenuOpen : false
    readonly property bool isHistoryOpen: barPluginRoot ? barPluginRoot.isHistoryOpen : false
    readonly property bool isExpanded: isSearchOpen || isMenuOpen || isHistoryOpen
    readonly property bool isIdle: centerIslandItem ? (centerIslandItem.currentMode === "clock") : true

    visible: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar-center"
    WlrLayershell.layer: isIdle ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: centerWindow.isExpanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: centerWindow.isExpanded
      left: true
      right: true
    }

    implicitHeight: centerWindow.isExpanded ? (screen ? screen.height : 0) : Math.ceil(centerIslandItem.implicitHeight + 8)

    // Full screen click-outside dismissal scrim when menu, search, or history is open
    MouseArea {
      id: outsideClickArea
      anchors.fill: parent
      visible: centerWindow.isExpanded
      hoverEnabled: true
      onClicked: {
        if (centerWindow.barPluginRoot) {
          centerWindow.barPluginRoot.closeMenu()
          centerWindow.barPluginRoot.isHistoryOpen = false
        }
      }
    }

    mask: Region {
      item: centerWindow.isExpanded ? centerWindow.contentItem : centerIslandItem
    }

    CenterIsland {
      id: centerIslandItem
      z: 15
      root: centerWindow.barPluginRoot
      barWindow: centerWindow
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.horizontalCenterOffset: {
        if (!barPluginRoot) return 0
        var base = Math.round((centerWindow.width - centerIslandItem.width) / 2)
        if (barPluginRoot.centerIslandAttach === "left") return -base
        if (barPluginRoot.centerIslandAttach === "right") return base
        return barPluginRoot.centerIslandOffset
      }

      Behavior on anchors.horizontalCenterOffset {
        enabled: !barPluginRoot || !barPluginRoot.isDraggingIsland
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }

      MouseArea {
        id: centerIslandDragArea
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.SizeHorCursor

        property real startPressWindowX: 0
        property real startOffset: 0

        onPressed: function(mouse) {
          startPressWindowX = mapToItem(null, mouse.x, mouse.y).x
          startOffset = centerIslandItem.anchors.horizontalCenterOffset
          if (centerWindow.barPluginRoot) centerWindow.barPluginRoot.isDraggingIsland = true
        }

        onPositionChanged: function(mouse) {
          if (!centerWindow.barPluginRoot || !centerWindow.barPluginRoot.isDraggingIsland) return
          var currentWindowX = mapToItem(null, mouse.x, mouse.y).x
          var delta = currentWindowX - startPressWindowX
          var targetOffset = startOffset + delta
          var base = Math.round((centerWindow.width - centerIslandItem.width) / 2)
          var targetX = base + targetOffset

          if (targetX <= 4) {
            centerWindow.barPluginRoot.centerIslandAttach = "left"
            centerWindow.barPluginRoot.centerIslandOffset = -base
          } else if (targetX >= centerWindow.width - centerIslandItem.width - 4) {
            centerWindow.barPluginRoot.centerIslandAttach = "right"
            centerWindow.barPluginRoot.centerIslandOffset = base
          } else {
            centerWindow.barPluginRoot.centerIslandAttach = "none"
            centerWindow.barPluginRoot.centerIslandOffset = Math.max(-base, Math.min(base, targetOffset))
          }
        }

        onReleased: function(mouse) {
          if (centerWindow.barPluginRoot) {
            centerWindow.barPluginRoot.isDraggingIsland = false
            centerWindow.barPluginRoot.resolveIslandCollisions(centerWindow.width, 100, centerIslandItem.width, 100)
            centerWindow.barPluginRoot.saveIslandLayout()
          }
        }
      }

      centerModulesComponent: Component {
        CenterModules {}
      }

      Component.onCompleted: {
        if (centerWindow.barPluginRoot) centerWindow.barPluginRoot.centerIslandRef = centerIslandItem
      }
    }
  }

  Component { id: emptyModuleComponent; Item { implicitWidth: 0; implicitHeight: 0; visible: false } }

  component DragGhostPanel: PanelWindow {
    id: ghostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barDragScreen === ghostScreen ||
      (root.barDragScreen && ghostScreen && root.barDragScreen.name && ghostScreen.name && root.barDragScreen.name === ghostScreen.name)
    readonly property bool active: root.barDragSource && root.barDragScreen && screenMatches
    readonly property var sourceItem: root.barDragSource ? root.barDragSource.activeItem : null
    readonly property int ghostPadding: Style.space(1)
    readonly property int ghostWidth: sourceItem ? Math.max(1, Math.ceil(sourceItem.width)) : 1
    readonly property int ghostHeight: sourceItem ? Math.max(1, Math.ceil(sourceItem.height)) : 1

    visible: active && sourceItem !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-drag-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only drag feedback. Keep the input region empty so the ghost can
    // sit under the cursor without stealing the MouseArea's active pointer grab.
    mask: Region {}

    Item {
      visible: ghostWindow.visible
      x: Math.round(root.barDragScreenX - root.barDragOffsetX - ghostWindow.ghostPadding)
      y: Math.round(root.barDragScreenY - root.barDragOffsetY - ghostWindow.ghostPadding)
      width: ghostWindow.ghostWidth + ghostWindow.ghostPadding * 2
      height: ghostWindow.ghostHeight + ghostWindow.ghostPadding * 2

      BorderSurface {
        anchors.fill: parent
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        radius: Math.min(Style.cornerRadius, height / 2)
        opacity: root.transparent ? 0.45 : 0.94
      }

      Image {
        anchors.fill: parent
        anchors.margins: ghostWindow.ghostPadding
        source: root.barDragImageUrl
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.84
      }
    }

    Rectangle {
      readonly property var targetRect: root.barDragTargetGeometry

      visible: ghostWindow.active && targetRect !== null
      x: targetRect ? Math.round(targetRect.x) : 0
      y: targetRect ? Math.round(targetRect.y) : 0
      width: targetRect ? targetRect.width : 0
      height: targetRect ? targetRect.height : 0
      color: Color.accent
      radius: Math.min(width, height) / 2
    }
  }

  component BarMoveGhostPanel: PanelWindow {
    id: moveGhostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barMoveScreen === ghostScreen ||
      (root.barMoveScreen && ghostScreen && root.barMoveScreen.name && ghostScreen.name && root.barMoveScreen.name === ghostScreen.name)
    visible: root.barMoveActive && screenMatches
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-move-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only preview of the candidate edge. Keep the input region empty
    // so the overlay never steals the gesture area's active pointer grab.
    mask: Region {}

    // One fixed-geometry slab per edge, crossfaded on candidate changes.
    // Resizing a single slab between edges repaints mid-transition and
    // flickers; fading between static ones does not.
    Repeater {
      model: ["top", "bottom", "left", "right"]

      BorderSurface {
        id: edgeSlab

        required property string modelData
        readonly property bool edgeVertical: modelData === "left" || modelData === "right"
        readonly property int edgeSize: edgeVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal

        x: modelData === "right" ? parent.width - edgeSize : 0
        y: modelData === "bottom" ? parent.height - edgeSize : 0
        width: edgeVertical ? edgeSize : parent.width
        height: edgeVertical ? parent.height : edgeSize
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        visible: opacity > 0
        opacity: root.barMoveCandidate === modelData ? (root.transparent ? 0.45 : 0.7) : 0

        Behavior on opacity {
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  function findCenterAnchorEntry() {
    var entries = root.layoutEntries("center")
    var idx = root.entryIndex(entries, root.centerAnchor)
    return idx === -1 ? null : entries[idx]
  }

  component EmptyZoneDropSlot: Item {
    id: emptySlot

    property string region: ""
    property string zoneLabel: ""
    readonly property string moduleName: ""
    readonly property var moduleSettings: ({})
    readonly property var activeItem: emptySlot
    readonly property bool isHoveredDrop: root.barDragTarget === emptySlot

    implicitWidth: 60
    implicitHeight: Math.max(22, root.islandHeight - 8)
    width: implicitWidth
    height: implicitHeight

    Component.onCompleted: root.registerModuleSlot(emptySlot)
    Component.onDestruction: root.unregisterModuleSlot(emptySlot)

    Rectangle {
      anchors.fill: parent
      anchors.margins: 2
      radius: Math.min(Style.cornerRadius, height / 2)
      color: emptySlot.isHoveredDrop ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(root.themeForeground.r, root.themeForeground.g, root.themeForeground.b, 0.08)
      border.color: emptySlot.isHoveredDrop ? Color.accent : Qt.rgba(root.themeForeground.r, root.themeForeground.g, root.themeForeground.b, 0.35)
      border.width: 1

      Row {
        anchors.centerIn: parent
        spacing: 4

        Text {
          text: "+"
          color: emptySlot.isHoveredDrop ? Color.accent : root.barForeground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.weight: Font.Bold
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: emptySlot.zoneLabel
          color: emptySlot.isHoveredDrop ? Color.accent : root.barForeground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
          opacity: 0.85
        }
      }
    }
  }

  component LeftModules: Item {
    id: leftModulesRoot
    property var entries: root.layoutEntries("left")
    readonly property bool isEmpty: !entries || entries.length === 0
    readonly property bool isDragActive: root.barDragSource !== null

    implicitWidth: isEmpty ? (isDragActive ? emptyDropSlot.implicitWidth : 0) : moduleList.implicitWidth
    implicitHeight: isEmpty ? (isDragActive ? emptyDropSlot.implicitHeight : 0) : moduleList.implicitHeight
    width: implicitWidth
    height: implicitHeight

    ModuleList {
      id: moduleList
      visible: !leftModulesRoot.isEmpty
      entries: leftModulesRoot.entries
      region: "left"
    }

    EmptyZoneDropSlot {
      id: emptyDropSlot
      visible: leftModulesRoot.isEmpty && leftModulesRoot.isDragActive
      region: "left"
      zoneLabel: "Left"
    }
  }

  component RightModules: Item {
    id: rightModulesRoot
    property var entries: root.layoutEntries("right")
    readonly property bool isEmpty: !entries || entries.length === 0
    readonly property bool isDragActive: root.barDragSource !== null

    implicitWidth: isEmpty ? (isDragActive ? emptyDropSlot.implicitWidth : 0) : moduleList.implicitWidth
    implicitHeight: isEmpty ? (isDragActive ? emptyDropSlot.implicitHeight : 0) : moduleList.implicitHeight
    width: implicitWidth
    height: implicitHeight

    ModuleList {
      id: moduleList
      visible: !rightModulesRoot.isEmpty
      entries: rightModulesRoot.entries
      region: "right"
    }

    EmptyZoneDropSlot {
      id: emptyDropSlot
      visible: rightModulesRoot.isEmpty && rightModulesRoot.isDragActive
      region: "right"
      zoneLabel: "Right"
    }
  }

  component CenterModules: Item {
    id: centerRoot

    property var entries: root.layoutEntries("center")
    readonly property bool hasAnchor: root.entryIndex(entries, root.centerAnchor) !== -1
    readonly property var anchorEntry: root.findCenterAnchorEntry()

    implicitWidth: centerRow.implicitWidth
    implicitHeight: centerRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    HoverHandler {
      onHoveredChanged: root.setCenterSectionHovered(hovered)
    }

    Row {
      id: centerRow
      anchors.centerIn: parent
      spacing: 0

      EmptyZoneDropSlot {
        visible: centerRoot.entries.length === 0 && root.barDragSource !== null
        region: "center"
        zoneLabel: "Center"
      }

      ModuleList {
        visible: !centerRoot.hasAnchor && centerRoot.entries.length > 0
        entries: centerRoot.entries
        region: "center"
      }

      ModuleList {
        visible: centerRoot.hasAnchor
        entries: root.entriesBefore(centerRoot.entries, root.centerAnchor)
        region: "center"
      }

      ModuleSlot {
        visible: centerRoot.hasAnchor
        entry: centerRoot.anchorEntry
        region: "center"
      }

      ModuleList {
        visible: centerRoot.hasAnchor
        entries: root.entriesAfter(centerRoot.entries, root.centerAnchor)
        region: "center"
      }
    }
  }

  component CenterGestureArea: MouseArea {
    id: gestureArea

    property bool dragging: false
    property bool suppressClick: false
    property real pressedX: 0
    property real pressedY: 0
    readonly property real dragThreshold: Style.space(4)

    acceptedButtons: Qt.LeftButton
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
    pressAndHoldInterval: 200

    function startDrag(x, y) {
      if (dragging) return
      dragging = true
      root.beginBarMove(root.targetWindow(gestureArea))
      var scenePoint = gestureArea.mapToItem(null, x, y)
      root.updateBarMove(root.windowScreenPoint(scenePoint, root.barMoveWindow))
    }

    onPressed: function(mouse) {
      dragging = false
      suppressClick = false
      pressedX = mouse.x
      pressedY = mouse.y
    }

    onPressAndHold: function(mouse) {
      startDrag(mouse.x, mouse.y)
    }

    onPositionChanged: function(mouse) {
      if (!(mouse.buttons & Qt.LeftButton)) return

      if (!dragging) {
        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance < dragThreshold) return
        startDrag(mouse.x, mouse.y)
        return
      }

      var scenePoint = gestureArea.mapToItem(null, mouse.x, mouse.y)
      root.updateBarMove(root.windowScreenPoint(scenePoint, root.barMoveWindow))
    }

    onReleased: function(mouse) {
      if (!dragging) return
      dragging = false
      suppressClick = true
      root.finishBarMove()
      mouse.accepted = true
    }

    onCanceled: {
      dragging = false
      suppressClick = false
      root.clearBarMove()
    }

    onClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        mouse.accepted = true
      }
    }

    onDoubleClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        return
      }
      if (mouse.button === Qt.LeftButton) {
        root.toggleTransparency()
        mouse.accepted = true
      }
    }
  }

  component ModuleList: Item {
    id: moduleListRoot

    property var entries: []
    property string region: ""

    visible: entries.length > 0
    implicitWidth: moduleRow.implicitWidth
    implicitHeight: moduleRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Row {
      id: moduleRow
      spacing: 0

      Repeater {
        model: moduleListRoot.entries

        ModuleSlot {
          required property var modelData
          entry: modelData
          region: moduleListRoot.region
        }
      }
    }
  }

  component ModuleSlot: Item {
    id: slot

    required property var entry
    property string region: ""
    readonly property string moduleName: root.entryId(entry)
    readonly property var moduleSettings: root.entrySettings(entry)
    readonly property string customType: root.customModuleType(entry)
    // Re-evaluate when the registry mutates (Component reference changes,
    // plugin enabled/disabled, etc.). Reading the `widgets` property creates
    // the binding dependency — the wrapped function call alone wouldn't.
    readonly property var registryComponent: {
      var w = root.barWidgetRegistry ? root.barWidgetRegistry.widgets : null
      if (!w || customType) return null
      var registryName = root.canonicalWidgetId(moduleName)
      return w[registryName] ? w[registryName].component : null
    }
    readonly property bool qmlCustom: customType === "qml"
    readonly property bool commandCustom: customType === "command"
    readonly property bool registered: registryComponent !== null
    readonly property var activeItem: {
      if (registered) return registryLoader.item
      if (qmlCustom) return qmlLoader.item
      return componentLoader.item
    }
    readonly property bool hovered: moduleHover.hovered
    readonly property bool dragSource: root.barDragSource === slot
    readonly property bool panelOpen: root.activePopout === slot.activeItem
    // Modules bigger than the mark they want (a text label in a padded slot,
    // a multi-line stack on a vertical bar) can say how long the open-panel
    // dot should be along the bar, so it tracks what the module paints
    // instead of a fraction of whatever slot it happens to fill.
    readonly property real panelIndicatorExtent: {
      var key = root.vertical ? "openPanelIndicatorHeight" : "openPanelIndicatorWidth"
      var hint = activeItem && key in activeItem ? activeItem[key] : undefined
      if (hint !== undefined && hint !== null && hint > 0) return Math.round(hint)
      return Math.max(Style.space(10), Math.round((root.vertical ? slot.height : slot.width) * 0.55))
    }
    implicitWidth: activeItem && activeItem.visible ? (root.vertical ? root.barSize : activeItem.implicitWidth) : 0
    implicitHeight: activeItem && activeItem.visible ? activeItem.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight
    z: modulePointer.dragging ? 100 : 0

    Component.onCompleted: root.registerModuleSlot(slot)
    Component.onDestruction: {
      if (root.barDragSource === slot) root.clearBarDrag()
      root.unregisterModuleSlot(slot)
    }

    HoverHandler { id: moduleHover }

    BorderSurface {
      visible: slot.dragSource
      anchors.fill: parent
      anchors.margins: Style.space(1)
      color: root.transparent ? "transparent" : root.background
      borderSpec: Border.flat(root.barForeground, 1)
      radius: Math.min(Style.cornerRadius, height / 2)
      opacity: root.transparent ? 0.22 : 0.32
    }

    Loader {
      id: componentLoader
      active: !slot.qmlCustom && !slot.registered
      sourceComponent: slot.commandCustom ? customCommandModuleComponent : emptyModuleComponent
      anchors.fill: parent
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: registryLoader
      active: slot.registered
      sourceComponent: slot.registered ? slot.registryComponent : null
      anchors.fill: parent
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: qmlLoader
      active: slot.qmlCustom
      source: slot.qmlCustom ? root.customModuleSource(slot.entry) : ""
      anchors.fill: parent
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Rectangle {
      id: openPanelIndicator

      readonly property int inset: Style.space(2)

      visible: opacity > 0
      opacity: slot.panelOpen && !slot.dragSource ? 0.9 : 0
      color: Color.accent
      radius: Math.min(width, height) / 2
      width: root.vertical ? Style.space(2) : slot.panelIndicatorExtent
      height: root.vertical ? slot.panelIndicatorExtent : Style.space(2)
      // The mark sits on the module's inner edge — the one facing the
      // desktop — so it underlines a top bar, overlines a bottom one, and
      // points inward from a left or right one. It reads as pointing at the
      // panel that opens on that side.
      x: root.vertical
        ? (root.position === "left" ? parent.width - width - inset : inset)
        : Math.round((parent.width - width) / 2)
      y: root.vertical
        ? Math.round((parent.height - height) / 2)
        : (root.position === "top" ? parent.height - height - inset : inset)
      z: 50

      Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      id: modulePointer

      property bool dragging: false
      property bool rightDragging: false
      property bool suppressClick: false
      property real pressedX: 0
      property real pressedY: 0
      property int pressedButton: Qt.NoButton
      readonly property bool canReorder: root.shell && typeof root.shell.mutateShellConfig === "function"
      readonly property real dragThreshold: Style.space(4)

      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      enabled: slot.visible && slot.width > 0 && slot.height > 0
      propagateComposedEvents: true
      cursorShape: {
        if (root.isDraggingIsland || rightDragging) return Qt.SizeHorCursor
        if (root.moduleClickTargetAt(slot, mouseX, mouseY)) return Qt.PointingHandCursor
        return Qt.ArrowCursor
      }
      // Do not assign drag.target here: ModuleSlot is owned by Row/Column
      // positioners, and mutating slot.x/slot.y can leave stale offsets that
      // make neighboring modules overlap after a small aborted drag.

      onPressed: function(mouse) {
        dragging = false
        rightDragging = false
        suppressClick = false
        pressedX = mouse.x
        pressedY = mouse.y
        pressedButton = mouse.button
        root.clearBarDrag()
        if (mouse.button === Qt.RightButton) {
          mouse.accepted = false
        }
      }

      onPositionChanged: function(mouse) {
        if (root.isDraggingIsland) {
          var windowPt = slot.mapToItem(null, mouse.x, mouse.y)
          var win = root.targetWindow(slot.activeItem) || root.targetWindow(slot) || root.barWindow || (slot.Window ? slot.Window.window : null)
          var screenW = win ? win.width : 1920
          root.updateIslandDrag(windowPt.x, screenW, 100, 200, 100)
          mouse.accepted = true
          return
        }

        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)

        if ((mouse.buttons & Qt.RightButton) || pressedButton === Qt.RightButton) {
          if (distance >= dragThreshold) {
            if (!rightDragging) {
              rightDragging = true
              root.startIslandDrag(slot, mouse)
            }
            var windowPt2 = slot.mapToItem(null, mouse.x, mouse.y)
            var win2 = root.targetWindow(slot.activeItem) || root.targetWindow(slot) || root.barWindow || (slot.Window ? slot.Window.window : null)
            var screenW2 = win2 ? win2.width : 1920
            root.updateIslandDrag(windowPt2.x, screenW2, 100, 200, 100)
            mouse.accepted = true
          }
          return
        }

        if (!canReorder || !(mouse.buttons & Qt.LeftButton)) return

        if (distance >= dragThreshold) {
          if (!dragging) {
            root.barDragWindow = root.targetWindow(slot.activeItem) || root.targetWindow(slot)
            root.barDragScreen = root.barDragWindow ? root.barDragWindow.screen : null
            root.barDragOffsetX = pressedX
            root.barDragOffsetY = pressedY
            root.captureBarDragGhost(slot)
            root.barDragSource = slot
          }
          dragging = true
          root.hideTooltip(slot.activeItem)
        }

        if (dragging) {
          var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
          var screenPoint = root.barDragScreenPoint(scenePoint)
          root.barDragSceneX = scenePoint.x
          root.barDragSceneY = scenePoint.y
          root.barDragScreenX = screenPoint.x
          root.barDragScreenY = screenPoint.y

          var drop = root.moduleDropAtScene(scenePoint, slot)
          root.barDragTarget = drop ? drop.slot : null
          root.barDragAfter = drop ? drop.after : false
          root.barDragTargetGeometry = drop ? root.dropMarkerRect(drop.slot, drop.after) : null
        }
      }

      onReleased: function(mouse) {
        if (root.isDraggingIsland || rightDragging) {
          var win = root.targetWindow(slot.activeItem) || root.targetWindow(slot) || root.barWindow || (slot.Window ? slot.Window.window : null)
          var screenW = win ? win.width : 1920
          root.finishIslandDrag(screenW, 100, 200, 100)
          rightDragging = false
          suppressClick = true
          mouse.accepted = true
          return
        }

        var wasDragging = dragging
        var targetSlot = root.barDragTarget
        var afterTarget = root.barDragAfter

        if (wasDragging) suppressClick = true

        dragging = false
        rightDragging = false
        root.clearBarDrag()

        if (wasDragging && targetSlot) {
          root.dropBarModuleAtTarget(slot, targetSlot, afterTarget)
          mouse.accepted = true
        } else if (!wasDragging) {
          mouse.accepted = false
        }
      }

      onCanceled: {
        dragging = false
        rightDragging = false
        suppressClick = false
        root.clearBarDrag()
        if (root.isDraggingIsland) {
          root.isDraggingIsland = false
        }
      }

      onClicked: function(mouse) {
        if (suppressClick) {
          suppressClick = false
          mouse.accepted = true
          return
        }

        if (!root.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) mouse.accepted = false
      }
    }

    onActiveItemChanged: Qt.callLater(injectProps)
    onModuleSettingsChanged: injectProps()

    function injectProps() {
      var target = activeItem
      if (!target) return
      if ("bar" in target) target.bar = root
      if ("moduleName" in target) target.moduleName = moduleName
      if ("settings" in target) target.settings = moduleSettings
    }

    Component {
      id: customCommandModuleComponent
      CustomCommandModule { entry: slot.entry }
    }
  }

  component CustomCommandModule: WidgetButton {
    id: customRoot

    required property var entry
    readonly property string moduleName: root.entryId(entry)
    readonly property var settings: root.entrySettings(entry)
    property string outputText: ""
    property string outputTooltip: ""
    property bool outputActive: false

    function setting(name, fallback) {
      var value = settings ? settings[name] : undefined
      return value === undefined || value === null ? fallback : value
    }

    function update(raw) {
      var data = Util.parseModuleJson(raw)
      var klass = data.class || data.alt || ""

      outputText = data.text || String(raw || "").trim()
      outputTooltip = data.tooltip || String(setting("tooltip", ""))
      outputActive = klass === "active" || (Array.isArray(klass) && klass.indexOf("active") !== -1)
    }

    bar: root
    text: outputText || String(setting("text", ""))
    tooltipText: outputTooltip || String(setting("tooltip", ""))
    active: outputActive
    keepSpace: setting("keepSpace", false) === true
    horizontalMargin: Number(setting("horizontalMargin", 7.5))
    verticalPadding: Number(setting("verticalPadding", 6))
    fontSize: Number(setting("fontSize", 12))

    onPressed: function(button) {
      var command = ""
      if (button === Qt.RightButton)
        command = String(setting("onRightClick", ""))
      else if (button === Qt.MiddleButton)
        command = String(setting("onMiddleClick", ""))
      else
        command = String(setting("onClick", ""))

      if (command) root.run(command)
    }

    Process {
      id: customProc
      command: ["bash", "-lc", String(customRoot.setting("exec", ""))]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: customRoot.update(text)
      }
    }

    Timer {
      interval: Math.max(1, Number(customRoot.setting("interval", 5))) * 1000
      running: String(customRoot.setting("exec", "")) !== ""
      repeat: true
      triggeredOnStart: true
      onTriggered: root.runProcess(customProc)
    }
  }
}
