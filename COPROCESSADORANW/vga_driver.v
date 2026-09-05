module vga_driver(
    input clk,
    input reset,
    output VGA_HS,          // pulso de sincronismo horizontal (ativo em baixo)
    output VGA_VS,          // pulso de sincronismo vertical (ativo em baixo)
    output video_on,        // vai pra 1 quando o feixe ta dentro da area visivel (640x480)
    output VGA_BLANK_N,     // sinal de blank do conector VGA, segue o video_on
    output VGA_SYNC_N,      // sync composto, esse driver nao usa, fica fixo em 0
    output [9:0] x,             // posicao x logica do pixel (0 a 319, depois de dividir por 2)
    output [9:0] y,             // posicao y logica do pixel (0 a 239, depois de dividir por 2)
    output [9:0] pixel_x_raw,   // contador horizontal cru, sem dividir (0 a 799)
    output [9:0] pixel_y_raw    // contador vertical cru, sem dividir (0 a 524)
);

    // timing padrao de VGA 640x480 @60Hz
    localparam MAX_H = 800; // total de ciclos numa linha (visivel + front porch + sync + back porch)
    localparam MAX_V = 525; // total de linhas num quadro (visivel + front porch + sync + back porch)

    reg [9:0] h_counter; // contador horizontal, anda 1 por clock
    reg [9:0] v_counter; // contador vertical, anda 1 a cada linha que termina

    // esses dois contadores aqui sao os que varrem a tela inteira, pixel por pixel,
    // linha por linha, ate estourar o quadro e comecar tudo de novo
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            h_counter <= 10'd0;
            v_counter <= 10'd0;
        end else begin
            if (h_counter == MAX_H - 1) begin
                // acabou a linha, contador horizontal volta pro comeco
                h_counter <= 10'd0;

                if (v_counter == MAX_V - 1) begin
                    // acabou o quadro inteiro, contador vertical volta pro comeco tambem
                    v_counter <= 10'd0;
                end else begin
                    // fim de uma linha, passa pra proxima
                    v_counter <= v_counter + 10'd1;
                end
            end else begin
                // ainda no meio da linha, so incrementa o contador horizontal
                h_counter <= h_counter + 10'd1;
            end
        end
    end

    // faixa fixa do pulso de sincronismo horizontal
    // 656 a 751 (96 ciclos) = depois da area visivel (0-639) e do front porch (640-655)
    // fica em 0 (ativo em baixo) so durante esse intervalo, resto do tempo fica em 1
    assign VGA_HS = (h_counter >= 10'd656 && h_counter <= 10'd751) ? 1'b0 : 1'b1;

    // faixa fixa do pulso de sincronismo vertical
    // 490 a 491 (so 2 linhas) = depois da area visivel (0-479) e do front porch (480-489)
    assign VGA_VS = (v_counter >= 10'd490 && v_counter <= 10'd491) ? 1'b0 : 1'b1;

    // area visivel da imagem: linha 0-639 e coluna 0-479
    // fora dessa faixa e front porch, sync ou back porch, ou seja tela apagada/preta
    assign video_on = (h_counter <= 639 && v_counter <= 479) ? 1'b1 : 1'b0;

    assign VGA_BLANK_N = video_on; // blank do monitor segue direto o video_on
    assign VGA_SYNC_N = 1'b0;      // sync composto fixo em 0, nao usado nesse projeto

    // x/y = contador dividido por 2 (>>1), entao cada pixel logico vira um bloco de
    // 2x2 pixels reais na tela - resolucao logica fica 320x240 mesmo a tela sendo 640x480
    // fora da area visivel trava x e y em zero, pra nao vazar lixo de contagem
    // (front porch/sync/back porch) pro resto do circuito que desenha os poligonos
    assign x = (video_on) ? (h_counter >> 1) : 10'd0;
    assign y = (video_on) ? (v_counter >> 1) : 10'd0;

    // aqui sao os contadores crus, sem dividir por 2 e sem travar em zero fora da area
    // visivel - serve tipo de debug ou caso alguem precise da posicao real do feixe
    assign pixel_x_raw = h_counter;
    assign pixel_y_raw = v_counter;

    // - x e y sao combinacionais (assign), nao tem registrador, entao seguem o
    //   h_counter/v_counter no mesmo ciclo, sem atraso extra
    // - red/green/blue tao declarados como reg mas ninguem escreve neles aqui dentro,
    //   entao esse modulo so entrega o timing (HS, VS, blank, x, y) e nao a cor final
    // - VGA_SYNC_N fixo em 0 sugere que o projeto nao usa sync-on-green nem sync composto

endmodule