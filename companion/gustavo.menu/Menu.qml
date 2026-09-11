import QtQuick
import Quickshell

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  function open(payloadJson) {
    Quickshell.execDetached(["omarchy-shell", "omarchy.menu", "toggle", payloadJson || "{}"])
  }

  function close() {
    Quickshell.execDetached(["omarchy-shell", "omarchy.menu", "close"])
  }

  function refresh() {
    Quickshell.execDetached(["omarchy-shell", "omarchy.menu", "refresh"])
    return "ok"
  }

  function ping() {
    return "ok"
  }
}
