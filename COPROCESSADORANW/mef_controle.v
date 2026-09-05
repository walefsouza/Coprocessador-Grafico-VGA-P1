module mef_controle (
    input             clk,
    input             reset,
    input      [9:0]  SW,                  // chaves da placa, uso muda conforme o estado atual
    input      [3:0]  KEY,                 // key1 avança estado, key2 confirma açao, key3 volta estado
    output     [9:0]  LEDR,                // mostra motor_atual e substado_atual

    input             vblank_start_pulse,  // pulso de 1 ciclo no inicio do vblank

    output reg        bg_we,               // habilita escrita no banco_background
    output reg [2:0]  bg_write_addr,       // indice do registrador do banco_background a escrever
    output reg [31:0] bg_write_data,       // valor a escrever no banco_background

    input      [31:0] bg_scroll_x_atual,   // scroll x atual, lido de volta do banco_background
    input      [31:0] bg_scroll_y_atual,   // scroll y atual, lido de volta do banco_background

    output reg        tilemap_we,          // habilita escrita direta na ram_tilemap
    output reg [10:0] tilemap_addr,        // posiçao do tilemap a escrever
    output reg [7:0]  tilemap_data,        // id do tile a gravar nessa posiçao

    output reg        spr_we,              // habilita escrita no banco_sprites
    output reg [4:0]  spr_write_addr,      // indice do sprite (0-31) a escrever
    output reg [31:0] spr_write_data,      // palavra completa do sprite a gravar
    output reg [4:0]  spr_read_addr,       // indice do sprite a ler (pra editar em cima do valor atual)
    input      [31:0] spr_read_data,       // palavra atual do sprite lido

    output reg        poly_we,             // habilita escrita no banco_poligonos
    output reg [2:0]  poly_write_addr,     // indice do poligono (0-7) a escrever
    output reg [31:0] poly_write_data,     // palavra completa do poligono a gravar
    output reg [2:0]  poly_read_addr,      // indice do poligono a ler
    input      [31:0] poly_read_data       // palavra atual do poligono lido
);

    // cada estado representa uma açao sobre um dos 3 motores (background, sprites, poligonos);
    // key1/key3 navegam nessa lista em sequencia, key2 confirma a açao do estado atual
    localparam MBG_SCROLL     = 4'd0;
    localparam MBG_PADRAO     = 4'd1;
    localparam MSP_SCROLL     = 4'd2;
    localparam MSP_PADRAO     = 4'd3;
    localparam MSP_ESPELHO    = 4'd4;
    localparam MSP_INSTANCIAR = 4'd5;
    localparam MSP_DELETAR    = 4'd6;
    localparam MPG_SCROLL     = 4'd7;
    localparam MPG_COR        = 4'd8;
    localparam MPG_ESPELHO    = 4'd9;
    localparam MPG_INSTANCIAR = 4'd10;
    localparam MPG_DELETAR    = 4'd11;

    reg [3:0] estado;

    // separa o estado (0-11) em motor (00=bg, 01=sprite, 10=poly) + substado dentro do motor,
    // so pra exibir no ledr de forma mais legivel que o numero do estado bruto
    reg [1:0] motor_atual;
    reg [2:0] substado_atual;

    always @(*) begin
        if (estado <= MBG_PADRAO) begin
            motor_atual    = 2'd0;
            substado_atual = estado[2:0];

        end else if (estado <= MSP_DELETAR) begin
            motor_atual    = 2'd1;
            substado_atual = estado - MSP_SCROLL;

        end else begin
            motor_atual    = 2'd2;
            substado_atual = estado - MPG_SCROLL;
        end
    end

    assign LEDR = {5'd0, substado_atual, motor_atual};

    // shift register de 3 bits em cada key: detecta transiçao 1->0 (borda de descida,
    // ja que as keys da placa sao ativas em nivel baixo) e filtra bounce mecanico
    reg [2:0] key1_sr;
    reg [2:0] key2_sr;
    reg [2:0] key3_sr;

    wire key1_pulso;
    wire key2_pulso;
    wire key3_pulso;

    always @(posedge clk) begin
        if (reset) begin
            key1_sr <= 3'b111;
            key2_sr <= 3'b111;
            key3_sr <= 3'b111;

        end else begin
            key1_sr <= {key1_sr[1:0], KEY[1]};
            key2_sr <= {key2_sr[1:0], KEY[2]};
            key3_sr <= {key3_sr[1:0], KEY[3]};
        end
    end

    // pulso de exatamente 1 ciclo no instante em que a key foi solta e voltou a subir
    assign key1_pulso = (key1_sr[2:1] == 2'b10);
    assign key2_pulso = (key2_sr[2:1] == 2'b10);
    assign key3_pulso = (key3_sr[2:1] == 2'b10);

    // key1 avança pro proximo estado, key3 volta pro anterior, com wraparound nas duas pontas
    // da lista de estados
    always @(posedge clk) begin
        if (reset) begin
            estado <= MBG_SCROLL;

        end else if (key1_pulso) begin
            estado <= (estado == MPG_DELETAR)
                    ? MBG_SCROLL
                    : estado + 4'd1;

        end else if (key3_pulso) begin
            estado <= (estado == MBG_SCROLL)
                    ? MPG_DELETAR
                    : estado - 4'd1;
        end
    end

    // nos estados de scroll, as mesmas 4 chaves (sw0-3) controlam ora o eixo x ora o eixo y;
    // esse flip-flop alterna entre os dois a cada vblank, entao segurar a chave move
    // o cenario na diagonal (um frame no x, um frame no y, alternadamente)
    reg toggle_eixo;

    always @(posedge clk) begin
        if (reset) begin
            toggle_eixo <= 1'b0;

        end else if (vblank_start_pulse) begin
            toggle_eixo <= ~toggle_eixo;
        end
    end

    always @(*) begin
        // valores padrao: nenhum write/read acontece a menos que o estado atual diga o contrario,
        // evita inferir latches e evita escrita acidental em outro motor
        bg_we         = 1'b0;
        bg_write_addr = 3'd0;
        bg_write_data = 32'd0;

        tilemap_we   = 1'b0;
        tilemap_addr = 11'd0;
        tilemap_data = 8'd0;

        spr_we         = 1'b0;
        spr_write_addr = 5'd0;
        spr_write_data = 32'd0;
        spr_read_addr  = 5'd0;

        poly_we         = 1'b0;
        poly_write_addr = 3'd0;
        poly_write_data = 32'd0;
        poly_read_addr  = 3'd0;

        case (estado)

            MBG_SCROLL: begin
                // scroll so anda 1 tile por frame (nao por ciclo de clock), senao seria rapido demais
                if (vblank_start_pulse) begin

                    if (!toggle_eixo) begin
                        // eixo x: sw0 incrementa, sw1 decrementa, mapa tem 40 colunas (0-39) entao
                        // o wrap acontece nas duas pontas
                        if (SW[0]) begin
                            bg_we         = 1'b1;
                            bg_write_addr = 3'd1;
                            bg_write_data = (bg_scroll_x_atual >= 32'd39)
                                          ? 32'd0
                                          : bg_scroll_x_atual + 32'd1;

                        end else if (SW[1]) begin
                            bg_we         = 1'b1;
                            bg_write_addr = 3'd1;
                            bg_write_data = (bg_scroll_x_atual == 32'd0)
                                          ? 32'd39
                                          : bg_scroll_x_atual - 32'd1;
                        end

                    end else begin
                        // eixo y: sw2 incrementa, sw3 decrementa, mapa tem 30 linhas (0-29)
                        if (SW[2]) begin
                            bg_we         = 1'b1;
                            bg_write_addr = 3'd2;
                            bg_write_data = (bg_scroll_y_atual >= 32'd29)
                                          ? 32'd0
                                          : bg_scroll_y_atual + 32'd1;

                        end else if (SW[3]) begin
                            bg_we         = 1'b1;
                            bg_write_addr = 3'd2;
                            bg_write_data = (bg_scroll_y_atual == 32'd0)
                                          ? 32'd29
                                          : bg_scroll_y_atual - 32'd1;
                        end
                    end
                end
            end

            MBG_PADRAO: begin
                // grava um tile_id direto numa posiçao do tilemap: sw9:5 escolhe a posiçao
                // (endereço linear no mapa), sw4:0 e o id do tile a colocar ali
                if (key2_pulso) begin
                    tilemap_we   = 1'b1;
                    tilemap_addr = {3'd0, SW[9:5]};
                    tilemap_data = {3'd0, SW[4:0]};
                end
            end

            MSP_SCROLL: begin
                // sw9:5 seleciona qual dos 32 sprites esta sendo editado; a leitura fica sempre
                // ativa nesse endereço pra spr_read_data estar disponivel quando for escrever
                spr_read_addr = SW[9:5];

                if (vblank_start_pulse) begin
                    if (SW[0] || SW[1] || SW[2] || SW[3]) begin

                        spr_we         = 1'b1;
                        spr_write_addr = SW[9:5];

                        // altera so os campos de posiçao x (sw0/sw1) e y (sw2/sw3). os outros campos (bits 31:24
                        // e 6:0, que guardam flags/padrao/espelho) sao copiados sem mudança
                        spr_write_data = {
                            spr_read_data[31:24],

                            SW[0]
                                ? spr_read_data[23:15] + 9'd1
                                : (SW[1]
                                    ? spr_read_data[23:15] - 9'd1
                                    : spr_read_data[23:15]),

                            SW[2]
                                ? spr_read_data[14:7] + 8'd1
                                : (SW[3]
                                    ? spr_read_data[14:7] - 8'd1
                                    : spr_read_data[14:7]),

                            spr_read_data[6:0]
                        };
                    end
                end
            end

            MSP_PADRAO: begin
                // troca o id do padrao grafico do sprite selecionado (sw4:0), mantendo
                // intacto o resto da palavra (flag ativo, posiçao, espelho)
                spr_read_addr = SW[9:5];

                if (key2_pulso) begin
                    spr_we         = 1'b1;
                    spr_write_addr = SW[9:5];

                    spr_write_data = {
                        spr_read_data[31],
                        SW[4:0],
                        spr_read_data[25:0]
                    };
                end
            end

            MSP_ESPELHO: begin
                // troca os bits de espelhamento horizontal (sw1) e vertical (sw0) do sprite,
                // mantendo o resto da palavra intacto
                spr_read_addr = SW[9:5];

                if (key2_pulso) begin
                    spr_we         = 1'b1;
                    spr_write_addr = SW[9:5];

                    spr_write_data = {
                        spr_read_data[31:26],
                        SW[1],
                        SW[0],
                        spr_read_data[23:0]
                    };
                end
            end

            MSP_INSTANCIAR: begin
                // cria um sprite novo na posiçao sw9:5 do banco, ativo (bit 31=1), com o
                // padrao escolhido em sw4:0 e posiçao/espelho zerados como ponto de partida
                if (key2_pulso) begin
                    spr_we         = 1'b1;
                    spr_write_addr = SW[9:5];

                    spr_write_data = {
                        1'b1,
                        SW[4:0],
                        1'b0,
                        1'b0,
                        9'd0,
                        8'd0,
                        7'd0
                    };
                end
            end

            MSP_DELETAR: begin
                // zera a palavra inteira do sprite sw9:5, o que derruba o bit ativo e
                // efetivamente remove ele da renderizaçao
                if (key2_pulso) begin
                    spr_we         = 1'b1;
                    spr_write_addr = SW[9:5];
                    spr_write_data = 32'd0;
                end
            end

            MPG_SCROLL: begin
                // sw9:7 seleciona qual dos 8 poligonos esta sendo editado
                poly_read_addr = SW[9:7];

                if (vblank_start_pulse) begin
                    if (SW[0] || SW[1] || SW[2] || SW[3]) begin

                        poly_we         = 1'b1;
                        poly_write_addr = SW[9:7];

                        // mesmo esquema do sprite: so os campos de posiçao x/y mudam,
                        // o resto da palavra (flags, cor, espelho) e preservado
                        poly_write_data = {
                            poly_read_data[31:18],

                            SW[0]
                                ? poly_read_data[17:9] + 9'd1
                                : (SW[1]
                                    ? poly_read_data[17:9] - 9'd1
                                    : poly_read_data[17:9]),

                            SW[2]
                                ? poly_read_data[8:0] + 9'd1
                                : (SW[3]
                                    ? poly_read_data[8:0] - 9'd1
                                    : poly_read_data[8:0])
                        };
                    end
                end
            end

            MPG_COR: begin
                // troca a cor do poligono selecionado (sw6:0), mantendo o bit de flag
                // logo abaixo (bit 20) fixo em 1 e o resto da palavra intacto
                poly_read_addr = SW[9:7];

                if (key2_pulso) begin
                    poly_we         = 1'b1;
                    poly_write_addr = SW[9:7];

                    poly_write_data = {
                        poly_read_data[31:28],
                        SW[6:0],
                        1'b1,
                        poly_read_data[19:0]
                    };
                end
            end

            MPG_ESPELHO: begin
                // troca os bits de espelhamento horizontal/vertical do poligono selecionado
                poly_read_addr = SW[9:7];

                if (key2_pulso) begin
                    poly_we         = 1'b1;
                    poly_write_addr = SW[9:7];

                    poly_write_data = {
                        poly_read_data[31:20],
                        SW[1],
                        SW[0],
                        poly_read_data[17:0]
                    };
                end
            end

            MPG_INSTANCIAR: begin
                // cria um poligono novo na posiçao sw9:7, ativo (bit 31=1), com o tipo/forma
                // em sw6:4, cor fixa de exemplo (8'b11100000) e posiçao inicial fixa no
                // centro da tela (x=160, y=119), sem espelho
                if (key2_pulso) begin
                    poly_we         = 1'b1;
                    poly_write_addr = SW[9:7];

                    poly_write_data = {
                        1'b1,
                        SW[6:4],
                        8'b11100000,
                        1'b0,
                        1'b0,
                        9'd160,
                        8'd119,
                        1'b0
                    };
                end
            end

            MPG_DELETAR: begin
                // zera a palavra inteira do poligono sw9:7, derrubando o bit ativo
                if (key2_pulso) begin
                    poly_we         = 1'b1;
                    poly_write_addr = SW[9:7];
                    poly_write_data = 32'd0;
                end
            end

            default: begin
            end

        endcase
    end

endmodule