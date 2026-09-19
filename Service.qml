import QtQuick
import Quickshell
import Quickshell.Io

// Headless service for Omarchy quattro. All the logic lives in bin/omarchy-rotate;
// this just ticks it on a timer, ticks with --wake when the shell starts (login/boot),
// restarts the background interval when the theme changes, and exposes IPC:
//
//   omarchy-shell rotate next     change the background now
//   omarchy-shell rotate interval 1h   change how often the background rotates
//   omarchy-shell rotate folder all    every theme pulls from BG_DIR ("gruvbox gruvbox-light": only those)
//   omarchy-shell rotate toggle   flip between the light and dark theme
//   omarchy-shell rotate tick     run a scheduling pass
//   omarchy-shell rotate status   plain-text status
Item {
  id: root

  // Injected by omarchy-shell (the service loader).
  property var shell: null

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  readonly property string bin: pluginDir + "bin/omarchy-rotate"
  readonly property string themeNameFile: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
  readonly property int tickIntervalMs: 5 * 60 * 1000

  property string lastTheme: ""
  property string lastStatus: ""

  function run(args) {
    var cmd = ["bash", "-lc", "\"$0\" \"$@\"", root.bin].concat(args)
    var p = runnerComponent.createObject(root, { command: cmd })
    p.running = true
  }

  Component {
    id: runnerComponent
    Process {
      onExited: destroy()
    }
  }

  Process {
    id: statusProc
    command: ["bash", "-lc", "\"$0\" status", root.bin]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lastStatus = text
    }
  }

  // Scheduling pass every 5 minutes. `tick` is idempotent and flock-serialized,
  // so it is fine if a systemd timer from `omarchy-rotate install` also ticks.
  Timer {
    interval: root.tickIntervalMs
    running: true
    repeat: true
    onTriggered: root.run(["tick"])
  }

  // The shell starts once per session: treat that as boot/wake.
  Component.onCompleted: {
    root.run(["tick", "--wake"])
    themeWatch.reload()
  }

  // When the theme changes (by hand, menu, or our own schedule), omarchy applies
  // the theme's own background. `bg sync` swaps it for one from the rotation pool
  // (or just restarts the interval if it already is one).
  FileView {
    id: themeWatch
    path: root.themeNameFile
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var theme = String(text()).trim()
      if (theme && root.lastTheme && theme !== root.lastTheme) root.run(["bg", "sync"])
      root.lastTheme = theme
    }
  }

  IpcHandler {
    target: "rotate"

    function next(): string {
      root.run(["bg", "next"])
      return "ok"
    }

    function interval(value: string): string {
      root.run(["interval", value])
      return "ok"
    }

    function folder(themes: string): string {
      root.run(["folder"].concat(themes.trim().split(/\s+/)))
      return "ok"
    }

    function toggle(): string {
      root.run(["theme", "toggle"])
      return "ok"
    }

    function tick(): string {
      root.run(["tick"])
      return "ok"
    }

    function status(): string {
      statusProc.running = true
      return root.lastStatus || "status refreshing, call again"
    }
  }
}
