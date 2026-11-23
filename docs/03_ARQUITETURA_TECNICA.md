# Arquitetura técnica

Godot 4.3, GDScript, renderizador **Mobile** (Vulkan) como alvo principal; o projeto também roda no
renderizador de Compatibilidade (GLES3) — usado nos testes visuais do ambiente de desenvolvimento.

## Autoloads (src/core)
| Nó | Responsabilidade |
|---|---|
| `Loc` | textos PT-BR/EN (menus, HUD, objetivos, legendas) |
| `Settings` | qualidade BAIXO/MÉDIO/ALTO/ULTRA, alvo 30/60/90 FPS, escala de render, sombras, sensibilidade, idioma de voz/legendas, layout do toque — salvo em `user://settings.cfg` |
| `InputRouter` | teclado/mouse, gamepad (remapeável, vibração), toque multitoque; detecta o dispositivo ativo |
| `AudioBus` | barramentos Master/Música/Efeitos/Voz/Ambiente, reverb por zona acústica, música em camadas (exploração/tensão/combate) |
| `Dialogue` | filas de falas com voz posicional (NPC) ou rádio, legendas sincronizadas, fallback para legenda temporizada se faltar áudio |
| `Game` | capítulos, checkpoints, salvamento automático/manual (JSON em `user://saves/`), transição entre capítulos levando inventário, fim da demo/créditos |

## Níveis (src/levels)
`LevelBase` constrói os mapas por código com peças modulares (`box`, `room` com aberturas, `stair`, `ramp`,
`facade_block`, `car_wreck`, `barrier`, luminárias, pôsteres). Toda a geometria estática é **agrupada por
setor e material** num único `MeshInstance3D` por célula de grade (`grid`, e `grid_y` para prédios de vários
andares) — poucas draw calls e respeito ao limite de 8 luzes por malha do Mobile Renderer. Colisões são
corpos estáticos por setor/superfície (a superfície define som de passos e impacto). A malha de navegação é
gerada no carregamento a partir das colisões.

Cada capítulo (`chapter_0N.gd`) define: materiais, construção por áreas, roteiro por gatilhos (`Interactables.trigger`),
checkpoints (`CP_ORDER`), inimigos/pickups com ID (o estado de mortos/coletados/flags é salvo), e
`after_build()` para restaurar o estado ao carregar um save.

| Capítulo | Áreas | Mecânicas |
|---|---|---|
| 1 Linha Nove | trem, estação, manutenção, duto, casa de bombas, pátio, guarita | máscara/filtro, chave inglesa, tábuas quebráveis, empilhar caixas, pistola/SMG, barris explosivos, alavanca do portão |
| 2 Praça do Terminal | Rua Vessel, praça monumental, Bloco 14 (5 andares), telhados, beco | holofote com detecção por cone + linha de visão, patrulhas, Matvei e a espingarda, batida policial, salto entre telhados, viga, escada de mão |
| 3 Distrito Leste | beco, galpão de montagem, Fosso dos Escribas, sala da prensa, dreno, saída para o rio | esteiras (velocidade constante física), operários/capataz, guindaste de pórtico em 2 etapas (mover/baixar → ponte), 3 válvulas com ondas de reforço, alavanca de sobrecarga, explosão, fuga |

## Personagens (src/npc)
`Humanoid` gera corpos articulados por código (cabeça, tronco, membros, roupas por tipo, LOD), anima
caminhada/mira/sentar e vira ragdoll ao morrer. `EnemyAI`: estados idle/patrol/investigate/combat/cover/search,
visão por cone + raycast, audição por ruído, cobertura, rajadas. `NpcAlly`: seguir, roteiro, sentar, fugir, falar.

## Testes (src/tests/autotest.gd)
`godot --headless -- --autotest` percorre os três capítulos pelos mesmos gatilhos/interações do jogador,
com tempo acelerado. Inclui testes de **movimento físico real** (o `CharacterBody3D` anda com a entrada
simulada): subir a escadaria do prédio, saltar o vão entre telhados, atravessar a viga, cruzar o fosso pela
ponte do guindaste, subir a passarela, entrar no dreno; e cair no fosso quando não há ponte.
Também valida dublagem PT/EN de todas as falas, tiros reais (pistola, espingarda), salvamento/carregamento.
Resultado mais recente: `docs/autotest_ultimo_resultado.txt`.
