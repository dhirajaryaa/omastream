#!/usr/bin/env bash
# omastream installer — app first: builds the Qt app, installs it with the
# launcher entry and icon, then the CLI (omastream-cli) and the shell bubble
# plugin. Everything lands in ~/.local — no root needed.
#
#   ./install.sh            build + install
#   ./install.sh --link     symlink the CLI + plugin so dev edits apply live
#   ./install.sh --uninstall
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK=0
case "${1:-}" in
  --link) LINK=1 ;;
  --uninstall)
    rm -f "$HOME/.local/bin/omastream" "$HOME/.local/bin/omastream-cli"
    rm -rf "$HOME/.config/omarchy/plugins/dhirajarya.omastream"
    rm -f "$HOME/.local/share/applications/omastream.desktop"
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

need() { command -v "$1" >/dev/null 2>&1; }

# ── legacy cleanup: the old start/stop launcher scripts are replaced by the ──
# ── one window; the name omastream now belongs to the app, the CLI is     ────
# ── omastream-cli.                                                        ────
rm -f "$HOME/.local/share/applications/omastream-start.desktop"
rm -f "$HOME/.local/share/applications/omastream-stop.desktop"

# ── the app (launcher: "Omastream", Super + Space) ───────────────────────────
if need qmake6 && need g++ && need make; then
  "$REPO/bin/build" >/dev/null 2>&1 || { echo "app build failed — run $REPO/bin/build for the full output" >&2; exit 1; }
  copy "$REPO/build/omastream" "$HOME/.local/bin/omastream" 755
  say "app" "$HOME/.local/bin/omastream"
else
  echo "build tools missing — install qmake6, g++, make, then re-run" >&2
  exit 1
fi

copy "$REPO/pkgbuild/omastream.desktop" "$HOME/.local/share/applications/omastream.desktop"
copy "$REPO/pkgbuild/omastream.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/omastream.svg"
ICON_BASE="$HOME/.local/share/icons/hicolor"
for size in 512x512 256x256 128x128 64x64; do
  copy "$REPO/assets/icons/$size/apps/omastream.png" "$ICON_BASE/$size/apps/omastream.png"
done
need gtk-update-icon-cache && gtk-update-icon-cache -qf "$ICON_BASE" 2>/dev/null || true
need update-desktop-database && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
say "launcher + icon" "$HOME/.local/share/applications/omastream.desktop"

# ── the engine CLI ───────────────────────────────────────────────────────────
copy "$REPO/cli/omastream" "$HOME/.local/bin/omastream-cli" 755
say "CLI" "$HOME/.local/bin/omastream-cli"

# ── the shell bubble plugin (optional overlay look) ──────────────────────────
PLUGIN_DST="$HOME/.config/omarchy/plugins/dhirajarya.omastream"
mkdir -p "$PLUGIN_DST"
for f in manifest.json Service.qml CameraBubble.qml BarWidget.qml; do
  copy "$REPO/plugin/$f" "$PLUGIN_DST/$f"
done
if need omarchy; then
  omarchy plugin enable dhirajarya.omastream right >/dev/null 2>&1 \
    && say "shell plugins" "camera bubble + LIVE bar badge enabled" \
    || say "shell plugins" "copied — enable with: omarchy plugin enable dhirajarya.omastream right"
fi

echo
echo "done. next:"
echo "  1. open Omastream from the launcher, paste your stream key, press Space"
echo "  2. GPU encode on pre-Haswell Intel: sudo pacman -S libva-intel-driver libva-utils"
echo "     (or start with --cpu-fallback from the CLI)"
