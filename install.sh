#!/usr/bin/env bash
# omastream installer — puts the CLI, shell plugin, icons and launchers in
# place, then enables the plugin in the Omarchy shell.
#
#   ./install.sh            copy files (default)
#   ./install.sh --link     symlink everything instead (dev workflow)
#   ./install.sh --uninstall
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK=0
case "${1:-}" in
  --link) LINK=1 ;;
  -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
  --uninstall)
    rm -f "$HOME/.local/bin/omastream"
    rm -rf "$HOME/.config/omarchy/plugins/dhirajarya.omastream"
    rm -f "$HOME/.local/share/applications/omastream-start.desktop"
    rm -f "$HOME/.local/share/applications/omastream-stop.desktop"
    rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/omastream.svg"
    for s in 512x512 256x256 128x128 64x64; do
      rm -f "$HOME/.local/share/icons/hicolor/$s/apps/omastream.png"
    done
    echo "omastream removed (config and state left in place)."
    exit 0 ;;
  "") : ;;
  *) echo "unknown option: $1"; exit 1 ;;
esac

copy() {
  local src="$1" dst="$2" mode="${3:-644}"
  mkdir -p "$(dirname "$dst")"
  if (( LINK )); then
    ln -sfn "$src" "$dst"
  else
    install -D -m "$mode" "$src" "$dst"
  fi
}

say() { printf '  %-46s %s\n' "$1" "$2"; }

# ── CLI ──────────────────────────────────────────────────────────────────────
copy "$REPO/bin/omastream" "$HOME/.local/bin/omastream" 755;            say "CLI" "$HOME/.local/bin/omastream"

# ── Omarchy shell plugin ─────────────────────────────────────────────────────
PLUGIN_SRC="$REPO/plugin"
PLUGIN_DST="$HOME/.config/omarchy/plugins/dhirajarya.omastream"
mkdir -p "$PLUGIN_DST"
for f in manifest.json Service.qml CameraBubble.qml BarWidget.qml; do
  copy "$PLUGIN_SRC/$f" "$PLUGIN_DST/$f"
done
say "shell plugin" "$PLUGIN_DST"

# ── icons + launchers ────────────────────────────────────────────────────────
ICON_BASE="$HOME/.local/share/icons/hicolor"
copy "$REPO/assets/omastream.svg" "$ICON_BASE/scalable/apps/omastream.svg"
for size in 512x512 256x256 128x128 64x64; do
  copy "$REPO/assets/icons/$size/apps/omastream.png" "$ICON_BASE/$size/apps/omastream.png"
done
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
  gtk-update-icon-cache -qf "$ICON_BASE" 2>/dev/null || true
say "icons" "$ICON_BASE (4 sizes + svg)"

for entry in omastream-start omastream-stop; do
  copy "$REPO/assets/$entry.desktop" "$HOME/.local/share/applications/$entry.desktop"
done
say "launchers" "start + stop desktop entries"

# ── enable the plugin in the shell ───────────────────────────────────────────
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin enable dhirajarya.omastream right >/dev/null 2>&1 \
    && say "plugin enabled" "right section of the bar" \
    || say "plugin" "not enabled automatically — run: omarchy plugin enable dhirajarya.omastream right"
fi

echo
echo "done. next:"
echo "  1. omastream config stream-key   # paste your YouTube stream key"
echo "  2. omarchy restart shell         # load the plugin (bubble + LIVE badge)"
echo "  3. omastream test                # 8 s local dry run, no YouTube needed"
echo "  4. omastream start               # go live"
