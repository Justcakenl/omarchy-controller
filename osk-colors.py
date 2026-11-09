#!/usr/bin/python3
"""Print wvkbd arguments (one per line) that match the current Omarchy theme."""
import os
import subprocess
import tomllib
from pathlib import Path

THEME = Path(os.environ.get("OSK_THEME_FILE") or Path.home() / ".local/state/omarchy/current/theme/colors.toml")


def hexpart(c, fallback):
    c = str(c or fallback).lstrip("#")
    return c[:6] if len(c) >= 6 else fallback.lstrip("#")


def lum(h):
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    f = lambda v: v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def readable_on(bg, a, b):
    """Whichever of a / b contrasts more with bg."""
    contrast = lambda x, y: (max(lum(x), lum(y)) + 0.05) / (min(lum(x), lum(y)) + 0.05)
    return a if contrast(bg, a) >= contrast(bg, b) else b


try:
    t = tomllib.loads(THEME.read_text())
except (OSError, ValueError):
    t = {}
g = lambda k, d: hexpart(t.get(k), d)

background = g("background", "121212")
darker = g("darker_background", background)
lighter = g("lighter_background", background)
foreground = g("foreground", "bebebe")
accent = g("accent", "e68e0d")
selection = g("selection", lighter)
bright = g("bright_blue", accent)

try:
    font = subprocess.run(["omarchy", "font", "current"], capture_output=True, text=True, timeout=3).stdout.strip()
except Exception:
    font = ""

args = {
    "--bg": darker + "00",           # fully see-through panel: only the keys show
    "--fg": lighter,                  # letter keys
    "--fg-sp": selection,             # shift, backspace, enter, ...
    "--press": accent,
    "--press-sp": accent,
    "--swipe": bright,
    "--swipe-sp": bright,
    "--text": foreground,
    "--text-sp": foreground,
    "--text-press": readable_on(accent, background, foreground),
    "--text-swipe": readable_on(bright, background, foreground),
    "--text-swipe-sp": readable_on(bright, background, foreground),
    "--text-press-sp": readable_on(accent, background, foreground),
    "-R": "10",
    "--fn": (font or "monospace") + " 14",
}
for k, v in args.items():
    print(k)
    print(v)
