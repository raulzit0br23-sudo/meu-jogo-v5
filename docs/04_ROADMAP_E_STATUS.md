# Roadmap e status (atualizado em 23/11/2026)

## Mudanças da 0.5.0-demo (texturas de props e armas do HL2)

- Caixas de madeira: textura nova em todas as 6 faces (tábuas, moldura, travessa diagonal, pregos, estêncil) e ripas 3D nas bordas.
- Barris azuis e explosivos: tampas com textura própria (aro, sulcos, bujões, triângulo de perigo). Causa do bug: as tampas de todos os sólidos de revolução estavam com a face invertida (invisíveis); corrigido no MeshKit. Corrigido também o texto espelhado nos barris.
- Armas novas (8): pé de cabra, .357, AR2 (com esfera de energia no ALT), besta (vergalhão fica cravado na parede), RPG com laser, isca, Gravity Gun e Physgun (levita sem puxar, mira fixa no ar, ALT muda distância). Total 31.
- 16 sons novos sintetizados (`tools/gen_audio_v05.py`).
- Estúdio `--lineup` agora renderiza também props e as armas novas para conferência visual.
- Pendentes: extintor, Sticky Launcher, canhão Tau, Thumper portátil, canhão de Strider e Rollerwand da beta; armas novas só existem na Sala de Testes por enquanto (entram na campanha nos próximos capítulos).

## Mudanças da 0.4.0-demo (capítulos 4–6, planejamento de 30 capítulos)

- **Cap. 4 A Muralha**: coletor de esgoto, comporta com manivela, barco a motor pelos canais, barreira com grade, helicóptero Caçador abatido com canhão antiaéreo, cais sob holofotes e elevador de carga até o topo da Muralha.
- **Cap. 5 Ferro-Velho**: Lindqvist entrega o Manipulador; puzzle físico (afastar o motor da portinhola, tirar a bateria do telhado e encaixá-la no soquete do portão); duas ondas de Rastejadores; planta do Trocador na oficina; o buggy "Besouro".
- **Cap. 6 Mar Seco**: ~900 m de leito oceânico em terreno com relevo, rota de balizas, petroleiro "Aurora" (passagem pelo rasgo do casco), ossada de baleia com Rastejadores, posto avançado com cancela e botão na cabine, tempestade de partículas (dano a pé, proteção no Besouro e em abrigos) e chegada ao farol do Depósito → fim da demo.
- **Campanha replanejada para 30 capítulos** em 3 atos (`data/campaign_plan.json`, `docs/02_DOCUMENTO_DE_DESIGN.md`). Capítulos 7–30 aparecem no seletor e no Planejamento como "Planejado".
- **Menu Planejamento**: galeria com 30 concept arts originais (geradas por IA, 1280×720 + miniaturas 320×180; a imagem grande só é carregada ao selecionar, para poupar memória no celular). Funciona com toque, mouse e gamepad.
- Texturas: materiais lisos restantes (pneus, lonas, tecidos, malas, kits, filtros, máscaras) trocados por materiais texturizados.
- Correções: gatilhos agora detectam o jogador dentro de veículos; alerta de esquadrão não quebra mais com o helicóptero no grupo "enemy"; decalques de tiro reciclados não geram mais erro ao trocar de fase; partículas da tempestade respeitam o preset.

### Testes executados de fato (0.4.0)
- `godot --headless -- --autotest` (Godot 4.3-stable, Linux) — resultado completo em `autotest_ultimo_resultado.txt`. Inclui caps. 1–6 de ponta a ponta (com encadeamento 4→5→6 e load de save em cada um) e a Sala de Testes.
- Capturas renderizadas (Compatibilidade, software) de todos os setores dos caps. 5 e 6 e do menu Planejamento.
- Limitação: o FPS dessas capturas (3–12) vem de renderização por software e **não representa** um celular.


## Mudanças da 0.3.2-demo (desempenho, texturas e trem)

- Texturas reimportadas com mipmaps (47/47 confirmadas por script). Sem mipmaps, cada pixel distante lia a textura de 512 px inteira: lento e cheio de "chuvisco".
- Materiais com qualidade por preset: BAIXO = só albedo (1 leitura de textura/pixel), MÉDIO = albedo+normal, ALTO = +ORM, ULTRA = +triplanar de mundo. Antes todos os níveis usavam triplanar com 5 mapas (até 15 leituras/pixel). A troca de preset reconfigura os materiais na hora.
- UVs em metros no MeshKit (caixas, sólidos de revolução, tubos, abóbadas, terreno) para substituir o triplanar sem esticar textura. Corrigido UV quebrado da abóbada (textura esticada).
- Materiais lisos (roupas, armas, props) recebem textura de detalhe neutra (detail_grime_albedo.png, gerada para o projeto).
- Luzes com distância de corte por preset (22/32/45/70 m); glow desligado no BAIXO em tempo real; filtro de sombra suave mínimo no renderizador Mobile; MSAA padrão do projeto desligado.
- Celular agora começa sempre no preset BAIXO; saves antigos recebem as chaves novas do preset salvo.
- Trem: aviso do alto-falante em 1 s (era 2,5 s); pegar a máscara interrompe a conversa opcional e a frenagem começa 4 s depois (antes esperava ~23 s de falas + 6 s de frenagem). Chegada ~8 s após pegar a máscara.
- Trem: Air Exchange, cidade distante e planície agora se deslocam com o trem (paralaxe). O relevo virou periódico em Z (400 m) para os ladrilhos rolarem sem costura; tudo volta à posição original durante o fade preto da chegada. O pátio fica oculto durante a viagem.
- Sala de Testes: a parede de materiais mostra OK/ERRO por textura carregada.
- Limitação honesta: o desempenho não foi medido em celular (não há aparelho no ambiente). Em renderização por software o FPS relativo da Sala de Testes ficou BAIXO 15 / MÉDIO 10, números que servem só para comparação.

## Pronto e validado na 0.3.1-demo
- **Capítulos 1, 2 e 3 jogáveis de ponta a ponta**, encadeados (o inventário passa de um capítulo ao outro),
  terminando na tela "Fim da demo" e nos créditos.
- Dublagem PT-BR e EN gerada por síntese de voz para **todas as 51 falas** (102 arquivos WAV), com filtros
  de rádio/alto-falante; legendas nos dois idiomas.
- Menus (novo jogo, continuar, capítulos, opções, créditos), HUD, controles de toque, gamepad e teclado/mouse.
- **Sala de Testes** (menu principal): arsenal, estande de tiro, arena com gerador de inimigos, física, circuito
  de movimento, NPCs/dublagem/áudio, materiais e troca de gráficos ao vivo com painel de desempenho
  (use-a para medir FPS no seu aparelho).
- Correções: contador de munição do HUD quebrava um dígito por linha; a tela de fim da demo podia fechar uma
  fase iniciada depois dela.
- Salvamento automático por checkpoint e manual; carregamento restaura posição, inventário e estado do mapa.

### Testes executados de fato
- `godot --headless -- --autotest` (Godot 4.3-stable, Linux): **142/142 PASS em ~66 s** (116 da campanha + 26 da Sala de Testes,
  incluindo tiro real nos alvos, escada de mão e esteira com física real)
  (lista completa em `autotest_ultimo_resultado.txt`).
- Capturas de tela renderizadas (renderizador de Compatibilidade, 1280×720, software) dos três capítulos,
  usadas para corrigir iluminação, HUD e tela de carregamento.

## O que NÃO foi testado (limitações honestas)
- **Nenhum teste em aparelho Android real** nem no editor Godot para Android. O ambiente de desenvolvimento
  não tem GPU/Vulkan: o desempenho medido lá (1–2 FPS em renderização por software) não representa um celular.
  Os presets 30/60/90 FPS e BAIXO–ULTRA existem, mas **não há números de FPS reais** a declarar.
- O renderizador Mobile (Vulkan) não pôde ser visualizado aqui; as capturas usam Compatibilidade, que pode
  ficar um pouco mais escuro/claro que o Mobile. No modo Compatibilidade o glow é desligado de propósito.
- Teste de jogabilidade humana (dificuldade, ritmo, leitura dos caminhos) não foi feito; os testes automáticos
  validam a lógica e a física de travessia, não a diversão.
- Vozes são sintéticas (TTS), não atores humanos.

## Pendente (campanha completa)
| Item | Status |
|---|---|
| Caps. 1–6 | jogáveis e testados |
| Caps. 7–18 (resto do Ato II) | planejados (resumo + concept art); não construídos |
| Caps. 19–30 (Ato III) e epílogo | planejados (resumo + concept art); não construídos |
| Veículos (barco, buggy) | prontos |
| Manipulador | pronto (cap. 5 e Sala de Testes) |
| Inimigos restantes (Sonda, Lâmina, chefes) | Rastejador e Caçador prontos; demais não iniciados |
| Modelos de personagens mais detalhados | corpos procedurais atuais são simples |
| Teste e ajuste em dispositivos Android | pendente — depende de aparelho real |

## Próximos passos sugeridos
1. Rodar a demo num Android real, anotar FPS por preset e ajustar `Settings` (escala de render, sombras, luzes).
2. Capítulos 7 (O Depósito) a 9, seguindo o Planejamento.
3. Passe de arte em personagens (malhas mais detalhadas, LODs) e animações.

### 0.4.1 — Redesenho dos Combine
- Vigilante (Civil Protection beta): sobretudo longo, gola alta, cinto largo, correia cruzada, coldre, filtro peitoral com mangueira até a máscara, capuz de borracha, máscara clara com duas lentes azuis redondas, capacete de patrulha de aba curta, botas pretas.
- Vigilante elite: sobretudo preto, quepe de oficial com faixa vermelha, lentes âmbar, ombreiras vermelhas.
- Soldado Combine: capacete integral, duas lentes âmbar com aro metálico, respirador frontal arredondado com grade, placas peitorais em camadas, mochila com tanque e mangueira, proteções de coxa e antebraço, camuflagem azul/cinza.
- Ferramenta de QA `--lineup=/caminho` (estúdio com todos os modelos lado a lado).
- Autotestes: 219/219.
