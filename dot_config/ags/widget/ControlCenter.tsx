import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { createBinding, createComputed, Variable, With } from "ags"
import Wp from "gi://AstalWp"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Battery from "gi://AstalBattery"
import Mpris from "gi://AstalMpris"
import { getMonitorState } from "./Bar"

const audio = Wp.get_default()
const network = Network.get_default()
const bluetooth = Bluetooth.get_default()
const mpris = Mpris.get_default()

export default function ControlCenter(gdkmonitor: Gdk.Monitor) {
    const { TOP, RIGHT } = Astal.WindowAnchor
    const state = getMonitorState(gdkmonitor)

    if (!network || !bluetooth || !audio) return <box />
    const wifi = network.wifi
    const speaker = audio.audio.defaultSpeaker!

    // Bindings
    const wifiEnabled = createBinding(wifi, "enabled")
    const btEnabled = createBinding(bluetooth, "isPowered")
    const wifiIcon = createBinding(wifi, "iconName")
    const vol = createBinding(speaker, "volume")
    const isMuted = createBinding(speaker, "mute")
    
    // Computed
    const wifiClass = createComputed(() => `cc-btn wifi-btn ${wifiEnabled() ? "active" : ""}`)
    const wifiLabel = createComputed(() => wifiEnabled() ? (wifi.ssid || "Connected") : "Wi-Fi")
    const btClass = createComputed(() => `cc-btn bt-btn ${btEnabled() ? "active" : ""}`)
    const btIcon = createComputed(() => btEnabled() ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
    const btLabel = createComputed(() => btEnabled() ? "Bluetooth" : "Off")
    const volIcon = createComputed(() => isMuted() ? "󰖁" : "")

    // Mpris Player
    const players = mpris ? createBinding(mpris, "players") : null
    const activePlayer = createComputed(() => {
        if (!players) return null
        const list = players() || []
        const nonMpv = list.filter(p => {
            const name = p.busName || p.bus_name || ""
            return name && !name.includes("mpv")
        })
        const playing = nonMpv.find(p => p.playback_status === Mpris.PlaybackStatus.PLAYING)
        return playing || nonMpv[0] || null
    })
    
    return <window
        name="control-center"
        class="ControlCenterWindow"
        namespace="dashboard"
        gdkmonitor={gdkmonitor}
        anchor={TOP | RIGHT}
        marginRight={12}
        marginTop={6}
        keymode={Astal.Keymode.EXCLUSIVE}
        visible={state.controlCenterVisible}
        application={app}
        onFocusOutEvent={(self) => {
            if (state.setControlCenterVisible) state.setControlCenterVisible(false)
        }}
        onKeyPressEvent={(self, event) => {
            if (event.get_keyval()[1] === Gdk.KEY_Escape) {
                if (state.setControlCenterVisible) state.setControlCenterVisible(false)
            }
        }}>
        
        <box class="dashboard-box control-center-box" vertical spacing={16}>
            {/* Toggles Row */}
            <box spacing={12} homogeneous>
                <button class={wifiClass} onClicked={() => wifi.set_enabled(!wifi.enabled)}>
                    <box spacing={8} halign={Gtk.Align.CENTER}>
                        <icon icon={wifiIcon} />
                        <label label={wifiLabel} truncate />
                    </box>
                </button>
                <button class={btClass} onClicked={() => bluetooth.set_is_powered(!bluetooth.isPowered)}>
                    <box spacing={8} halign={Gtk.Align.CENTER}>
                        <icon icon={btIcon} />
                        <label label={btLabel} truncate />
                    </box>
                </button>
            </box>

            {/* Sliders Box */}
            <box class="cc-sliders" vertical spacing={12}>
                <box spacing={12}>
                    <label class="slider-icon" label={volIcon} />
                    <slider
                        class="vol-slider"
                        hexpand
                        drawValue={false}
                        value={vol}
                        onDragged={({ value }) => speaker.set_volume(value)}
                    />
                </box>
            </box>
            
            {/* Media Player */}
            <With value={activePlayer}>
                {p => {
                    if (!p) return <box />
                    
                    const title = createBinding(p, "title")
                    const artist = createBinding(p, "artist")
                    const status = createBinding(p, "playbackStatus")
                    const cover = createBinding(p, "coverArt")
                    
                    const playIcon = createComputed(() => status() === Mpris.PlaybackStatus.PLAYING ? "󰏤" : "󰐊")
                    const cssCover = createComputed(() => {
                        const art = cover()
                        return art ? `background-image: url('${art}');` : ""
                    })

                    return <box class="cc-media-player" spacing={12}>
                        <box class="media-cover" css={cssCover} />
                        <box vertical valign={Gtk.Align.CENTER} spacing={6} hexpand>
                            <label class="media-title" label={title} halign={Gtk.Align.START} truncate />
                            <label class="media-artist" label={artist} halign={Gtk.Align.START} truncate />
                            <box class="media-controls" halign={Gtk.Align.START} spacing={12}>
                                <button onClicked={() => p.previous()}><label label="󰒮" /></button>
                                <button onClicked={() => p.play_pause()}><label label={playIcon} /></button>
                                <button onClicked={() => p.next()}><label label="󰒭" /></button>
                            </box>
                        </box>
                    </box>
                }}
            </With>
        </box>
    </window>
}
