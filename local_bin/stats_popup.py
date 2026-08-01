#!/usr/bin/env python3
import gi, psutil, threading, os, signal, subprocess

PIDFILE = "/tmp/stats_popup.pid"

def cleanup(*_):
    try: os.remove(PIDFILE)
    except Exception: pass
    Gtk.main_quit()

signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)
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
label.value { color: #89b4fa; font-weight: bold; min-width: 42px; }
label.value.warn  { color: #f9e2af; }
label.value.crit  { color: #f38ba8; }
label.proc-name { color: #cdd6f4; font-size: 11px; }
label.proc-val  { color: #89b4fa;  font-size: 11px; min-width: 38px; }
progressbar { min-height: 6px; }
progressbar trough {
    background-color: rgba(49,50,68,0.8);
    border-radius: 4px;
    border: 1px solid rgba(137,180,250,0.1);
    min-height: 6px;
}
progressbar progress {
    background: linear-gradient(90deg, rgba(137,180,250,0.9), rgba(203,166,247,0.7));
    border-radius: 4px;
    min-height: 6px;
}
progressbar.warn progress  { background: rgba(249,226,175,0.85); }
progressbar.crit progress  { background: rgba(243,139,168,0.85); }
separator { background-color: rgba(137,180,250,0.12); min-height: 1px; margin: 6px 0; }
"""

def apply_css():
    p = Gtk.CssProvider()
    p.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

def pct_class(v):
    if v >= 85: return "crit"
    if v >= 65: return "warn"
    return ""

def temp_class(t):
    if t >= 85: return "crit"
    if t >= 70: return "warn"
    return ""

def make_bar(value, css_class=""):
    bar = Gtk.ProgressBar()
    bar.set_fraction(min(value / 100, 1.0))
    bar.set_hexpand(True)
    if css_class:
        bar.get_style_context().add_class(css_class)
    return bar

def make_row(icon_text, value_text, fraction, css=""):
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    lbl = Gtk.Label(label=icon_text)
    lbl.set_halign(Gtk.Align.START)
    row.pack_start(lbl, False, False, 0)
    bar = make_bar(fraction * 100, css)
    row.pack_start(bar, True, True, 0)
    val = Gtk.Label(label=value_text)
    val.get_style_context().add_class("value")
    if css: val.get_style_context().add_class(css)
    val.set_halign(Gtk.Align.END)
    row.pack_start(val, False, False, 0)
    return row

def get_cpu_temp():
    try:
        temps = psutil.sensors_temperatures()
        for key in ("coretemp", "k10temp", "acpitz", "cpu_thermal"):
            if key in temps:
                entries = temps[key]
                # Prefer "Package id 0" or "Tctl", fall back to first entry
                pkg = next((e for e in entries if "package" in e.label.lower() or "tctl" in e.label.lower()), entries[0])
                return pkg.current
    except Exception:
        pass
    return None

def get_gpu_stats():
    try:
        out = subprocess.check_output(
            ["nvidia-smi",
             "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,clocks.current.graphics,clocks.max.graphics",
             "--format=csv,noheader,nounits"],
            text=True, timeout=3
        ).strip()
        parts = [p.strip() for p in out.split(",")]
        return {
            "util":      float(parts[0]),
            "mem_used":  float(parts[1]),
            "mem_total": float(parts[2]),
            "temp":      float(parts[3]),
            "power":     float(parts[4]),
            "clk_cur":   float(parts[5]),
            "clk_max":   float(parts[6]),
        }
    except Exception:
        return None

class StatsPopup:
    def __init__(self):
        apply_css()
        self.win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.win.set_decorated(False)
        self.win.set_resizable(False)

        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_keyboard_mode(self.win, GtkLayerShell.KeyboardMode.ON_DEMAND)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.TOP,   True)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.LEFT,  True)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.RIGHT, False)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.BOTTOM,False)
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.TOP,  59)
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.LEFT, 20)

        self.win.connect("destroy", cleanup)
        self.win.connect("key-press-event",
            lambda w, e: cleanup() if e.keyval == Gdk.KEY_Escape else None)

        self.outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.outer.set_margin_top(12)
        self.outer.set_margin_bottom(12)
        self.outer.set_margin_start(14)
        self.outer.set_margin_end(14)
        self.outer.set_size_request(320, -1)
        self.win.add(self.outer)

        psutil.cpu_percent(interval=None)
        threading.Thread(target=self._load_data, daemon=True).start()

        self.win.show_all()
        self.win.present()

    def _load_data(self):
        cpu  = psutil.cpu_percent(interval=0.5)
        mem  = psutil.virtual_memory()
        swap = psutil.swap_memory()
        disks = [(p.mountpoint, psutil.disk_usage(p.mountpoint))
                 for p in psutil.disk_partitions()
                 if p.fstype and not p.mountpoint.startswith("/boot")]
        procs = sorted(psutil.process_iter(['pid','name','cpu_percent','memory_percent']),
                       key=lambda p: p.info['cpu_percent'] or 0, reverse=True)[:5]
        gpu = get_gpu_stats()
        cpu_temp = get_cpu_temp()
        GLib.idle_add(self._build_ui, cpu, mem, swap, disks, procs, gpu, cpu_temp)

    def _build_ui(self, cpu, mem, swap, disks, procs, gpu, cpu_temp):
        for c in self.outer.get_children():
            c.destroy()

        def section(title):
            lbl = Gtk.Label(label=title)
            lbl.get_style_context().add_class("section-title")
            lbl.set_halign(Gtk.Align.START)
            self.outer.pack_start(lbl, False, False, 0)

        def sep():
            s = Gtk.Separator()
            s.set_margin_top(6); s.set_margin_bottom(2)
            self.outer.pack_start(s, False, False, 0)

        # ── CPU ─────────────────────────────────────────────
        section("  CPU")
        css = pct_class(cpu)
        self.outer.pack_start(
            make_row("  Total", f"{cpu:.0f}%", cpu/100, css), False, False, 4)
        if cpu_temp is not None:
            tcss = temp_class(cpu_temp)
            self.outer.pack_start(
                make_row("  Temp", f"{cpu_temp:.0f}°C", cpu_temp/100, tcss),
                False, False, 4)
        freq = psutil.cpu_freq()
        if freq:
            freq_pct = freq.current / freq.max if freq.max else 0
            self.outer.pack_start(
                make_row("  Freq", f"{freq.current/1000:.2f}GHz", freq_pct),
                False, False, 4)

        per = psutil.cpu_percent(percpu=True)
        grid = Gtk.Grid(column_spacing=6, row_spacing=3)
        grid.set_margin_top(2)
        for i, p in enumerate(per):
            c = pct_class(p)
            b = make_bar(p, c)
            b.set_size_request(52, -1)
            v = Gtk.Label(label=f"{p:.0f}%")
            v.get_style_context().add_class("value")
            if c: v.get_style_context().add_class(c)
            v.set_size_request(34, -1)
            grid.attach(b, (i % 4) * 2,     i // 4, 1, 1)
            grid.attach(v, (i % 4) * 2 + 1, i // 4, 1, 1)
        self.outer.pack_start(grid, False, False, 4)

        sep()
        # ── GPU ─────────────────────────────────────────────
        section("󰾲  GPU  ·  RTX 3050")
        if gpu:
            util_css = pct_class(gpu["util"])
            self.outer.pack_start(
                make_row("󰾲  Usage", f"{gpu['util']:.0f}%", gpu["util"]/100, util_css),
                False, False, 4)

            vram_pct = gpu["mem_used"] / gpu["mem_total"] * 100
            vram_css = pct_class(vram_pct)
            self.outer.pack_start(
                make_row("  VRAM",
                         f"{gpu['mem_used']/1024:.1f}/{gpu['mem_total']/1024:.1f}G",
                         vram_pct/100, vram_css),
                False, False, 4)

            temp_css = temp_class(gpu["temp"])
            self.outer.pack_start(
                make_row("  Temp", f"{gpu['temp']:.0f}°C", gpu["temp"]/100, temp_css),
                False, False, 4)

            self.outer.pack_start(
                make_row("󱪉  Power", f"{gpu['power']:.0f}W", min(gpu["power"]/80, 1.0)),
                False, False, 4)
            if gpu["clk_max"] > 0:
                clk_pct = gpu["clk_cur"] / gpu["clk_max"]
                self.outer.pack_start(
                    make_row("  Freq", f"{gpu['clk_cur']:.0f}MHz", clk_pct),
                    False, False, 4)
        else:
            lbl = Gtk.Label(label="  nvidia-smi unavailable")
            lbl.set_halign(Gtk.Align.START)
            self.outer.pack_start(lbl, False, False, 4)

        sep()
        # ── RAM ─────────────────────────────────────────────
        section("  MEMORY")
        mem_pct = mem.percent
        css = pct_class(mem_pct)
        used  = mem.used  / 1024**3
        total = mem.total / 1024**3
        self.outer.pack_start(
            make_row("  RAM", f"{used:.1f}/{total:.1f}G", mem_pct/100, css),
            False, False, 4)
        if swap.total > 0:
            sw_pct = swap.percent
            sw_used = swap.used / 1024**3
            sw_tot  = swap.total / 1024**3
            self.outer.pack_start(
                make_row("  Swap", f"{sw_used:.1f}/{sw_tot:.1f}G", sw_pct/100, pct_class(sw_pct)),
                False, False, 4)

        sep()
        # ── Disk ────────────────────────────────────────────
        section("󰋊  DISK")
        for mount, usage in disks[:3]:
            name = mount if mount != "/" else "/ (root)"
            pct  = usage.percent
            used_g = usage.used  / 1024**3
            tot_g  = usage.total / 1024**3
            self.outer.pack_start(
                make_row(f"  {name}", f"{used_g:.0f}/{tot_g:.0f}G", pct/100, pct_class(pct)),
                False, False, 4)

        sep()
        # ── Top processes ────────────────────────────────────
        section("  TOP PROCESSES")
        for p in procs:
            try:
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                nm = Gtk.Label(label=p.info['name'][:22])
                nm.get_style_context().add_class("proc-name")
                nm.set_halign(Gtk.Align.START)
                nm.set_hexpand(True)
                cpu_l = Gtk.Label(label=f"CPU {p.info['cpu_percent']:.0f}%")
                cpu_l.get_style_context().add_class("proc-val")
                mem_l = Gtk.Label(label=f"MEM {p.info['memory_percent']:.1f}%")
                mem_l.get_style_context().add_class("proc-val")
                row.pack_start(nm, True, True, 0)
                row.pack_start(cpu_l, False, False, 0)
                row.pack_start(mem_l, False, False, 0)
                self.outer.pack_start(row, False, False, 2)
            except Exception:
                pass

        self.win.show_all()
        GLib.timeout_add(3000, self._refresh)
        return False

    def _refresh(self):
        if not self.win.get_visible():
            return False
        psutil.cpu_percent(interval=None)
        threading.Thread(target=self._load_data, daemon=True).start()
        return False

if __name__ == "__main__":
    StatsPopup()
    Gtk.main()
