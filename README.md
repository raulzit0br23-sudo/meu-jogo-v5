# ATMOSFERA ZERO — Demo (Capítulos 1 a 6)

FPS single-player original em **Godot 4 (GDScript, Mobile Renderer)**, inspirado na atmosfera e nas ideias
descartadas da beta de Half-Life 2 (2001–2003). Todo o conteúdo (história, personagens, mapas, modelos,
texturas, sons, músicas e vozes) é original — nenhum arquivo da Valve foi usado.

Versão: `0.4.0-demo` — **6 de 30 capítulos jogáveis**: Ato I completo (1 Linha Nove · 2 Praça do Terminal ·
3 Distrito Leste · 4 A Muralha) e início do Ato II (5 Ferro-Velho · 6 Mar Seco), seguidos da tela de fim da demo
e créditos. Inclui a **Sala de Testes** e o menu **Planejamento (30 capítulos)**.

## Planejamento (menu principal)
Galeria com uma concept art por capítulo dos 30 planejados, agrupada por ato: título, ato, status
(Jogável/Planejado) e resumo em PT/EN; "Jogar" abre o capítulo se ele estiver pronto e desbloqueado.
As artes são **originais, geradas por IA** para orientar a produção — não são capturas do jogo nem material da Valve.
Fonte dos dados: `data/campaign_plan.json`; imagens em `assets/concept/`.

## Sala de Testes
Hangar fora da campanha (não salva progresso) para experimentar tudo. Você entra com todas as armas e munição
máxima. Cada botão tem uma placa com o nome e funciona com "Usar" (E / X / botão de toque).
- **Arsenal:** bancada com as 23 armas, munições, kit médico, filtro e máscara. Botões: todas as armas, curar,
  invulnerável, levar dano.
- **Estande de tiro (oeste):** alvos a 10/20/30 m que contam acertos e dano; botão zerar alvos.
- **Arena de combate (leste):** gera Vigilante (cassetete), Vigilante (pistola), Soldado ou esquadrão de 4
  (até 8 vivos), modo passivo, eliminar todos, remover corpos.
- **Física (centro):** todos os 10 tipos de objeto, barris explosivos em fila (reação em cadeia), pilha de caixas,
  chuva de objetos, repor objetos, explosão de teste.
- **Circuito de movimento (norte):** escada, saltos, túnel para agachar, rampa, escada de mão com queda de 6 m,
  esteira, elevador, porta livre e porta trancada (botão trancar/destrancar), zona de dano elétrica e holofote.
- **NPCs, dublagem e áudio (parede oeste):** Irina (use para ela seguir/esperar), cidadãos, próxima fala
  (percorre as 51 falas dos capítulos 1–3), troca de dublagem PT/EN, idioma da interface, ambiências e efeitos sonoros.
- **Gráficos (parede sul):** predefinições Baixo/Médio/Alto/Ultra e limites 30/60/90 FPS aplicados ao vivo,
  painel de desempenho (FPS, ms, draw calls, objetos, triângulos, nós, VRAM, GPU e renderizador).
- **Materiais (parede sul):** amostras de todas as texturas PBR e cartazes.

## Como abrir

### Godot no celular/tablet Android (Godot Engine – editor para Android)
1. Extraia o zip numa pasta do aparelho (ex.: `Documents/atmosfera_zero`).
2. Abra o editor Godot → **Importar** → selecione `project.godot` dessa pasta.
3. A primeira abertura reimporta ~60 MB de texturas/áudio (pode levar alguns minutos no celular).
4. Rode com ▶ (F5). Controles de toque aparecem automaticamente ao tocar na tela.

### PC (Windows/Linux/macOS)
Godot **4.3 ou mais novo** (testado no 4.3-stable). Abra `project.godot` e pressione F5.

### Exportar APK
Projeto → Exportar → Adicionar… → Android. Requer o template de exportação e (no PC) o Android SDK/JDK
configurados em Editor → Configurações do Editor → Exportar → Android. Use ETC2/ASTC (já ativado).

## Controles (padrão, remapeáveis em Opções)
| Ação | Teclado/Mouse | Gamepad | Toque |
|---|---|---|---|
| Mover / olhar | WASD / mouse | analógicos | joystick esquerdo / arrastar à direita |
| Atirar / mirar | botão esq./dir. | RT / LT | botões na tela |
| Pular / agachar / correr | Espaço / Ctrl / Shift | A / B / L3 | botões |
| Usar / pegar objeto | E | X | botão "usar" |
| Recarregar / trocar arma | R / 1–4, roda | Y / LB-RB | botões |
| Lanterna / inventário | F / Tab | D-pad ↑ / Back | botões |
| Salvar / carregar rápido | F5 / F9 | — | menu de pausa |
| Pausa | Esc | Start | ⏸ |

## Linha de comando úteis
- `godot --headless -- --autotest` — roda os testes de integração (sai com 0 se tudo passar).
- `godot -- --menu=plan` — abre direto o menu Planejamento.
- `godot -- --chapter=2 --cp=plaza` — abre direto num capítulo/checkpoint (`--chapter=0` = Sala de Testes).
- `AZ_ONLY=ch4|ch5|test godot --headless -- --autotest` — roda só os testes da Sala de Testes.

## Estrutura
- `src/core` — autoloads (jogo/saves, entrada, áudio, diálogo, localização PT-BR/EN, configurações)
- `src/levels` — `level_base.gd` (construção modular, setores, navegação) + `chapter_01..06.gd` + `test_range.gd` (Sala de Testes)
- `src/player`, `src/weapons`, `src/npc`, `src/physics`, `src/interaction`, `src/world`, `src/ui`
- `data/dialogue` — roteiros PT/EN por capítulo; `assets/audio/voice/{pt,en}` — dublagem
- `docs/` — pesquisa histórica, design, arquitetura, roadmap/status e último resultado dos testes
- `tools/` — geradores de texturas/sons (Python) usados para criar os assets originais

Veja `docs/04_ROADMAP_E_STATUS.md` para o que está pronto, o que foi testado e as limitações conhecidas.
