import QtQuick
import Quickshell
import "../gustavo.notchbar/MenuBridge.js" as MenuBridge

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false

  Component.onCompleted: {
    MenuBridge.registerMenuPlugin(root)
  }
  Component.onDestruction: {
    MenuBridge.unregisterMenuPlugin(root)
  }

  function open(payloadJson) {
    if (!MenuBridge.openMenu(payloadJson)) {
      Quickshell.execDetached(["omarchy-shell", "omarchy.menu", "summon", payloadJson || "{}"])
    }
  }

  function close() {
    if (!MenuBridge.closeMenu()) {
      Quickshell.execDetached(["omarchy-shell", "omarchy.menu", "close"])
    }
  }

  function toggle(payloadJson) {
    if (!MenuBridge.toggleMenu(payloadJson)) {
      Quickshell.execDetached(["omarchy-shell", "omarchy.menu", "toggle", payloadJson || "{}"])
    }
  }

  function refresh() {
    return MenuBridge.refreshMenu()
  }

  function ping() {
    return "ok"
  }
}
