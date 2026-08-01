#!/usr/bin/env python3
import gi, subprocess, re
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
import os, signal
PIDFILE = "/tmp/audio_popup.pid"
def cleanup(*_):
    try: os.remove(PIDFILE)
    except Exception: pass
    Gtk.main_quit()
signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell

CSS = b"""
window {
    background-color: rgba(17, 17, 27, 0.92);
    border: 1px solid rgba(137, 180, 250, 0.3);
    border-radius: 14px;
}

box { background-color: transparent; }

label {
    font-family: 'JetBrainsMono Nerd Font Propo', monospace;
    font-size: 12px;
    color: #cdd6f4;
}

label.section-title {
    color: #6c7086;
    font-size: 11px;
    font-weight: bold;
}

label.volume-label {
    color: #89b4fa;
    font-size: 13px;
    font-weight: bold;
    min-width: 40px;
}

scale {
    padding: 0 4px;
}

scale trough {
    background-color: rgba(49, 50, 68, 0.8);
    border-radius: 8px;
    min-height: 6px;
    border: 1px solid rgba(137, 180, 250, 0.15);
}

scale trough highlight {
    background: linear-gradient(90deg, rgba(137, 180, 250, 0.9), rgba(203, 166, 247, 0.7));
    border-radius: 8px;
}

scale slider {
    background-color: #89b4fa;
    border-radius: 50%;
    border: none;
    box-shadow: 0 0 6px rgba(137, 180, 250, 0.5);
    min-height: 14px;
    min-width: 14px;
}

button {
    background-color: rgba(49, 50, 68, 0.7);
    border: 1px solid rgba(137, 180, 250, 0.2);
    border-radius: 10px;
    color: #cdd6f4;
    font-family: 'JetBrainsMono Nerd Font Propo', monospace;
    font-size: 12px;
    padding: 6px 12px;
}

button:hover {
    background-color: rgba(137, 180, 250, 0.15);
    border-color: rgba(137, 180, 250, 0.5);
    color: #89b4fa;
}

button.muted {
    background-color: rgba(243, 139, 168, 0.15);
    border-color: rgba(243, 139, 168, 0.4);
    color: #f38ba8;
}

button.muted:hover {
    background-color: rgba(243, 139, 168, 0.25);
}

separator {
    background-color: rgba(137, 180, 250, 0.12);
    min-height: 1px;
    margin: 4px 0;
}

combobox button {
    border-radius: 10px;
    padding: 5px 10px;
}
"""

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()

def get_volume():
    try:
        return int(run(["pamixer", "--get-volume"]))
    except Exception:
        return 50

def is_muted():
    return run(["pamixer", "--get-mute"]) == "true"

def is_mic_muted():
    return run(["pamixer", "--default-source", "--get-mute"]) == "true"

def clean_sink_name(name, desc):
    desc_lower = desc.lower()
    name_lower = name.lower()
    if "jbl" in desc_lower or "jbl" in name_lower:
        return "󰋋  Audífonos JBL (USB-C)"
    if "speaker" in desc_lower or "speaker" in name_lower:
        return "󰓃  Altavoces de la Laptop"
    if "ga107" in name_lower or ("hdmi" in desc_lower and "raptor" not in desc_lower):
        return "󰍹  Monitor HDMI"
    if "raptor" in desc_lower and "hdmi" in desc_lower:
        try:
            num = desc.split("HDMI / DisplayPort ")[-1].split(" Output")[0]
            return f"󰍹  Intel HDMI/DP {num}"
        except Exception:
            return "󰍹  Intel HDMI/DP"
    if "virtual" in desc_lower or "loopback" in name_lower:
        return "󰍬  Audio Virtual (KVM)"
    return desc[:45]

def clean_source_name(name, desc):
    desc_lower = desc.lower()
    name_lower = name.lower()
    if "jbl" in desc_lower or "jbl" in name_lower:
        return "󰍬  Micrófono JBL (USB-C)"
    if "redragon" in desc_lower or "redragon" in name_lower:
        return "󰍬  Micrófono de Cámara Redragon"
    if "stereo microphone" in desc_lower:
        return "󰍬  Micrófono Interno (Estéreo)"
    if "digital microphone" in desc_lower:
        return "󰍬  Micrófono Digital Interno"
    if "virtual" in desc_lower or "loopback" in name_lower:
        return "󰍬  Micrófono Virtual (KVM)"
    return desc[:45]

def get_default_sink():
    return run(["pactl", "get-default-sink"])

def get_sinks():
    out = run(["pactl", "list", "sinks"])
    sinks = []
    name, desc = None, None
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("Name:"):
            name = line.split(":", 1)[1].strip()
        elif line.startswith("Description:"):
            desc = line.split(":", 1)[1].strip()
            if name and desc:
                sinks.append((name, desc))
                name, desc = None, None
                
    default = get_default_sink()
    filtered_sinks = []
    for s_name, s_desc in sinks:
        is_intel_hdmi = "raptor" in s_desc.lower() and "hdmi" in s_desc.lower()
        if not is_intel_hdmi or s_name == default:
            filtered_sinks.append((s_name, clean_sink_name(s_name, s_desc)))
    return filtered_sinks

def get_default_source():
    return run(["pactl", "get-default-source"])

def get_sources():
    out = run(["pactl", "list", "sources"])
    sources = []
    name, desc = None, None
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("Name:"):
            name = line.split(":", 1)[1].strip()
        elif line.startswith("Description:"):
            desc = line.split(":", 1)[1].strip()
            if name and desc:
                if not name.endswith(".monitor"):
                    sources.append((name, desc))
                name, desc = None, None
                
    cleaned_sources = []
    for s_name, s_desc in sources:
        cleaned_sources.append((s_name, clean_source_name(s_name, s_desc)))
    return cleaned_sources

def apply_css():
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

class AudioPopup:
    def __init__(self):
        apply_css()
        self.win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.win.set_decorated(False)
        self.win.set_resizable(False)

        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_keyboard_mode(self.win, GtkLayerShell.KeyboardMode.ON_DEMAND)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.TOP,    True)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.RIGHT,  True)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.LEFT,   False)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.BOTTOM, False)
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.TOP,   59)
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.RIGHT, 20)

        self.win.connect("destroy", cleanup)
        self.win.connect("key-press-event",
            lambda w, e: cleanup() if e.keyval == Gdk.KEY_Escape else None)

        self.build_ui()
        self.win.show_all()
        self.win.present()

    def build_ui(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_margin_top(12)
        outer.set_margin_bottom(12)
        outer.set_margin_start(14)
        outer.set_margin_end(14)

        # ── Output volume ──────────────────────────────────
        lbl_out = Gtk.Label(label="  OUTPUT")
        lbl_out.get_style_context().add_class("section-title")
        lbl_out.set_halign(Gtk.Align.START)
        outer.pack_start(lbl_out, False, False, 0)

        row_vol = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        row_vol.set_margin_top(6)

        self.mute_btn = Gtk.Button()
        self._update_mute_btn()
        self.mute_btn.connect("clicked", self.on_mute_toggle)
        row_vol.pack_start(self.mute_btn, False, False, 0)

        self.vol_scale = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.vol_scale.set_value(get_volume())
        self.vol_scale.set_draw_value(False)
        self.vol_scale.set_hexpand(True)
        self.vol_scale.connect("value-changed", self.on_volume_changed)
        row_vol.pack_start(self.vol_scale, True, True, 0)

        self.vol_lbl = Gtk.Label(label=f"{get_volume()}%")
        self.vol_lbl.get_style_context().add_class("volume-label")
        self.vol_lbl.set_halign(Gtk.Align.END)
        row_vol.pack_start(self.vol_lbl, False, False, 0)

        outer.pack_start(row_vol, False, False, 0)

        # ── Separator ──────────────────────────────────────
        sep1 = Gtk.Separator()
        sep1.set_margin_top(10)
        sep1.set_margin_bottom(4)
        outer.pack_start(sep1, False, False, 0)

        # ── Mic volume ─────────────────────────────────────
        lbl_mic = Gtk.Label(label="  MICROPHONE")
        lbl_mic.get_style_context().add_class("section-title")
        lbl_mic.set_halign(Gtk.Align.START)
        outer.pack_start(lbl_mic, False, False, 0)

        row_mic = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        row_mic.set_margin_top(6)

        self.mic_btn = Gtk.Button()
        self._update_mic_btn()
        self.mic_btn.connect("clicked", self.on_mic_toggle)
        row_mic.pack_start(self.mic_btn, False, False, 0)

        self.mic_scale = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        mic_vol = int(run(["pamixer", "--default-source", "--get-volume"]) or 50)
        self.mic_scale.set_value(mic_vol)
        self.mic_scale.set_draw_value(False)
        self.mic_scale.set_hexpand(True)
        self.mic_scale.connect("value-changed", self.on_mic_changed)
        row_mic.pack_start(self.mic_scale, True, True, 0)

        self.mic_lbl = Gtk.Label(label=f"{mic_vol}%")
        self.mic_lbl.get_style_context().add_class("volume-label")
        self.mic_lbl.set_halign(Gtk.Align.END)
        row_mic.pack_start(self.mic_lbl, False, False, 0)

        outer.pack_start(row_mic, False, False, 0)

        # ── Separator (Output Device) ──────────────────────
        sinks = get_sinks()
        if len(sinks) > 1:
            sep2 = Gtk.Separator()
            sep2.set_margin_top(10)
            sep2.set_margin_bottom(4)
            outer.pack_start(sep2, False, False, 0)

            lbl_dev = Gtk.Label(label="󰓃  OUTPUT DEVICE")
            lbl_dev.get_style_context().add_class("section-title")
            lbl_dev.set_halign(Gtk.Align.START)
            outer.pack_start(lbl_dev, False, False, 0)

            self.sink_combo = Gtk.ComboBoxText()
            default = get_default_sink()
            active_idx = 0
            for i, (name, desc) in enumerate(sinks):
                self.sink_combo.append(name, desc)
                if name == default:
                    active_idx = i
            self.sink_combo.set_active(active_idx)
            self.sink_combo.set_margin_top(6)
            self.sink_combo.connect("changed", self.on_sink_changed)
            outer.pack_start(self.sink_combo, False, False, 0)

        # ── Separator (Input Device) ───────────────────────
        sources = get_sources()
        if len(sources) > 1:
            sep3 = Gtk.Separator()
            sep3.set_margin_top(10)
            sep3.set_margin_bottom(4)
            outer.pack_start(sep3, False, False, 0)

            lbl_src = Gtk.Label(label="󰍬  INPUT DEVICE")
            lbl_src.get_style_context().add_class("section-title")
            lbl_src.set_halign(Gtk.Align.START)
            outer.pack_start(lbl_src, False, False, 0)

            self.source_combo = Gtk.ComboBoxText()
            default_src = get_default_source()
            active_src_idx = 0
            for i, (name, desc) in enumerate(sources):
                self.source_combo.append(name, desc)
                if name == default_src:
                    active_src_idx = i
            self.source_combo.set_active(active_src_idx)
            self.source_combo.set_margin_top(6)
            self.source_combo.connect("changed", self.on_source_changed)
            outer.pack_start(self.source_combo, False, False, 0)

        self.win.add(outer)

    def _update_mute_btn(self):
        muted = is_muted()
        self.mute_btn.set_label("󰝟  Muted" if muted else "󰕾  Unmuted")
        ctx = self.mute_btn.get_style_context()
        if muted:
            ctx.add_class("muted")
        else:
            ctx.remove_class("muted")

    def _update_mic_btn(self):
        muted = is_mic_muted()
        self.mic_btn.set_label("󰍭  Muted" if muted else "󰍬  Live")
        ctx = self.mic_btn.get_style_context()
        if muted:
            ctx.add_class("muted")
        else:
            ctx.remove_class("muted")

    def on_mute_toggle(self, btn):
        subprocess.run(["pamixer", "-t"])
        self._update_mute_btn()

    def on_mic_toggle(self, btn):
        subprocess.run(["pamixer", "--default-source", "-t"])
        self._update_mic_btn()

    def on_volume_changed(self, scale):
        val = int(scale.get_value())
        self.vol_lbl.set_text(f"{val}%")
        subprocess.run(["pamixer", "--set-volume", str(val)])

    def on_mic_changed(self, scale):
        val = int(scale.get_value())
        self.mic_lbl.set_text(f"{val}%")
        subprocess.run(["pamixer", "--default-source", "--set-volume", str(val)])

    def on_sink_changed(self, combo):
        sink_id = combo.get_active_id()
        if sink_id:
            subprocess.run(["pactl", "set-default-sink", sink_id])
            try:
                inputs_out = run(["pactl", "list", "short", "sink-inputs"])
                for line in inputs_out.splitlines():
                    parts = line.split()
                    if parts:
                        input_id = parts[0]
                        subprocess.run(["pactl", "move-sink-input", input_id, sink_id])
            except Exception as e:
                print(f"Error moving sink inputs: {e}")

    def on_source_changed(self, combo):
        source_id = combo.get_active_id()
        if source_id:
            subprocess.run(["pactl", "set-default-source", source_id])
            try:
                outputs_out = run(["pactl", "list", "short", "source-outputs"])
                for line in outputs_out.splitlines():
                    parts = line.split()
                    if parts:
                        output_id = parts[0]
                        subprocess.run(["pactl", "move-source-output", output_id, source_id])
            except Exception as e:
                print(f"Error moving source outputs: {e}")

if __name__ == "__main__":
    AudioPopup()
    Gtk.main()
