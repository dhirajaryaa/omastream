# Omastream

Stream your screen to YouTube Live from Omarchy — one window, zero-lag GPU encode
(gpu-screen-recorder → VA-API), a live floating camera bubble overlay, and a CLI that
still works when you don't feel like clicking.

<p align="center">
  <img src="docs/screenshot.png" alt="The Omastream window — sleek cards, concentric live button and live camera studio controls" width="360">
</p>

The app is the main surface: press **Space** to go live, press it again to
stop. Everything it does it does through `omastream-cli`, the engine —
quick settings (`config set`) require nothing more. No Electron, no web
view: a native Qt Quick app that follows your Omarchy theme accent, needs
about 10 MB of RAM, and leaves the CPU heavy lifting to your GPU.

---

## Install

### One-Line Install (Recommended)

Run this single command in your terminal to build and install Omastream and its Omarchy shell plugin:

```sh
curl -fsSL https://raw.githubusercontent.com/dhirajaryaa/omastream/main/install.sh | bash
```

Everything installs cleanly into `~/.local` (no root / sudo needed).

---

### Prerequisites (Arch Linux / Omarchy)

Make sure the required packages are installed:

```sh
sudo pacman -S --needed base-devel qt6-base qt6-declarative qt6-multimedia qt6-wayland gpu-screen-recorder jq
```

> **Note for Intel iGPU (Pre-Haswell / Ivy Bridge):**
> If you have older Intel graphics, install the legacy VA-API driver:
> `sudo pacman -S --needed libva-intel-driver libva-utils`
> (Or simply toggle **Auto CPU fallback** in Omastream settings if GPU encoding is unsupported).

---

### Manual Clone & Install (Optional)

If you prefer cloning the repository manually:

```sh
git clone https://github.com/dhirajaryaa/omastream.git
cd omastream
./install.sh
```

`install.sh` builds the native Qt app and sets up everything in your user profile:

| Component | Destination | Description |
| --- | --- | --- |
| **Omastream App** | `~/.local/bin/omastream` | Sleek, native Qt Quick window |
| **Omastream CLI** | `~/.local/bin/omastream-cli` | Core streaming & overlay engine |
| **Desktop Launcher** | `~/.local/share/applications/omastream.desktop` | App launcher entry (`Super + Space` → **Omastream**) |
| **App Icons** | `~/.local/share/icons/hicolor/` | Scalable vector and raster icons |
| **Omarchy Plugin** | `~/.config/omarchy/plugins/dhirajarya.omastream/` | Interactive camera bubble overlay & LIVE top bar badge |

Once finished, launch **Omastream** directly from your application launcher (**Super + Space**) or terminal:

```sh
omastream
```

---

### Arch Package Route (Optional)

If you prefer installing as a system package via `makepkg`:

```sh
cd omastream/pkgbuild
makepkg -si
```

---

## Go live in 60 seconds

1. **Open Omastream** from the launcher.
   - The camera preview overlay launches **automatically** so you can preview framing and position your webcam immediately.
2. **Paste your stream key.**
   - Click the **YouTube Studio** button in the header (or visit Studio → **Go live** → Stream settings) to copy your **stream key**.
   - Paste it into Omastream's Settings (**⚙** icon). It is stored privately in `~/.config/omastream/config.env` (`chmod 600`, never committed, never logged).
   - Prefer terminal? `omastream-cli config stream-key` or `omastream-cli config set STREAM_KEY 'xxxx-xxxx-xxxx'`.
3. **Configure your stream**:
   - Choose your **Stream resolution limit** (Native/Auto, 1080p, 720p, 1440p, 4K, or custom `WxH`).
   - Pick **System audio** (desktop sound), **Microphone**, **Video codec** (`h264`/`hevc`), and **Bitrate**.
4. **Test run (optional)**:
   - Click **Test Stream (8s recording)** to record a short local test file (`test.flv`) to verify audio levels and video before going live.
5. **Press Space** (or click the big central button). You are live on YouTube with hardware-accelerated GPU capture!
6. **Press Space again** (or click the button) to stop. The stream ends gracefully (RTMP close, all frames intact).

---

## Live Camera Studio & Bubble Overlay

The floating camera bubble is always interactive and visible both during preview and live streaming:

- **Instant Framing on Launch**: When you open Omastream, the webcam bubble appears immediately on screen so you can set up framing before broadcasting. It automatically closes and releases the camera when you exit the app (unless actively live streaming), and never auto-starts on PC/OS boot.
- **Zero-Flicker Hover HUD**: Hover over the webcam bubble to reveal on-glass controls with smooth transitions—no blinking, re-render flashing, or video blanking.
- **Interactive Shape Selector**: Switch instantly between **Circle**, **1:1 Square** (true pixel square width and height), and **16:9 Wide**.
- **Dynamic Corner Rounding Slider**: For 1:1 and 16:9 modes, adjust corners on-the-fly from sharp (`0px`), to squircle, to fully rounded capsules, with instant `0` and `Max` preset buttons.
- **Natural Webcam Preview**: Webcam video feed is displayed cleanly and naturally without artificial color shifts or HUD filters.
- **Stream Lifecycle Auto-Off**: When live streaming completes or when the app is closed, the webcam overlay automatically turns off and releases without leaving a dangling overlay on your desktop.
- **Selfie Mirror**: One-click toggle (`CAM_FLIP`) to mirror your front camera for a natural view.
- **Corner Snap Presets**:
  - `↖` **Top-Left**
  - `↗` **Top-Right**
  - `↙` **Bottom-Left**
  - `↘` **Bottom-Right**
- **Free Drag & Resize**: Drag the bubble anywhere across your displays with magnetic edge snapping. Grab the bottom-right handle to resize smoothly. Coordinates, shape, and corner radius persist across sessions.

---

## Top Bar Controls & Live Sync

The top bar remains completely normal during desktop use. While streaming:

- A red **LIVE** badge appears on the top bar showing live stream elapsed time.
- **Left-click** opens a quick control popup:
  - **Stop Stream**: Stops the stream immediately.
  - **Hide / Show Webcam**: Toggles the camera bubble overlay.
- **Middle-click** directly toggles the camera bubble.
- **Right-click** opens YouTube Studio.
- **Real-Time Synchronization**: Stopping or toggling the stream from the app, top bar popup, or `omastream-cli stop` synchronizes instantly across all surfaces.

---

## Settings Reference

| Setting | What it does |
| --- | --- |
| **YouTube stream key** | The ingest key (or full `rtmp://` URL). Stored locally in `chmod 600` config. |
| **Stream resolution limit** | `Native / Auto` (original display), `1080p` (1920x1080), `720p` (1280x720), `1440p` (2560x1440), `4K` (3840x2160), or **Custom resolution** (`WxH` like `1600x900` or `1920x1200`). |
| **System audio** | Desktop sound: `Default output` follows system speakers, plus every separate output device PipeWire/PulseAudio reports. |
| **Microphone** | `Default microphone` follows system input; or pick any audio source. Toggle off removes the mic track completely. |
| **Video codec** | `h264` (recommended for YouTube RTMP ingest) or `hevc`. |
| **Bitrate (CBR)** | 3000 / 4500 / 6000 / 8000 / 9000 kbps (4500 ≈ recommended 1080p30). |
| **Screen text sharpness** | Enhance font and UI text clarity when streaming from low-resolution monitors (e.g. 720p/900p): `Normal / Off`, `Crisp` (full contrast range 0-255 & edge tuning), `High Sharpness` (clean text for code & terminals), or `Ultra Sharp` (maximum font clarity & deblocking). |
| **Auto CPU fallback** | Automatically falls back to CPU encoding if the GPU encoder fails or is unsupported. |
| **Mirror camera** | Flips the camera horizontally. |
| **Webcam Overlay** | Show / hide the floating self-view bubble on screen. |

---

## Keyboard Shortcuts

| Key | Action |
| --- | --- |
| `Space` | Go live to YouTube / stop stream |
| `C` | Show or hide the webcam bubble |
| `Escape` | Close settings overlay |
| `Q` | Quit — prompts if a stream is running |

---

## `omastream-cli` — The Engine

Everything the window does is fully scriptable via the CLI:

| Command | What it does |
| --- | --- |
| `omastream-cli` | Status summary |
| `omastream-cli start [--cam on\|off] [--res WxH] [--file PATH] [--cpu-fallback]` | Go live (STREAM_KEY) or record to a file with resolution limit |
| `omastream-cli stop` | Graceful stop (SIGINT closes RTMP cleanly; protected against self-kill) |
| `omastream-cli toggle` | Stop ↔ start |
| `omastream-cli status [--json\|--check]` | Machine-readable status query used by top bar and scripts |
| `omastream-cli test [--secs N]` | Short local-file pipeline test, no key required |
| `omastream-cli cam on\|off\|toggle` | Show / hide the camera bubble |
| `omastream-cli cam shape <circle\|1:1\|16:9>` | Change camera bubble shape |
| `omastream-cli cam cycle-shape` | Cycle through bubble shapes |
| `omastream-cli cam radius <0..1\|0..100>` | Adjust corner rounding (0 = sharp square, 1.0 = round/capsule) |
| `omastream-cli cam corner <tl\|tr\|bl\|br>` | Snap camera bubble to a screen corner |
| `omastream-cli cam flip <true\|false>` | Toggle horizontal camera mirror |
| `omastream-cli cam save '<json>'` | Persist bubble coordinates, dimensions, and radius |
| `omastream-cli cam status` | Output current camera visibility, shape, radius, and coordinates |
| `omastream-cli config [stream-key\|set KEY VALUE\|open\|print]` | Manage settings in `config.env` |

---

## Files

| Path | What lives there |
| --- | --- |
| `~/.config/omastream/config.env` | Settings — stream key, resolution, audio devices, codec… (`chmod 600`) |
| `~/.local/state/omastream/state.json` | Runtime state — shared between the app, bubble, and top bar |
| `~/.local/state/omastream/stream.log` | `gpu-screen-recorder` execution log |
| `~/.config/omarchy/plugins/dhirajarya.omastream/` | Camera bubble overlay + LIVE bar badge Quickshell plugin |

---

## Security & Privacy

- **Private Stream Keys**: Your YouTube stream key is stored strictly on your local filesystem at `~/.config/omastream/config.env` with owner-only read/write permissions (`chmod 600`).
- **No Analytics / Telemetry**: Omastream communicates only with YouTube's RTMP ingest servers via `gpu-screen-recorder`. No remote logging, analytics, or background telemetry.
- **Clean Repository**: Git ignores all `.env` files and runtime state by design. Local keys and logs will never be committed or uploaded.

---

## Troubleshooting

- **"test" fails with VA-API errors on older Intel**:
  Pre-Haswell (3rd gen Ivy Bridge included) uses the legacy driver:
  `sudo pacman -S libva-intel-driver libva-utils`, then retry.
  Without sudo: `omastream-cli start --cpu-fallback` streams with software encoding.
- **Screen capture blocked while locked**:
  The Wayland compositor/portal intentionally rejects capture while the screen is locked. Unlock before starting.
- **Top bar badge missing or bubble not updating**:
  Restart the Omarchy shell: `omarchy restart shell`.
- **Diagnostics**:
  Check `~/.local/state/omastream/stream.log` for recorder stderr.

---

## Uninstall

```sh
./install.sh --uninstall
```

Removes the app, CLI, launcher entry, icons, and shell plugin. Your config and recordings stay intact.

---

## License

MIT — see [LICENSE](LICENSE). The Qt theme/translation scaffolding is adapted from Omacut and Monologue by David Heinemeier Hansson (MIT).
