# Spec — MVP Viral Editor (closing features)

## Context
Palmier X já faz: import → preview → trim único → legendas manuais (CRUD + burn libass)
→ export ffmpeg; motor Omni v1 (analisa vídeo, sugere cortes). Falta fechar o loop
"analisar → produzir vários virais". Estas 3 features tornam o MVP 100% usável.

## Requirements

### F1 — Export com aspect ratio + preset social
- FR1.1 `exportVideo` aceita `aspect` (original | r9x16 | r1x1 | r4x5 | r16x9). Crop-center + scale via ffmpeg `crop`/`scale`, mantendo o conteúdo central.
- FR1.2 Encoding social: `-movflags +faststart`, `-pix_fmt yuv420p` (compatível web/mobile).
- FR1.3 UI: seletor de formato no editor (dropdown), default 9:16.

### F2 — Auto-legenda do transcript
- FR2.1 Botão "Auto-legenda" gera caption track a partir de `OmniResult.analysis.transcript` (1 Caption por segmento, start/end do segmento, estilo default).
- FR2.2 Só habilitado quando há transcript (Omni rodou com backend de transcrição). Aviso claro quando ausente.
- FR2.3 As legendas geradas entram no mesmo `_captions` (editáveis/deletáveis como as manuais).

### F3 — Export em lote dos destaques
- FR3.1 Ação "Exportar destaques" → escolhe pasta → para cada sugestão Omni (ou as selecionadas) exporta 1 clipe (janela start/end) com as legendas do transcript que caem na janela, no aspect ratio escolhido.
- FR3.2 Nomes: `<base>_01_<score>.mp4` ordenados por score.
- FR3.3 Progresso por clipe (N/total) + resumo final (quantos exportados, pasta).
- FR3.4 Reusa `exportVideo` (1 chamada por clipe) — sem segundo pipeline.

## Non-goals (v2+)
Multi-track real, re-corte por receita Edit-DNA, geração de footage, música, transições.

## Traceability
F1→FR1.1-1.3 · F2→FR2.1-2.3 · F3→FR3.1-3.4
