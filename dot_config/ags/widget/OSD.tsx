import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync } from "ags/process"
import { createState, createComputed, createBinding } from "ags"
import GLib from "gi://GLib"
import Wp from "gi://AstalWp"

const osdState = createState(false)
export const osdVisible = osdState[0]
export const setOsdVisible = osdState[1]

const brightnessState = createState(1)
export const brightness = brightnessState[0]
export const setBrightness = brightnessState[1]

const modeState = createState<"audio" | "brightness">("audio")
export const osdMode = modeState[0]
export const setOsdMode = modeState[1]

let hideTimeout: any = null

export function showOSD() {
    setOsdVisible(true)
    if (hideTimeout) {
        GLib.source_remove(hideTimeout)
    }
    hideTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
        setOsdVisible(false)
        hideTimeout = null
        return false
    })
}

export function updateBrightness() {
    execAsync(["bash", "-c", "brightnessctl -d 'amdgpu_bl*' -m 2>/dev/null"])
        .then(out => {
            const parts = out.split(",")
            if (parts.length >= 4) {
                const percent = parseInt(parts[3].replace("%", ""))
                setBrightness(percent / 100)
            }
        })
        .catch(console.error)
    setOsdMode("brightness")
    showOSD()
}

export default function OSD(monitor: Gdk.Monitor) {
    const audio = Wp.get_default()?.audio

    let volBinding = () => 0
    let muteBinding = () => false

    if (audio && audio.default_speaker) {
        volBinding = createBinding(audio.default_speaker, "volume")
        muteBinding = createBinding(audio.default_speaker, "mute")

        audio.default_speaker.connect("notify::volume", () => {
            setOsdMode("audio")
            showOSD()
        })
        audio.default_speaker.connect("notify::mute", () => {
            setOsdMode("audio")
            showOSD()
        })
    }

    const iconText = createComputed(() => {
        const mode = osdMode()
        if (mode === "audio") {
            const isMute = muteBinding()
            if (isMute) return "󰖁"
            const vol = volBinding() * 100
            if (vol < 30) return "󰕿"
            if (vol < 70) return "󰖀"
            return "󰕾"
        } else {
            return "󰃠"
        }
    })

    const realProgress = createComputed(() => {
        const mode = osdMode()
        if (mode === "audio") {
            return volBinding()
        } else {
            return brightness()
        }
    })

    return (
        <window
            name="osd"
            monitor={monitor}
            namespace="osd"
            layer={Astal.Layer.OVERLAY}
            anchor={Astal.WindowAnchor.BOTTOM}
            margin_bottom={100}
            visible={osdVisible}
        >
            <box class="osd-container" vertical={false} spacing={16} valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER}>
                <label class="osd-icon" label={iconText} />
                <levelbar
                    class="osd-progress"
                    widthRequest={200}
                    valign={Gtk.Align.CENTER}
                    value={realProgress}
                />
            </box>
        </window>
    )
}
