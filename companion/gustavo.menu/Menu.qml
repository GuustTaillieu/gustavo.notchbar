import QtQuick
import Quickshell

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property bool opened: (shell && shell.bar && typeof shell.bar.isMenuOpen !== "undefined")
    ? shell.bar.isMenuOpen
    : false

  function open(payloadJson) {
    if (shell && shell.bar && typeof shell.bar.openMenu === "function") {
      var payload = ({})
      try { payload = JSON.parse(payloadJson || "{}") } catch(e) {}
      var route = payload.menu || payload.initialMenu || "root"
      if (payload.mode === "select" || payload.mode === "input") {
        var island = typeof shell.bar.activeCenterIsland === "function" ? shell.bar.activeCenterIsland() : shell.bar.centerIslandRef
        if (island) island.openDmenu(payload)
      } else {
        shell.bar.openMenu(route)
      }
    } else {
      Quickshell.execDetached(["omarchy-shell", "omarchy.menu", "summon", payloadJson || "{}"])
    }
  }

  function close() {
    if (shell && shell.bar && typeof shell.bar.closeMenu === "function") {
      shell.bar.closeMenu()
    } else {
      Quickshell.execDetached(["omarchy-shell", "omarchy.menu", "close"])
    }
  }

  function refresh() {
    if (shell && shell.bar && shell.bar.centerIslandRef) {
      shell.bar.centerIslandRef.refreshMenu()
    }
    return "ok"
  }

  function ping() {
    return "ok"
  }
}
