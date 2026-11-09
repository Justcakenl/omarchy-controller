# Omarchy Controller

Use an Xbox (or any gamepad) as a mouse and keyboard for your whole
[Omarchy](https://omarchy.org) desktop. Sit back on the couch, browse, switch windows,
type with an on-screen keyboard, and remap every button from a compact bar panel.

## Features

- **Sticks as mouse and scroll** (swap or turn off), with an adjustable dead zone and speed
- **Every button remappable**, three slots each: *Tap*, *Hold* and *With LT held* (second layer)
- **Xbox logo menu**: a popup with your favorite things (Browser, Steam, YouTube by default).
  D-pad moves, A picks, B closes. Add or remove entries yourself
- **Your own actions**: pick an installed app or type any shell command; it shows up in every dropdown
- **Compact panel**: opens small, press *More* for the full button table and editors
- **On-screen keyboard** (wvkbd) themed from your current Omarchy theme
- **RT = slow precise cursor**, hold **B** to close a window
- **Never grabs the pad**, so games keep working. It pauses itself while a game
  (`steam_app_*`, gamescope) or Steam Big Picture is focused
- **Start + Select** for one second switches controller control off or on

## Install

```bash
omarchy plugin add https://github.com/Justcakenl/omarchy-controller.git --enable
bash ~/.config/omarchy/plugins/io.github.justcakenl.controller/install.sh
omarchy bar put io.github.justcakenl.controller
```

`install.sh` does three things, nothing else:

1. installs `python-evdev` and (AUR) `wvkbd` via `omarchy pkg`
2. writes the user service `~/.config/systemd/user/controller-desktop.service`
3. enables and starts it

It never touches your existing Hyprland or Omarchy configuration.

> Tip: if the Xbox logo also opens the Steam overlay, turn off
> *Steam > Settings > Controller > Guide button focuses Steam*. Steam grabs that
> button itself.

## Use

Click the gamepad icon in the bar for settings, right-click it for the on-screen keyboard.

| Control | Default |
| --- | --- |
| Left stick / Right stick | Mouse / Scroll |
| A / X | Left click / Right click |
| B (tap / hold) | Escape / Close window |
| Y | On-screen keyboard |
| LB / RB | Previous / next workspace |
| Start / Select | Omarchy menu / Next window |
| D-pad | Arrow keys (Focus window with LT) |
| Xbox logo | Controller menu |
| LT held | Second layer |
| RT held | Slow cursor |

## Configure

Everything is saved to `~/.config/controller-desktop/config.json` and applied within a
second. You can edit it by hand:

```json
{
  "bindings": { "x": { "tap": "cmd:omarchy-lock-screen" } },
  "custom_actions": [{ "label": "Spotify", "cmd": "gtk-launch spotify" }],
  "menu": [
    { "label": "Browser", "cmd": "omarchy-launch-browser" },
    { "label": "YouTube", "cmd": "omarchy-launch-webapp https://www.youtube.com" }
  ]
}
```

Missing keys fall back to `defaults.json`. Any entry of `actions.json` or
`"cmd:<shell command>"` is a valid binding.

## Remove

```bash
bash ~/.config/omarchy/plugins/io.github.justcakenl.controller/uninstall.sh   # add --purge to delete settings
omarchy plugin remove io.github.justcakenl.controller
```

## Notes

- Plugins run unsandboxed. This one runs a small Python daemon that creates virtual
  mouse and keyboard devices through `/dev/uinput` and runs the shell commands *you* configure.
- Dependencies: `python-evdev`, `wvkbd` (optional, on-screen keyboard), `systemd --user`.

## Files

| File | Purpose |
| --- | --- |
| `manifest.json`, `BarWidget.qml` | bar widget and settings panel |
| `controller-desktop` | the daemon (evdev in, uinput out) |
| `actions.json`, `defaults.json` | available actions and default settings |
| `osk-toggle`, `osk-colors.py` | on-screen keyboard and theme colors |
| `install.sh`, `uninstall.sh` | service setup and removal |

## License

MIT
