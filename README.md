- - -

# Coprocessador Gráfico 2D em FPGA (DE1-SoC)

## Descrição do Projeto

Desenvolvimento do núcleo de um coprocessador gráfico em hardware (FPGA), inspirado na arquitetura de consoles clássicos de 16 bits. O hardware aplica os conceitos de *Datapath* e Controle para renderizar um plano de fundo baseado em tiles, uma camada de polígonos rasterizados e uma camada de sprites dinâmicos, culminando na geração contínua de um sinal de vídeo VGA.

`vamos colocar uma imagem do monitor/imagem da placa ou nenhuma`

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

## 3. Software e Hardware para Prototipação

* **Plataforma Física:** Kit acadêmico Terasic DE1-SoC, com no FPGA Intel Cyclone V.
* **Módulos de Armazenamento:** Blocos dedicados de SRAM internos do chip (M10K).
* **Ferramentas de Síntese e Lógica:** Intel Quartus Prime para roteamento, mapeamento de IP e descrição lógica do hardware em Verilog;
* **Interface Visual:** Monitor compatível com barramento analógico VGA padrão (640x480 @ 60Hz).
  
## 4. Testbenches e Testes de Funcionamento 

## 5. Análise de Recursos da Plataforma
## 6. Instalação e Configuração do Projeto 

`quando tivermos todos os arquivos, podemos fazer print a print`

1. Baixe o diretório do projeto e abra o arquivo descritor `.qpf` no software Quartus Prime.
2. Certifique-se de que os dados de carregamento inicial, contidos nos ficheiros `.mif` (padrões gráficos e *tilemaps*), permanecem no diretório central de execução.
3. As infraestruturas físicas de memória (RAMs e ROMs *Dual-Port* e buffers de matriz) já encontram-se instanciadas e estruturadas por meio da aba *IP Catalog*, evitando erros na remontagem de módulos periféricos.
4. Envie o projeto à síntese clicando em **Processing > Start Compilation**.
5. Conecte o cabo serial USB-Blaster e o pino VGA e utilize o **Programmer** para transferir o gerado `.sof` ao dispositivo físico.
