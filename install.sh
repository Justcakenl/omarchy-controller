#!/bin/bash
# Set up the controller-desktop daemon for this plugin: packages + user service.
# Run once after installing the plugin:  bash install.sh
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
omarchy pkg add python-evdev
omarchy pkg aur add wvkbd   # on-screen keyboard (optional but used by the OSK action)
chmod +x "$HERE/controller-desktop" "$HERE/osk-toggle"
mkdir -p ~/.config/systemd/user ~/.config/controller-desktop
cat > ~/.config/systemd/user/controller-desktop.service <<UNIT
[Unit]
Description=Control the Omarchy desktop with a game controller
After=graphical-session.target

[Service]
ExecStart=$HERE/controller-desktop
Restart=always
RestartSec=3

[Install]
WantedBy=graphical-session.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now controller-desktop
echo "Done. Add the widget with: omarchy bar put io.github.justcakenl.controller"
