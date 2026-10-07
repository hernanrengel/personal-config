import app from "ags/gtk3/app"
import style from "./style.css"
import Bar, { 
  HardwareDashboard, 
  CalendarDashboard, 
  AudioDashboard, 
  ConnectivityDashboard, 
  BatteryDashboard,
  getMonitorState,
  getMonitorIndex
} from "./widget/Bar"
import AppLauncher from "./widget/AppLauncher"
import PowerMenu from "./widget/PowerMenu"
import NotificationPopups from "./widget/NotificationPopups"
import NotificationCenter from "./widget/NotificationCenter"
import ControlCenter from "./widget/ControlCenter"
import OSD, { updateBrightness } from "./widget/OSD"
import { Gdk } from "ags/gtk3"
import Hyprland from "gi://AstalHyprland"

const hyprland = Hyprland.get_default()
const activeWindows = new Map<Gdk.Monitor, any[]>()

function getActiveMonitor(): Gdk.Monitor {
  try {
    const focused = hyprland.focused_monitor
    if (focused) {
      const gdkMonitors = app.get_monitors()
      for (const m of gdkMonitors) {
        const geom = m.get_geometry()
        if (geom.x === focused.x && geom.y === focused.y &&
            geom.width === focused.width && geom.height === focused.height) {
          return m
        }
      }
    }
  } catch (e) {
    console.error("Error getting active monitor via AstalHyprland:", e)
  }
  return app.get_monitors()[0]
}

function startWidgets(monitor: Gdk.Monitor) {
  const index = getMonitorIndex(monitor)
  const geom = monitor.get_geometry()
  console.log(`[AGS Startup] startWidgets called for monitor index: ${index}, geometry: x=${geom.x}, y=${geom.y}, w=${geom.width}, h=${geom.height}`)
  if (activeWindows.has(monitor)) return
  
  const bars = [
    Bar(monitor),
    HardwareDashboard(monitor),
    CalendarDashboard(monitor),
    AudioDashboard(monitor),
    ConnectivityDashboard(monitor),
    BatteryDashboard(monitor),
    AppLauncher(monitor),
    PowerMenu(monitor),
    NotificationPopups(monitor),
    NotificationCenter(monitor),
    ControlCenter(monitor),
    OSD(monitor)
  ]
  activeWindows.set(monitor, bars)
}

function stopWidgets(monitor: Gdk.Monitor) {
  const bars = activeWindows.get(monitor)
  if (bars) {
    bars.forEach(win => {
      try {
        win.destroy()
      } catch (e) {
        // ignore
      }
    })
    activeWindows.delete(monitor)
  }
}

app.start({
  css: style,
  main() {
    // Start for existing monitors
    app.get_monitors().forEach(startWidgets)
    
    // Connect to monitor changes dynamically
    const display = Gdk.Display.get_default()
    if (display) {
      display.connect("monitor-added", (disp, monitor) => {
        startWidgets(monitor)
      })
      display.connect("monitor-removed", (disp, monitor) => {
        stopWidgets(monitor)
      })
    }
  },
  requestHandler(argv, response) {
    if (argv.includes("osd-brightness")) {
      updateBrightness()
      response("ok")
    } else if (argv.includes("toggle-launcher")) {
      const monitor = getActiveMonitor()
      const state = getMonitorState(monitor)
      state.setLauncherVisible(!state.launcherVisible())
      response("ok")
    } else if (argv.includes("toggle-power")) {
      const monitor = getActiveMonitor()
      const state = getMonitorState(monitor)
      state.setPowerVisible(!state.powerVisible())
      response("ok")
    } else if (argv.includes("toggle-notif")) {
      const monitor = getActiveMonitor()
      const state = getMonitorState(monitor)
      state.setNotifVisible(!state.notifVisible())
      response("ok")
    } else if (argv.includes("toggle-control-center")) {
      const monitor = getActiveMonitor()
      const state = getMonitorState(monitor)
      if (state.setControlCenterVisible && state.controlCenterVisible) {
          state.setControlCenterVisible(!state.controlCenterVisible())
      }
      response("ok")
    } else {
      response("unknown request: " + JSON.stringify(argv))
    }
  }
})
