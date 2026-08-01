#!/usr/bin/env python3
import gi, os
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
import os, signal
PIDFILE = "/tmp/battery_popup.pid"
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
label.section-title { color: #6c7086; font-size: 11px; font-weight: bold; }
label.key   { color: #6c7086; font-size: 12px; min-width: 140px; }
label.value { color: #cdd6f4; font-size: 12px; font-weight: bold; }
label.value.good     { color: #a6e3a1; }
label.value.warn     { color: #f9e2af; }
label.value.crit     { color: #f38ba8; }
label.value.charging { color: #89b4fa; }
label.pct-big {
    font-size: 36px;
    font-weight: bold;
    color: #89b4fa;
}
label.pct-big.warn { color: #f9e2af; }
label.pct-big.crit { color: #f38ba8; }
progressbar { min-height: 8px; }
progressbar trough {
    background-color: rgba(49,50,68,0.8);
    border-radius: 6px;
    border: 1px solid rgba(137,180,250,0.1);
    min-height: 8px;
}
progressbar progress {
    background: linear-gradient(90deg, rgba(166,227,161,0.9), rgba(137,180,250,0.7));
    border-radius: 6px;
}
progressbar.warn progress  { background: rgba(249,226,175,0.85); }
progressbar.crit progress  { background: rgba(243,139,168,0.85); }
progressbar.charging progress {
    background: linear-gradient(90deg, rgba(137,180,250,0.9), rgba(203,166,247,0.7));
}
separator { background-color: rgba(137,180,250,0.12); min-height: 1px; margin: 6px 0; }
"""

BAT = "/sys/class/power_supply/BAT0"

def read(f):
    try:
        return open(os.path.join(BAT, f)).read().strip()
    except Exception:
        return None

def apply_css():
    p = Gtk.CssProvider()
    p.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

class BatteryPopup:
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

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_margin_top(12)
        outer.set_margin_bottom(12)
        outer.set_margin_start(14)
        outer.set_margin_end(14)
        outer.set_size_request(280, -1)
        self.win.add(outer)
        self.build_ui(outer)

        self.win.show_all()
        self.win.present()
        GLib.timeout_add(5000, self._refresh, outer)

    def build_ui(self, outer):
        for c in outer.get_children():
            c.destroy()

        capacity    = int(read("capacity") or 0)
        status      = read("status") or "Unknown"
        charge_now  = int(read("charge_now")        or 0)
        charge_full = int(read("charge_full")        or 1)
        charge_des  = int(read("charge_full_design") or 1)
        voltage     = int(read("voltage_now")        or 0) / 1_000_000
        current     = int(read("current_now")        or 0) / 1_000_000
        cycles      = read("cycle_count") or "N/A"
        tech        = read("technology")  or "N/A"
        mfr         = read("manufacturer") or "N/A"
        model       = read("model_name")  or "N/A"

        health     = charge_full / charge_des * 100 if charge_des else 0
        wattage    = voltage * current
        charge_pct = charge_now / charge_full if charge_full else 0

        # Estimate time remaining
        time_str = "N/A"
        if current > 0.01:
            if status == "Discharging":
                hours = (charge_now / 1_000_000) / current
            elif status == "Charging":
                remaining = (charge_full - charge_now) / 1_000_000
                hours = remaining / current
            else:
                hours = 0
            if hours > 0:
                h = int(hours)
                m = int((hours - h) * 60)
                time_str = f"{h}h {m}m"

        def section(title):
            lbl = Gtk.Label(label=title)
            lbl.get_style_context().add_class("section-title")
            lbl.set_halign(Gtk.Align.START)
            outer.pack_start(lbl, False, False, 0)

        def sep():
            s = Gtk.Separator()
            s.set_margin_top(4); s.set_margin_bottom(2)
            outer.pack_start(s, False, False, 0)

        def kv(key, val, val_class=""):
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
            k = Gtk.Label(label=key)
            k.get_style_context().add_class("key")
            k.set_halign(Gtk.Align.START)
            v = Gtk.Label(label=val)
            v.get_style_context().add_class("value")
            if val_class: v.get_style_context().add_class(val_class)
            v.set_halign(Gtk.Align.END)
            v.set_hexpand(True)
            row.pack_start(k, False, False, 0)
            row.pack_start(v, True, True, 0)
            outer.pack_start(row, False, False, 3)

        # Big percentage + bar
        section("  BATTERY")
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        top.set_margin_top(6)

        pct_css = "crit" if capacity <= 20 else ("warn" if capacity <= 35 else
                  ("charging" if status == "Charging" else "good"))
        pct_icon = "󰂄" if status == "Charging" else (
                   "󰁺" if capacity <= 10 else "󰁾" if capacity <= 30 else
                   "󰂀" if capacity <= 60 else "󰂂" if capacity <= 90 else "󰁹")
        big = Gtk.Label(label=f"{pct_icon} {capacity}%")
        big.get_style_context().add_class("pct-big")
        if pct_css in ("crit","warn"): big.get_style_context().add_class(pct_css)
        top.pack_start(big, False, False, 0)

        info_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        status_lbl = Gtk.Label(label=status)
        status_lbl.get_style_context().add_class("value")
        status_lbl.get_style_context().add_class(pct_css)
        status_lbl.set_halign(Gtk.Align.START)
        time_lbl = Gtk.Label(label=time_str)
        time_lbl.get_style_context().add_class("value")
        time_lbl.set_halign(Gtk.Align.START)
        info_col.pack_start(status_lbl, False, False, 0)
        info_col.pack_start(time_lbl, False, False, 0)
        top.pack_start(info_col, True, True, 0)
        outer.pack_start(top, False, False, 0)

        bar = Gtk.ProgressBar()
        bar.set_fraction(capacity / 100)
        bar.set_margin_top(6)
        if pct_css == "charging":
            bar.get_style_context().add_class("charging")
        elif pct_css in ("warn","crit"):
            bar.get_style_context().add_class(pct_css)
        outer.pack_start(bar, False, False, 0)

        sep()
        section("  DETAILS")
        kv("  Power draw",   f"{wattage:.2f} W")
        kv("  Voltage",      f"{voltage:.2f} V")
        kv("  Current",      f"{current:.3f} A")

        sep()
        section("  HEALTH")
        health_css = "crit" if health < 70 else ("warn" if health < 85 else "good")
        kv("  Health",       f"{health:.1f}%",   health_css)
        kv("  Cycles",       str(cycles))
        kv("  Capacity",     f"{charge_full/1e6:.2f} / {charge_des/1e6:.2f} Ah")

        sep()
        section("󰋊  HARDWARE")
        kv("  Manufacturer", mfr)
        kv("  Model",        model)
        kv("  Technology",   tech)

    def _refresh(self, outer):
        if not self.win.get_visible():
            return False
        self.build_ui(outer)
        self.win.show_all()
        return True

if __name__ == "__main__":
    BatteryPopup()
    Gtk.main()
