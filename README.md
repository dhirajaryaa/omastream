# omastream

Zero-lag YouTube Live streaming for Omarchy, built the Omarchy way: **gpu-screen-recorder** does the hardware encode (VA-API / Intel QuickSync), a tiny **Quickshell plugin** draws your camera bubble and the live bar, and one **CLI** owns everything — `omastream`.

No Electron. No web views. A 2 GB Radeon-free Ivy Bridge laptop can stream 1080p30.

```
screen ──┐
         ├─ gpu-screen-recorder ─flv/CBR h264→ rtmp://a.rtmp.youtube.com/live2
camera ──┘
```

## What you get

- **Camera bubble** — draggable, resizable self-view in three shapes: `circle`, `1:1`, `16:9`. Hover it for the shape pill (switch shape / hide) and a corner grip to resize.
- **LIVE bar badge** — red, pulsing, with elapsed time. Click stops the stream, middle-click toggles the camera, right-click opens YouTube's Live Control Room.
- **CLI switchgear** — every control scriptable: `omastream start|stop|toggle|status|cam|test`.
- **One honest config file** — `~/.config/omastream/config.env`. Stream key, audio in/out devices, camera shape, codec and bitrate. That's it.
- **Capture-safe** — the styled bubble is excluded from capture, so YouTube never sees your UI twice: gpu-screen-recorder composites the raw camera into the stream at the same coordinates the bubble occupies.

## Install

Assumes a running Omarchy (Hyprland + omarchy shell + gpu-screen-recorder).

```bash
git clone https://github.com/dhirajaryaa/omastream
cd omastream
./install.sh          # CLI → ~/.local/bin, plugin, icons, launchers
omarchy restart shell # spawn the bubble service + LIVE badge
```

Dev shortcut (edits take effect without re-copying): `./install.sh --link`.

### Intel setup older than Haswell

3rd-gen (Ivy Bridge) cores use the legacy VAAPI driver. If `omastream test` fails on encode:

```bash
sudo pacman -S libva-intel-driver libva-utils
vainfo                # should report i965 + H264 entrypoints
```

Stuck without sudo? `omastream start --cpu-fallback` streams anyway (soft encode, soft battery).

## Go live

```bash
omastream config stream-key    # paste your YouTube stream key (kept local, chmod 700)
omastream test                 # 8 s local dry run → ~/.local/state/omastream/test.flv
omastream start                # live. the bar turns red.
```

In YouTube Studio, start the broadcast and set *Stream key management* to "use the stream key"; once your ingest turns green, viewers see the screen.

## CLI

| command                              | what it does                                        |
|--------------------------------------|-----------------------------------------------------|
| `omastream` / `status`               | am I live? (uptime, output masked)                  |
| `status --json`                      | machine-readable state (bars and scripts)           |
| `start`                              | go live using `STREAM_KEY`                          |
| `start --file out.flv`               | record to a file instead (dry run)                  |
| `start --cpu-fallback`               | force software encode (VA-API unavailable)          |
| `start --cam on / --cam off`         | stream with/without the camera composited           |
| `stop`                               | graceful stop — SIGINT, stream closes clean         |
| `toggle`                             | stop ↔ start                                        |
| `cam on / off / toggle`              | show / hide the camera bubble                       |
| `cam shape circle \| 1:1 \| 16:9`    | set the bubble shape                                |
| `cam cycle-shape`                    | next shape                                          |
| `cam save '<json>'`                  | persist geometry (the bubble calls this when moved) |
| `config`                             | print the config path (write it to change settings) |
| `config stream-key`                  | set the stream key from a prompt                    |
| `test`                               | 8 s local capture, no key needed, then inspect it   |

## Config quick reference (`~/.config/omastream/config.env`)

```sh
STREAM_KEY=            # or a full rtmp:// URL
VIDEO_CODEC=h264       # h264 for YouTube ingest; hevc is best-effort
VIDEO_BITRATE=4500     # kbps CBR ≈ YouTube's 1080p30 recommendation
FPS=30

AUDIO_SYSTEM=auto      # auto = default output (speakers/headphones); or an exact sink name
AUDIO_MIC=auto         # auto = default microphone
MIC_ENABLED=true       # false → screen audio only

CAM_DEVICE=/dev/video0
CAM_FLIP=true          # mirrored selfie view
CAM_RECORD=true        # composite the camera into the stream while the bubble shows
CAM_ON_START=false     # pop the bubble on every stream start
DEFAULT_CAM_SHAPE=16:9
```

## The camera bubble, precisely

- Geometry is stored as fractions of the display, `shape@screen` keyed, so the same numbers drive both the on-screen bubble and the in-stream composite. Drag or resize commits through `omastream cam save`; only when the CLI accepts is the bubble relaxed.
- While you stream, gpu-screen-recorder holds `/dev/videoN` exclusively, so the preview pauses: the bubble shows a themed **LIVE** placeholder until the stream ends. That's a feature of the single-device design — for simultaneous preview, install [v4l2loopback](https://github.com/umlaeute/v4l2loopback) so two readers can share the camera, then point `CAM_DEVICE` at the loopback device it creates.
- One bubble lives per monitor; it parks on the display where you left it (or, on first show, the focused one).

## Troubleshooting

- **Bar shows nothing when live** — restart the shell (`omarchy restart shell`) then re-check `omastream status`.
- **Encode errors with `libva intel: iHD/i965 init failed`** — see Intel setup above, or run `--cpu-fallback`.
- **Stream green but no video** — check YouTube's *Stream key management* is using the key, and that Studio's preview is "off" unless the dashboard is open.
- **Test file missing** — read the log tail: `~/.local/state/omastream/stream.log`.

## Safety

The stream key lives only in `~/.config/omastream`, `chmod 700`, and every human-facing CLI output masks it. Nothing in this repo will ever read your browser cookies; the tool speaks raw RTMP like any encoder would.

## License

MIT — see [LICENSE](LICENSE).
