# Tasks — MVP Viral Editor

## T1 — exportVideo: aspect ratio + social preset (FR1.1, FR1.2)
- Where: lib/ffmpeg.dart
- Add enum `ExportAspect { original, r9x16, r1x1, r4x5, r16x9 }` + filter builder (crop-center + scale to a target, even dims). Compose with the existing subtitles `-vf` (chain with comma). Add `-movflags +faststart -pix_fmt yuv420p`.
- ASS PlayRes must match the OUTPUT aspect (so caption positions land right). Make `_buildAss` take target W×H.
- Done when: export in 9:16 produces a vertical mp4; captions still land; headless test asserts output dimensions via ffprobe.
- Test: extend test/export_test.dart — export r9x16, ffprobe shows portrait (h>w).

## T2 — Auto-captions from transcript (FR2.1-2.3)
- Where: lib/editor_screen.dart (+ small helper)
- Method `_autoCaption()`: from `_omni.analysis.transcript` → append Caption per segment (id seq, start/end, default style). Guard: no transcript → snackbar.
- UI: button in OmniPanel ("Auto-legenda") enabled when result has transcriptSource.
- Done when: clicking fills the caption panel from speech; editable.
- Test: pure-Dart unit on the mapping (transcript segments → captions count/timing).

## T3 — Aspect selector UI (FR1.3)
- Where: lib/editor_screen.dart AppBar (dropdown) → `_aspect` state, passed to all exports.
- Done when: dropdown changes the export format; default r9x16.

## T4 — Batch highlight export (FR3.1-3.4)
- Where: lib/omni/ (export helper) + editor_screen.dart
- `exportHighlights(input, suggestions, transcript, aspect, fontPath, outDir, onProgress(i,total))` → loops exportVideo per suggestion, captions = transcript segments intersecting [start,end] shifted to clip-relative, names `<base>_NN_<pct>.mp4`.
- UI: "Exportar destaques" button in OmniPanel → folder picker → progress → summary snackbar.
- Done when: N clips land in the folder, each vertical + captioned; verified manually + headless test on 2 fake suggestions.

## Gate (each task)
`flutter analyze lib test` clean + `flutter test` green. Commit per task. CI green at the end.
