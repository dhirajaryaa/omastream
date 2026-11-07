# Omastream

Stream your screen to YouTube Live from Omarchy — one window, GPU encode
(gpu-screen-recorder → VA-API), a draggable camera bubble, and a CLI that
still works when you don't feel like clicking.

<p align="center">
  <img src="docs/screenshot.png" alt="The Omastream window — sleek omareel-style cards, concentric live button and camera bubble controls" width="360">
</p>

The app is the main surface: press **Space** to go live, press it again to
stop. Everything it does it does through `omastream-cli`, the engine —
quick settings (`config set`) require... nothing more. No Electron, no web
view: a native Qt Quick app that follows your Omarchy theme accent, needs
about 10 MB of RAM, and leaves the CPU heavy lifting to your GPU.

---

## Install

```sh
git clone git@github.com:dhirajaryaa/omastream.git
cd omastream
./install.sh
```

`install.sh` builds the app, installs it user-level (no sudo):

| What | Where |
| --- | --- |
| App (the window) | `~/.local/bin/omastream` |
| CLI (the engine) | `~/.local/bin/omastream-cli` |
| Launcher entry + icon | `~/.local/share/applications/omastream.desktop`, hicolor icons |
| Shell bubble + LIVE badge plugin | `~/.config/omarchy/plugins/dhirajarya.omastream/` |

Then open your launcher (**Super + Space**) and type **Omastream**.

> The old `omastream-start` / `omastream-stop` launcher scripts are removed by
> the installer — the app and its Space key replace them.

Arch package route instead (asks for the sudo password): `./install.sh --package`.

## Go live in 60 seconds

1. **Open Omastream** from the launcher.
2. **Paste your stream key.** In YouTube: Studio → **Go live** → Stream
   settings → copy the **stream key** — paste it in the app's *YouTube stream
   key* field. It's stored locally in `~/.config/omastream/config.env`
   (file is `chmod 700`, never committed, never logged).
   Prefer the terminal? `omastream-cli config stream-key` (paste, Enter) or
   `omastream-cli config set STREAM_KEY 'xxxx-xxxx-xxxx'`.
3. Pick **System audio** (desktop sound), **Microphone**, **codec** and
   **bitrate** in Settings — honest defaults for 1080p are already set.
4. Press **Space** (or the big play button). The status card turns red with
   a live clock; YouTube Studio reports "Excellent connectivity".
5. Press **Space** again to stop. The stream ends gracefully (RTMP close,
   final frames intact).

Not sure the capture works before showtime? Press **T** — *Test capture*
records an 8 s local file (`/tmp/omastream-test.flv`), nothing is uploaded,
and it stops itself.

## The camera bubble

Toggle with the **Camera bubble** switch or **C**:

- **Drag** it anywhere — hold the corner grip to resize; the shape ratio is
  kept and both the on-screen bubble and the in-stream composite stay in step.
- **Shapes:** Circle · 1:1 · 16:9 (the selected one wears your Omarchy accent).
- **Mirror** — the natural "selfie view" for your front camera.
- While you're live, the preview pauses into a **LIVE** placeholder — that's
  by design: the camera device is busy being composited into the YouTube
  frame.

> If the camera refuses (`EBUSY`) after a stream ends, close the bubble once
> (C) and reopen; some laptop drivers hold the device a beat longer.

## Settings reference

| Setting | What it does |
| --- | --- |
| **YouTube stream key** | The ingest key (or a full `rtmp://` URL). Local only. |
| **System audio** | Desktop sound: `Default output` follows your current speakers, plus every separate output device PulseAudio/PipeWire reports. |
| **Microphone** | `Default microphone` follows your default; other entries are your real input devices. The toggle off records **no** mic track at all. |
| **Video codec** | `h264` — YouTube RTMP ingest, VA-API QuickSync. `hevc` is there to try, but YouTube RTMP may reject it. |
| **Bitrate (CBR)** | 3000 / 4500 / 6000 / 8000 / 9000 kbps. 1080p30 → **4500**, 1080p60 → 6000–9000. |
| **Mirror** | Flips the camera horizontally. |
| **Camera bubble** | Show / hide the floating self-view. |

## Keyboard shortcuts

| Key | Action |
| --- | --- |
| `Space` | Go live / stop |
| `C` | Show or hide the camera bubble |
| `T` | 8 second test capture — local file, no upload |
| `?` | Show or hide the shortcuts overlay |
| `Q` | Quit — asks first if a stream is running |

Wayland-only, in-app. The shell plugin adds its own: **click** the LIVE badge
to stop the stream, **middle-click** to toggle the camera bubble.

## `omastream-cli` — the engine

Everything the window does, scriptable:

| Command | What it does |
| --- | --- |
| `omastream-cli` | status summary |
| `start [--cam on\|off] [--file PATH] [--cpu-fallback]` | go live (STREAM_KEY), or record to a file |
| `stop` | graceful stop — SIGINT closes the RTMP stream cleanly |
| `toggle` | stop ↔ start |
| `status` / `status --json` / `status --check` | what the bar widget calls |
| `test [--secs N]` | local-file pipeline test, no key needed |
| `cam on\|off\|toggle` | show / hide the bubble |
| `cam shape <circle\|1:1\|16:9>` · `cam cycle-shape` | set or cycle the bubble shape |
| `cam save '<json>'` | the shell bubble persists drag/resize here |
| `cam status` | bubble state |
| `config [stream-key\|set KEY VALUE\|open\|print]` | edit `config.env` |

## Files

| Path | What lives there |
| --- | --- |
| `~/.config/omastream/config.env` | settings — stream key, devices, codec… (`chmod 700`) |
| `~/.local/state/omastream/state.json` | runtime state — what the app, bubble and bar all watch |
| `~/.local/state/omastream/stream.log` | gpu-screen-recorder's log |
| `~/.config/omarchy/plugins/dhirajarya.omastream/` | camera bubble + LIVE bar badge |

## Troubleshooting

- **"test" fails with VA-API errors on older Intel** — pre-Haswell (3rd gen
  Ivy Bridge included) uses the legacy driver:
  `sudo pacman -S libva-intel-driver libva-utils`, then retry. No sudo?
  `omastream-cli start --cpu-fallback` streams anyway with software encode.
- **Capture can't find the screen while the session is locked** — expected:
  the Wayland portal refuses while the screen is locked. Unlock, retry.
- **The camera shows EBUSY** — see the bubble section above.
- **Bar badge missing / bubble gone after updates** — restart the shell:
  `omarchy restart shell` (refuses while locked, politely).
- **Still stuck** — read `~/.local/state/omastream/stream.log`.

## Uninstall

```sh
./install.sh --uninstall
```

Removes the app, CLI, launcher entry, icons and plugin. Your config and
recordings stay put.

## License

MIT — see [LICENSE](LICENSE). The Qt theme/translation scaffolding is
adapted from Omacut and Monologue by David Heinemeier Hansson (MIT).
