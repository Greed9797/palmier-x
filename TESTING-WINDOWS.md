# Palmier X — Teste no Windows (time de marketing)

Build cross-platform do editor. Esta é a versão **walking-skeleton**: importar →
preview → cortar (trim) → legendas → exportar. Funciona sem instalar nada.

## Instalar

1. Baixe `PalmierX-windows.zip` (Actions → "Build Windows" → artifact, ou link enviado).
2. Extraia a pasta inteira para um lugar fixo (ex.: `C:\PalmierX`).
   **Não rode de dentro do .zip** — extraia primeiro.
3. Dê duplo-clique em `palmier_x.exe`.
   - Se o Windows SmartScreen avisar ("app não reconhecido"), clique **Mais informações → Executar assim mesmo** (o app não é assinado ainda).

Tudo que o app precisa já vem na pasta (runtime, ffmpeg, fontes) — não precisa
instalar Visual C++ nem codecs.

## Roteiro de teste (5 min)

| # | Ação | Esperado |
|---|------|----------|
| 1 | App abre | Janela "Palmier X", tela escura, "Importe um vídeo para começar" |
| 2 | **Importar** → escolher um .mp4 | Vídeo aparece no preview |
| 3 | Play (▶) | Vídeo toca com som, suave |
| 4 | Arrastar na timeline | Preview pula pro ponto (scrub) |
| 5 | Arrastar as alças laranja (in/out) | Faixa de corte muda; "Trim X → Y" atualiza |
| 6 | Painel direito → **"No playhead"** | Legenda "Legenda" aparece sobre o vídeo |
| 7 | Editar texto / tamanho / posição Y | Legenda muda ao vivo no preview |
| 8 | **Exportar** → salvar .mp4 | Barra de progresso → "Exportado: …" |
| 9 | Abrir o .mp4 exportado | Só o trecho cortado, com a legenda queimada |

## Reportar problema

Anote o **passo #** que falhou, o que aconteceu, e o nome/tamanho do vídeo de teste.
Print da tela ajuda. Manda pro canal do dev.

## O que ainda NÃO tem (próximas versões)

Multi-track, legenda automática por fala, animação de legenda (karaokê), efeitos.
Esta versão valida o fluxo base no Windows.
