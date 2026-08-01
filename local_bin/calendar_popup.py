#!/usr/bin/env python3
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
import os, signal
PIDFILE = "/tmp/calendar_popup.pid"
def cleanup(*_):
    try: os.remove(PIDFILE)
    except Exception: pass
    Gtk.main_quit()
signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)
from gi.repository import Gtk, Gdk, GtkLayerShell

CSS = b"""
window {
    background-color: rgba(17, 17, 27, 0.92);
    border: 1px solid rgba(137, 180, 250, 0.3);
    border-radius: 14px;
}

calendar {
    background-color: transparent;
    color: #cdd6f4;
    border: none;
    padding: 6px;
    font-family: 'JetBrainsMono Nerd Font Propo', monospace;
    font-size: 13px;
}

calendar:selected {
    background-color: rgba(137, 180, 250, 0.35);
    color: #89b4fa;
    border-radius: 50%;
    font-weight: bold;
}

calendar.highlight {
    background-color: rgba(137, 180, 250, 0.2);
    color: #89b4fa;
    font-weight: bold;
}

calendar.other-month {
    color: rgba(108, 112, 134, 0.4);
}

calendar header {
    background-color: transparent;
    color: #89b4fa;
    font-weight: bold;
    padding: 4px 0;
}

calendar header button {
    background: transparent;
    border: none;
    color: #89b4fa;
    border-radius: 8px;
    padding: 2px 6px;
    min-width: 24px;
    min-height: 24px;
}

calendar header button:hover {
    background-color: rgba(137, 180, 250, 0.15);
    color: #cdd6f4;
}

calendar header label {
    color: #cdd6f4;
    font-weight: bold;
    font-size: 13px;
}
"""

def apply_css():
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

def main():
    apply_css()

    win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    win.set_decorated(False)
    win.set_resizable(False)

    # Layer shell setup
    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.TOP)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.ON_DEMAND)

    # Anchor top-right, with margin from bar bottom and screen edge
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP,   True)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.RIGHT, True)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT,  False)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.BOTTOM,False)

    # margin-top = waybar margin(13) + bar height(36) + gap(10) = 59
    # margin-right = waybar margin-right(20)
    GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP,   59)
    GtkLayerShell.set_margin(win, GtkLayerShell.Edge.RIGHT, 20)

    cal = Gtk.Calendar()
    cal.set_display_options(
        Gtk.CalendarDisplayOptions.SHOW_HEADING |
        Gtk.CalendarDisplayOptions.SHOW_DAY_NAMES
    )

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    box.set_margin_top(8)
    box.set_margin_bottom(8)
    box.set_margin_start(10)
    box.set_margin_end(10)
    box.pack_start(cal, True, True, 0)
    win.add(box)

    win.connect("destroy", Gtk.main_quit)
    win.connect("key-press-event", lambda w, e: cleanup() if e.keyval == Gdk.KEY_Escape else None)

    win.show_all()
    win.present()
    Gtk.main()

if __name__ == "__main__":
    main()
