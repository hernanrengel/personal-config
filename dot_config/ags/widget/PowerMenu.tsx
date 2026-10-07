import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync } from "ags/process"
import { getMonitorState } from "./Bar"

export default function PowerMenu(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    const state = getMonitorState(gdkmonitor)

    const handleAction = (cmd: string) => {
        state.setPowerVisible(false)
        execAsync(cmd).catch(print)
    }

    return (
        <window
            name="power-menu"
            class="PowerMenuWindow"
            gdkmonitor={gdkmonitor}
            anchor={TOP | BOTTOM | LEFT | RIGHT}
            visible={state.powerVisible}
            keymode={Astal.Keymode.ON_DEMAND}
            application={app}
            onKeyPressEvent={(self, event) => {
                const [ok, keyval] = event.get_keyval()
                if (ok && keyval === Gdk.KEY_Escape) {
                    state.setPowerVisible(false)
                }
            }}
        >
            {/* Click outside to close */}
            <eventbox onButtonReleaseEvent={() => state.setPowerVisible(false)} class="power-menu-overlay">
                <box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} hexpand={true} vexpand={true}>
                    <box class="power-menu-card" vertical={true} spacing={20} onButtonReleaseEvent={() => true} onButtonPressEvent={() => true}>
                        <box class="power-menu-header" vertical={false} spacing={8} valign={Gtk.Align.CENTER}>
                            <label class="power-menu-title-icon" label="󰐥" />
                            <label class="power-menu-title" label="System Control" />
                            <box hexpand={true} />
                            <button class="dashboard-close" onClicked={() => state.setPowerVisible(false)}>
                                <label label="󰅖" />
                            </button>
                        </box>

                        <box class="dashboard-separator" />

                        <box class="power-menu-options" spacing={14} vertical={false}>
                            {/* Lock Screen */}
                            <button
                                class="power-btn lock"
                                onClicked={() => handleAction("hyprlock")}
                                tooltipText="Lock Screen"
                            >
                                <box vertical={true} spacing={8} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                                    <label class="power-icon" label="󰌾" />
                                    <label class="power-label" label="Lock" />
                                </box>
                            </button>

                            {/* Suspend */}
                            <button
                                class="power-btn suspend"
                                onClicked={() => handleAction("systemctl suspend")}
                                tooltipText="Suspend System"
                            >
                                <box vertical={true} spacing={8} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                                    <label class="power-icon" label="󰤄" />
                                    <label class="power-label" label="Suspend" />
                                </box>
                            </button>

                            {/* Logout */}
                            <button
                                class="power-btn logout"
                                onClicked={() => handleAction("hyprctl dispatch exit")}
                                tooltipText="Log Out Session"
                            >
                                <box vertical={true} spacing={8} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                                    <label class="power-icon" label="󰍃" />
                                    <label class="power-label" label="Logout" />
                                </box>
                            </button>

                            {/* Reboot */}
                            <button
                                class="power-btn reboot"
                                onClicked={() => handleAction("systemctl reboot")}
                                tooltipText="Reboot System"
                            >
                                <box vertical={true} spacing={8} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                                    <label class="power-icon" label="󰜉" />
                                    <label class="power-label" label="Reboot" />
                                </box>
                            </button>

                            {/* Poweroff */}
                            <button
                                class="power-btn shutdown"
                                onClicked={() => handleAction("systemctl poweroff")}
                                tooltipText="Shutdown System"
                            >
                                <box vertical={true} spacing={8} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                                    <label class="power-icon" label="󰐥" />
                                    <label class="power-label" label="Shutdown" />
                                </box>
                            </button>
                        </box>
                    </box>
                </box>
            </eventbox>
        </window>
    )
}
