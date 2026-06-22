# Palmier X

Cross-platform (Windows / macOS / Linux) rebuild of the Palmier Pro editor in
Flutter desktop. The native Swift app (`palmier-pro`) is macOS-only — its UI
(SwiftUI/AppKit), media engine (AVFoundation) and render (WebKit) don't exist
off Apple. This is a parallel codebase, not a port of that one.

## Download

Pega o build da última release — **tudo já vem dentro do pacote** (runtime,
libmpv, ffmpeg, fontes). Não precisa instalar nada.

| OS | Download |
|----|----------|
| **Windows** (10/11, 64-bit) | [PalmierX-windows.zip](https://github.com/Greed9797/palmier-x/releases/latest/download/PalmierX-windows.zip) |
| **macOS** (Apple Silicon) | [PalmierX-macos.zip](https://github.com/Greed9797/palmier-x/releases/latest/download/PalmierX-macos.zip) |

Todas as releases: <https://github.com/Greed9797/palmier-x/releases>

> Repo privado → o download pede login GitHub com acesso ao repositório. Via CLI:
> ```bash
> gh release download --repo Greed9797/palmier-x --pattern "PalmierX-windows.zip"
> gh release download --repo Greed9797/palmier-x --pattern "PalmierX-macos.zip"
> ```

### Instalar — Windows
1. Extraia o `.zip` inteiro para uma pasta fixa (ex.: `C:\PalmierX`).
2. Duplo-clique em `palmier_x.exe`.
3. SmartScreen ("app não reconhecido") → **Mais informações → Executar assim mesmo** (não assinado ainda).

### Instalar — macOS
1. Extraia o `.zip` → `palmier_x.app`.
2. Como não é assinado, limpe a quarentena uma vez:
   ```bash
   xattr -dr com.apple.quarantine /caminho/para/palmier_x.app
   ```
   (ou clique-direito → **Abrir** → **Abrir**.)
3. Duplo-clique no app.

**Tudo incluído** — Windows: runtime VC++ (`msvcp140`/`vcruntime140`/`_1`), `flutter_windows.dll`,
`libmpv-2.dll`, plugins media_kit, stack GL (ANGLE/Vulkan), `ffmpeg.exe`, fontes.
macOS: `.app` com Flutter + libmpv embutidos + `ffmpeg` em `Contents/MacOS`.

## Status — walking skeleton

- **Importar** vídeo (`file_picker`).
- **Preview** com playback acelerado por GPU (`media_kit`/libmpv → D3D11VA no Windows).
- **Timeline** com scrub + alças de trim (in/out).
- **Legendas** burned-in (CRUD + overlay ao vivo, queima via libass no export).
- **Exportar** o trecho cortado via ffmpeg (H.264/AAC) com progresso ao vivo.

Validado em Windows e macOS **reais** no CI: app **boota** sem crash, libmpv
**decodifica** vídeo, export de trim e de legenda rodam no ffmpeg que embarca.
Roteiro de teste manual pro time: [`TESTING-WINDOWS.md`](TESTING-WINDOWS.md).

## Build (CI)

| Workflow | Runner | Produz |
|----------|--------|--------|
| `.github/workflows/windows.yml` | `windows-latest` | `PalmierX-windows.zip` (artifact + release on tag) |
| `.github/workflows/macos.yml` | `macos-14` (arm64) | `PalmierX-macos.zip` (artifact + release on tag) |

Cada workflow: analyze → testa export/legenda no ffmpeg que embarca → build →
bundla deps → smoke test de boot → integration test de decode → zip.

**Cortar uma release** (gera os dois binários + anexa links): empurra uma tag `v*`.
```bash
git tag v0.1.0 && git push origin v0.1.0
```

Dev local (Flutter + ffmpeg no PATH):
```bash
flutter pub get
flutter run -d windows   # ou macos / linux
flutter test
```

## Próximas rungs

Multi-track compositing, legenda automática por fala, animação de legenda
(karaokê via tags ASS), keyframes, agente IA (MCP), motion-graphics.
