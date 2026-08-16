pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The shell's notification daemon, standing in for mako.
//
// Two lists come out of this: the log, which is everything still on file and
// what the bell's panel shows, and the popups, which is the short-lived subset
// currently hanging off the bar as toasts. Popups are held by id rather than by
// object so a notification the sender withdraws drops out of both at once
// instead of leaving a dangling reference behind.
Singleton {
    id: root

    // Suppresses toasts only — notifications still land in the log, so nothing
    // is lost while it is on.
    property bool silent: false

    // Ids currently showing as a toast, newest last.
    property var popupIds: []

    // Arrival times, keyed by id, for the "3m ago" line in the panel.
    property var stamps: ({})

    NotificationServer {
        id: server

        // Everything mako advertised, so senders format for us the same way.
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true

        onNotification: notification => {
            // Without this the server drops it the moment this handler
            // returns; the log is the tracked list.
            notification.tracked = true;

            const stamps = root.stamps;
            stamps[notification.id] = Date.now();
            root.stamps = stamps;

            // Do-not-disturb suppresses the toast only — it still lands in the
            // log, so nothing is missed by having been quiet.
            if (root.silent)
                return;

            // Only the last few hang off the bar at once; the rest are waiting
            // in the panel.
            root.popupIds = root.popupIds.concat([notification.id]).slice(-Theme.toastMaxVisible);
        }
    }

    // Newest first: a panel you open to catch up should not make you scroll to
    // find what just arrived.
    readonly property var log: {
        const all = server.trackedNotifications.values.slice();
        all.reverse();
        return all;
    }

    readonly property int count: log.length

    // The toasts, in arrival order, minus anything that has since been closed
    // out from under us.
    readonly property var popups: {
        const live = server.trackedNotifications.values;
        const out = [];

        for (const id of root.popupIds) {
            for (const notification of live) {
                if (notification.id === id) {
                    out.push(notification);
                    break;
                }
            }
        }

        return out;
    }

    readonly property bool hasUrgent: {
        for (const notification of root.log) {
            if (notification.urgency === NotificationUrgency.Critical)
                return true;
        }
        return false;
    }

    function stampOf(notification) {
        return notification ? (root.stamps[notification.id] ?? Date.now()) : Date.now();
    }

    // How long a toast should stay up. A sender's own timeout wins; critical
    // notifications wait for a click.
    function timeoutOf(notification) {
        if (!notification)
            return Theme.toastTimeout;
        if (notification.urgency === NotificationUrgency.Critical)
            return 0;
        if (notification.expireTimeout > 0)
            return notification.expireTimeout;

        return Theme.toastTimeout;
    }

    // Take a toast down without touching the log entry behind it.
    function hidePopup(notification) {
        if (!notification)
            return;

        root.popupIds = root.popupIds.filter(id => id !== notification.id);
    }

    function hideAllPopups() {
        root.popupIds = [];
    }

    // Gone for good: off the bar and out of the panel.
    function dismiss(notification) {
        if (!notification)
            return;

        root.hidePopup(notification);
        notification.dismiss();
    }

    function clear() {
        // dismiss() mutates the tracked list, so the sweep runs over a copy.
        const all = server.trackedNotifications.values.slice();
        root.popupIds = [];
        root.stamps = ({});

        for (const notification of all)
            notification.dismiss();
    }

    function invoke(notification, action) {
        if (!notification || !action)
            return;

        action.invoke();

        // A notification that asked to stay resident is one the sender will
        // update in place, so only the toast goes.
        if (notification.resident)
            root.hidePopup(notification);
        else
            root.dismiss(notification);
    }

    // ─── formatting ──────────────────────────────────────────────────

    function appLabel(notification) {
        if (!notification)
            return "";

        const name = notification.appName || notification.desktopEntry || "";
        return name.length > 0 ? name : "Notification";
    }

    function summaryOf(notification) {
        if (!notification)
            return "";

        const summary = notification.summary || "";
        return summary.length > 0 ? summary : root.appLabel(notification);
    }

    // The body arrives as pango markup when a sender feels like it. Anything
    // that is not a link or an emphasis is stripped rather than shown raw.
    function bodyOf(notification) {
        if (!notification || !notification.body)
            return "";

        return notification.body.replace(/<[^>]*>/g, "").trim();
    }

    function glyphFor(notification) {
        const name = (root.appLabel(notification) + " " + (notification && notification.appIcon ? notification.appIcon : "")).toLowerCase();

        if (name.includes("volume") || name.includes("audio") || name.includes("pipewire"))
            return "󰕾";
        if (name.includes("battery") || name.includes("power") || name.includes("batsignal"))
            return "󰁽";
        if (name.includes("network") || name.includes("nm-") || name.includes("wifi"))
            return "󰤨";
        if (name.includes("bluetooth") || name.includes("blueman"))
            return "󰂯";
        if (name.includes("screenshot") || name.includes("grim") || name.includes("hyprshot"))
            return "󰄄";
        if (name.includes("spotify") || name.includes("music") || name.includes("mpris"))
            return "󰝚";
        if (name.includes("discord") || name.includes("telegram") || name.includes("signal"))
            return "󰭹";
        if (name.includes("mail") || name.includes("thunderbird"))
            return "󰇮";
        if (name.includes("firefox") || name.includes("zen") || name.includes("chrom"))
            return "󰖟";

        return "󰂚";
    }

    // Coarse on purpose — the exact second something arrived is never what you
    // are asking when you open the panel.
    function ageOf(notification, now) {
        const elapsed = Math.max(0, (now - root.stampOf(notification)) / 1000);

        if (elapsed < 60)
            return "now";
        if (elapsed < 3600)
            return Math.floor(elapsed / 60) + "m ago";
        if (elapsed < 86400)
            return Math.floor(elapsed / 3600) + "h ago";

        return Math.floor(elapsed / 86400) + "d ago";
    }
}
