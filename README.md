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
* **RF05**: Módulo compositor de quadros que avalia os níveis de prioridade entre as três camadas e aplica a regra de transparência (ignorando o índice de cor `0x00`).

**1.2. Não Funcionais:**

* **RNF01**: Descrição integral do coprocessador gráfico na linguagem de descrição de hardware Verilog.
* **RNF02**: Arquitetura modular garantindo isolamento entre o *datapath* (motores), unidade de controle e instâncias de memória.
* **RNF03**: Estruturação dos mapeamentos de registradores (MMIO) preparada para integração futura com uma CPU ARM rodando Linux e um jogo escrito em C.

## 2. Arquitetura Proposta e Justificativa

`aqui vem a descrição da nossa lógica + talvez um possível diagrama explicativo`

`explicar os estados da mef, a questão dos leds e mapeamento`

## 3. Software e Hardware usados para Prototipação

* **Plataforma Física:** Kit acadêmico Terasic DE1-SoC, FPGA Intel Cyclone V 5CSEMA5F31C6.
* **Módulos de Armazenamento:** Blocos dedicados de SRAM internos do chip (M10K).
* **Linguagem de Descrição de Hardware:** Verilog-2001;
* **Ferramentas de Síntese e Lógica:** Intel Quartus Prime Lite Edition para compilação, pinagem e mapeamento;
* **Interface Visual:** Monitor Philips com barramento analógico VGA padrão (640x480 @ 60Hz).
  
## 4. Demonstração e Testes de Funcionamento 

Como apresentado anteriormente, os leds [9:0] LEDR estão sendo utilizados para representar a visualização dos estados da FSM de controle. As chaves [9:0] SW são usadas para entradas de dados e os botões KEY0, KEY1, KEY2, KEY3, são utilizados para, respectivamente, resetar, avançar estado, confirmar entrada de dados, retornar estado.

### Motor de Background

* **Scroll**

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
  <img src="images/gif914.gif" alt="Prioridade de sprites sobre polígono" width="500">
  <br>
  <i>Gif 13: Sprites com prioridade sobre polígonos.</i>
</div>
<br>

<div align="center">
  <img src="images/placa914.jpg" alt="Motor de Polígonos, sobreposição sprites" width="500">
  <br>
  <i>Figura 13: Chaves da placa no motor de sprites para deslocamento.</i>
</div>
<br>

* **Deletando Polígonos do Monitor**

<div align="center">
  <img src="images/gif913.gif" alt="Deletar polígono" width="500">
  <br>
  <i>Gif 14: Polígonos sendo deletados.</i>
</div>
<br>

<div align="center">
  <img src="images/placa913.jpg" alt="Motor de Polígonos, deletar" width="500">
  <br>
  <i>Figura 14: Chaves da placa no motor de polígonos para deletar.</i>
</div>
<br>

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

## 6. Instalação e Configuração do Projeto 

### Pré-requisitos:

- Ter o software Quartus Prime (Standard ou Lite Edition) instalado;
- Driver USB-Blaster instalado e reconhecido pelo sistema operacional;
- Placa DE1-SoC conectada via cabo USB-Blaster e saída VGA conectada a um monitor.

### Passos:

1. Baixe o diretório do projeto e abra o arquivo `COPROCESSADORANW.qpf` no Quartus Prime.
2. Certifique-se de que os arquivos `.mif` (padrões gráficos e *tilemaps*) permanecem no mesmo diretório do projeto, pois são usados para a inicialização das memórias durante a síntese.
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
