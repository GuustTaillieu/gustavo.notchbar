.pragma library

var barInstance = null;
var serviceInstance = null;
var pendingNotifications = [];

function registerBar(bar) {
  barInstance = bar;
  if (serviceInstance && barInstance) {
    barInstance.bridgedNotifService = serviceInstance;
  }
  while (pendingNotifications.length > 0) {
    var notif = pendingNotifications.shift();
    if (barInstance && typeof barInstance.showNotificationData === "function") {
      barInstance.showNotificationData(notif);
    }
  }
}

function unregisterBar(bar) {
  if (barInstance === bar) {
    barInstance = null;
  }
}

function registerService(service) {
  serviceInstance = service;
  if (barInstance) {
    barInstance.bridgedNotifService = service;
  }
}

function unregisterService(service) {
  if (serviceInstance === service) {
    serviceInstance = null;
    if (barInstance) {
      barInstance.bridgedNotifService = null;
    }
  }
}

function getService() {
  return serviceInstance;
}

function hasBar() {
  return barInstance !== null;
}

function dispatchNotification(data) {
  if (barInstance && typeof barInstance.showNotificationData === "function") {
    barInstance.showNotificationData(data);
    return true;
  } else {
    pendingNotifications.push(data);
    if (pendingNotifications.length > 10) pendingNotifications.shift();
    return false;
  }
}

function dismissNotification(key) {
  if (serviceInstance && typeof serviceInstance.closeToast === "function") {
    serviceInstance.closeToast(key, "dismissed", true);
    return true;
  }
  return false;
}

function copyCode(code, key) {
  if (serviceInstance && typeof serviceInstance.copyCode === "function") {
    serviceInstance.copyCode(code, key);
    return true;
  }
  return false;
}

function runExecAction(key, index) {
  if (serviceInstance && typeof serviceInstance.runExecAction === "function") {
    serviceInstance.runExecAction(key, index);
    return true;
  }
  return false;
}

function invokeAction(key, identifier) {
  if (serviceInstance && typeof serviceInstance.invokeAction === "function") {
    serviceInstance.invokeAction(key, identifier);
    return true;
  }
  return false;
}

function actionsOf(key) {
  if (serviceInstance && typeof serviceInstance.actionsOf === "function") {
    return serviceInstance.actionsOf(key, serviceInstance.refsRevision);
  }
  return [];
}
