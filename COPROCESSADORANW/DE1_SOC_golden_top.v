`define ENABLE_CLOCK
`define ENABLE_KEY
`define ENABLE_SW
`define ENABLE_LEDR
`define ENABLE_VGA

module DE1_SOC_golden_top(

`ifdef ENABLE_CLOCK
    input CLOCK_50,
`endif

`ifdef ENABLE_KEY
    input [3:0] KEY,             // key0 = reset (ativo baixo), key1/key2/key3 usadas pela mef_controle
`endif

`ifdef ENABLE_SW
    input [9:0] SW,               // chaves, uso muda conforme o estado da mef_controle
`endif

`ifdef ENABLE_LEDR
    output [9:0] LEDR,            // reflete o estado atual da mef_controle
`endif

`ifdef ENABLE_VGA
    output [7:0] VGA_B,
    output VGA_BLANK_N,
    output VGA_CLK,
    output [7:0] VGA_G,
    output VGA_HS,
    output [7:0] VGA_R,
    output VGA_SYNC_N,
    output VGA_VS
`endif
);

    // divide o clock de 50MHz por 2, gerando o clock de pixel de 25MHz usado pelo VGA 640x480
    reg clk_25 = 1'b0;

    always @(posedge CLOCK_50)
        clk_25 <= ~clk_25;

    wire clk = clk_25;
    wire reset = ~KEY[0];

    assign VGA_CLK = clk_25;

    // gera a varredura VGA e as coordenadas logicas do pixel atual sendo desenhado
    wire video_on;
    wire vga_hs_raw, vga_vs_raw, vga_blank_n_raw, vga_sync_n_raw;
    wire [9:0] logic_x;
    wire [8:0] logic_y;
    wire [9:0] pixel_x_raw;
    wire [9:0] pixel_y_raw;

    vga_driver vga_d (
        .clk(clk),
        .reset(reset),
        .VGA_HS(vga_hs_raw),
        .VGA_VS(vga_vs_raw),
        .video_on(video_on),
        .VGA_BLANK_N(vga_blank_n_raw),
        .VGA_SYNC_N(vga_sync_n_raw),
        .x(logic_x),
        .y(logic_y),
        .pixel_x_raw(pixel_x_raw),
        .pixel_y_raw(pixel_y_raw)
    );

    // detecta a borda de subida do vblank (inicio da area de retraco vertical) e gera
    // um pulso de 1 ciclo; esse pulso e o sinal que sincroniza scroll, double buffer, etc
    reg vblank_d;

    always @(posedge clk)
        vblank_d <= (pixel_y_raw == 10'd480);

    wire vblank_start_pulse = (pixel_y_raw == 10'd480) && !vblank_d;

    // barramento entre a mef_controle e o banco_background
    wire        bg_we;
    wire [2:0]  bg_write_addr;
    wire [31:0] bg_write_data;
    wire [31:0] bg_scroll_x_atual, bg_scroll_y_atual;

    // barramento entre a mef_controle e a ram_tilemap (via motor_background)
    wire        tilemap_we;
    wire [10:0] tilemap_addr;
    wire [7:0]  tilemap_data;

    // barramento entre a mef_controle e o banco_sprites
    wire        spr_we;
    wire [4:0]  spr_write_addr;
    wire [31:0] spr_write_data;
    wire [4:0]  spr_read_addr;
    wire [31:0] spr_read_data;

    // barramento entre a mef_controle e o banco_poligonos
    wire        poly_we;
    wire [2:0]  poly_write_addr;
    wire [31:0] poly_write_data;
    wire [2:0]  poly_read_addr;
    wire [31:0] poly_read_data;

    wire [9:0]  leds_estado;

    // controla os 3 motores via SW/KEY, gerando os sinais de escrita/leitura
    mef_controle mf_controle (
        .clk(clk_25),
        .reset(reset),
        .SW(SW),
        .KEY(KEY),
        .LEDR(leds_estado),
        .vblank_start_pulse(vblank_start_pulse),
        .bg_we(bg_we),
        .bg_write_addr(bg_write_addr),
        .bg_write_data(bg_write_data),
        .bg_scroll_x_atual(bg_scroll_x_atual),
        .bg_scroll_y_atual(bg_scroll_y_atual),
        .tilemap_we(tilemap_we),
        .tilemap_addr(tilemap_addr),
        .tilemap_data(tilemap_data),
        .spr_we(spr_we),
        .spr_write_addr(spr_write_addr),
        .spr_write_data(spr_write_data),
        .spr_read_addr(spr_read_addr),
        .spr_read_data(spr_read_data),
        .poly_we(poly_we),
        .poly_write_addr(poly_write_addr),
        .poly_write_data(poly_write_data),
        .poly_read_addr(poly_read_addr),
        .poly_read_data(poly_read_data)
    );

    // guarda controle de video e scroll x/y do background; realimenta bg_scroll_x/y_atual
    // pra mef_controle poder incrementar/decrementar em cima do valor atual
    wire [31:0] out_video_ctrl, out_scroll_x, out_scroll_y;
    assign bg_scroll_x_atual = out_scroll_x;
    assign bg_scroll_y_atual = out_scroll_y;

    banco_background b_background (
        .clk(clk),
        .reset(reset),
        .cpu_write_en(bg_we),
        .cpu_write_addr(bg_write_addr),
        .cpu_write_data(bg_write_data),
        .out_video_ctrl(out_video_ctrl),
        .out_scroll_x(out_scroll_x),
        .out_scroll_y(out_scroll_y)
    );

    // guarda os atributos dos 32 sprites (posiçao, padrao, espelho, ativo);
    // sprite_attr concatena todos os sprites pro motor_sprites varrer de uma vez
    wire [1023:0] sprite_attr;

    banco_sprites b_sprites (
        .clk(clk),
        .reset(reset),
        .we(spr_we),
        .write_addr(spr_write_addr),
        .write_data(spr_write_data),
        .read_addr(spr_read_addr),
        .read_data(spr_read_data),
        .read_data_all(sprite_attr)
    );

    // guarda os atributos dos 8 poligonos (posiçao, cor, forma, espelho, ativo)
    wire [255:0] poly_attr;

    banco_poligonos b_poligonos (
        .clk(clk),
        .reset(reset),
        .we(poly_we),
        .write_addr(poly_write_addr),
        .write_data(poly_write_data),
        .read_addr(poly_read_addr),
        .read_data(poly_read_data),
        .read_data_all(poly_attr)
    );

    // calcula, pro pixel atual, qual endereço buscar na rom de padrões do background
    wire [10:0] endereco_padroes_bg;

    motor_background m_background (
        .clk(clk),
        .reset(reset),
        .logic_x(logic_x),
        .logic_y(logic_y),
        .out_scroll_x(out_scroll_x),
        .out_scroll_y(out_scroll_y),
        .cpu_we(tilemap_we),
        .cpu_addr(tilemap_addr),
        .cpu_data(tilemap_data),
        .endereco_memoria_padroes(endereco_padroes_bg)
    );

    // varre os 32 sprites e decide, pro pixel atual, qual cor de sprite (se houver)
    // deve aparecer ali; usa 2 portas de rom em paralelo (rom_addr1/2) pra dar conta
    // da varredura dentro de 1 pixel de tempo
    wire [12:0] rom_addr1_sprite, rom_addr2_sprite;
    wire [7:0]  rom_data1_sprite, rom_data2_sprite;
    wire [7:0]  sprite_color_out;

    motor_sprites m_sprites (
        .clk(clk),
        .reset(reset),
        .logic_x(logic_x),
        .logic_y(logic_y),
        .sprite_attr(sprite_attr),
        .rom_addr1(rom_addr1_sprite),
        .rom_data1(rom_data1_sprite),
        .rom_addr2(rom_addr2_sprite),
        .rom_data2(rom_data2_sprite),
        .sprite_color_out(sprite_color_out)
    );

    // rasteriza os poligonos e decide, pro pixel atual, qual cor de poligono (se houver)
    // deve aparecer ali (cor vem direto do banco, sem rom)
    wire [7:0] poly_color_out;

    motor_poligonos m_poligonos (
        .clk(clk),
        .reset(reset),
        .logic_x(logic_x),
        .logic_y(logic_y),
        .poly_attr(poly_attr),
        .poly_color_out(poly_color_out)
    );

    // rom com os padroes graficos (tiles 8x8 e sprites 16x16); bg le por 1 porta,
    // sprites leem por 2 portas em paralelo pra varredura simultanea
    wire [7:0] bg_index_raw;

    rom_tiles r_padroes_tiles (
        .address(endereco_padroes_bg),
        .clock(clk),
        .q(bg_index_raw)
    );

    rom_padroes r_padroes_sprites (
        .address_a({1'b0, rom_addr1_sprite}),
        .address_b({1'b0, rom_addr2_sprite}),
        .clock_a(clk),
        .clock_b(clk),
        .q_a(rom_data1_sprite),
        .q_b(rom_data2_sprite)
    );

    // atrasa 1 ciclo o indice de cor do bg e do poligono, pra alinhar com a latencia
    // de leitura da rom_tiles
    // sprite_color_out ja sai pronto do motor_sprites, sem precisar desse atraso extra
    reg [7:0] bg_index_d;
    reg [7:0] poly_index_d;

    always @(posedge clk) begin
        if (reset) begin
            bg_index_d <= 8'd0;
            poly_index_d <= 8'd0;
        end else begin
            bg_index_d <= bg_index_raw;
            poly_index_d <= poly_color_out;
        end
    end

    // decide a prioridade final entre as 3 camadas (bg/poly/sprite) pra cada pixel,
    // resultando num unico indice de cor de 8 bits
    wire [7:0] final_index;

    compositor u_compositor (
        .bg_index(bg_index_d),
        .poly_index(poly_index_d),
        .sprite_index(sprite_color_out),
        .final_index(final_index)
    );

    // atrasa logic_x/y em 3 ciclos pra acompanhar a latencia acumulada do pipeline
    // (tilemap + rom + compositor), garantindo que o pixel escrito no frame buffer
    // corresponda a posiçao correta na tela
    reg [9:0] x_pipe1, x_pipe2, x_pipe3;
    reg [8:0] y_pipe1, y_pipe2, y_pipe3;

    always @(posedge clk) begin
        if (reset) begin
            x_pipe1 <= 10'd0;
            x_pipe2 <= 10'd0;
            x_pipe3 <= 10'd0;
            y_pipe1 <= 9'd0;
            y_pipe2 <= 9'd0;
            y_pipe3 <= 9'd0;
        end else begin
            x_pipe1 <= logic_x;
            y_pipe1 <= logic_y;
            x_pipe2 <= x_pipe1;
            y_pipe2 <= y_pipe1;
            x_pipe3 <= x_pipe2;
            y_pipe3 <= y_pipe2;
        end
    end

    wire [9:0] wr_x = x_pipe3;
    wire [8:0] wr_y = y_pipe3;

    // grava o pixel ja composto (final_index) na posiçao correta, e ao mesmo tempo
    // le o pixel que vai pra tela agora, de um buffer diferente
    wire [7:0] color_index_final;
    wire front_sel;

    frame_buffer f_buffer (
        .clk(clk),
        .wr_en(1'b1),
        .wr_x(wr_x),
        .wr_y(wr_y),
        .wr_color_index(final_index),
        .rd_x(logic_x),
        .rd_y(logic_y),
        .rd_color_index(color_index_final),
        .vblank_start_pulse(vblank_start_pulse),
        .front_sel(front_sel)
    );

    assign LEDR = leds_estado;

    // atrasa os sinais de sincronismo VGA em 1 ciclo pra alinhar com o pipeline de cor
    reg vga_hs_d, vga_vs_d, vga_blank_n_d, vga_sync_n_d, video_on_d;

    always @(posedge clk) begin
        if (reset) begin
            vga_hs_d <= 1'b1;
            vga_vs_d <= 1'b1;
            vga_blank_n_d <= 1'b0;
            vga_sync_n_d <= 1'b0;
            video_on_d <= 1'b0;
        end else begin
            vga_hs_d <= vga_hs_raw;
            vga_vs_d <= vga_vs_raw;
            vga_blank_n_d <= vga_blank_n_raw;
            vga_sync_n_d <= vga_sync_n_raw;
            video_on_d <= video_on;
        end
    end

    assign VGA_HS = vga_hs_d;
    assign VGA_VS = vga_vs_d;
    assign VGA_BLANK_N = vga_blank_n_d;
    assign VGA_SYNC_N = vga_sync_n_d;

    // converte o indice de cor de 8 bits em rgb: 3 bits pro vermelho, 3 pro verde,
    // 2 pro azul (formato 3-3-2), zerado fora da area visivel
    assign VGA_R = (video_on_d && vga_blank_n_d) ? {color_index_final[7:5], 5'd0} : 8'd0;
    assign VGA_G = (video_on_d && vga_blank_n_d) ? {color_index_final[4:2], 5'd0} : 8'd0;
    assign VGA_B = (video_on_d && vga_blank_n_d) ? {color_index_final[1:0], 6'd0} : 8'd0;

endmodule