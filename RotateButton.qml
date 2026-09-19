import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar button for omarchy-rotate. The scheduling lives in Service.qml; this is
// just a handle on it:
//
//   left click    change the background now
//   right click   flip between the light and dark theme
//   middle click  open rotate.conf in the editor
//   hover         current background, next rotation, next theme switch
BarWidget {
  id: root
  moduleName: "drake.rotate"

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  readonly property string bin: pluginDir + "bin/omarchy-rotate"

  property string summary: ""

  function run(args) {
    if (root.bar) root.bar.run(root.bar.shellQuote(root.bin) + " " + args)
    settle.restart()
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  // Keep the lines of `status` worth a tooltip, without their labels.
  function summarize(text) {
    var wanted = ["Background:", "Interval:", "Now:"]
    var out = []
    var lines = String(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
      for (var j = 0; j < wanted.length; j++) {
        if (lines[i].indexOf(wanted[j]) === 0) out.push(lines[i].slice(wanted[j].length).trim())
      }
    }
    return out.join("\n")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: ["bash", "-lc", "\"$0\" status", root.bin]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.summary = root.summarize(text)
    }
  }

  Timer {
    interval: 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // A click changes the background or theme; give it a moment, then re-read.
  Timer {
    id: settle
    interval: 2000
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: root.summary || "Rotate"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.run("theme toggle")
      else if (b === Qt.MiddleButton) root.bar.run("omarchy-launch-editor \"$(" + root.bar.shellQuote(root.bin) + " config --init)\"")
      else root.run("bg next")
    }
  }
}
