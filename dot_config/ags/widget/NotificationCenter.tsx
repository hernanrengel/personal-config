import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import Notifd from "gi://AstalNotifd"
import { getMonitorState } from "./Bar"
import { createComputed, createBinding, With } from "ags"

const notifd = Notifd.get_default()

function NotifItem({ notification }: { notification: Notifd.Notification }) {
    const appName = notification.appName || notification.app_name || "Notification"
    const summary = notification.summary || ""
    const body = notification.body || ""

    return (
        <box class="notif-center-item" vertical={true} spacing={6}>
            <box spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                <icon icon={notification.appIcon || "dialog-information"} class="notif-center-icon" />
                <label class="notif-center-app" label={appName} halign={Gtk.Align.START} hexpand={true} />
                <button class="notif-center-dismiss-btn" onClicked={() => notification.dismiss()}>
                    <label label="󰅖" />
                </button>
            </box>
            <box class="notif-center-content" vertical={true}>
                <label class="notif-center-summary" label={summary} halign={Gtk.Align.START} xalign={0} wrap={true} useMarkup={true} />
                {body && (
                    <label class="notif-center-body" label={body} halign={Gtk.Align.START} xalign={0} wrap={true} useMarkup={true} />
                )}
            </box>
            {notification.actions && notification.actions.length > 0 && (
                <box class="notif-center-actions" spacing={8} vertical={false} halign={Gtk.Align.END}>
                    {notification.actions.map(action => (
                        <button
                            class="notif-center-action-btn"
                            onClicked={() => {
                                notification.invoke(action.id)
                            }}
                        >
                            <label label={action.label} />
                        </button>
                    ))}
                </box>
            )}
        </box>
    )
}

export default function NotificationCenter(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    const state = getMonitorState(gdkmonitor)
    const list = createBinding(notifd, "notifications")

    const handleClearAll = () => {
        const currentList = list() || []
        currentList.forEach(n => n.dismiss())
    }

    const dndEnabled = createBinding(notifd, "dont_disturb")

    return (
        <window
            name="notification-center"
            class="NotificationCenterWindow"
            namespace="dashboard"
            gdkmonitor={gdkmonitor}
            anchor={TOP | BOTTOM | LEFT | RIGHT}
            visible={state.notifVisible}
            keymode={Astal.Keymode.ON_DEMAND}
            application={app}
            onKeyPressEvent={(self, event) => {
                const [ok, keyval] = event.get_keyval()
                if (ok && keyval === Gdk.KEY_Escape) {
                    state.setNotifVisible(false)
                }
            }}
        >
            <eventbox onButtonReleaseEvent={() => state.setNotifVisible(false)} class="notif-center-overlay">
                <box halign={Gtk.Align.CENTER} valign={Gtk.Align.START} margin={8} hexpand={true} vexpand={true}>
                    <box class="notif-center-card" vertical={true} spacing={12} onButtonReleaseEvent={() => true} onButtonPressEvent={() => true}>
                {/* Header */}
                <box class="dashboard-header" vertical={false} spacing={8} valign={Gtk.Align.CENTER}>
                    <label class="dashboard-title-icon" label="󰂚" />
                    <label class="dashboard-title" label="Notifications Center" />
                    <box hexpand={true} />
                    
                    {/* Do Not Disturb Toggle */}
                    <button
                        class={dndEnabled.as(dnd => dnd ? "dnd-btn active" : "dnd-btn")}
                        onClicked={() => { notifd.dont_disturb = !notifd.dont_disturb }}
                        tooltipText="Do Not Disturb"
                    >
                        <label label={dndEnabled.as(dnd => dnd ? "󰂛 DND ON" : "󰂚 DND OFF")} />
                    </button>

                    {/* Clear All Button */}
                    <button class="clear-all-btn" onClicked={handleClearAll} tooltipText="Clear All Notifications">
                        <label label="󰛖 Clear" />
                    </button>

                    <button class="dashboard-close" onClicked={() => state.setNotifVisible(false)}>
                        <label label="󰅖" />
                    </button>
                </box>

                <box class="dashboard-separator" />

                {/* Notifications list */}
                <scrollable class="notif-center-list-scroll" hscroll={Gtk.PolicyType.NEVER} vscroll={Gtk.PolicyType.AUTOMATIC} heightRequest={400}>
                    <box vertical={true} spacing={8} class="notif-center-list-box">
                        <With value={list}>
                            {(items) => (
                                <box vertical={true} spacing={8}>
                                    {(!items || items.length === 0) ? (
                                        <box class="no-notifs" halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} heightRequest={150}>
                                            <label label="No notifications" />
                                        </box>
                                    ) : (
                                        items.map(notification => (
                                            <NotifItem notification={notification} />
                                        ))
                                    )}
                                </box>
                            )}
                        </With>
                    </box>
                </scrollable>
                    </box>
                </box>
            </eventbox>
        </window>
    )
}
