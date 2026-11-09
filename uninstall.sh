#!/bin/bash
# Remove the controller-desktop service. Your settings in
# ~/.config/controller-desktop are kept unless you pass --purge.
systemctl --user disable --now controller-desktop 2>/dev/null || true
rm -f ~/.config/systemd/user/controller-desktop.service
systemctl --user daemon-reload
pkill -x wvkbd-mobintl 2>/dev/null || true
[[ "$1" == "--purge" ]] && rm -rf ~/.config/controller-desktop
echo "Removed. Now run: omarchy plugin remove io.github.justcakenl.controller"
