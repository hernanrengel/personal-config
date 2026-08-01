#!/usr/bin/env python3
import gi, subprocess, threading
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
import os, signal
PIDFILE = "/tmp/bluetooth_popup.pid"
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

label.device-name {
    color: #cdd6f4;
    font-size: 12px;
}

label.device-connected {
    color: #89b4fa;
    font-weight: bold;
}

label.status-label {
    color: #6c7086;
    font-size: 11px;
}

button {
    background-color: rgba(49, 50, 68, 0.7);
    border: 1px solid rgba(137, 180, 250, 0.2);
    border-radius: 10px;
    color: #cdd6f4;
    font-family: 'JetBrainsMono Nerd Font Propo', monospace;
    font-size: 12px;
    padding: 5px 10px;
}

button:hover {
    background-color: rgba(137, 180, 250, 0.15);
    border-color: rgba(137, 180, 250, 0.5);
    color: #89b4fa;
}

button.toggle-on {
    background-color: rgba(137, 180, 250, 0.2);
    border-color: rgba(137, 180, 250, 0.5);
    color: #89b4fa;
}

button.toggle-off {
    background-color: rgba(108, 112, 134, 0.2);
    border-color: rgba(108, 112, 134, 0.3);
    color: #6c7086;
}

button.connect-btn {
    background-color: rgba(166, 227, 161, 0.1);
    border-color: rgba(166, 227, 161, 0.3);
    color: #a6e3a1;
    padding: 3px 8px;
    border-radius: 8px;
    font-size: 11px;
}

button.connect-btn:hover {
    background-color: rgba(166, 227, 161, 0.2);
    border-color: rgba(166, 227, 161, 0.6);
}

button.disconnect-btn {
    background-color: rgba(243, 139, 168, 0.1);
    border-color: rgba(243, 139, 168, 0.3);
    color: #f38ba8;
    padding: 3px 8px;
    border-radius: 8px;
    font-size: 11px;
}

button.disconnect-btn:hover {
    background-color: rgba(243, 139, 168, 0.2);
    border-color: rgba(243, 139, 168, 0.6);
}

separator {
    background-color: rgba(137, 180, 250, 0.12);
    min-height: 1px;
    margin: 6px 0;
}

spinner {
    color: #89b4fa;
}
"""

def run(cmd, timeout=5):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ""

def bt_powered():
    out = run(["bluetoothctl", "show"])
    for line in out.splitlines():
        if "Powered:" in line:
            return "yes" in line
    return False

def bt_devices():
    out = run(["bluetoothctl", "devices"])
    devices = []
    for line in out.splitlines():
        parts = line.strip().split(" ", 2)
        if len(parts) == 3:
            mac, name = parts[1], parts[2]
            connected = "yes" in run(["bluetoothctl", "info", mac])
            devices.append({"mac": mac, "name": name, "connected": connected})
    return devices

def apply_css():
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

class BluetoothPopup:
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

        self.outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.outer.set_margin_top(12)
        self.outer.set_margin_bottom(12)
        self.outer.set_margin_start(14)
        self.outer.set_margin_end(14)
        self.win.add(self.outer)

        self.build_ui()
        self.win.show_all()
        self.win.present()

    def build_ui(self):
        powered = bt_powered()

        # ── Header: toggle ─────────────────────────────────
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        lbl = Gtk.Label(label="  BLUETOOTH")
        lbl.get_style_context().add_class("section-title")
        lbl.set_halign(Gtk.Align.START)
        lbl.set_hexpand(True)
        header.pack_start(lbl, True, True, 0)

        self.toggle_btn = Gtk.Button()
        self._update_toggle(powered)
        self.toggle_btn.connect("clicked", self.on_toggle)
        header.pack_start(self.toggle_btn, False, False, 0)

        self.outer.pack_start(header, False, False, 0)

        if not powered:
            self.win.show_all()
            return

        sep = Gtk.Separator()
        sep.set_margin_top(8)
        sep.set_margin_bottom(4)
        self.outer.pack_start(sep, False, False, 0)

        # ── Device list ────────────────────────────────────
        devices = bt_devices()
        if not devices:
            empty = Gtk.Label(label="No paired devices")
            empty.get_style_context().add_class("status-label")
            empty.set_margin_top(6)
            self.outer.pack_start(empty, False, False, 0)
        else:
            for dev in devices:
                self.outer.pack_start(self._device_row(dev), False, False, 4)

        # ── Scan button ────────────────────────────────────
        sep2 = Gtk.Separator()
        sep2.set_margin_top(4)
        self.outer.pack_start(sep2, False, False, 0)

        scan_btn = Gtk.Button(label="󰂰  Open Blueman")
        scan_btn.set_margin_top(6)
        scan_btn.connect("clicked", lambda b: (
            subprocess.Popen(["blueman-manager"]), Gtk.main_quit()))
        self.outer.pack_start(scan_btn, False, False, 0)

        self.win.show_all()

    def _device_row(self, dev):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

        icon = "󰂱 " if dev["connected"] else "󰂲 "
        name_lbl = Gtk.Label(label=f"{icon}{dev['name']}")
        name_lbl.set_halign(Gtk.Align.START)
        name_lbl.set_hexpand(True)
        name_lbl.set_ellipsize(3)
        if dev["connected"]:
            name_lbl.get_style_context().add_class("device-connected")
        else:
            name_lbl.get_style_context().add_class("device-name")
        row.pack_start(name_lbl, True, True, 0)

        if dev["connected"]:
            btn = Gtk.Button(label="Disconnect")
            btn.get_style_context().add_class("disconnect-btn")
            btn.connect("clicked", self.on_disconnect, dev["mac"], row, name_lbl, btn)
        else:
            btn = Gtk.Button(label="Connect")
            btn.get_style_context().add_class("connect-btn")
            btn.connect("clicked", self.on_connect, dev["mac"], row, name_lbl, btn)
        row.pack_start(btn, False, False, 0)

        return row

    def _update_toggle(self, powered):
        self.toggle_btn.set_label("󰂯  On" if powered else "󰂲  Off")
        ctx = self.toggle_btn.get_style_context()
        ctx.remove_class("toggle-on")
        ctx.remove_class("toggle-off")
        ctx.add_class("toggle-on" if powered else "toggle-off")

    def on_toggle(self, btn):
        powered = bt_powered()
        cmd = "power off" if powered else "power on"
        subprocess.run(["bluetoothctl", *cmd.split()])
        # Rebuild UI
        for child in self.outer.get_children():
            child.destroy()
        self.build_ui()

    def on_connect(self, btn, mac, row, lbl, action_btn):
        action_btn.set_sensitive(False)
        action_btn.set_label("…")
        def do_connect():
            run(["bluetoothctl", "connect", mac], timeout=15)
            connected = "yes" in run(["bluetoothctl", "info", mac])
            GLib.idle_add(self._after_action, lbl, action_btn, connected, mac)
        threading.Thread(target=do_connect, daemon=True).start()

    def on_disconnect(self, btn, mac, row, lbl, action_btn):
        action_btn.set_sensitive(False)
        action_btn.set_label("…")
        def do_disconnect():
            run(["bluetoothctl", "disconnect", mac], timeout=10)
            connected = "yes" in run(["bluetoothctl", "info", mac])
            GLib.idle_add(self._after_action, lbl, action_btn, connected, mac)
        threading.Thread(target=do_disconnect, daemon=True).start()

    def _after_action(self, lbl, btn, connected, mac):
        icon = "󰂱 " if connected else "󰂲 "
        name = lbl.get_text().split(" ", 1)[1] if " " in lbl.get_text() else lbl.get_text()
        lbl.set_text(f"{icon}{name}")
        ctx_lbl = lbl.get_style_context()
        ctx_lbl.remove_class("device-connected")
        ctx_lbl.remove_class("device-name")
        ctx_lbl.add_class("device-connected" if connected else "device-name")

        ctx_btn = btn.get_style_context()
        ctx_btn.remove_class("connect-btn")
        ctx_btn.remove_class("disconnect-btn")
        if connected:
            btn.set_label("Disconnect")
            ctx_btn.add_class("disconnect-btn")
            btn.disconnect_by_func(self.on_connect) if hasattr(btn, '_connect_handler') else None
        else:
            btn.set_label("Connect")
            ctx_btn.add_class("connect-btn")
        btn.set_sensitive(True)
        return False

if __name__ == "__main__":
    import subprocess
    BluetoothPopup()
    Gtk.main()
