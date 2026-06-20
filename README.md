# Palmier X

Cross-platform (Windows / macOS / Linux) rebuild of the Palmier Pro editor in
Flutter desktop. The native Swift app (`palmier-pro`) is macOS-only — its UI
(SwiftUI/AppKit), media engine (AVFoundation) and render (WebKit) don't exist
off Apple. This is a parallel codebase, not a port of that one.

## Status — walking skeleton

Proves the viable path on Windows before porting advanced features:

- **Import** a video (`file_picker`).
- **Preview** with GPU-accelerated playback (`media_kit` / libmpv → D3D11VA on Windows).
- **Timeline** scrub + in/out trim handles.
- **Export** the trimmed range via ffmpeg (H.264/AAC) with live progress.

Verified: `flutter analyze` clean; `test/export_test.dart` cuts a clip and
asserts the trimmed duration; plugin graph resolves the Windows libs.

## Build

Windows binaries are produced by CI (`.github/workflows/windows.yml`,
`windows-latest`) — they bundle a static `ffmpeg.exe`. Trigger via push to
`main` or "Run workflow"; download the `PalmierX-windows` artifact.

Local dev (any desktop with Flutter + ffmpeg on PATH):

```bash
flutter pub get
flutter run -d windows   # or macos / linux
flutter test
```

## Not yet ported (next rungs)

Multi-track compositing, text/caption overlays, keyframed transforms, the AI
agent (MCP), motion-graphics render. Export of a composited timeline is ffmpeg
`filter_complex` (or frame-by-frame) — the skeleton only trims a single clip.
