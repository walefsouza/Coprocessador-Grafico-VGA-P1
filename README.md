- - -

# Coprocessador Gráfico 2D em FPGA (DE1-SoC)

## Descrição do Projeto

Desenvolvimento do núcleo de um coprocessador gráfico em hardware (FPGA), inspirado na arquitetura de consoles clássicos de 16 bits. O hardware aplica os conceitos de *Datapath* e Controle para renderizar um plano de fundo baseado em tiles, uma camada de polígonos rasterizados e uma camada de sprites dinâmicos, culminando na geração contínua de um sinal de vídeo VGA.

## Contexto Acadêmico e Autoria

Este projeto foi desenvolvido como parte do componente curricular **TEC499 - MI Sistemas Digitais**, ministrado pelo professor **Wild Freitas da Silva Santos**, na **Universidade Estadual de Feira de Santana (UEFS)**, como parte da metodologia de Aprendizagem Baseada em Projetos (PBL).

**Equipe:**
* Airam Santos Macêdo ([@mthepassionfruit-lab](https://github.com/imthepassionfruit-lab));
* Nicolas Carvalho Pimentel ([@nicolascrp07](https://github.com/nicolascrp07));
* Walef Souza da Silva ([@walefsouza](https://github.com/walefsouza)).

## Sumário

1. [Requisitos Funcionais e Não Funcionais](#requisitos-funcionais-e-não-funcionais)
2. [Arquitetura Proposta e Justificativa](#arquitetura-proposta-e-justificativa)
3. [Software e Hardware para Prototipação](#software-e-hardware-para-prototipação)
4. [Testbenches e Testes de Funcionamento](#testbenches-e-testes-de-funcionamento)
5. [Análise de Recursos da Plataforma](#análise-de-recursos-da-plataforma)
6. [Instalação e Configuração do Projeto](#instalação-e-configuração-do-projeto)
7. [Limitações e Possíveis Melhorias](limitacoes-e-possiveis-melhorias)

## 1. Requisitos Funcionais e Não Funcionais

**1.1. Funcionais:**

* **RF01**: Geração contínua de sinal de vídeo VGA em 640x480 pixels a 60 Hz, originado de uma resolução lógica interna de 320x240 pixels (fator 2x2).
* **RF02**: Camada de *background* baseada em *tilemap* de 40x30 posições, utilizando tiles de 8x8 pixels e suportando deslocamento (scroll) contínuo.
* **RF03**: Motor dinâmico baseado em uma memória OAM para no mínimo 32 sprites de 16×16 pixels (compostos por quatro tiles de 8×8), implementando prioridade, seleção de padrões de cor e espelhamento.
* **RF04**: Rasterização de primitivas geométricas (triângulos e retângulos preenchidos) utilizando exclusivamente aritmética inteira no hardware.
* **RF05**: Módulo compositor de quadros que avalia os níveis de prioridade entre as três camadas e aplica a regra de transparência (ignorando o índice de cor 0x00).

**1.2. Não Funcionais:**

* **RNF01**: Descrição integral do coprocessador gráfico na linguagem de descrição de hardware Verilog.
* **RNF02**: Arquitetura modular garantindo isolamento entre o *datapath* (motores), unidade de controle e instâncias de memória.
* **RNF03**: Estruturação dos mapeamentos de registradores (MMIO) preparada para integração futura com uma CPU ARM rodando Linux e um jogo escrito em C.

## 2. Arquitetura Proposta e Justificativa

### 2.1. *Motor de Background*:

O *banco_background* simula o *MMIO* do *motor de cenário*: banco de 3 registradores de 32 bits, escritos síncronamente via cpu_write_en/cpu_write_addr e distribuídos ao *datapath* por assign assíncrono, garantindo latência zero de leitura. O endereço 3'd0 mapeia out_video_ctrl (uso livre); 3'd1 mapeia out_scroll_x, do qual o motor lê a fatia [5:0] para o deslocamento horizontal; e 3'd2 mapeia out_scroll_y, fatiando [4:0] para o deslocamento vertical. Em paralelo, a *RAM de tilemap* é endereçada por cpu_addr de 11 bits (cobrindo a malha 40×30) e armazena em cada posição um dado de 8 bits (cpu_data), a ID do *tile*.

O *motor_background* renderiza o cenário combinacionalmente. Recebe as coordenadas lógicas do *driver VGA* e decodifica as coordenadas de varredura ativa para localizar o bloco 8×8 correspondente na grade. O *wrap-around* do *scroll* é obtido somando essas coordenadas aos *offsets* out_scroll_x/out_scroll_y e comparando com os limites da tela, subtraindo quando excedidos. O mapeamento da grade 2D para endereço linear na ram_tilemap usa deslocamento de bits ((linha<<5)+(linha<<3)) em vez de um multiplicador (Chu, 2008). Por fim, um estágio de *pipeline* atrasa as coordenadas do pixel (px_r, py_r) em um ciclo, alinhando tile_id e pixel ao barramento da *ROM de padrões*.

### 2.2. *Motor de Sprites*:

O *banco_sprites* simula a *Memória de Atributos de Sprites (OAM)*, repositório síncrono do estado de até 32 *sprites* (Chu, 2008). Cada um dos 32 registradores de 32 bits concentra o mapa completo de um *sprite*: [31] s_en habilita/oculta; [30:26] prioridade_padrao é a ID da textura na *ROM*; [25]/[24] controlam espelho horizontal/vertical; [23:15] s_x0 e [14:7] s_y0 são as coordenadas de origem na tela; [6:0] fica reservado. A CPU grava essa palavra síncronamente na borda de subida do *clock*, coordenada por we/write_addr. A leitura isolada (read_data) é assíncrona, com a exportação paralela do banco inteiro num barramento de 1024 bits (read_data_all), entregando os 32 *sprites* de uma vez ao motor, sem acessos sequenciais.

O *motor_sprites* varre esse barramento de 1024 bits combinacionalmente, gerenciando a sobreposição de até dois *sprites* por pixel com transparência resolvida em tempo real. Verifica se as coordenadas ativas (logic_x, logic_y) interceptam as caixas de 16×16 de cada objeto, ordenando os dois candidatos de maior prioridade (prioridade_valida/prioridade2_valida). O espelhamento é resolvido invertendo bits das coordenadas relativas (yr, xr) por negação lógica (~), em vez de subtração (Tocci, Widmer & Moss, 2011). Os sinais dos dois candidatos passam por dois estágios de *pipeline* (_r, _r2) para sincronizar com a saída da *ROM*. No *mux* final, se o *sprite* de maior prioridade for transparente (8'd0), deixa passar o pixel do segundo *sprite* antes de repassar ao compositor, resolvendo a oclusão dos *sprites* mais altos na prioridade sem *line buffers* (Chu, 2018).

### 2.3. *Motor de Polígonos*:

O *banco_poligonos* é o banco de registradores síncrono do desenho geométrico: cada um dos 8 registradores de 32 bits concentra a geometria completa de uma forma. [31] p_enable habilita/oculta; [30:28] p_shape define o tipo (0=quadrado, 1=retângulo, 2=isósceles, 3=equilátero, 4=escaleno); [27:20] p_color é o índice na paleta de 256 cores; [19]/[18] controlam espelho horizontal/vertical; [17:9] p_base_x e [8:1] p_base_y são a coordenada de ancoragem; [0] fica reservado. O processador grava essa palavra síncronamente via we/write_addr, e a exportação paralela do banco inteiro num barramento de 256 bits (read_data_all) entrega os 8 polígonos de uma vez ao *motor rasterizador*, sem acessos sequenciais.

O *motor_poligonos* varre esse barramento combinacionalmente, extraindo de cada slot as *flags*, o formato, a cor, o espelhamento e as coordenadas base. Translada as coordenadas ativas (logic_x, logic_y) para o espaço local de cada polígono, tratando o espelhamento por seletores condicionais em vez de somadores (Tocci, Widmer & Moss, 2011). O *hit testing* dos triângulos resolve equações de *semiplanos* por arestas (A·x+B·y≥C) com aritmética inteira pura (Chu, 2018). A saída de cor é atrasada em dois estágios de *pipeline* (poly_color_r1, poly_color_out) para manter a fase alinhada com *sprites* e *background* no *compositor*.

### 2.4. *MEF Controle*:

O *mef_controle* é o controlador interativo central, uma *FSM híbrida Mealy/Moore* que gerencia e edita em tempo real os atributos de cenário, *sprites* e polígonos. Tem 12 estados organizados por *motor gráfico*, com transição cíclica pelos botões da *DE1-SoC*. As entradas assíncronas (KEY) passam por registradores de deslocamento que detectam borda (*debouncing*), gerando pulsos de um ciclo (Chu, 2008). Todas as escritas no *datapath* são sincronizadas com vblank_start_pulse, garantindo que ocorram fora da janela ativa e evitando *tearing* (tela não desenhada completamente).

### 2.5. *Compositor*:

O *compositor* mistura as camadas de vídeo pixel a pixel antes de enviar as cores ao *frame buffer*, de forma puramente combinacional. Implementa uma rede de *multiplexação condicional* encadeada com prioridade fixa (*sprites* primeiro, depois polígonos, por último o *background*), em que o índice 0 é transparente, e a rede chaveia instantaneamente para a camada inferior quando o pixel superior é nulo. Essa abordagem imita a arquitetura clássica de consoles 2D de 16 bits, dispensando *alpha blending* (definir o nível de transparência de cada pixel) contínuo (Chu, 2018).

### 2.6. *VGA Driver*:

O vga_driver gera a temporização de vídeo, coordenando a varredura física do monitor e fornecendo coordenadas lógicas e físicas aos motores, seguindo o modelo de *máquina de estados por contadores* descrito por Adams (ADAMS, [s.d.]). Usa dois contadores em cascata (h_counter mód. 800, v_counter mód. 525) para rastrear o feixe, comparando-os para ativar em nível baixo VGA_HS/VGA_VS nos intervalos de *apagamento horizontal* (656–751) e *vertical* (490–491). Aplica >>1 nas coordenadas visíveis (video_on) para gerar as coordenadas lógicas em 320×240 (x, y), mantendo pixel_x_raw/pixel_y_raw em 640×480. O núcleo opera internamente em 320×240 e a saída é ampliada 2×2 na exibição real.

### 2.7. *Frame Buffer*:

O frame_buffer implementa *Double Buffering*, alternando páginas de exibição e escrita para transições fluidas sem rasgos ou piscadas (Patterson & Hennessy, 2013). Converte as coordenadas (X, Y) em índice linear por (Y<<8)+(Y<<6)+X, e inverte pagina_frontal na transição do vblank_start_pulse. Esse bit direciona as escritas (wr_en) a uma das duas *RAMs Simple Dual-Port* (ram_a/ram_b), lendo as cores da página oposta para exibição. O mapeamento, que exigiria multiplicar por 320, usa *shifts* (Y*256+Y*64) em vez de um multiplicador (Chu, 2008).

### 2.8. *Top-Level (DE1_SOC_golden_top)*:

O DE1_SOC_golden_top integra o *coprocessador* na *FPGA*: *clock de pixel*, *driver VGA*, *controlador de estados*, bancos, motores, *compositor* e *frame buffer*, todos síncronos. O CLOCK_50 é dividido por dois para gerar o *clock de 25 MHz (clk_25)*, exigido pelo VGA em 640×480. O VGA_VS bruto é decodificado por um *detector de borda síncrono*, gerando o pulso vblank_start_pulse (sinalizador global para atualizações de registradores fora da janela ativa e para a troca de buffers). Devido à latência de leitura das *memórias internas (M10K)*, insere uma *linha de atraso de três ciclos* nas coordenadas de tela (x_pipe, y_pipe), alinhando-as aos pixels na gravação do *frame buffer*. O *double frame buffer* isola o preenchimento de pixel do feixe de exibição ativo, eliminando o *tearing*, e os índices de cor de 8 bits são expandidos para *RGB 24 bits (3R/3G/2B)*.

## 3. Software e Hardware usados para Prototipação

* **Plataforma Física:** Kit acadêmico Terasic DE1-SoC, FPGA Intel Cyclone V 5CSEMA5F31C6.
* **Módulos de Armazenamento:** Blocos dedicados de SRAM internos do chip (M10K).
* **Linguagem de Descrição de Hardware:** Verilog-2001;
* **Ferramentas de Síntese e Lógica:** Intel Quartus Prime Lite Edition para compilação, pinagem e mapeamento;
* **Interface Visual:** Monitor Philips com barramento analógico VGA padrão (640x480 @ 60Hz).
  
## 4. Demonstração e Testes de Funcionamento 

Os LEDs LEDR[9:0] mostram o estado atual da *FSM*, decompondo o estado bruto em dois campos: LEDR[1:0] indica o motor selecionado (background, sprites ou polígonos) e LEDR[4:2] indica o subestado dentro daquele motor onde os bits [9:5] permanecem sempre zerados. As chaves SW[9:0] são reutilizadas em todos os estados, mudando de função conforme a ação ativa: geralmente as chaves mais altas selecionam o índice do sprite/polígono/posição a editar, e as mais baixas (SW[3:0]) controlam o valor ou o deslocamento a aplicar. Os botões KEY[3:0] são ativos em nível baixo e filtrados por *debouncing*: KEY0 reseta a *FSM*, KEY1 avança para o próximo estado, KEY2 confirma a ação do estado atual, KEY3 retorna ao estado anterior e KEY1/KEY3 percorrem a lista de 12 estados em ciclo (voltam ao início/fim nas pontas). Estados de deslocamento (*scroll*) não usam KEY2: a escrita ocorre automaticamente a cada pulso de *vblank* enquanto a chave correspondente estiver ativa.

| Estado | Motor | LEDR (motor/substado) | Função | Uso das chaves `SW` | Grava com |
|---|---|---|---|---|---|
| MBG_SCROLL | Background | 0 / 0 | Rola o tilemap em X ou Y (eixo alterna a cada vblank) | SW0/SW1: X +/−; SW2/SW3: Y +/− | Automático (vblank) |
| MBG_PADRAO | Background | 0 / 1 | Grava um tile\_id direto numa posição do tilemap | SW[9:5]: posição no mapa; SW[4:0]: ID do tile | KEY2 |
| MSP_SCROLL | Sprites | 1 / 0 | Move o sprite selecionado em X/Y | SW[9:5]: sprite; SW0/SW1: X +/−; SW2/SW3: Y +/− | Automático (vblank) |
| MSP_PADRAO | Sprites | 1 / 1 | Troca o padrão gráfico do sprite | SW[9:5]: sprite; SW[4:0]: ID do padrão | KEY2 |
| MSP_ESPELHO | Sprites | 1 / 2 | Define espelhamento horizontal/vertical do sprite | SW[9:5]: sprite; SW1: espelho H; SW0: espelho V | KEY2 |
| MSP_INSTANCIAR | Sprites | 1 / 3 | Cria um sprite novo (ativo, posição/espelho zerados) | SW[9:5]: posição no banco; SW[4:0]: padrão inicial | KEY2 |
| MSP_DELETAR | Sprites | 1 / 4 | Remove o sprite (zera a palavra, desativando-o) | SW[9:5]: sprite a remover | KEY2 |
| MPG_SCROLL | Polígonos | 2 / 0 | Move o polígono selecionado em X/Y | SW[9:7]: polígono; SW0/SW1: X +/−; SW2/SW3: Y +/− | Automático (vblank) |
| MPG_COR | Polígonos | 2 / 1 | Troca a cor do polígono | SW[9:7]: polígono; SW[6:0]: índice de cor | KEY2 |
| MPG_ESPELHO | Polígonos | 2 / 2 | Define espelhamento horizontal/vertical do polígono | SW[9:7]: polígono; SW1: espelho H; SW0: espelho V | KEY2 |
| MPG_INSTANCIAR | Polígonos | 2 / 3 | Cria um polígono novo (posição central fixa, cor fixa) | SW[9:7]: posição no banco; SW[6:4]: forma | KEY2 |
| MPG_DELETAR | Polígonos | 2 / 4 | Remove o polígono (zera a palavra) | SW[9:7]: polígono a remover | KEY2 |

### Motor de Background

* **Scroll de Background**

<div align="center">
  <img src="images/gif01.gif" alt="Animação de Scroll no background" width="500">
  <br>
  <i>Gif 1: Animação de Scroll no background.</i>
</div>
<br>

<div align="center">
  <img src="images/placa01.jpg" alt="Motor de Background, modo de scroll" width="500">
  <br>
  <i>Figura 1: Chaves da placa no motor de background para scroll.</i>
</div>
<br>

* **Troca de Padrões do Tilemap**

<div align="center">
  <img src="images/gif02.gif" alt="Animação de troca de padrões" width="500">
  <br>
  <i>Gif 2: Animação de troca de padrões no background.</i>
</div>
<br>

<div align="center">
  <img src="images/placa02.jpg" alt="Motor de Background, alterar padrões" width="500">
  <br>
  <i>Figura 2: Chaves da placa no motor de background para troca de padrão.</i>
</div>
<br>


### Motor de Sprites 

* **Instâncias de Novos Sprites**

<div align="center">
  <img src="images/gif03.gif" alt="Instância de novos sprites" width="500">
  <br>
  <i>Gif 3: Instanciação de novos sprites.</i>
</div>
<br>

<div align="center">
  <img src="images/placa03.jpg" alt="Motor de Sprites, novas instâncias" width="500">
  <br>
  <i>Figura 3: Chaves da placa no motor de sprites para novas instâncias.</i>
</div>
<br>

* **Movimentação dos Sprites**

<div align="center">
  <img src="images/gif04.gif" alt="Deslocamento dos sprites" width="500">
  <br>
  <i>Gif 4: Deslocamento dos sprites nos eixos x e y.</i>
</div>
<br>

<div align="center">
  <img src="images/placa04.jpg" alt="Motor de Sprites, deslocamento" width="500">
  <br>
  <i>Figura 4: Chaves da placa no motor de sprites para deslocamentos.</i>
</div>
<br>

* **Espelhamento dos Sprites**

<div align="center">
  <img src="images/gif05.gif" alt="Espelhamento dos sprites" width="500">
  <br>
  <i>Gif 5: Espelhamento horizontal e vertical dos sprites.</i>
</div>
<br>

<div align="center">
  <img src="images/placa05.jpg" alt="Motor de Sprites, espelhamento" width="500">
  <br>
  <i>Figura 5: Chaves da placa no motor de sprites para espelhamentos.</i>
</div>
<br>

* **Troca de Padrão dos Sprites**

<div align="center">
  <img src="images/gif06.gif" alt="Troca de padrão dos sprites" width="500">
  <br>
  <i>Gif 6: Alteração dos padrões dos sprites.</i>
</div>
<br>

<div align="center">
  <img src="images/placa06.jpg" alt="Motor de Sprites, troca de padrão" width="500">
  <br>
  <i>Figura 6: Chaves da placa no motor de sprites para troca de padrão.</i>
</div>
<br>

* **Deletando Sprite da Tela**

<div align="center">
  <img src="images/gif07.gif" alt="Deletar sprite" width="500">
  <br>
  <i>Gif 7: Deletando sprites do monitor.</i>
</div>
<br>

<div align="center">
  <img src="images/placa07.jpg" alt="Motor de Sprites, deletar" width="500">
  <br>
  <i>Figura 7: Chaves da placa no motor de sprites para delete.</i>
</div>
<br>

### Motor de Polígonos

* **Instanciando Polígono**

<div align="center">
  <img src="images/gif08.gif" alt="Instanciar polígono" width="500">
  <br>
  <i>Gif 8: Instanciando polígonos no monitor.</i>
</div>
<br>

<div align="center">
  <img src="images/placa08.jpg" alt="Motor de Polígonos, nova instância" width="500">
  <br>
  <i>Figura 8: Chaves da placa no motor de polígonos para instanciação.</i>
</div>
<br>

* **Deslocamento de Polígonos**

<div align="center">
  <img src="images/gif09.gif" alt="Deslocar polígono" width="500">
  <br>
  <i>Gif 9: Scroll de polígonos no monitor.</i>
</div>
<br>

<div align="center">
  <img src="images/placa09.jpg" alt="Motor de Polígonos, scroll" width="500">
  <br>
  <i>Figura 9: Chaves da placa no motor de polígonos para scroll.</i>
</div>
<br>

* **Troca de Cor de Polígonos**

<div align="center">
  <img src="images/gif910.gif" alt="Troca de cor de um polígono" width="500">
  <br>
  <i>Gif 10: Alterando cor de um polígono.</i>
</div>
<br>

<div align="center">
  <img src="images/placa910.jpg" alt="Motor de Polígonos, nova cor" width="500">
  <br>
  <i>Figura 10: Chaves da placa no motor de polígonos para troca de cor.</i>
</div>
<br>

* **Hierarquia de Prioridade Polígono**

<div align="center">
  <img src="images/gif911.gif" alt="Sobreposição de um polígono" width="500">
  <br>
  <i>Gif 11: Sobreposição de polígonos.</i>
</div>
<br>

<div align="center">
  <img src="images/placa911.jpg" alt="Motor de Polígonos, sobreposição" width="500">
  <br>
  <i>Figura 11: Chaves da placa no motor de polígonos para deslocamento.</i>
</div>
<br>

* **Espelhamento de Polígonos**

<div align="center">
  <img src="images/gif912.gif" alt="Espelhamento de um polígono" width="500">
  <br>
  <i>Gif 12: Espelhamento horizontal e vertical dos polígonos.</i>
</div>
<br>

<div align="center">
  <img src="images/placa912.jpg" alt="Motor de Polígonos, espelhamento" width="500">
  <br>
  <i>Figura 12: Chaves da placa no motor de polígonos para espelhamento.</i>
</div>
<br>

* **Relação de Prioridade Polígonos-Sprites**

<div align="center">
  <img src="images/gif913.gif" alt="Prioridade de sprites sobre polígono" width="500">
  <br>
  <i>Gif 13: Sprites com prioridade sobre polígonos.</i>
</div>
<br>

<div align="center">
  <img src="images/placa913.jpg" alt="Motor de Polígonos, sobreposição sprites" width="500">
  <br>
  <i>Figura 13: Chaves da placa no motor de sprites para deslocamento.</i>
</div>
<br>

* **Deletando Polígonos do Monitor**

<div align="center">
  <img src="images/gif914.gif" alt="Deletar polígono" width="500">
  <br>
  <i>Gif 14: Polígonos sendo deletados.</i>
</div>
<br>

<div align="center">
  <img src="images/placa914.jpg" alt="Motor de Polígonos, deletar" width="500">
  <br>
  <i>Figura 14: Chaves da placa no motor de polígonos para deletar.</i>
</div>
<br>

### Tratamento de Comandos Inválidos e Limites de Hardware

Embora a interface atual seja operada fisicamente por chaves (SW) e botões, os testes do hardware são limitados pela arquitetura. A tentativa de instanciar sprites em endereços acima do limite de 32 entidades ou a inserção de coordenadas de deslocamento que extrapolam a malha visual (320x240) são ignoradas ou limitadas na borda pela lógica combinacional. A máquina de estados não sofre travamentos nem perde o sincronismo de vídeo perante estímulos imprevistos no barramento.

## 5. Análise de Recursos da Plataforma

O projeto utilizou os recursos da placa DE1-SoC de forma equilibrada, com destaque para o uso intensivo de memória e blocos DSP frente a um consumo moderado de lógica. Os principais pontos são:

- **Utilização de Lógica:**
  Foram utilizados 3.083 ALMs (Adaptive Logic Modules) de um total de 32.070 disponíveis na FPGA Cyclone V, representando 10% da capacidade total.

- **Uso de Registradores:**
  O design inclui 1.297 registradores dedicados, distribuídos entre o controle de máquinas de estado (FSM), motores de renderização (polígonos e sprites) e lógica de sincronismo de vídeo.

- **Pinos Utilizados:**
  Foram utilizados 54 pinos físicos da FPGA (12% dos 457 disponíveis), destinados à saída de vídeo VGA, entradas de controle e demais periféricos da placa.

- **Blocos de Memória:**
  O projeto utilizou 1.320.960 bits de memória dos 4.065.280 bits disponíveis, o que representa 32% da memória total, alocada principalmente para o frame buffer e as ROMs de sprites e tiles.

- **Blocos DSP:**
  Foram utilizados 16 blocos DSP, o equivalente a 18% dos 87 disponíveis, aplicados nas operações aritméticas do motor de rasterização de polígonos.

  <div align="center">
  <img src="images/analise-recursos.png" alt="Analise de Recursos" width="500">
  <br>
  <i>Fonte: Flow Summary, Quartus Prime Lite Edition.</i>
</div>
<br>

- **Análise de Timing e Frequência Máxima (Fmax):**
  Um dos maiores desafios de projetos gráficos é garantir que o caminho crítico lógico não atrase a geração de pixels. Através do *Timing Analyzer*, verificou-se que o modelo de atraso mais crítico (*Slow 1100mV 85C Model*) atingiu uma Frequência Máxima (Fmax) de **53.82 MHz** para o domínio de clock principal. Como o clock exigido para a varredura VGA padrão é de apenas 25.175 MHz, o circuito fechou o *timing* com folga (*Slack* positivo), garantindo que não haverá perda de sincronismo ou metaestabilidade mesmo nas piores condições de temperatura e tensão do silício.

<div align="center">
  <img src="images/fmax.png" alt="Análise de Timing - Fmax" width="400">
  <br>
  <i>Figura 15: Frequência Máxima atestada no Timing Analyzer.</i>
</div>
<br>

## 6. Instalação e Configuração do Projeto 

### Pré-requisitos:

- Ter o software Quartus Prime (Standard ou Lite Edition) instalado;
- Driver USB-Blaster instalado e reconhecido pelo sistema operacional;
- Placa DE1-SoC conectada via cabo USB-Blaster e saída VGA conectada a um monitor.

### Passos:

1. Baixe o diretório do projeto e abra o arquivo COPROCESSADORANW.qpf no Quartus Prime.
2. Certifique-se de que os arquivos .mif (padrões gráficos e *tilemaps*) permanecem no mesmo diretório do projeto, pois são usados para a inicialização das memórias durante a síntese.
3. As IPs de memória (RAMs e ROMs *Dual-Port*, buffers de frame) já estão instanciadas e configuradas via *IP Catalog*, não sendo necessário reconfigurá-las manualmente.
4. Envie o projeto à síntese clicando em **Processing > Start Compilation**.
5. Após a compilação bem-sucedida, abra o **Programmer**, selecione o cabo USB-Blaster e clique em “Start” para gravar o projeto na FPGA.

## 7. Limitações e Possíveis Melhorias

O projeto apresenta algumas limitações técnicas, decorrentes de decisões de escopo tomadas para viabilizar a entrega dentro do prazo. A seguir, cada limitação é acompanhada de uma possível melhoria futura:

- **Pipeline de atraso de clock para sincronização de memórias síncronas:**
  Introduz latência adicional no caminho de dados. Uma melhoria possível seria revisar a arquitetura de sincronização para reduzir os estágios de atraso necessários.

- **Transparência limitada a dois sprites sobrepostos:**
  O compositor atual só resolve corretamente a sobreposição de até dois sprites. Uma extensão natural seria generalizar a lógica de composição para suportar N camadas de transparência.

- **Avaliação sequencial de todas as entidades sem MEFs de estados delimitados:**
  A ausência de máquinas de estado bem definidas por entidade limita o paralelismo do processamento. Estruturar o controle em FSMs delimitadas permitiria pipeline e maior throughput.

- **Modelagem de polígonos restrita a formas fixas:**
  O rasterizador atual não suporta geometria arbitrária. Uma melhoria seria generalizar o motor para aceitar polígonos com número variável de vértices.

- **Domínios de clock não explicitamente tratados:**
  A ausência de sincronizadores dedicados entre domínios de clock é um risco de metaestabilidade. A melhoria recomendada é a implementação de circuitos sincronizadores nas interfaces relevantes.

  ## 8. Referências

ADAMS, V. Hunter. VGA Driver in Verilog. [S. l.], [s. d.]. Disponível em: https://vanhunteradams.com/DE1/VGA_Driver/Driver.html. Acesso em: 17 ago. 2026.

CHU, Pong P. FPGA prototyping by Verilog examples: Xilinx Spartan-3 version. Hoboken, NJ: John Wiley & Sons, 2008.

CHU, Pong P. FPGA prototyping by SystemVerilog examples: Xilinx MicroBlaze MCS SoC edition. 2. ed. Hoboken, NJ: Wiley, 2018.

PATTERSON, David A.; HENNESSY, John L. Computer organization and design: the hardware/software interface: ARM edition. Waltham, MA: Morgan Kaufmann, 2017.

TOCCI, Ronald J.; WIDMER, Neal S.; MOSS, Gregory L. Sistemas digitais: princípios e aplicações. 11. ed. São Paulo: Pearson Prentice Hall, 2011. Tradução de Jorge Ritter; revisão técnica de Renato Giacomini.
