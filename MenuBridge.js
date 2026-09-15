.pragma library

var barInstance = null;
var menuPluginInstance = null;

function registerBar(bar) {
  barInstance = bar;
  if (menuPluginInstance && barInstance) {
    menuPluginInstance.opened = (barInstance.isMenuOpen || barInstance.isSearchOpen);
  }
}

function unregisterBar(bar) {
  if (barInstance === bar) barInstance = null;
}

function registerMenuPlugin(menuPlugin) {
  menuPluginInstance = menuPlugin;
  if (barInstance && menuPluginInstance) {
    menuPluginInstance.opened = (barInstance.isMenuOpen || barInstance.isSearchOpen);
  }
}

function unregisterMenuPlugin(menuPlugin) {
  if (menuPluginInstance === menuPlugin) menuPluginInstance = null;
}

function updateOpened(opened) {
  if (menuPluginInstance) {
    menuPluginInstance.opened = !!opened;
  }
}

function toggleMenu(payloadJson) {
  if (barInstance) {
    if (barInstance.isMenuOpen || barInstance.isSearchOpen) {
      barInstance.closeMenu();
      return true;
    } else {
      return openMenu(payloadJson);
    }
  }
  return false;
}

function openMenu(payloadJson) {
  if (barInstance && typeof barInstance.openMenu === "function") {
    var payload = {};
    try { payload = JSON.parse(payloadJson || "{}"); } catch(e) {}
    var route = payload.menu || payload.initialMenu || "root";
    if (payload.mode === "select" || payload.mode === "input") {
      var island = typeof barInstance.activeCenterIsland === "function" ? barInstance.activeCenterIsland() : barInstance.centerIslandRef;
      if (island) island.openDmenu(payload);
    } else {
      barInstance.openMenu(route);
    }
    return true;
  }
  return false;
}

function closeMenu() {
  if (barInstance && typeof barInstance.closeMenu === "function") {
    barInstance.closeMenu();
    return true;
  }
  return false;
}

function refreshMenu() {
  if (barInstance && barInstance.centerIslandRef && typeof barInstance.centerIslandRef.refreshMenu === "function") {
    return barInstance.centerIslandRef.refreshMenu();
  }
  return "ok";
}
