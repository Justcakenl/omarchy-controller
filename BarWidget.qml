import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Game controller as mouse + keyboard, from the bar.
//   left click    open the panel: remap every button, tune the sticks
//   right click   show / hide the on-screen keyboard
// The panel edits ~/.config/controller-desktop/config.json; the
// controller-desktop daemon (same folder) picks changes up within a second.
Panel {
  id: root
  moduleName: "io.github.justcakenl.controller"
  ipcTarget: "controller"

  readonly property string cfgPath:
    (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/controller-desktop/config.json"
  readonly property string statePath:
    (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/controller-desktop/state.json"
  readonly property string folder: Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")

  property var defaults: ({ bindings: {}, sticks: {} })
  property var cfg: ({ bindings: {}, sticks: {} })
  property var actionOptions: []
  property var daemon: ({ enabled: true, paused: false, pads: [] })
  property bool serviceOn: false
  property bool showMore: false

  // Installed apps for the "pick an app" dropdown (launched with gtk-launch).
  readonly property var appOptions: {
    var out = []
    var vals = DesktopEntries.applications.values
    for (var i = 0; i < vals.length; i++)
      if (!vals[i].noDisplay) out.push({ value: vals[i].id, label: vals[i].name })
    out.sort(function(a, b) { return a.label.localeCompare(b.label) })
    return out
  }
  function appName(id) {
    for (var i = 0; i < appOptions.length; i++) if (appOptions[i].value === id) return appOptions[i].label
    return id
  }
  // Built-in actions plus the user's own, so every dropdown offers both.
  readonly property var allActions: {
    var out = actionOptions.slice()
    var c = (cfg.custom_actions || [])
    for (var i = 0; i < c.length; i++) out.push({ value: "cmd:" + c[i].cmd, label: "★ " + c[i].label })
    return out
  }

  readonly property var buttonRows: [
    { id: "guide", label: "Xbox logo" },
    { id: "a", label: "A" }, { id: "b", label: "B" },
    { id: "x", label: "X" }, { id: "y", label: "Y" },
    { id: "lb", label: "LB" }, { id: "rb", label: "RB" },
    { id: "l3", label: "L3 (stick)" }, { id: "r3", label: "R3 (stick)" },
    { id: "start", label: "Start" }, { id: "select", label: "Select" },
    { id: "up", label: "D-pad up" }, { id: "down", label: "D-pad down" },
    { id: "left", label: "D-pad left" }, { id: "right", label: "D-pad right" }
  ]
  readonly property var stickOptions: [
    { value: "mouse", label: "Mouse" }, { value: "scroll", label: "Scroll" }, { value: "off", label: "Off" }
  ]

  readonly property string statusText: !serviceOn ? "Controller control is off"
    : (daemon.pads && daemon.pads.length > 0
        ? (daemon.paused ? "Paused: a game is in front"
           : (daemon.enabled ? daemon.pads[0] + " connected" : "Switched off (Start + Select)"))
        : "No controller connected")

  readonly property real colWidth: Style.space(150)

  // List editor shared by the Xbox menu and the custom actions: existing rows
  // with a remove button, plus an add row (pick an app, or type a name + command).
  component EntryEditor: Column {
    id: ed
    property string listKey: ""
    spacing: Style.space(6)

    Repeater {
      model: root.cfg[ed.listKey] || []
      Row {
        required property var modelData
        required property int index
        spacing: Style.space(6)
        Text {
          width: Style.space(130)
          height: Style.spacing.controlHeight
          verticalAlignment: Text.AlignVCenter
          text: modelData.label
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Text {
          width: Style.space(330)
          height: Style.spacing.controlHeight
          verticalAlignment: Text.AlignVCenter
          text: modelData.cmd
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Qt.darker(Commons.Color.popups.text, 1.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Button { text: "Remove"; onClicked: root.removeEntry(ed.listKey, index) }
      }
    }

    Row {
      spacing: Style.space(6)
      SearchableDropdown {
        width: Style.space(180)
        showLabel: false
        triggerLabel: "Pick an app…"
        options: root.appOptions
        value: ""
        onChanged: function(v) {
          nameField.text = root.appName(v)
          cmdField.text = "gtk-launch " + v
        }
      }
      TextField { id: nameField; width: Style.space(120); placeholderText: "Name" }
      TextField { id: cmdField; width: Style.space(230); placeholderText: "or a shell command" }
      Button {
        text: "Add"
        onClicked: {
          root.addEntry(ed.listKey, nameField.text.trim(), cmdField.text.trim())
          nameField.text = ""; cmdField.text = ""
        }
      }
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function merged(over) {
    var out = JSON.parse(JSON.stringify(defaults))
    if (!over || typeof over !== "object") return out
    for (var k in over) {
      if (k === "custom_actions" || k === "menu") {
        if (Array.isArray(over[k])) out[k] = over[k]
      } else if ((k === "bindings" || k === "sticks") && typeof over[k] === "object") {
        for (var n in over[k]) {
          if (k === "bindings" && typeof over[k][n] === "object") {
            out.bindings[n] = out.bindings[n] || {}
            for (var s in over[k][n]) out.bindings[n][s] = over[k][n][s]
          } else {
            out[k][n] = over[k][n]
          }
        }
      } else if (k in out) {
        out[k] = over[k]
      }
    }
    return out
  }

  function save(next) {
    cfg = next
    cfgFile.setText(JSON.stringify(next, null, 2) + "\n")
  }

  function setBinding(name, slot, value) {
    var next = JSON.parse(JSON.stringify(cfg))
    next.bindings[name] = next.bindings[name] || {}
    next.bindings[name][slot] = value
    save(next)
  }

  function setValue(key, value) {
    var next = JSON.parse(JSON.stringify(cfg))
    next[key] = value
    save(next)
  }

  function setStick(side, value) {
    var next = JSON.parse(JSON.stringify(cfg))
    next.sticks[side] = value
    save(next)
  }

  function addEntry(key, label, cmd) {
    if (!label || !cmd) return
    var next = JSON.parse(JSON.stringify(cfg))
    next[key] = (next[key] || []).concat([{ label: label, cmd: cmd }])
    save(next)
  }

  function removeEntry(key, index) {
    var next = JSON.parse(JSON.stringify(cfg))
    next[key].splice(index, 1)
    save(next)
  }

  function resetAll() {
    save(JSON.parse(JSON.stringify(defaults)))
  }

  function bindingOf(name, slot) {
    var b = cfg.bindings && cfg.bindings[name]
    return (b && b[slot]) || "none"
  }

  function setService(on) {
    systemctl.command = on
      ? ["systemctl", "--user", "enable", "--now", "controller-desktop"]
      : ["systemctl", "--user", "disable", "--now", "controller-desktop"]
    systemctl.running = true
  }

  Component.onCompleted: {
    var acts = JSON.parse(actionsFile.text() || "{}")
    var list = []
    for (var id in acts) list.push({ value: id, label: acts[id].label || id })
    actionOptions = list
    defaults = JSON.parse(defaultsFile.text() || "{}")
    cfg = JSON.parse(JSON.stringify(defaults))
    mkdir.running = true
    cfgFile.reload()
    activeCheck.running = true
  }

  FileView { id: actionsFile; path: root.folder + "/actions.json"; blockLoading: true }
  FileView { id: defaultsFile; path: root.folder + "/defaults.json"; blockLoading: true }

  FileView {
    id: cfgFile
    path: root.cfgPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.cfg = root.merged(JSON.parse(text())) } catch (err) { root.cfg = root.merged(null) }
    }
    onLoadFailed: root.cfg = root.merged(null)
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.daemon = JSON.parse(text()) } catch (err) {} }
  }

  Process { id: mkdir; command: ["mkdir", "-p", root.cfgPath.replace(/\/[^/]*$/, "")] }

  Process {
    id: systemctl
    onExited: activeCheck.running = true
  }

  Process {
    id: activeCheck
    command: ["systemctl", "--user", "is-active", "--quiet", "controller-desktop"]
    onExited: function(code) { root.serviceOn = (code === 0) }
  }

  Process { id: oskRun; command: [root.folder + "/osk-toggle"] }

  // The state file only appears once the daemon runs, and a watch on a
  // missing file never fires.
  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: { stateFile.reload(); activeCheck.running = true }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰊴" // nf-md-gamepad (U+F02B4)
    active: root.opened || (root.serviceOn && root.daemon.pads && root.daemon.pads.length > 0 && root.daemon.enabled && !root.daemon.paused)
    dimmed: !root.serviceOn
    tooltipText: root.statusText + " — click for settings, right-click for the on-screen keyboard"
    onPressed: function(b) {
      if (b === Qt.RightButton) oskRun.running = true
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(root.showMore ? Style.space(640) : Style.space(340))
    contentHeight: panel.fittedContentHeight(root.showMore ? Style.space(640) : Style.space(330))

    content: Item {
      anchors.fill: parent

      Column {
        id: head
        width: parent.width
        spacing: Style.space(8)

        Toggle {
          width: parent.width
          label: "Control the desktop with a controller"
          description: root.statusText
          checked: root.serviceOn
          onClicked: root.setService(!root.serviceOn)
        }

        Row {
          spacing: Style.space(6)
          Button { text: "Keyboard"; onClicked: oskRun.running = true; tooltipText: "Show or hide the virtual keyboard" }
          Button { text: "Reset"; onClicked: root.resetAll(); tooltipText: "Put every button and stick back to the default" }
          Button {
            text: root.showMore ? "Less ▴" : "More ▾"
            onClicked: root.showMore = !root.showMore
            tooltipText: "Show every button binding, the controller menu and your own actions"
          }
        }
      }

      Flickable {
        id: scroller
        anchors.top: head.bottom
        anchors.topMargin: Style.space(8)
        anchors.bottom: root.showMore ? foot.top : parent.bottom
        anchors.bottomMargin: Style.space(6)
        width: parent.width
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: body
          width: scroller.width - Style.space(10)
          spacing: Style.space(6)

          PanelSectionHeader { text: "STICKS" }

          Row {
            spacing: Style.space(12)
            Dropdown {
              width: Style.space(150)
              label: "Left stick"
              options: root.stickOptions
              value: (root.cfg.sticks && root.cfg.sticks.left) || "mouse"
              onChanged: function(v) { root.setStick("left", v) }
            }
            Dropdown {
              width: Style.space(150)
              label: "Right stick"
              options: root.stickOptions
              value: (root.cfg.sticks && root.cfg.sticks.right) || "scroll"
              onChanged: function(v) { root.setStick("right", v) }
            }
          }

          PanelSectionHeader { text: "MOUSE SPEED" }
          PanelSlider {
            bar: root.bar
            width: parent.width
            height: Style.spacing.controlHeight
            minimum: 300; maximum: 4000; step: 100; integer: true
            value: root.cfg.mouse_speed || 1500
            onReleased: function(v) { root.setValue("mouse_speed", Math.round(v)) }
          }

          Column {
            id: more
            visible: root.showMore
            width: parent.width
            spacing: Style.space(6)

          PanelSectionHeader { text: "SCROLL SPEED" }
          PanelSlider {
            bar: root.bar
            width: parent.width
            height: Style.spacing.controlHeight
            minimum: 200; maximum: 3000; step: 100; integer: true
            value: root.cfg.scroll_speed || 1100
            onReleased: function(v) { root.setValue("scroll_speed", Math.round(v)) }
          }

          PanelSectionHeader { text: "STICK DEAD ZONE (raise it if the cursor drifts)" }
          PanelSlider {
            bar: root.bar
            width: parent.width
            height: Style.spacing.controlHeight
            minimum: 0.05; maximum: 0.5; step: 0.01
            value: root.cfg.deadzone || 0.16
            onReleased: function(v) { root.setValue("deadzone", Math.round(v * 100) / 100) }
          }

            PanelSeparator {}
            PanelSectionHeader { text: "BUTTONS" }

            Row {
              spacing: Style.space(6)
              Text { width: Style.space(100); text: ""; textFormat: Text.PlainText }
              Repeater {
                model: ["Tap", "Hold", "With LT held"]
                Text {
                  required property string modelData
                  width: root.colWidth
                  text: modelData
                  textFormat: Text.PlainText
                  color: Qt.darker(Commons.Color.popups.text, 1.4)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }

            Repeater {
              model: root.buttonRows
              Row {
                required property var modelData
                spacing: Style.space(6)

                Text {
                  width: Style.space(100)
                  height: Style.spacing.controlHeight
                  verticalAlignment: Text.AlignVCenter
                  text: modelData.label
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  color: Commons.Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                Repeater {
                  model: ["tap", "hold", "layer"]
                  Dropdown {
                    required property string modelData
                    width: root.colWidth
                    showLabel: false
                    options: root.allActions
                    value: root.bindingOf(parent.modelData.id, modelData)
                    onChanged: function(v) { root.setBinding(parent.modelData.id, modelData, v) }
                  }
                }
              }
            }


            PanelSeparator {}
            PanelSectionHeader { text: "XBOX LOGO MENU (what opens when you press the logo)" }
            EntryEditor { listKey: "menu"; width: parent.width }

            PanelSeparator {}
            PanelSectionHeader { text: "YOUR OWN ACTIONS (show up in every dropdown, marked with ★)" }
            EntryEditor { listKey: "custom_actions"; width: parent.width }
          }
        }
      }

      Text {
        id: foot
        visible: root.showMore
        anchors.bottom: parent.bottom
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: "Hold LT for the second layer, RT for a slow cursor. Hold Start + Select for a second to switch the controller off or on. A \"Hold\" action fires after holding a button; tapping it does the Tap action."
        color: Qt.darker(Commons.Color.popups.text, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
