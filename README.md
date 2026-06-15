# Zaíta Conflitos

Protótipo educacional e de código aberto criado em Godot 4.6. O jogo é inspirado no conto **“Zaíta esqueceu de guardar os brinquedos”**, de Conceição Evaristo, e propõe uma leitura interativa sobre cuidado, território, infância e violência urbana sem usar violência gráfica.

O jogador controla o irmão de Zaíta em uma cena isométrica em preto e branco. Zaíta e Naíta caminham automaticamente na área elevada do mapa, enquanto inimigos surgem na parte baixa. O objetivo mecânico é proteger as crianças usando movimento por clique, disparos simbólicos em forma de raio amarelo, escudos e torretas. A condição narrativa é sempre trágica: se Zaíta ou Naíta for atingida, a partida para e aparece a mensagem:

**“Zaíta, você esqueceu de guardar os brinquedos”**

## Como Rodar

1. Abra o Godot 4.6.
2. Importe a pasta deste projeto.
3. Abra `scenes/Main.tscn`.
4. Pressione **F5** para executar.

O projeto já define `scenes/Main.tscn` como cena principal em `project.godot`.

## Controles

- Clique no botão **Jogar** para iniciar.
- Clique no chão para mover o irmão.
- Clique em um inimigo para o irmão se aproximar e atirar quando estiver no alcance.
- Use os botões da HUD para escolher ou desbloquear armas.
- Use **Escudo** ou **Torreta** e depois clique em uma posição válida do chão.
- O botão **Jogar novamente** reinicia o estado e volta para a tela inicial.

## Mecânicas Implementadas

- Zaíta e Naíta são instâncias independentes de `Child.tscn`.
- As crianças e o irmão ficam dentro da região verde superior, delimitada por polígono editável.
- O irmão usa movimento por clique e mira por clique em inimigos.
- Inimigos surgem nas regiões vermelha ou azul e só caminham dentro da região onde nasceram.
- Inimigos da região azul usam perspectiva invertida em relação aos da região vermelha.
- Inimigos podem mirar no irmão, em Zaíta ou em Naíta, mas o irmão nunca recebe dano.
- Escudos são instalados na borda interna da região verde, bloqueiam disparos e possuem 20 pontos de vida.
- Escudos ficam estáticos em repouso, animam quando sofrem impacto e usam animação simbólica ao explodir.
- Torretas giratórias usam o sprite `rotarygun.png`, animam ao disparar, consomem crânios negros por tiro e desaparecem após duração ou munição limite.
- A moeda `black_skulls` recompensa derrotas e compra armas ou itens.
- `background-1.png` é escalada para cobrir toda a viewport; `background-2.png` fica por baixo com paralaxe sutil.
- Irmão, crianças e inimigos usam folhas de caminhada para baixo/cima, com espelhamento horizontal para esquerda/direita.
- Os retângulos e durações das animações são lidos dos arquivos `.json` em `assets/sprites/`.
- O esgoto na região amarela usa um shader suave de fluxo lento.
- A câmera acompanha o irmão para melhorar a leitura dos personagens no mapa.
- Personagens possuem sombras nos pés para reforçar contato com o chão.
- O fim de jogo usa desaparecimento simbólico, sem sangue e sem representação gráfica de ferimento.
- `background-2.png` se desloca levemente em sentido oposto ao irmão para criar paralaxe.

## Valores Para Estudar no Inspector

Abra `scenes/Main.tscn` e selecione o nó `Main`. As zonas principais ficam exportadas como retângulos de apoio e polígonos editáveis:

- `children_walk_zone`
- `enemy_spawn_left_zone`
- `enemy_spawn_right_zone`
- `enemy_walk_zone`
- `player_walk_zone`
- `item_place_zone`
- `safe_zone_polygon`
- `item_place_polygon`
- `enemy_red_polygon`
- `enemy_blue_polygon`
- `sewer_polygon`

Ative `debug_mode` para desenhar essas zonas durante a execução. Também há custos, intervalos de spawn, força de paralaxe e raio de clique expostos no Inspector.

Cada cena reutilizável também possui valores editáveis:

- `Player.tscn`: alcance, dano, intervalo e custo dos tiros.
- `Child.tscn`: velocidade, pausas e zona de caminhada.
- `Enemy.tscn`: tipo de arma, dano, recompensa e alcance.
- `Shield.tscn`: vida e raio de bloqueio.
- `AutoTurret.tscn`: alcance, duração, custo por tiro e limite de munição.
- `HUD.tscn`: custos exibidos nos botões.

## Estrutura

- `scenes/`: cenas principais e reutilizáveis.
- `scripts/`: comportamentos em GDScript com comentários em português brasileiro.
- `assets/images/`: fundos e imagens de abertura/final.
- `assets/props/`: escudo, armas, crânio negro e torreta.
- `assets/sprites/`: personagens e inimigos.

## Observação Sobre Assets

O protótipo usa os arquivos disponíveis na pasta `assets/`. Para trocar qualquer imagem ou folha de animação, preserve o caminho ou ajuste a textura e o JSON exportados na cena correspondente.

## Propósito Educacional

Este projeto foi pensado para aulas e oficinas que conectem literatura, design de jogos, pensamento computacional e reflexão crítica. A estrutura favorece experimentos visuais em Godot: zonas são editáveis no Inspector, cenas são pequenas e reutilizáveis, e os scripts separam lógica de composição visual.

O jogo não busca transformar a tragédia do conto em espetáculo. A mecânica de defesa serve como mediação para discutir escolhas de design, limites éticos da representação e formas de narrar cuidado, medo e ausência em sistemas interativos.
