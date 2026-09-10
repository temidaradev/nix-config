function getBtDevice() {
    var connectedDevices = [];

    var status = {
        active: false,
        message: ""
    }

    for (var i = 0; i < btManager.devices.length; ++i) {
        var device = btManager.devices[i];
        if (device.connected) {
            connectedDevices.push(device);
        }
    }

    if (btManager.bluetoothBlocked) {
        status.active = false;
        status.message = i18n("Disabled");
    } else if (!btManager.bluetoothOperational) {
        if (!btManager.adapters.length) {
            status.active = false;
            status.message = i18n("Unavailable");
        } else {
            status.active = false;
            status.message = i18n("Offline");
        }
    } else if (connectedDevices.length >= 1) {
            status.active = true;
            status.message = connectedDevices[0].name;
    } else {
        status.active = true;
        status.message = i18n("Not Connected");
    }
    return status;
}

function toggleBluetooth()
{
    var enable = !btManager.bluetoothOperational;
    btManager.bluetoothBlocked = !enable;

    for (var i = 0; i < btManager.adapters.length; ++i) {
        var adapter = btManager.adapters[i];
        adapter.powered = enable;
    }
}


function checkInhibition() {
    var inhibited = false;

    if (!NotificationManager.Server.valid) {
        return false;
    }
    var inhibitedUntil = notificationSettings.notificationsInhibitedUntil;
    if (!isNaN(inhibitedUntil.getTime())) {
        inhibited |= (Date.now() < inhibitedUntil.getTime());
    }

    if (notificationSettings.notificationsInhibitedByApplication) {
        inhibited |= true;
    }

    if (notificationSettings.inhibitNotificationsWhenScreensMirrored) {
        inhibited |= notificationSettings.screensMirrored;
    }
    return inhibited;
}

function toggleDnd() {
    if (Funcs.checkInhibition()) {
        notificationSettings.notificationsInhibitedUntil = undefined;
        notificationSettings.revokeApplicationInhibitions();

        // overrules current mirrored screen setup, updates again when screen configuration
        notificationSettings.screensMirrored = false;
        notificationSettings.save();

        return;
    }

    var d = new Date();
    d.setYear(d.getFullYear()+1)

    notificationSettings.notificationsInhibitedUntil = d
    notificationSettings.save()
}

function revokeInhibitions() {
    notificationSettings.notificationsInhibitedUntil = undefined;
    notificationSettings.revokeApplicationInhibitions();
    // overrules current mirrored screen setup, updates again when screen configuration changes
    notificationSettings.screensMirrored = false;

    notificationSettings.save();
}

function toggleRedshiftInhibition() {
    if (!monitor.available) {
        return;
    }
    switch (inhibitor.state) {
    case Redshift.Inhibitor.Inhibiting:
    case Redshift.Inhibitor.Inhibited:
        inhibitor.uninhibit();
        break;
    case Redshift.Inhibitor.Uninhibiting:
    case Redshift.Inhibitor.Uninhibited:
        inhibitor.inhibit();
        break;
    }
}

function volumePercent(volume) {
    return volume / Vol.PulseAudio.NormalVolume * 100
}

function boundVolume(volume) {
    return Math.max(Vol.PulseAudio.MinimalVolume, Math.min(volume, Vol.PulseAudio.NormalVolume));
}

function changeVolumeByPercent(volumeObject, deltaPercent) {
    const oldVolume = volumeObject.volume;
    const oldPercent = volumePercent(oldVolume);
    const targetPercent = oldPercent + deltaPercent;
    const newVolume = boundVolume(Math.round(Vol.PulseAudio.NormalVolume * (targetPercent/100)));
    const newPercent = volumePercent(newVolume);
    volumeObject.muted = newPercent == 0;
    volumeObject.volume = newVolume;
    return newPercent;
}
function volIconName(volume, muted, prefix) {
    if (!prefix) {
        prefix = "audio-volume";
    }
    var icon = null;
    var percent = volume / Vol.PulseAudio.NormalVolume
    if (percent <= 0.0 || muted) {
        icon = prefix + "-muted";
    } else if (percent <= 0.25) {
        icon = prefix + "-low";
    } else if (percent <= 0.75) {
        icon = prefix + "-medium";
    } else {
        icon = prefix + "-high";
    }
    return icon;
}

function getNetworkConnectionName() {
    var status = network.networkStatus.activeConnections;
    var statusParts;

    if(isAirplane){ return i18n("On"); }

    if(status && status !== "Disconnected") {
        statusParts = status.split(":");
        var connectionName = statusParts[1]?.trim().split(" ").slice(2).join(" ");
        return connectionName || i18n("Connected");
    } 

    return i18n("Disconnected");
}