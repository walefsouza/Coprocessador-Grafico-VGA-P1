module frame_buffer (
    input wire clk,
    input wire wr_en,                // habilita escrita de um pixel
    input wire [9:0] wr_x,           // coluna do pixel a escrever
    input wire [8:0] wr_y,           // linha do pixel a escrever
    input wire [7:0] wr_color_index, // indice de cor (paleta) do pixel a escrever
    input wire [9:0] rd_x,           // coluna do pixel a ler (pra mandar pro VGA)
    input wire [8:0] rd_y,           // linha do pixel a ler (pra mandar pro VGA)
    output wire [7:0] rd_color_index, // indice de cor lido, sai pro resto do video
    input wire vblank_start_pulse,   // pulso de 1 ciclo no comeco do vertical blank, avisa fim do quadro
    output wire front_sel            // mostra qual pagina ta sendo exibida no momento (front)
);

    // calcula o endereco linear (y * 320 + x) sem usar multiplicador, so com shift:
    // y<<8 = y*256 e y<<6 = y*64, somando os dois da y*320 (320 = 256+64)
    // isso e o endereco dentro da RAM, tratando a tela como um vetor de 320x240
    wire [16:0] endereco_escrita = (wr_y << 8) + (wr_y << 6) + wr_x[8:0];
    wire [16:0] endereco_leitura = (rd_y << 8) + (rd_y << 6) + rd_x[8:0];

    // flag que diz qual das duas RAMs (a ou b) e a "pagina frontal" (a que ta sendo
    // exibida agora) - comeca em 0 direto no reg, esse modulo nao tem entrada de
    // reset, entao depende do valor inicial de fabrica/simulacao
    reg pagina_frontal = 1'b0;

    // double buffer (ping-pong): toda vez que comeca o vertical blank (fim do
    // quadro), inverte qual pagina e a frontal - assim troca o buffer que ta
    // sendo desenhado com o que ta sendo mostrado, sem dar tearing na tela
    always @(posedge clk) begin
        if (vblank_start_pulse)
            pagina_frontal <= ~pagina_frontal;
    end

    assign front_sel = pagina_frontal;

    // so deixa escrever se realmente ta dentro da resolucao logica (320x240),
    // pra nao mandar endereco fora da faixa pra RAM
    wire escrita_valida = wr_en && (wr_x < 10'd320) && (wr_y < 9'd240);

    // enquanto uma RAM ta sendo mostrada na tela (a "frontal"), a escrita vai
    // pra outra RAM (a "de tras"/back buffer) - por isso os enables sao opostos
    // um do outro, usando pagina_frontal e o inverso dela
    wire habilita_ram_a = escrita_valida & pagina_frontal;
    wire habilita_ram_b = escrita_valida & ~pagina_frontal;

    wire [7:0] dado_ram_a, dado_ram_b;

    // RAM A - dual port (porta de escrita e porta de leitura separadas, mas
    // no mesmo clock aqui - wrclock e rdclock sao os dois o clk)
    ram_framebufferi ram_a (
        .data(wr_color_index),
        .wraddress(endereco_escrita),
        .wren(habilita_ram_a),
        .wrclock(clk),
        .rdaddress(endereco_leitura),
        .rdclock(clk),
        .q(dado_ram_a)
    );

    // RAM B, mesma coisa que a RAM A, so que essa e a "outra" pagina
    ram_framebufferii ram_b (
        .data(wr_color_index),
        .wraddress(endereco_escrita),
        .wren(habilita_ram_b),
        .wrclock(clk),
        .rdaddress(endereco_leitura),
        .rdclock(clk),
        .q(dado_ram_b)
    );

    // as duas RAMs ficam sendo lidas o tempo todo (mesmo endereco_leitura pras
    // duas), so no final escolhe qual dado usar: se a pagina frontal e a A,
    // quem ta sendo desenhado (e deve ser lido pra exibir) e a B, e vice versa
    assign rd_color_index = pagina_frontal ? dado_ram_b : dado_ram_a;

endmodule