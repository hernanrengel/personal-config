import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import { Process } from "ags/process"
import { createState, createComputed, createBinding, onCleanup, With } from "ags"
import GLib from "gi://GLib"
import Hyprland from "gi://AstalHyprland"
import Wp from "gi://AstalWp"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Battery from "gi://AstalBattery"
import PowerProfiles from "gi://AstalPowerProfiles"
import Mpris from "gi://AstalMpris"
import CavaService from "gi://AstalCava"
import Notifd from "gi://AstalNotifd"

const hyprland = Hyprland.get_default()
const audio = Wp.get_default()
const network = Network.get_default()
const bluetooth = Bluetooth.get_default()
const battery = Battery.get_default()
const powerProfiles = PowerProfiles.get_default()
const mpris = Mpris.get_default()
const notifd = Notifd.get_default()

// Shared states for floating windows indexed by monitor
interface MonitorState {
    stateId: number;
    visible: any;
    setVisible: (v: boolean) => void;
    calendarVisible: any;
    setCalendarVisible: (v: boolean) => void;
    audioVisible: any;
    setAudioVisible: (v: boolean) => void;
    connVisible: any;
    setConnVisible: (v: boolean) => void;
    batteryVisible: any;
    setBatteryVisible: (v: boolean) => void;
    launcherVisible: any;
    setLauncherVisible: (v: boolean) => void;
    powerVisible: any;
    setPowerVisible: (v: boolean) => void;
    notifVisible: any;
    setNotifVisible: (v: boolean) => void;
    controlCenterVisible?: any;
    setControlCenterVisible?: (v: boolean) => void;
}

export function getMonitorIndex(monitor: Gdk.Monitor): number {
    try {
        const geom = monitor.get_geometry()
        const monitors = app.get_monitors()
        for (let i = 0; i < monitors.length; i++) {
            const mGeom = monitors[i].get_geometry()
            if (geom.x === mGeom.x && geom.y === mGeom.y && 
                geom.width === mGeom.width && geom.height === mGeom.height) {
                return i
            }
        }
    } catch (e) {
        print("Error getting monitor index:", e)
    }
    return 0
}

const monitorStates = new Map<number, MonitorState>()

export function getMonitorState(monitor: Gdk.Monitor): MonitorState {
    const index = getMonitorIndex(monitor)
    let state = monitorStates.get(index)
    if (!state) {
        const [visible, setVisible] = createState(false)
        const [calendarVisible, setCalendarVisible] = createState(false)
        const [audioVisible, setAudioVisible] = createState(false)
        const [connVisible, setConnVisible] = createState(false)
        const [batteryVisible, setBatteryVisible] = createState(false)
        const [launcherVisible, setLauncherVisible] = createState(false)
        const [powerVisible, setPowerVisible] = createState(false)
        const [notifVisible, setNotifVisible] = createState(false)
        const [controlCenterVisible, setControlCenterVisible] = createState(false)
        const stateId = Math.random()
        state = {
            stateId,
            visible, setVisible,
            calendarVisible, setCalendarVisible,
            audioVisible, setAudioVisible,
            connVisible, setConnVisible,
            batteryVisible, setBatteryVisible,
            launcherVisible, setLauncherVisible,
            powerVisible, setPowerVisible,
            notifVisible, setNotifVisible,
            controlCenterVisible, setControlCenterVisible
        }
        monitorStates.set(index, state)
        console.log(`[AGS State] Created state for monitor index: ${index}, stateId: ${stateId}`)
    }
    return state
}

// Helper to map window class to Nerd Font icon
function getWindowIcon(clientClass: string): string {
    if (!clientClass) return ""
    const cls = clientClass.toLowerCase()
    if (cls.includes("firefox")) return " 󰈹"
    if (cls.includes("chrome") || cls.includes("chromium")) return " 󰊯"
    if (cls.includes("code")) return " 󰨞"
    if (cls.includes("kitty") || cls.includes("alacritty") || cls.includes("foot")) return " 󰆍"
    if (cls.includes("discord") || cls.includes("vesktop")) return " 󰙯"
    if (cls.includes("spotify")) return " 󰓇"
    if (cls.includes("thunar") || cls.includes("nautilus")) return " 󰉋"
    if (cls.includes("obsidian")) return " 󰠮"
    if (cls.includes("telegram")) return " 󰔁"
    return " 󰣆" // Generic Arch/System icon
}

// Clean device names helper functions (English versions)
function cleanSinkName(name: string | null, desc: string | null): string {
    const descLower = (desc || "").toLowerCase()
    const nameLower = (name || "").toLowerCase()
    if (descLower.includes("jbl") || nameLower.includes("jbl")) {
        return "󰋋  JBL Headphones (USB-C)"
    }
    if (descLower.includes("speaker") || nameLower.includes("speaker")) {
        return "󰓃  Laptop Speakers"
    }
    if (nameLower.includes("ga107") || (descLower.includes("hdmi") && !descLower.includes("raptor"))) {
        return "󰍹  HDMI Monitor"
    }
    if (descLower.includes("raptor") && descLower.includes("hdmi")) {
        try {
            const num = (desc || "").split("HDMI / DisplayPort ").pop()?.split(" Output")[0] || ""
            return `󰍹  Intel HDMI/DP ${num}`.trim()
        } catch {
            return "󰍹  Intel HDMI/DP"
        }
    }
    if (descLower.includes("virtual") || nameLower.includes("loopback")) {
        return "󰍬  Virtual Audio (KVM)"
    }
    return (desc || name || "Unknown Device").substring(0, 45)
}

function cleanSourceName(name: string | null, desc: string | null): string {
    const descLower = (desc || "").toLowerCase()
    const nameLower = (name || "").toLowerCase()
    if (descLower.includes("jbl") || nameLower.includes("jbl")) {
        return "󰍬  JBL Microphone (USB-C)"
    }
    if (descLower.includes("redragon") || nameLower.includes("redragon")) {
        return "󰍬  Redragon Camera Mic"
    }
    if (descLower.includes("stereo microphone")) {
        return "󰍬  Internal Microphone (Stereo)"
    }
    if (descLower.includes("digital microphone")) {
        return "󰍬  Internal Digital Mic"
    }
    if (descLower.includes("virtual") || nameLower.includes("loopback")) {
        return "󰍬  Virtual Microphone (KVM)"
    }
    return (desc || name || "Unknown Source").substring(0, 45)
}

// Battery sysfs dir: BAT0 on the old laptop, BAT1 on the G14 — detect the first BAT*
const BAT_DIR = (() => {
    for (const name of ["BAT0", "BAT1", "BAT2"]) {
        const dir = `/sys/class/power_supply/${name}`
        if (GLib.file_test(dir, GLib.FileTest.IS_DIR)) return dir
    }
    return "/sys/class/power_supply/BAT0"
})()

// Battery stats file reader helper
function readBatFile(file: string): string {
    try {
        const [ok, content] = GLib.file_get_contents(`${BAT_DIR}/${file}`)
        if (ok && content) {
            return new TextDecoder().decode(content).trim()
        }
        return ""
    } catch {
        return ""
    }
}

function getBatteryDetails() {
    const capacity = parseInt(readBatFile("capacity") || "0")
    const status = readBatFile("status") || "Unknown"
    const chargeNow = parseInt(readBatFile("charge_now") || "0")
    const chargeFull = parseInt(readBatFile("charge_full") || "1")
    const chargeDes = parseInt(readBatFile("charge_full_design") || "1")
    const voltage = parseInt(readBatFile("voltage_now") || "0") / 1000000
    const current = parseInt(readBatFile("current_now") || "0") / 1000000
    const cycles = readBatFile("cycle_count") || "N/A"
    const tech = readBatFile("technology") || "N/A"
    const mfr = readBatFile("manufacturer") || "N/A"
    const model = readBatFile("model_name") || "N/A"

    const health = chargeDes > 0 ? (chargeFull / chargeDes) * 100 : 0
    const wattage = voltage * current
    
    let timeStr = "N/A"
    if (current > 0.01) {
        if (status === "Discharging") {
            const hours = (chargeNow / 1000000) / current
            const h = Math.floor(hours)
            const m = Math.round((hours - h) * 60)
            timeStr = `${h}h ${m}m remaining`
        } else if (status === "Charging") {
            const remaining = (chargeFull - chargeNow) / 1000000
            const hours = remaining / current
            const h = Math.floor(hours)
            const m = Math.round((hours - h) * 60)
            timeStr = `${h}h ${m}m to full`
        }
    } else if (status === "Full") {
        timeStr = "Full"
    }

    return {
        capacity,
        status,
        health: health.toFixed(1),
        wattage: wattage.toFixed(2),
        voltage: voltage.toFixed(2),
        current: current.toFixed(3),
        cycles,
        tech,
        mfr,
        model,
        timeStr
    }
}

/* ── Island A: Clock & Workspaces ── */
function Workspaces() {
    const workspaceIds = [1, 2, 3, 4, 5]
    const focusedWorkspace = createBinding(hyprland, "focusedWorkspace")
    const clients = createBinding(hyprland, "clients")

    // "clients" solo notifica al abrir/cerrar ventanas; mover una a otro
    // workspace no cambia la lista, así que forzamos el recálculo con un contador.
    const [moves, setMoves] = createState(0)
    const movedId = hyprland.connect("client-moved", () => setMoves(moves() + 1))
    onCleanup(() => hyprland.disconnect(movedId))

    return (
        <box name="workspaces" class="workspaces" vertical={false} spacing={4} valign={Gtk.Align.CENTER}>
            {workspaceIds.map(id => {
                const isFocused = createComputed(() => {
                    const fw = focusedWorkspace()
                    return fw && fw.id === id
                })

                const clientIcons = createComputed(() => {
                    moves()
                    const wsClients = clients().filter(c => c.workspace && c.workspace.id === id)
                    if (wsClients.length === 0) return ""
                    return wsClients.map(c => getWindowIcon(c.class)).join("")
                })

                return (
                    <button
                        class={isFocused.as(focused => focused ? "active" : "")}
                        valign={Gtk.Align.CENTER}
                        onClicked={() => {
                            execAsync(`hyprctl dispatch workspace ${id}`).catch(print)
                        }}
                    >
                        <box spacing={3} vertical={false} valign={Gtk.Align.CENTER}>
                            <label label={createComputed(() => isFocused() ? "●" : "○")} />
                            <label label={clientIcons} />
                        </box>
                    </button>
                )
            })}
        </box>
    )
}

function Clock({ monitor }: { monitor: Gdk.Monitor }) {
    const state = getMonitorState(monitor)
    const time = createPoll("", 1000, "date +%H:%M")

    return (
        <button
            name="clock"
            valign={Gtk.Align.CENTER}
            onClicked={() => state.setCalendarVisible(!state.calendarVisible())}
        >
            <label label={time} />
        </button>
    )
}

/* ── Hardware Monitor Button (Toggles Dashboard) ── */
function HardwareWidget({ monitor }: { monitor: Gdk.Monitor }) {
    const state = getMonitorState(monitor)
    return (
        <button
            name="custom-hw-icon"
            onClicked={() => state.setVisible(!state.visible())}
        >
            <label label="󰘚" />
        </button>
    )
}

/* ── Island Music: Playerctl & Cava ── */
function Cava() {
    const cava = CavaService.get_default()
    if (!cava) return <label label="" />

    // Configure cava settings matching the user's script
    cava.bars = 24
    cava.framerate = 60
    cava.noise_reduction = 0.35
    cava.autosens = true

    const values = createBinding(cava, "values")
    const glyphs = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    const text = createComputed(() => {
        const vals = values() || []
        const chars = vals.map(val => {
            const index = Math.min(Math.floor(val * 8), 7)
            return glyphs[index] || " "
        }).join("")
        return `<span letter_spacing="1024">${chars}</span>`
    })

    return (
        <label 
            name="custom-cava" 
            label={text} 
            useMarkup={true} 
        />
    )
}

function Media() {
    if (!mpris) return <box />
    
    const players = createBinding(mpris, "players")
    const activePlayer = createComputed(() => {
        const list = players() || []
        const nonMpv = list.filter(p => {
            const name = p.busName || p.bus_name || ""
            return name && !name.includes("mpv")
        })
        const playing = nonMpv.find(p => p.playback_status === Mpris.PlaybackStatus.PLAYING)
        return playing || nonMpv[0] || null
    })

    return (
        <With value={activePlayer}>
            {p => {
                if (!p) return <box />
                
                const title = createBinding(p, "title")
                const artist = createBinding(p, "artist")
                const status = createBinding(p, "playbackStatus")
                
                const playIcon = createComputed(() => {
                    return status() === Mpris.PlaybackStatus.PLAYING ? "󰏤" : "󰐊"
                })
                
                const songText = createComputed(() => {
                    const t = title() || ""
                    const a = artist() || ""
                    const full = a ? `󰓇 ${t} - ${a}` : `󰓇 ${t}`
                    return full.length > 20 ? full.substring(0, 20) + "..." : full
                })
                
                return (
                    <box name="island-music" class="music-flat-box" spacing={6} vertical={false} valign={Gtk.Align.CENTER}>
                        <button
                            name="custom-media-prev"
                            onClicked={() => p.previous()}
                        >
                            <label label="󰒮" />
                        </button>
                        
                        <button
                            name="custom-media-playpause"
                            onClicked={() => p.play_pause()}
                        >
                            <label label={playIcon} />
                        </button>
                        
                        <button
                            name="custom-media-next"
                            onClicked={() => p.next()}
                        >
                            <label label="󰒭" />
                        </button>
                        
                        <button
                            name="custom-playerctl"
                            onClicked={() => p.play_pause()}
                            onScrollEvent={(self, event) => {
                                const [ok, direction] = event.get_scroll_direction()
                                if (!ok) return
                                if (direction === Gdk.ScrollDirection.UP) {
                                    p.next()
                                } else if (direction === Gdk.ScrollDirection.DOWN) {
                                    p.previous()
                                }
                            }}
                        >
                            <label label={songText} />
                        </button>

                        <Cava />
                    </box>
                )
            }}
        </With>
    )
}

/* ── Island Utils: Monitor, SuperDrag, Keyboard Backlight ── */
function MonitorToggle() {
    const statusJson = createPoll("", 5000, ["/home/brosso3d/.config/hypr/scripts/toggle-internal-monitor.sh", "--status"])
    const text = statusJson.as(str => {
        try { return JSON.parse(str).text || "󰌢" } catch { return "󰌢" }
    })
    return (
        <button
            name="custom-monitor-toggle"
            onClicked={() => execAsync("/home/brosso3d/.config/hypr/scripts/toggle-internal-monitor.sh --toggle").catch(print)}
        >
            <label label={text} />
        </button>
    )
}

function SuperDrag() {
    const statusText = createPoll("", 5000, ["/home/brosso3d/.config/hypr/scripts/super-drag-status.sh"])
    const text = statusText.as(s => s || "󰍽")
    return (
        <button
            name="custom-super-drag"
            onClicked={() => execAsync("/home/brosso3d/.config/hypr/scripts/toggle-super-drag.sh").catch(print)}
        >
            <label label={text} />
        </button>
    )
}

function KeyboardBacklight() {
    const levelState = createState(0)
    const level = levelState[0]
    const setLevel = levelState[1]

    const updateLevel = () => {
        execAsync(["bash", "-c", "cat /sys/class/leds/asus::kbd_backlight/brightness 2>/dev/null"])
            .then(stdout => setLevel(parseInt(stdout) || 0))
            .catch(print)
        return true
    }

    GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 4, updateLevel)
    // Run once initially
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => { updateLevel(); return false })

    const text = createComputed(() => {
        const l = level()
        if (l === 0) return "󰌹 off"
        if (l === 1) return "󰌹 low"
        if (l === 2) return "󰌹 med"
        if (l === 3) return "󰌹 high"
        return "󰌹 off"
    })

    return (
        <button
            name="custom-kb-backlight"
            onClicked={() => {
                execAsync(["bash", "-c", "~/.config/waybar/scripts/kb-backlight-cycle.sh"])
                    .then(() => updateLevel())
                    .catch(print)
            }}
        >
            <label label={text} />
        </button>
    )
}

function UtilsIsland() {
    return (
        <box name="island-utils" spacing={6} vertical={false} valign={Gtk.Align.CENTER}>
            <MonitorToggle />
            <SuperDrag />
            <KeyboardBacklight />
        </box>
    )
}

/* ── Island C: Audio, Wifi, Bluetooth, Battery, Profiles, Notification, Power ── */
function getVolumeIcon(volume: number, mute: boolean): string {
    if (mute) return "󰝟"
    const vol = volume * 100
    if (vol < 30) return "󰕿"
    if (vol < 70) return "󰖀"
    return "󰕾"
}

// Compact English version of output/input status
function Audio({ monitor }: { monitor: Gdk.Monitor }) {
    const state = getMonitorState(monitor)
    const speaker = audio ? audio.defaultSpeaker : null
    if (!speaker) return <box name="pulseaudio"><label label="󰝟" /></box>

    const volume = createBinding(speaker, "volume")
    const mute = createBinding(speaker, "mute")

    const volText = createComputed(() => {
        const v = volume()
        const m = mute()
        const icon = getVolumeIcon(v, m)
        return m ? "󰝟" : `${Math.round(v * 100)}% ${icon}`
    })

    return (
        <button
            name="pulseaudio"
            onClicked={() => state.setAudioVisible(!state.audioVisible())}
            onButtonReleaseEvent={(self, event) => {
                const [ok, button] = event.get_button()
                if (ok && button === 3) {
                    execAsync("pavucontrol").catch(print)
                }
            }}
            onScrollEvent={(self, event) => {
                const [ok, direction] = event.get_scroll_direction()
                if (!ok) return
                if (direction === Gdk.ScrollDirection.UP) {
                    speaker.volume = Math.min(1, speaker.volume + 0.05)
                } else if (direction === Gdk.ScrollDirection.DOWN) {
                    speaker.volume = Math.max(0, speaker.volume - 0.05)
                }
            }}
        >
            <label label={volText} />
        </button>
    )
}

function WifiConnected({ wifi }: { wifi: any }) {
    const strength = createBinding(wifi, "strength")
    
    const text = createComputed(() => {
        const s = strength()
        let icon = "󰤨"
        if (s < 20) icon = "󰤯"
        else if (s < 40) icon = "󰤟"
        else if (s < 60) icon = "󰤢"
        else if (s < 80) icon = "󰤥"
        return `${s}% ${icon}`
    })
    
    return <label label={text} />
}

// wifi, bluetooth, battery widgets
function Wifi({ monitor }: { monitor: Gdk.Monitor }) {
    const state = getMonitorState(monitor)
    if (!network) return <label label="󰤮" />
    const primary = createBinding(network, "primary")
    const wifi = createBinding(network, "wifi")
    
    return (
        <button
            name="network"
            onClicked={() => state.setConnVisible(!state.connVisible())}
        >
            <With value={primary}>
                {p => {
                    if (p === Network.Primary.WIRED) {
                        return <label label="󰈀" />
                    }
                    return (
                        <box>
                            <With value={wifi}>
                                {w => w ? <WifiConnected wifi={w} /> : <label label="󰤮" />}
                            </With>
                        </box>
                    )
                }}
            </With>
        </button>
    )
}

function BluetoothConnected({ device }: { device: any }) {
    const name = createBinding(device, "name")
    const alias = createBinding(device, "alias")
    return (
        <box spacing={2} vertical={false} valign={Gtk.Align.CENTER}>
            <label label="󰂱" />
            <label label={createComputed(() => alias() || name() || "Connected")} />
        </box>
    )
}

function BluetoothWidget({ monitor }: { monitor: Gdk.Monitor }) {
    const state = getMonitorState(monitor)
    if (!bluetooth) return <label label="󰂲" />
    const isPowered = createBinding(bluetooth, "isPowered")
    const isConnected = createBinding(bluetooth, "isConnected")
    
    const bluetoothState = createComputed(() => {
        if (!isPowered()) return { status: "off" }
        if (isConnected()) {
            const devices = bluetooth.devices || []
            const conn = devices.filter(d => d.connected)
            return { status: "connected", device: conn[0] || null }
        }
        return { status: "on" }
    })

    return (
        <button
            name="custom-bluetooth"
            onClicked={() => state.setConnVisible(!state.connVisible())}
            onButtonReleaseEvent={(self, event) => {
                const [ok, button] = event.get_button()
                if (ok && button === 3) {
                    execAsync("blueman-manager").catch(print)
                }
            }}
        >
            <With value={bluetoothState}>
                {state => {
                    if (state.status === "off") return <label label="󰂲" />
                    if (state.status === "connected") {
                        return state.device ? <BluetoothConnected device={state.device} /> : <label label="󰂱" />
                    }
                    return <label label="󰂯" />
                }}
            </With>
        </button>
    )
}

function PowerProfilesWidget() {
    if (!powerProfiles) return <label label="󰊚" />
    const active = createBinding(powerProfiles, "activeProfile")
    const icon = active.as(p => {
        if (p === "performance") return "󱐋"
        if (p === "power-saver") return "󰌪"
        return "󰊚"
    })
    
    return (
        <button
            name="power-profiles-daemon"
            class={active}
            onClicked={() => execAsync("asusctl profile next").catch(print)}
        >
            <label label={icon} />
        </button>
    )
}

function GPUModeWidget({ monitor }: { monitor: Gdk.Monitor }) {
    const modeState = createState("hybrid")
    const mode = modeState[0]
    const setMode = modeState[1]
    
    const updateMode = () => {
        // supergfxctl (ASUS) on the G14; envycontrol on the old Intel/NVIDIA laptop.
        // execAsync throws synchronously when the binary is missing, so guard with try.
        const cmd = GLib.find_program_in_path("supergfxctl") ? "supergfxctl -g"
            : GLib.find_program_in_path("envycontrol") ? "envycontrol --query"
            : null
        if (!cmd) return true
        try {
            execAsync(cmd)
                .then(stdout => setMode(stdout.trim()))
                .catch(print)
        } catch (e) {
            print(e)
        }
        return true
    }
    
    GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 30, updateMode)
    updateMode()

    const icon = createComputed(() => {
        const cleaned = (mode() || "").toLowerCase()
        if (cleaned === "hybrid") return "󰢮 Hyb"
        if (cleaned === "nvidia" || cleaned === "asusmuxdgpu") return "󰢮 dGPU"
        if (cleaned === "integrated") return "󰘚 Int"
        return "󰘚"
    })
    
    const className = createComputed(() => (mode() || "").toLowerCase())
    const tooltip = createComputed(() => `Graphics Mode: ${mode() || ""}`)

    return (
        <button
            name="custom-gpu-mode"
            class={className}
            tooltipText={tooltip.as(t => t)}
            onClicked={() => {
                execAsync(["notify-send", "GPU Mode", `Current graphics mode: ${mode() || ""}`]).catch(print)
            }}
        >
            <label label={icon} />
        </button>
    )
}









function BatteryWidget({ monitor }: { monitor: Gdk.Monitor }) {
    const state = getMonitorState(monitor)
    if (!battery) return <label label="󰂃" />

    const percentage = createBinding(battery, "percentage")
    const charging = createBinding(battery, "charging")

    const batteryText = createComputed(() => {
        const p = percentage()
        const isCharging = charging()
        const pct = Math.round(p * 100)
        
        let icon = "󰁹"
        if (isCharging) {
            const chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
            const idx = Math.min(Math.floor(p * 10), 9)
            icon = chargingIcons[idx]
        } else {
            const dischargeIcons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
            const idx = Math.min(Math.floor(p * 10), 10)
            icon = dischargeIcons[idx]
        }
        
        return `${pct}% ${icon}`
    })

    const batteryClass = createComputed(() => {
        const p = percentage()
        const isCharging = charging()
        if (p < 0.25 && !isCharging) return "critical"
        if (p < 0.35 && !isCharging) return "warning"
        return ""
    })

    return (
        <button
            name="battery"
            class={batteryClass}
            onClicked={() => state.setBatteryVisible(!state.batteryVisible())}
        >
            <label label={batteryText} />
        </button>
    )
}

function NotificationBell({ monitor }: { monitor: Gdk.Monitor }) {
    const state = getMonitorState(monitor)
    const list = createBinding(notifd, "notifications")
    const dnd = createBinding(notifd, "dont_disturb")

    const count = createComputed(() => (list() || []).length)
    const bellClass = createComputed(() => {
        if (dnd()) return "dnd"
        return count() > 0 ? "active" : "idle"
    })

    const text = createComputed(() => {
        if (dnd()) return "󰂛"
        return count() > 0 ? `󰂚 (${count()})` : "󰂚"
    })

    return (
        <button
            name="custom-notif"
            class={bellClass}
            onClicked={() => state.setNotifVisible(!state.notifVisible())}
            onButtonReleaseEvent={(self, event) => {
                const [ok, button] = event.get_button()
                if (ok && button === 3) {
                    notifd.dont_disturb = !notifd.dont_disturb
                }
            }}
        >
            <label label={text} />
        </button>
    )
}

function PowerButton({ monitor }: { monitor: Gdk.Monitor }) {
    const state = getMonitorState(monitor)
    return (
        <button
            name="custom-power"
            onClicked={() => state.setPowerVisible(!state.powerVisible())}
        >
            <label label="󰐥" />
        </button>
    )
}

/* ── Single Center Island Droplet (Unclipped full-width window) ── */
export default function Bar(gdkmonitor: Gdk.Monitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

    // State to track the dynamic width of the center island
    const [islandWidth, setIslandWidth] = createState(0)

    // Dynamic presence of media elements inside the island
    const mprisPlayers = mpris ? createBinding(mpris, "players") : null
    const hasMedia = createComputed(() => {
        if (!mprisPlayers) return false
        const list = mprisPlayers() || []
        const nonMpv = list.filter(p => {
            const name = p.busName || p.bus_name || ""
            return name && !name.includes("mpv")
        })
        return nonMpv.length > 0
    })

    return (
        <window
            class="BarWindow"
            namespace="bar"
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={TOP | LEFT | RIGHT}
            application={app}
        >
            <box class="glassy-premium-bar" halign={Gtk.Align.FILL} hexpand={true} vertical={false} valign={Gtk.Align.START}>
                <centerbox 
                    halign={Gtk.Align.FILL} 
                    hexpand={true} 
                    vertical={false}
                    startWidget={
                        <box class="bar-left" halign={Gtk.Align.START} spacing={16} vertical={false} valign={Gtk.Align.CENTER}>
                            <Workspaces />
                            <With value={hasMedia}>
                                {hm => hm ? (
                                    <box><Media /></box>
                                ) : <box visible={false} />}
                            </With>
                        </box>
                    }
                    centerWidget={
                        <box class="bar-center" halign={Gtk.Align.CENTER} vertical={false} valign={Gtk.Align.CENTER}>
                            <Clock monitor={gdkmonitor} />
                        </box>
                    }
                    endWidget={
                        <box class="bar-right" halign={Gtk.Align.END} spacing={20} vertical={false} valign={Gtk.Align.CENTER}>
                            <box spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                                <HardwareWidget monitor={gdkmonitor} />
                                <GPUModeWidget monitor={gdkmonitor} />
                            </box>
                            <box spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                                <Audio monitor={gdkmonitor} />
                                <Wifi monitor={gdkmonitor} />
                                <BluetoothWidget monitor={gdkmonitor} />
                            </box>
                            <box spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                                <PowerProfilesWidget />
                                <BatteryWidget monitor={gdkmonitor} />
                            </box>
                            <box spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                                <UtilsIsland />
                                <NotificationBell monitor={gdkmonitor} />
                                <PowerButton monitor={gdkmonitor} />
                            </box>
                        </box>
                    }
                />
            </box>
        </window>
    )
}

/* ── Hardware Dashboard Stat Row ── */
function StatRow({ name, icon, value, label }: { name: string, icon: string, value: any, label: any }) {
    return (
        <box class="stat-row" spacing={12} vertical={false} valign={Gtk.Align.CENTER}>
            <label class="stat-icon" label={icon} />
            <box vertical={true} hexpand={true}>
                <box vertical={false} valign={Gtk.Align.CENTER}>
                    <label class="stat-name" label={name} />
                    <box hexpand={true} />
                    <label class="stat-value" label={label} />
                </box>
                <levelbar class="stat-bar" value={value} />
            </box>
        </box>
    )
}

/* ── Hardware Dashboard independent floating window ── */
export function HardwareDashboard(gdkmonitor: Gdk.Monitor) {
    const { TOP } = Astal.WindowAnchor
    const state = getMonitorState(gdkmonitor)

    // CPU, Memory, GPU, Temperature polled values
    const cpuVal = createPoll(0, 3000, ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8}'"], stdout => parseFloat(stdout) / 100)
    const memVal = createPoll(0, 3000, ["bash", "-c", "free | awk '/Mem:/ {print $3/$2}'"], stdout => parseFloat(stdout))
    // iGPU (AMD): busy % straight from sysfs, no cost
    const igpuVal = createPoll(0, 4000, ["bash", "-c", "for c in /sys/class/drm/card[0-9]*; do [ \"$(cat $c/device/vendor 2>/dev/null)\" = 0x1002 ] && cat $c/device/gpu_busy_percent && exit; done; echo 0"], stdout => parseFloat(stdout) / 100)
    // dGPU (NVIDIA): nvidia-smi wakes the card from runtime suspend, so only call it
    // when sysfs says it is already active; -1 = sleeping
    const gpuVal = createPoll(-1, 4000, ["bash", "-c", "for d in /sys/bus/pci/devices/*; do [ \"$(cat $d/vendor)\" = 0x10de ] && [ \"$(cat $d/class)\" = 0x030000 -o \"$(cat $d/class)\" = 0x030200 ] || continue; if [ \"$(cat $d/power/runtime_status)\" = active ]; then v=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null); echo \"${v:-0}\"; else echo -1; fi; exit; done; echo -1"], stdout => parseFloat(stdout) / 100)
    const tempVal = createPoll(0, 4000, ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp"], stdout => parseFloat(stdout) / 1000)

    const cpuLabel = createComputed(() => `${Math.round(cpuVal() * 100)}%`)
    const memLabel = createComputed(() => `${Math.round(memVal() * 100)}%`)
    const igpuLabel = createComputed(() => `${Math.round(igpuVal() * 100)}%`)
    const gpuLabel = createComputed(() => gpuVal() < 0 ? "Sleeping" : `${Math.round(gpuVal() * 100)}%`)
    const tempLabel = createComputed(() => `${Math.round(tempVal())}°C`)

    return (
        <window
            name="hardware-dashboard"
            class="HardwareDashboard"
            namespace="dashboard"
            gdkmonitor={gdkmonitor}
            anchor={TOP | Astal.WindowAnchor.RIGHT}
            marginRight={415}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={state.visible}
            application={app}
            onFocusOutEvent={() => {
                state.setVisible(false)
                return false
            }}
        >
            <box class="dashboard-card" vertical={true} spacing={12}>
                <box class="dashboard-header" vertical={false} spacing={8} valign={Gtk.Align.CENTER}>
                    <label class="dashboard-title-icon" label="󰘚" />
                    <label class="dashboard-title" label="System Status" />
                    <box hexpand={true} />
                    <button class="dashboard-close" onClicked={() => state.setVisible(false)}>
                        <label label="󰅖" />
                    </button>
                </box>

                <box class="dashboard-separator" />

                <box class="dashboard-stats" vertical={true} spacing={12}>
                    <StatRow name="Processor (CPU)" icon="󰻠" value={cpuVal} label={cpuLabel} />
                    <StatRow name="Memory (RAM)" icon="󰍛" value={memVal} label={memLabel} />
                    <StatRow name="iGPU (Radeon)" icon="󰾲" value={igpuVal} label={igpuLabel} />
                    <StatRow name="dGPU (NVIDIA)" icon="󰢮" value={gpuVal.as(v => Math.max(v, 0))} label={gpuLabel} />
                    <StatRow name="Temperature" icon="󰔏" value={tempVal.as(t => t / 100)} label={tempLabel} />
                </box>

                <box class="dashboard-separator" />

                {/* Quick actions inside the dashboard */}
                <box class="dashboard-actions" spacing={16} vertical={false} halign={Gtk.Align.CENTER}>
                    <button
                        class="action-btn"
                        onClicked={() => {
                            state.setVisible(false)
                            execAsync("/home/brosso3d/.local/bin/stats-popup.sh").catch(print)
                        }}
                    >
                        <box spacing={6} vertical={false} valign={Gtk.Align.CENTER}>
                            <label label="󰋊" />
                            <label label="Details" />
                        </box>
                    </button>

                    <button
                        class="action-btn"
                        onClicked={() => execAsync(["bash", "-c", "~/.config/waybar/scripts/gpu-mode-cycle.sh"]).catch(print)}
                    >
                        <box spacing={6} vertical={false} valign={Gtk.Align.CENTER}>
                            <label label="󰾲" />
                            <label label="GPU Mode" />
                        </box>
                    </button>
                </box>
            </box>
        </window>
    )
}

// Helper interface and function to parse the raw agenda text output from check_calendar.mjs
interface AgendaEvent {
    time: string;
    summary: string;
    location: string;
}

interface AgendaDay {
    dayName: string;
    events: AgendaEvent[];
}

function parseAgendaText(text: string): AgendaDay[] {
    const lines = text.split("\n");
    const days: AgendaDay[] = [];
    let currentDay: AgendaDay | null = null;

    for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;

        // If it's a day header (starts with day name like LUNES, MARTES, etc. and has no divider)
        if (!line.startsWith(" ") && !line.includes(" — ")) {
            currentDay = {
                dayName: trimmed,
                events: []
            };
            days.push(currentDay);
        } else if (currentDay && trimmed.includes(" — ")) {
            const parts = trimmed.split(" — ");
            const time = parts[0].trim();
            const rest = parts.slice(1).join(" — ").trim();

            let summary = rest;
            let location = "";

            if (rest.includes(" @ ")) {
                const subparts = rest.split(" @ ");
                summary = subparts[0].trim();
                location = subparts.slice(1).join(" @ ").trim();
                location = location.replace(/\s*\[Calendar\]\s*$/, "");
            } else {
                summary = summary.replace(/\s*\[Calendar\]\s*$/, "");
            }

            currentDay.events.push({ time, summary, location });
        }
    }
    return days;
}

/* ── Calendar Dashboard independent floating window ── */
export function CalendarDashboard(gdkmonitor: Gdk.Monitor) {
    const { TOP } = Astal.WindowAnchor
    const state = getMonitorState(gdkmonitor)

    // Polled values for the large clock and full date
    const largeTime = createPoll("", 1000, "date +%H:%M:%S")
    const fullDate = createPoll("", 60000, ["bash", "-c", "date +'%A, %B %d'"])
    const capitalizedDate = createComputed(() => {
        const d = fullDate()
        if (!d) return ""
        return d.charAt(0).toUpperCase() + d.slice(1)
    })

    // Google Calendar agenda state
    const [agendaText, setAgendaText] = createState("Cargando agenda de Google Calendar...")
    const [isRefreshing, setIsRefreshing] = createState(false)

    const fetchAgenda = () => {
        setIsRefreshing(true)
        execAsync(["bash", "-c", "cd /home/brosso3d/scripts && node check_calendar.mjs | sed -n '/===== Próximos 7 días =====/,$p' | tail -n +3"])
            .then(stdout => {
                setAgendaText(stdout.trim() || "No hay eventos próximos en los siguientes 7 días.")
                setIsRefreshing(false)
            })
            .catch(err => {
                setAgendaText("Error al cargar la agenda. Revisa tu token o conexión.")
                setIsRefreshing(false)
            })
    }

    // Cargar la primera vez
    fetchAgenda()

    // Actualizar automáticamente cada 15 minutos (900000 ms)
    const intervalId = setInterval(fetchAgenda, 900000)

    // Limpiar intervalo al desmontar
    onCleanup(() => clearInterval(intervalId))

    return (
        <window
            name="calendar-dashboard"
            class="CalendarDashboard"
            namespace="dashboard"
            gdkmonitor={gdkmonitor}
            anchor={TOP}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={state.calendarVisible}
            application={app}
            onFocusOutEvent={() => {
                state.setCalendarVisible(false)
                return false
            }}
        >
            <box class="calendar-card" vertical={false} spacing={16}>
                {/* Left side: Clock and GTK Calendar */}
                <box vertical={true} spacing={12}>
                    <box class="calendar-header" vertical={true} spacing={4} halign={Gtk.Align.CENTER}>
                        <label class="calendar-large-time" label={largeTime} />
                        <label class="calendar-full-date" label={capitalizedDate} />
                    </box>

                    <box class="calendar-separator" />

                    <box class="calendar-body" halign={Gtk.Align.CENTER}>
                        <Gtk.Calendar class="calendar-widget" showDetails={false} />
                    </box>
                </box>

                {/* Vertical Divider */}
                <box class="calendar-vertical-separator" />

                {/* Right side: Google Calendar Agenda */}
                <box vertical={true} spacing={8} widthRequest={320}>
                    <box vertical={false} spacing={6} valign={Gtk.Align.CENTER}>
                        <label class="section-title" label="AGENDA DE TRABAJO" halign={Gtk.Align.START} />
                        <box hexpand={true} />
                        <button
                            class={createComputed(() => isRefreshing() ? "refresh-btn refreshing" : "refresh-btn")}
                            onClicked={() => fetchAgenda()}
                            tooltipText="Sincronizar calendario"
                        >
                            <label label={createComputed(() => isRefreshing() ? "󱍸" : "󰑐")} />
                        </button>
                    </box>
                    
                    <scrollable 
                        class="agenda-scroll" 
                        hscroll={Gtk.PolicyType.NEVER} 
                        vscroll={Gtk.PolicyType.AUTOMATIC} 
                        vexpand={true}
                        heightRequest={280}
                    >
                        <box vertical={true} spacing={12}>
                            <With value={createComputed(() => parseAgendaText(agendaText()))}>
                                {days => (
                                    <box vertical={true} spacing={12}>
                                        {(days || []).map(day => (
                                            <box vertical={true} spacing={6}>
                                                {/* Day Header */}
                                                <label class="agenda-day-header" label={day.dayName} halign={Gtk.Align.START} />
                                                
                                                {/* Events List */}
                                                {(day.events || []).map(event => (
                                                    <box class="agenda-event-item" vertical={false} spacing={8} valign={Gtk.Align.START}>
                                                        <label class="agenda-event-dot" label="•" />
                                                        <box vertical={true} spacing={2} hexpand={true}>
                                                            <label class="agenda-event-time" label={event.time} halign={Gtk.Align.START} />
                                                            <label class="agenda-event-summary" label={event.summary} halign={Gtk.Align.START} wrap={true} xalign={0} />
                                                            {event.location ? (
                                                                <button 
                                                                    class="agenda-event-link" 
                                                                    onClicked={() => execAsync(["xdg-open", event.location]).catch(print)}
                                                                    tooltipText="Hacer clic para abrir reunión en el navegador"
                                                                >
                                                                    <label label="󰅟 Enlace de reunión" halign={Gtk.Align.START} />
                                                                </button>
                                                            ) : <box visible={false} />}
                                                        </box>
                                                    </box>
                                                ))}
                                            </box>
                                        ))}
                                    </box>
                                )}
                            </With>
                        </box>
                    </scrollable>
                </box>
            </box>
        </window>
    )
}

/* ── Audio Dashboard independent floating window ── */
export function AudioDashboard(gdkmonitor: Gdk.Monitor) {
    const { TOP } = Astal.WindowAnchor
    const state = getMonitorState(gdkmonitor)

    // Sinks and Sources reactive lists from the get_audio() object
    const wpAudio = audio ? audio.get_audio() : null

    const [speakersList, setSpeakersList] = createState(wpAudio ? wpAudio.get_speakers() || [] : [])
    if (wpAudio) {
        wpAudio.connect("speaker-added", () => setSpeakersList(wpAudio.get_speakers() || []))
        wpAudio.connect("speaker-removed", () => setSpeakersList(wpAudio.get_speakers() || []))
    }

    const [micsList, setMicsList] = createState(wpAudio ? wpAudio.get_microphones() || [] : [])
    if (wpAudio) {
        wpAudio.connect("microphone-added", () => setMicsList(wpAudio.get_microphones() || []))
        wpAudio.connect("microphone-removed", () => setMicsList(wpAudio.get_microphones() || []))
    }

    const defaultSpeaker = createBinding(audio, "default-speaker")
    const defaultMicrophone = createBinding(audio, "default-microphone")

    // Filter output speakers (exclude raptor hdmi unless active)
    const filteredSpeakers = createComputed(() => {
        const list = speakersList()
        const def = defaultSpeaker()
        return list.filter(s => {
            const desc = s.description || ""
            const isIntelHdmi = desc.toLowerCase().includes("raptor") && desc.toLowerCase().includes("hdmi")
            return !isIntelHdmi || (def && s.name === def.name)
        })
    })

    return (
        <window
            name="audio-dashboard"
            class="AudioDashboard"
            namespace="dashboard"
            gdkmonitor={gdkmonitor}
            anchor={TOP | Astal.WindowAnchor.RIGHT}
            marginRight={250}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={state.audioVisible}
            application={app}
            onFocusOutEvent={() => {
                state.setAudioVisible(false)
                return false
            }}
        >
            <box class="audio-card" vertical={true} spacing={12}>
                {/* Header */}
                <box class="dashboard-header" vertical={false} spacing={8} valign={Gtk.Align.CENTER}>
                    <label class="dashboard-title-icon" label="󰓃" />
                    <label class="dashboard-title" label="Audio Control" />
                    <box hexpand={true} />
                    <button class="dashboard-close" onClicked={() => state.setAudioVisible(false)}>
                        <label label="󰅖" />
                    </button>
                </box>

                <box class="dashboard-separator" />

                {/* ── OUTPUT SECTION ── */}
                <With value={defaultSpeaker}>
                    {speaker => {
                        if (!speaker) return <box />
                        const volume = createBinding(speaker, "volume")
                        const mute = createBinding(speaker, "mute")
                        const icon = createComputed(() => getVolumeIcon(volume(), mute()))
                        const pctLabel = createComputed(() => `${Math.round(volume() * 100)}%`)

                        return (
                            <box vertical={true} spacing={8}>
                                <label class="section-title" label="OUTPUT DEVICE" halign={Gtk.Align.START} />
                                
                                <box spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                                    <button
                                        class={createComputed(() => mute() ? "mute-btn muted" : "mute-btn")}
                                        onClicked={() => { speaker.mute = !speaker.mute }}
                                    >
                                        <label label={icon} />
                                    </button>
                                    <slider
                                        class="vol-slider"
                                        hexpand={true}
                                        value={volume}
                                        onDragged={(self) => { speaker.volume = self.value }}
                                    />
                                    <label class="volume-label" label={pctLabel} />
                                </box>

                                {/* Out Sinks List */}
                                <box class="device-list" vertical={true} spacing={4}>
                                    <With value={filteredSpeakers}>
                                        {list => (
                                            <box vertical={true} spacing={4}>
                                                {(list || []).map(s => {
                                                    const isActive = createBinding(s, "is_default")
                                                    const cleanName = cleanSinkName(s.name, s.description || "")
                                                    return (
                                                        <button
                                                            class={createComputed(() => isActive() ? "device-btn active" : "device-btn")}
                                                            onClicked={() => { s.is_default = true }}
                                                        >
                                                            <label label={cleanName} halign={Gtk.Align.START} />
                                                        </button>
                                                    )
                                                })}
                                            </box>
                                        )}
                                    </With>
                                </box>
                            </box>
                        )
                    }}
                </With>

                <box class="dashboard-separator" />

                {/* ── INPUT SECTION ── */}
                <With value={defaultMicrophone}>
                    {mic => {
                        if (!mic) return <box />
                        const volume = createBinding(mic, "volume")
                        const mute = createBinding(mic, "mute")
                        const icon = createComputed(() => mute() ? "󰍭" : "󰍬")
                        const pctLabel = createComputed(() => `${Math.round(volume() * 100)}%`)

                        return (
                            <box vertical={true} spacing={8}>
                                <label class="section-title" label="MICROPHONE / INPUT" halign={Gtk.Align.START} />

                                <box spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                                    <button
                                        class={createComputed(() => mute() ? "mute-btn muted" : "mute-btn")}
                                        onClicked={() => { mic.mute = !mic.mute }}
                                    >
                                        <label label={icon} />
                                    </button>
                                    <slider
                                        class="vol-slider"
                                        hexpand={true}
                                        value={volume}
                                        onDragged={(self) => { mic.volume = self.value }}
                                    />
                                    <label class="volume-label" label={pctLabel} />
                                </box>

                                {/* In Sources List */}
                                <box class="device-list" vertical={true} spacing={4}>
                                    <With value={micsList}>
                                        {list => (
                                            <box vertical={true} spacing={4}>
                                                {(list || []).map(m => {
                                                    const isActive = createBinding(m, "is_default")
                                                    const cleanName = cleanSourceName(m.name, m.description || "")
                                                    return (
                                                        <button
                                                            class={createComputed(() => isActive() ? "device-btn active" : "device-btn")}
                                                            onClicked={() => { m.is_default = true }}
                                                        >
                                                            <label label={cleanName} halign={Gtk.Align.START} />
                                                        </button>
                                                    )
                                                })}
                                            </box>
                                        )}
                                    </With>
                                </box>
                            </box>
                        )
                    }}
                </With>

                <box class="dashboard-separator" />

                {/* Footer mixer shortcut */}
                <button
                    class="action-btn"
                    onClicked={() => {
                        state.setAudioVisible(false)
                        execAsync("pavucontrol").catch(print)
                    }}
                >
                    <box spacing={6} vertical={false} valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER}>
                        <label label="󰓃" />
                        <label label="Advanced Mixer (Pavucontrol)" />
                    </box>
                </button>
            </box>
        </window>
    )
}

/* ── Connectivity Dashboard independent floating window ── */
export function ConnectivityDashboard(gdkmonitor: Gdk.Monitor) {
    const { TOP } = Astal.WindowAnchor
    const state = getMonitorState(gdkmonitor)

    if (!network || !network.wifi || !bluetooth) return <box />

    const wifi = network.wifi
    const wifiEnabled = createBinding(wifi, "enabled")
    const activeAP = createBinding(wifi, "activeAccessPoint")
    const accessPoints = createBinding(wifi, "accessPoints")

    const sortedAPs = createComputed(() => {
        const list = accessPoints() || []
        const active = activeAP()
        return list
            .filter(ap => ap.ssid && (!active || ap.ssid !== active.ssid))
            .sort((a, b) => b.strength - a.strength)
            .slice(0, 4)
    })

    const btEnabled = createBinding(bluetooth, "isPowered")
    const [btDevices, setBtDevices] = createState(bluetooth.devices || [])
    bluetooth.connect("device-added", () => setBtDevices(bluetooth.devices || []))
    bluetooth.connect("device-removed", () => setBtDevices(bluetooth.devices || []))

    // Filter paired devices to show in the list
    const pairedDevices = createComputed(() => {
        const list = btDevices()
        return list.filter(d => d.paired)
    })

    return (
        <window
            name="connectivity-dashboard"
            class="ConnectivityDashboard"
            namespace="dashboard"
            gdkmonitor={gdkmonitor}
            anchor={TOP | Astal.WindowAnchor.RIGHT}
            marginRight={210}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={state.connVisible}
            application={app}
            onFocusOutEvent={() => {
                state.setConnVisible(false)
                return false
            }}
        >
            <box class="conn-card" vertical={true} spacing={12}>
                {/* Header */}
                <box class="dashboard-header" vertical={false} spacing={8} valign={Gtk.Align.CENTER}>
                    <label class="dashboard-title-icon" label="󰤨" />
                    <label class="dashboard-title" label="Connectivity" />
                    <box hexpand={true} />
                    <button class="dashboard-close" onClicked={() => state.setConnVisible(false)}>
                        <label label="󰅖" />
                    </button>
                </box>

                <box class="dashboard-separator" />

                {/* ── WI-FI SECTION ── */}
                <box class="conn-section" vertical={true} spacing={8}>
                    <box vertical={false} valign={Gtk.Align.CENTER}>
                        <label class="section-title" label="WI-FI NETWORK" />
                        <box hexpand={true} />
                        <button
                            class={wifiEnabled.as(enabled => enabled ? "toggle-btn active" : "toggle-btn")}
                            onClicked={() => { wifi.enabled = !wifi.enabled }}
                        >
                            <label label={wifiEnabled.as(enabled => enabled ? "ON" : "OFF")} />
                        </button>
                    </box>

                    {/* Current SSID info */}
                    <With value={wifiEnabled}>
                        {enabled => enabled ? (
                            <box vertical={true} spacing={6}>
                                <With value={activeAP}>
                                    {ap => ap ? (
                                        <box class="active-connection" spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                                            <label class="conn-icon connected" label="󰤨" />
                                            <box vertical={true}>
                                                <label class="conn-name connected" label={ap.ssid || "Connected"} halign={Gtk.Align.START} />
                                                <label class="conn-status" label={`${ap.strength}% strength`} halign={Gtk.Align.START} />
                                            </box>
                                        </box>
                                    ) : (
                                        <label class="conn-status" label="Not Connected" halign={Gtk.Align.START} />
                                    )}
                                </With>

                                {/* AP scan list */}
                                <box class="device-list" vertical={true} spacing={4}>
                                    <With value={sortedAPs}>
                                        {list => (
                                            <box vertical={true} spacing={4}>
                                                {(list || []).map(ap => (
                                                    <button
                                                        class="device-btn"
                                                        onClicked={() => {
                                                            execAsync(["nmcli", "device", "wifi", "connect", ap.ssid]).catch(print)
                                                        }}
                                                    >
                                                        <box spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                                                            <label label="󰤢" />
                                                            <label label={ap.ssid} />
                                                            <box hexpand={true} />
                                                            <label class="conn-status" label={`${ap.strength}%`} />
                                                        </box>
                                                    </button>
                                                ))}
                                            </box>
                                        )}
                                    </With>
                                </box>
                            </box>
                        ) : (
                            <label class="conn-status" label="Wi-Fi is disabled" halign={Gtk.Align.START} />
                        )}
                    </With>

                    {/* Footer WiFi action */}
                    <button
                        class="action-btn"
                        onClicked={() => {
                            state.setConnVisible(false)
                            execAsync("rofi-wifi-menu").catch(print)
                        }}
                    >
                        <box spacing={6} vertical={false} valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER}>
                            <label label="󰤨" />
                            <label label="More Wi-Fi Networks..." />
                        </box>
                    </button>
                </box>

                <box class="dashboard-separator" />

                {/* ── BLUETOOTH SECTION ── */}
                <box class="conn-section" vertical={true} spacing={8}>
                    <box vertical={false} valign={Gtk.Align.CENTER}>
                        <label class="section-title" label="BLUETOOTH DEVICES" />
                        <box hexpand={true} />
                        <button
                            class={btEnabled.as(enabled => enabled ? "toggle-btn active" : "toggle-btn")}
                            onClicked={() => { bluetooth.isPowered = !bluetooth.isPowered }}
                        >
                            <label label={btEnabled.as(enabled => enabled ? "ON" : "OFF")} />
                        </button>
                    </box>

                    <With value={btEnabled}>
                        {enabled => enabled ? (
                            <box vertical={true} spacing={6}>
                                <box class="device-list" vertical={true} spacing={4}>
                                    <With value={pairedDevices}>
                                        {list => (list || []).length > 0 ? (
                                            <box vertical={true} spacing={4}>
                                                {(list || []).map(d => {
                                                    const connected = createBinding(d, "connected")
                                                    const icon = connected.as(c => c ? "󰂱" : "󰂯")
                                                    const cleanAlias = d.alias || d.name || "Unknown Device"

                                                     return (
                                                        <button
                                                            class={connected.as(c => c ? "device-btn active" : "device-btn")}
                                                            onClicked={() => {
                                                                if (d.connected) {
                                                                    d.disconnect_device().catch(print)
                                                                } else {
                                                                    d.connect_device().catch(print)
                                                                }
                                                            }}
                                                        >
                                                            <box spacing={8} vertical={false} valign={Gtk.Align.CENTER}>
                                                                <label label={icon} />
                                                                <label label={cleanAlias} />
                                                                <box hexpand={true} />
                                                                <label class="conn-status" label={connected.as(c => c ? "Connected" : "Disconnected")} />
                                                            </box>
                                                        </button>
                                                    )
                                                })}
                                            </box>
                                        ) : (
                                            <label class="conn-status" label="No paired devices found" halign={Gtk.Align.START} />
                                        )}
                                    </With>
                                </box>
                            </box>
                        ) : (
                            <label class="conn-status" label="Bluetooth is disabled" halign={Gtk.Align.START} />
                        )}
                    </With>

                    {/* Footer Bluetooth action */}
                    <button
                        class="action-btn"
                        onClicked={() => {
                            state.setConnVisible(false)
                            execAsync("blueman-manager").catch(print)
                        }}
                    >
                        <box spacing={6} vertical={false} valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER}>
                            <label label="󰂯" />
                            <label label="Bluetooth Settings (Blueman)" />
                        </box>
                    </button>
                </box>
            </box>
        </window>
    )
}

/* ── Battery Dashboard independent floating window ── */
export function BatteryDashboard(gdkmonitor: Gdk.Monitor) {
    const { TOP } = Astal.WindowAnchor
    const state = getMonitorState(gdkmonitor)

    const batData = createPoll(
        {
            capacity: 0,
            status: "Unknown",
            health: "0.0",
            wattage: "0.00",
            voltage: "0.00",
            current: "0.000",
            cycles: "N/A",
            tech: "N/A",
            mfr: "N/A",
            model: "N/A",
            timeStr: "N/A"
        },
        5000,
        () => getBatteryDetails()
    )

    return (
        <window
            name="battery-dashboard"
            class="BatteryDashboard"
            namespace="dashboard"
            gdkmonitor={gdkmonitor}
            anchor={TOP | Astal.WindowAnchor.RIGHT}
            marginRight={70}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={state.batteryVisible}
            application={app}
            onFocusOutEvent={() => {
                state.setBatteryVisible(false)
                return false
            }}
        >
            <box class="battery-card" vertical={true} spacing={12}>
                {/* Header */}
                <box class="dashboard-header" vertical={false} spacing={8} valign={Gtk.Align.CENTER}>
                    <label class="dashboard-title-icon" label="󰁹" />
                    <label class="dashboard-title" label="Battery & Power" />
                    <box hexpand={true} />
                    <button class="dashboard-close" onClicked={() => state.setBatteryVisible(false)}>
                        <label label="󰅖" />
                    </button>
                </box>

                <box class="dashboard-separator" />

                {/* Big Info Block */}
                <box class="battery-large-info" spacing={16} vertical={false} valign={Gtk.Align.CENTER}>
                    <With value={batData}>
                        {data => {
                            const isCharging = data.status === "Charging"
                            const cap = data.capacity
                            const icon = isCharging ? "󰂄" : (
                                cap <= 10 ? "󰁺" : cap <= 30 ? "󰁾" :
                                cap <= 60 ? "󰂀" : cap <= 90 ? "󰂂" : "󰁹"
                            )
                            const colorClass = cap <= 20 ? "crit" : (cap <= 35 ? "warn" : (isCharging ? "charging" : "good"))

                            return (
                                <box spacing={16} vertical={false} valign={Gtk.Align.CENTER}>
                                    <label class={`battery-large-pct ${colorClass}`} label={`${icon} ${cap}%`} />
                                    <box vertical={true}>
                                        <label class="battery-status-text" label={data.status} halign={Gtk.Align.START} />
                                        <label class="battery-time-text" label={data.timeStr} halign={Gtk.Align.START} />
                                    </box>
                                </box>
                            )
                        }}
                    </With>
                </box>

                {/* Progress LevelBar */}
                <With value={batData}>
                    {data => {
                        const isCharging = data.status === "Charging"
                        const cap = data.capacity
                        const colorClass = cap <= 20 ? "crit" : (cap <= 35 ? "warn" : (isCharging ? "charging" : "good"))
                        return (
                            <levelbar 
                                class={`battery-bar ${colorClass}`} 
                                value={cap / 100} 
                            />
                        )
                    }}
                </With>

                <box class="dashboard-separator" />

                {/* Details Section */}
                <box vertical={true} spacing={4}>
                    <label class="section-title" label="DETAILS" halign={Gtk.Align.START} />
                    <With value={batData}>
                        {data => (
                            <box vertical={true} spacing={4}>
                                <box class="detail-row" vertical={false}>
                                    <label class="detail-key" label="Power Draw" />
                                    <box hexpand={true} />
                                    <label class="detail-val" label={`${data.wattage} W`} />
                                </box>
                                <box class="detail-row" vertical={false}>
                                    <label class="detail-key" label="Voltage" />
                                    <box hexpand={true} />
                                    <label class="detail-val" label={`${data.voltage} V`} />
                                </box>
                                <box class="detail-row" vertical={false}>
                                    <label class="detail-key" label="Current" />
                                    <box hexpand={true} />
                                    <label class="detail-val" label={`${data.current} A`} />
                                </box>
                            </box>
                        )}
                    </With>
                </box>

                <box class="dashboard-separator" />

                {/* Health Section */}
                <box vertical={true} spacing={4}>
                    <label class="section-title" label="HEALTH" halign={Gtk.Align.START} />
                    <With value={batData}>
                        {data => {
                            const h = parseFloat(data.health)
                            const healthClass = h < 70 ? "crit" : (h < 85 ? "warn" : "good")
                            const capText = `${(parseFloat(readBatFile("charge_full") || "0")/1e6).toFixed(2)} / ${(parseFloat(readBatFile("charge_full_design") || "1")/1e6).toFixed(2)} Ah`
                            
                            return (
                                <box vertical={true} spacing={4}>
                                    <box class="detail-row" vertical={false}>
                                        <label class="detail-key" label="Battery Health" />
                                        <box hexpand={true} />
                                        <label class={`detail-val ${healthClass}`} label={`${data.health}%`} />
                                    </box>
                                    <box class="detail-row" vertical={false}>
                                        <label class="detail-key" label="Cycle Count" />
                                        <box hexpand={true} />
                                        <label class="detail-val" label={data.cycles} />
                                    </box>
                                    <box class="detail-row" vertical={false}>
                                        <label class="detail-key" label="Capacity Ratio" />
                                        <box hexpand={true} />
                                        <label class="detail-val" label={capText} />
                                    </box>
                                </box>
                            )
                        }}
                    </With>
                </box>

                <box class="dashboard-separator" />

                {/* Hardware Section */}
                <box vertical={true} spacing={4}>
                    <label class="section-title" label="HARDWARE DETAILS" halign={Gtk.Align.START} />
                    <With value={batData}>
                        {data => (
                            <box vertical={true} spacing={4}>
                                <box class="detail-row" vertical={false}>
                                    <label class="detail-key" label="Manufacturer" />
                                    <box hexpand={true} />
                                    <label class="detail-val" label={data.mfr} />
                                </box>
                                <box class="detail-row" vertical={false}>
                                    <label class="detail-key" label="Model Name" />
                                    <box hexpand={true} />
                                    <label class="detail-val" label={data.model} />
                                </box>
                                <box class="detail-row" vertical={false}>
                                    <label class="detail-key" label="Technology" />
                                    <box hexpand={true} />
                                    <label class="detail-val" label={data.tech} />
                                </box>
                            </box>
                        )}
                    </With>
                </box>
            </box>
        </window>
    )
}
