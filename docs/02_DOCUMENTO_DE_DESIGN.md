# ATMOSFERA ZERO — Documento de Design (GDD)

FPS single-player, Godot 4 (Mobile Renderer), Android + Windows. Inspirado no clima da beta de 2002 de Half-Life 2, com mundo, personagens e história 100% originais.

## Premissa

Dezoito anos depois da Noite do Céu Partido, o Domínio — um império interdimensional — ocupa a Terra. Para tornar o planeta habitável para seus Arcontes, ergueu os Trocadores Atmosféricos: complexos que sugam o ar terrestre através de fendas e devolvem um smog esverdeado. Humanos só respiram com máscaras; os oceanos foram drenados até o leito.

O protagonista, Tomás Varga, engenheiro de sistemas de ventilação, ajudou a projetar — antes da guerra — os dutos que o Domínio converteu no primeiro Trocador. Ele é "realocado" de trem para a Cidade Nove. Quem o chama é alguém que conhece seu passado: o Capitão Anselm Kovač, comandante dos Conscritos, os soldados humanos forçados a guardar o próprio Trocador.

Tema: responsabilidade e reparação — o homem que ajudou a construir a máquina é o único que sabe como pará-la.

## Personagens

| Personagem | Papel | Personalidade | Voz (PT/EN) |
|---|---|---|---|
| Tomás Varga | Protagonista; fala pouco (apenas grunhidos/respiração) | Determinado, culpado | — |
| Velho Bohdan | Passageiro do trem, guia do cap. 1 | Fatalista, gentil, humor seco | grave, idosa |
| Irina Kovač | Batedora da Resistência, filha do Capitão | Sarcástica, rápida, leal | firme, jovem |
| Cap. Anselm Kovač | Líder secreto dos Conscritos | Militar cansado, honrado | grave, autoritária |
| Dr. Oskar Lindqvist | Inventor no Ferro-Velho; perdeu a perna numa Tempestade de Partículas | Excêntrico, falador | animada, rouca |
| Dra. Marta Halden | Diretora da Estação Thule; trai a Resistência | Fria, racional, dividida | clara, contida |
| Ezequiel Brandt | Maquinista do quebra-gelo Nordvik | Teimoso, prático | rouca |
| O Regente | Governante humano colaboracionista, só visto em telas | Paternal, sinistro | calma, profunda |
| Vigilantes | Polícia do Domínio (inimigo comum) | Rádio filtrado | sintético |

## Estrutura da campanha (30 capítulos, 3 atos)

Replanejada na 0.4.0 de 12 para 30 capítulos (pedido do usuário). Cada capítulo tem uma concept art original (gerada por IA para orientar a produção, não captura do jogo) em `assets/concept/chNN.jpg`, visível no menu **Planejamento**. Dados em `data/campaign_plan.json`.

### ATO I — A Cidade
1. Linha Nove [JOGÁVEL] — Trem de realocação até a Estação Central; inspeção dos Vigilantes, fuga pelos pátios ferroviários e a primeira visão do Trocador.
2. Praça do Terminal [JOGÁVEL] — Praça monumental com telões do Regente, apartamentos e telhados; encontro com Irina e o Discurso do Ar Puro.
3. Distrito Leste [JOGÁVEL] — Fábricas de peças para o Domínio, guindastes, esteiras e a sabotagem da prensa hidráulica.
4. A Muralha [JOGÁVEL] — Esgotos, canais e a muralha entre Cidade Nova e Velha; barco a motor perseguido por um helicóptero-caçador e elevador sob holofotes.

### ATO II — O Ermo e o Norte
5. Ferro-Velho [JOGÁVEL] — O inventor Lindqvist entrega o Manipulador; quebra-cabeças físicos, um cão-robô de sucata e Rastejadores; os planos originais de Tomás.
6. Mar Seco [JOGÁVEL] — Travessia de buggy pelo leito do mar drenado: o petroleiro Aurora, ossadas de baleia, um posto do Domínio e a tempestade de partículas.
7. O Depósito — Antiga ilha-presídio virada depósito ferroviário; infiltração noturna pelo farol e pelas docas, torretas automáticas.
8. Bloco de Celas — Resgate dos prisioneiros que seguem para o Trocador; corredores de celas, câmaras de triagem e um alarme geral.
9. Docas das Naves — Docas onde naves de transporte do Domínio carregam prisioneiros; combate entre contêineres e fuga num trem de carga.
10. Ferrovia do Ermo — Viagem no teto de um trem blindado pelo Ermo; tiroteios em movimento, pontes e túneis.
11. O Trocador: Exterior — Aproximação do complexo-besouro; jatos de ar gigantes, conscritos aliados e o Capitão Kovač.
12. O Trocador: Entranhas — Dentro dos dutos que Tomás projetou: ventiladores colossais, correntes de ar como quebra-cabeça e passarelas.
13. Reator — Sabotagem do reator que inicia o levante; o céu limpa por um minuto.
14. Costa Queimada — Fuga pelo litoral em ruínas, vilas de pescadores abandonadas e naves de combate patrulhando.
15. Nordvik — Um quebra-gelo à deriva; tripulação desaparecida, câmaras de contenção e o maquinista Ezequiel.
16. Mar de Gelo — Navegação pelo gelo rumo ao norte; criaturas sob o gelo e uma travessia a pé pelas placas.
17. Estação Thule — Base submarina científica; a Dra. Halden recebe o grupo e esconde suas intenções.
18. Inundação — Halden trai a Resistência e inunda a base; Ezequiel se sacrifica; fuga em cápsula.

### ATO III — O Levante
19. A Cúpula — Controle climático ártico do Domínio; infiltração em uma cúpula gigantesca sobre o gelo.
20. Hangar Ártico — Batalha ao lado dos Conscritos de Kovač para roubar um avião de transporte.
21. Queda — O avião é abatido sobre a Cidade Nove e cai num arranha-céu stalinista.
22. Arranha-céu — Descida pelos andares destruídos do arranha-céu, entre destroços e milícias.
23. Guerra de Rua — O levante toma a Cidade Nove; barricadas, cidadãos armados e blindados do Domínio.
24. Canais Velhos — Retorno aos canais da Cidade Velha; caçada a uma máquina andante de pernas longas.
25. Hospital Ocupado — Hospital convertido em centro de conversão; resgate de médicos da Resistência.
26. Estação Central — De volta à estação onde tudo começou; tomar o centro ferroviário para levar o levante à torre.
27. Distrito do Regente — Avenidas monumentais guardadas pelos Arcontes; a Torre do Regente domina o horizonte.
28. A Torre: Base — Invasão da base da torre; elevadores de carga, salas de máquinas e a guarda de elite.
29. A Torre: Ápice — Ascensão final; confronto com Halden (poupar ou não) e com o Regente.
30. Trocador-Mãe — Desligar o Trocador-mãe; o primeiro amanhecer sem máscara. Epílogo e créditos.

Cada capítulo: 25–45 min de jogo previstos, ao menos um puzzle físico, um encontro de combate distinto, um momento cinematográfico e uma área secreta.

## Pilares de jogabilidade
1. Física como ferramenta: empilhar, arremessar, quebrar, bloquear, contrapesos.
2. Combate tático: inimigos em esquadrão, cobertura, flanqueamento, supressão.
3. Narrativa ambiental: cartazes, rádios, diários, conversas de NPCs.
4. Escala: alternar espaços apertados e vistas monumentais.

## Arsenal
| Slot | Arma | Função | Munição |
|---|---|---|---|
| 1 | Chave inglesa | corpo a corpo, quebrar tábuas | — |
| 1 | Manipulador (cap. 5) | pegar/arremessar/empurrar objetos | energia |
| 2 | Pistola P-9 "Vigília" | precisa, semi-auto | 9 mm, pente 15 |
| 3 | Submetralhadora K-60 | automática, pente de 60 | 9 mm |
| 3 | Fuzil AR-7 | rajadas, luneta 2x | 7,62, pente 30 |
| 4 | Escopeta "Arado" | dispersão, carregamento cartucho a cartucho | calibre 12, 6 |
| 5 | Fuzil de Pulso | projétil de energia, carga alternativa | células |
| 6 | Granada de tubo | arremesso físico | — |

## Inimigos
Vigilante (polícia, cassetete/pistola), Soldado do Domínio (fuzil de pulso, granadas, esquadrão), Sonda (drone), Rastejador (fauna, matilha), Incinerador, Lâmina (elite ágil), Bastião (chefe), Tentáculo Abissal (Thule), Helicóptero-caçador.

## Direção de arte
Ver docs/01_PESQUISA_HISTORICA.md §7. Paleta: concreto #5E5F60, petróleo #2B3E42, ferrugem #7A3E1A, sódio #E8A040, smog #7F9478.
