#!/usr/bin/env python3
import gi, subprocess, threading
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
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
label.section-title { color: #6c7086; font-size: 11px; font-weight: bold; }
label.tile-label { font-size: 11px; color: #cdd6f4; margin-top: 2px; }
label.tile-sub   { font-size: 10px; color: #6c7086; }

button.tile {
    background-color: rgba(49, 50, 68, 0.7);
    border: 1px solid rgba(137, 180, 250, 0.18);
    border-radius: 12px;
    min-width: 86px;
    min-height: 72px;
    padding: 8px;
}
button.tile:hover {
    background-color: rgba(137, 180, 250, 0.12);
    border-color: rgba(137, 180, 250, 0.45);
}
button.tile.active {
    background-color: rgba(137, 180, 250, 0.22);
    border-color: rgba(137, 180, 250, 0.55);
}
button.tile.active label { color: #89b4fa; }

scale trough {
    background-color: rgba(49,50,68,0.8);
    border-radius: 8px;
    min-height: 6px;
    border: 1px solid rgba(137,180,250,0.1);
}
scale trough highlight {
    background: linear-gradient(90deg, rgba(137,180,250,0.9), rgba(203,166,247,0.7));
    border-radius: 8px;
}
scale slider {
    background-color: #89b4fa;
    border-radius: 50%;
    border: none;
    min-height: 14px;
    min-width: 14px;
    box-shadow: 0 0 6px rgba(137,180,250,0.5);
}
separator { background-color: rgba(137,180,250,0.12); min-height: 1px; margin: 6px 0; }
"""

def run(cmd, timeout=4):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except Exception:
        return ""

def apply_css():
    p = Gtk.CssProvider()
    p.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

# ── State getters ──────────────────────────────────────────
def wifi_state():
    st = run(["nmcli", "-fields", "WIFI", "g"]).splitlines()
    on = any("enabled" in l for l in st)
    ssid = run(["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"])
    ssid = next((l.split(":",1)[1] for l in ssid.splitlines() if l.startswith("yes:")), "")
    return on, ssid

def bt_state():
    out = run(["bluetoothctl", "show"])
    on = any("Powered: yes" in l for l in out.splitlines())
    conn = run(["bluetoothctl", "info"])
    device = ""
    for l in conn.splitlines():
        if "Name:" in l:
            device = l.split(":",1)[1].strip()
            break
    return on, device

def vol_state():
    try:
        vol = int(run(["pamixer", "--get-volume"]))
        muted = run(["pamixer", "--get-mute"]) == "true"
        return vol, muted
    except Exception:
        return 50, False

def brightness_state():
    try:
        v = run(["brightnessctl", "g"])
        m = run(["brightnessctl", "m"])
        return int(int(v) / int(m) * 100)
    except Exception:
        return 100

class QuickSettings:
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

        self.win.connect("destroy", Gtk.main_quit)
        self.win.connect("key-press-event",
            lambda w, e: Gtk.main_quit() if e.keyval == Gdk.KEY_Escape else None)

        self.outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.outer.set_margin_top(14)
        self.outer.set_margin_bottom(14)
        self.outer.set_margin_start(14)
        self.outer.set_margin_end(14)
        self.outer.set_size_request(300, -1)
        self.win.add(self.outer)

        self.build_ui()
        self.win.show_all()
        self.win.present()

    def make_tile(self, icon, label, sublabel, active, on_click):
        btn = Gtk.Button()
        btn.get_style_context().add_class("tile")
        if active:
            btn.get_style_context().add_class("active")

        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        col.set_halign(Gtk.Align.CENTER)
        col.set_valign(Gtk.Align.CENTER)

        ico = Gtk.Label(label=icon)
        ico.set_markup(f'<span font="18">{icon}</span>')
        lbl = Gtk.Label(label=label)
        lbl.get_style_context().add_class("tile-label")
        sub = Gtk.Label(label=sublabel[:14] if sublabel else "")
        sub.get_style_context().add_class("tile-sub")

        col.pack_start(ico, False, False, 0)
        col.pack_start(lbl, False, False, 0)
        col.pack_start(sub, False, False, 0)
        btn.add(col)
        btn.connect("clicked", on_click, btn)
        return btn

    def build_ui(self):
        for c in self.outer.get_children():
            c.destroy()

        title = Gtk.Label(label="  QUICK SETTINGS")
        title.get_style_context().add_class("section-title")
        title.set_halign(Gtk.Align.START)
        self.outer.pack_start(title, False, False, 0)

        # ── Tiles grid ─────────────────────────────────────
        grid = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        grid.set_margin_top(10)
        grid.set_homogeneous(True)

        wifi_on, ssid   = wifi_state()
        bt_on, bt_dev   = bt_state()
        vol, muted      = vol_state()

        wifi_tile = self.make_tile(
            "󰤨" if wifi_on else "󰤭",
            "Wi-Fi", ssid if wifi_on else "Off",
            wifi_on, self.on_wifi_toggle)
        bt_tile = self.make_tile(
            "󰂯" if bt_on else "󰂲",
            "Bluetooth", bt_dev if bt_on else "Off",
            bt_on, self.on_bt_toggle)
        vol_tile = self.make_tile(
            "󰝟" if muted else "󰕾",
            "Audio", "Muted" if muted else f"{vol}%",
            not muted, self.on_vol_toggle)

        grid.pack_start(wifi_tile, True, True, 0)
        grid.pack_start(bt_tile,   True, True, 0)
        grid.pack_start(vol_tile,  True, True, 0)
        self.outer.pack_start(grid, False, False, 0)

        # ── Sliders ────────────────────────────────────────
        sep1 = Gtk.Separator()
        sep1.set_margin_top(12); sep1.set_margin_bottom(4)
        self.outer.pack_start(sep1, False, False, 0)

        # Volume slider
        v_title = Gtk.Label(label="󰕾  VOLUME")
        v_title.get_style_context().add_class("section-title")
        v_title.set_halign(Gtk.Align.START)
        self.outer.pack_start(v_title, False, False, 0)

        vol_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        vol_row.set_margin_top(4)
        self.vol_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.vol_scale.set_value(vol)
        self.vol_scale.set_draw_value(False)
        self.vol_scale.set_hexpand(True)
        self.vol_scale.connect("value-changed", self.on_vol_changed)
        self.vol_lbl = Gtk.Label(label=f"{vol}%")
        self.vol_lbl.set_size_request(36, -1)
        vol_row.pack_start(self.vol_scale, True, True, 0)
        vol_row.pack_start(self.vol_lbl, False, False, 0)
        self.outer.pack_start(vol_row, False, False, 0)

        # Brightness slider
        sep2 = Gtk.Separator()
        sep2.set_margin_top(8); sep2.set_margin_bottom(4)
        self.outer.pack_start(sep2, False, False, 0)

        b_title = Gtk.Label(label="󰃠  BRIGHTNESS")
        b_title.get_style_context().add_class("section-title")
        b_title.set_halign(Gtk.Align.START)
        self.outer.pack_start(b_title, False, False, 0)

        bri = brightness_state()
        bri_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        bri_row.set_margin_top(4)
        self.bri_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 1, 100, 1)
        self.bri_scale.set_value(bri)
        self.bri_scale.set_draw_value(False)
        self.bri_scale.set_hexpand(True)
        self.bri_scale.connect("value-changed", self.on_bri_changed)
        self.bri_lbl = Gtk.Label(label=f"{bri}%")
        self.bri_lbl.set_size_request(36, -1)
        bri_row.pack_start(self.bri_scale, True, True, 0)
        bri_row.pack_start(self.bri_lbl, False, False, 0)
        self.outer.pack_start(bri_row, False, False, 0)

        self.win.show_all()

    def on_wifi_toggle(self, btn, tile):
        on, _ = wifi_state()
        subprocess.Popen(["nmcli", "radio", "wifi", "off" if on else "on"])
        GLib.timeout_add(600, self.build_ui)

    def on_bt_toggle(self, btn, tile):
        on, _ = bt_state()
        subprocess.Popen(["bluetoothctl", "power", "off" if on else "on"])
        GLib.timeout_add(600, self.build_ui)

    def on_vol_toggle(self, btn, tile):
        subprocess.Popen(["pamixer", "-t"])
        GLib.timeout_add(100, self.build_ui)

    def on_vol_changed(self, scale):
        val = int(scale.get_value())
        self.vol_lbl.set_text(f"{val}%")
        subprocess.Popen(["pamixer", "--set-volume", str(val)])

    def on_bri_changed(self, scale):
        val = int(scale.get_value())
        self.bri_lbl.set_text(f"{val}%")
        subprocess.Popen(["brightnessctl", "s", f"{val}%"])

if __name__ == "__main__":
    import subprocess
    QuickSettings()
    Gtk.main()
