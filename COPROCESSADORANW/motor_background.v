module motor_background (
    input  wire        clk,
    input  wire        reset,

    input  wire [9:0]  logic_x,          // posiçao x do pixel atual
    input  wire [8:0]  logic_y,          // posiçao y do pixel atual

    input  wire [31:0] out_scroll_x,     // scroll horizontal do cenario
    input  wire [31:0] out_scroll_y,     // scroll vertical do cenario

    input  wire        cpu_we,           // habilita escrita no tilemap
    input  wire [10:0] cpu_addr,         // endereço de escrita no tilemap
    input  wire [7:0]  cpu_data,         // valor a escrever (id do tile)

    output wire [13:0] endereco_memoria_padroes  // endereço final na rom de padroes
);

    // descobre em qual tile do mapa o pixel atual cai (tile = 8x8, por isso >>3)
    wire [5:0] coluna_base = logic_x[8:3];
    wire [4:0] linha_base  = logic_y[7:3];

    // aplica o scroll (desloca a camera sobre o mapa)
    wire [6:0] soma_x = coluna_base + out_scroll_x[5:0];
    wire [5:0] soma_y = linha_base  + out_scroll_y[4:0];

    // wraparound: mapa tem 40x30 tiles, se passou do limite volta ao inicio
    wire [5:0] coluna = (soma_x >= 7'd40)
                      ? (soma_x - 7'd40)
                      : soma_x[5:0];
    wire [4:0] linha = (soma_y >= 6'd30)
                     ? (soma_y - 6'd30)
                     : soma_y[5:0];

    // posiçao do pixel dentro do tile, independe do scroll
    wire [2:0] px_in = logic_x[2:0];
    wire [2:0] py_in = logic_y[2:0];

    // endereco linear do tile no tilemap: linha*40 + coluna, via shifts (linha<<5 + linha<<3 = linha*40)
    wire [10:0] tilemap_addr = (linha << 5) + (linha << 3) + coluna;

    // busca qual tile esta armazenado nessa posiçao do mapa
    wire [7:0] tile_id;
    ram_tilemap ip_memoria_cenario (
        .data      (cpu_data),
        .wraddress (cpu_addr),
        .wren      (cpu_we),
        .wrclock   (clk),
        .rdaddress (tilemap_addr),
        .rdclock   (clk),
        .q         (tile_id)
    );

    // a ram tem 1 ciclo de atraso entre endereco e dado, entao px/py tambem
    // precisam ser atrasados 1 ciclo pra ficarem alinhados com tile_id
    reg [2:0] px_r;
    reg [2:0] py_r;
    always @(posedge clk) begin
        if (reset) begin
            px_r <= 3'd0;
            py_r <= 3'd0;
        end else begin
            px_r <= px_in;
            py_r <= py_in;
        end
    end

    // monta o endereco final na rom de padroes
    // tile_id escolhe o bloco de 64 bytes (8x8), py_r/px_r escolhem o pixel dentro dele
    assign endereco_memoria_padroes = {tile_id, py_r, px_r};

endmodule