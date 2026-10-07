import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import Notifd from "gi://AstalNotifd"
import { createState, createComputed, createBinding, With } from "ags"

const notifd = Notifd.get_default()

interface PopupList {
    popups: Notifd.Notification[]
    setPopups: (p: Notifd.Notification[]) => void
}

const activePopups = new Map<Gdk.Monitor, {
    list: any
    setList: (p: any[]) => void
}>()

function getMonitorPopups(monitor: Gdk.Monitor) {
    let entry = activePopups.get(monitor)
    if (!entry) {
        const [list, setList] = createState<Notifd.Notification[]>([])
        entry = { list, setList }
        activePopups.set(monitor, entry)
    }
    return entry
}

// Connect the global daemon listener
notifd.connect("notified", (self, id) => {
    // Only show popup if Do Not Disturb is off
    if (notifd.dont_disturb) return

    const notification = notifd.get_notification(id)
    if (notification) {
        // Add popup to all active monitor popup lists
        activePopups.forEach(({ list, setList }) => {
            setList([...list(), notification])
            
            // Auto dismiss after 6 seconds
            setTimeout(() => {
                setList(list().filter(n => n.id !== id))
            }, 6000)
        })
    }
})

// Dismiss when resolved externally
notifd.connect("resolved", (self, id) => {
    activePopups.forEach(({ list, setList }) => {
        setList(list().filter(n => n.id !== id))
    })
})

function NotificationCard({ notification, onClose }: { notification: Notifd.Notification, onClose: () => void }) {
    const appName = notification.appName || notification.app_name || "Notification"
    const summary = notification.summary || ""
    const body = notification.body || ""

    return (
        <box class="notification-popup-card" vertical={true} spacing={8}>
            {/* Header */}
            <box class="notif-header" vertical={false} spacing={8} valign={Gtk.Align.CENTER}>
                <icon icon={notification.appIcon || "dialog-information"} class="notif-app-icon" />
                <label class="notif-app-name" label={appName} halign={Gtk.Align.START} hexpand={true} />
                <button class="notif-close-btn" onClicked={onClose}>
                    <label label="󰅖" />
                </button>
            </box>

            <box class="notif-separator" />

            {/* Content */}
            <box class="notif-content" vertical={false} spacing={12} valign={Gtk.Align.CENTER}>
                {notification.image && (
                    <box class="notif-image-box" valign={Gtk.Align.CENTER}>
                        <icon icon={notification.image} class="notif-image" />
                    </box>
                )}
                <box vertical={true} hexpand={true}>
                    <label class="notif-summary" label={summary} halign={Gtk.Align.START} xalign={0} wrap={true} useMarkup={true} />
                    {body && (
                        <label class="notif-body" label={body} halign={Gtk.Align.START} xalign={0} wrap={true} useMarkup={true} />
                    )}
                </box>
            </box>

            {/* Actions */}
            {notification.actions && notification.actions.length > 0 && (
                <box class="notif-actions" spacing={8} vertical={false} halign={Gtk.Align.END}>
                    {notification.actions.map(action => (
                        <button
                            class="notif-action-btn"
                            onClicked={() => {
                                notification.invoke(action.id)
                                onClose()
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

export default function NotificationPopups(gdkmonitor: Gdk.Monitor) {
    const { TOP, RIGHT } = Astal.WindowAnchor
    const { list, setList } = getMonitorPopups(gdkmonitor)

    return (
        <window
            name={`notification-popups-${gdkmonitor}`}
            class="NotificationPopupsWindow"
            gdkmonitor={gdkmonitor}
            anchor={TOP | RIGHT}
            application={app}
        >
            <box class="notification-popups-box" vertical={true} spacing={8}>
                <With value={list}>
                    {currentPopups => (
                        <box vertical={true} spacing={8}>
                            {currentPopups.map(notification => (
                                <NotificationCard
                                    notification={notification}
                                    onClose={() => setList(list().filter(n => n.id !== notification.id))}
                                />
                            ))}
                        </box>
                    )}
                </With>
            </box>
        </window>
    )
}
