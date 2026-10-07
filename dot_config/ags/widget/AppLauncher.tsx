import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import Apps from "gi://AstalApps"
import { getMonitorState } from "./Bar"
import { createState, createComputed, createBinding, With } from "ags"

export default function AppLauncher(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    const state = getMonitorState(gdkmonitor)

    const apps = new Apps.Apps()
    const [search, setSearch] = createState("")

    const list = createComputed(() => {
        const query = search()
        if (!query) {
            // Sort by frequency of use
            return apps.get_list().sort((a, b) => b.frequency - a.frequency).slice(0, 8)
        }
        return apps.fuzzy_query(query)
    })

    const handleLaunch = (application: Apps.Application) => {
        state.setLauncherVisible(false)
        setSearch("")
        application.launch()
    }

    let entryWidget: Gtk.Entry | null = null

    createComputed(() => {
        if (state.launcherVisible() && entryWidget) {
            setTimeout(() => {
                entryWidget?.grab_focus()
            }, 50)
        }
    })

    return (
        <window
            name="app-launcher"
            class="AppLauncherWindow"
            gdkmonitor={gdkmonitor}
            anchor={TOP | BOTTOM | LEFT | RIGHT}
            visible={state.launcherVisible}
            keymode={Astal.Keymode.ON_DEMAND}
            application={app}
            onKeyPressEvent={(self, event) => {
                const [ok, keyval] = event.get_keyval()
                if (ok && keyval === Gdk.KEY_Escape) {
                    state.setLauncherVisible(false)
                    setSearch("")
                }
            }}
        >
            <eventbox onButtonReleaseEvent={() => { state.setLauncherVisible(false); setSearch("") }} class="app-launcher-overlay">
                <box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} hexpand={true} vexpand={true}>
                    <box class="app-launcher-card" vertical={true} spacing={12} onButtonReleaseEvent={() => true} onButtonPressEvent={() => true}>
                        
                        {/* Search Input */}
                        <box class="search-box" spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                            <label class="search-icon" label="󰍉" />
                            <entry
                                class="search-entry"
                                placeholderText="Search applications..."
                                text={search}
                                hexpand={true}
                                onChanged={(self) => setSearch(self.text)}
                                onActivate={() => {
                                    const currentList = list()
                                    if (currentList && currentList.length > 0) {
                                        handleLaunch(currentList[0])
                                    }
                                }}
                                onRealize={(self) => {
                                    entryWidget = self
                                }}
                            />
                        </box>

                        <box class="dashboard-separator" />

                        {/* Apps List */}
                        <scrollable class="apps-list-scroll" hscroll={Gtk.PolicyType.NEVER} vscroll={Gtk.PolicyType.AUTOMATIC} heightRequest={380}>
                            <box vertical={true} spacing={4} class="apps-list-box">
                                <With value={list}>
                                    {(items) => (
                                        <box vertical={true} spacing={4}>
                                            {(!items || items.length === 0) ? (
                                                <box class="no-results" halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} heightRequest={100}>
                                                    <label label="No matching applications found" />
                                                </box>
                                            ) : (
                                                items.map(application => (
                                                    <button
                                                        class="app-item-btn"
                                                        onClicked={() => handleLaunch(application)}
                                                    >
                                                        <box spacing={12} vertical={false} valign={Gtk.Align.CENTER}>
                                                            <icon icon={application.iconName || "system-run"} class="app-icon" />
                                                            <box vertical={true} valign={Gtk.Align.CENTER}>
                                                                <label class="app-name" label={application.name} halign={Gtk.Align.START} />
                                                                {application.description && (
                                                                    <label class="app-description" label={application.description.substring(0, 60)} halign={Gtk.Align.START} />
                                                                )}
                                                            </box>
                                                        </box>
                                                    </button>
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
