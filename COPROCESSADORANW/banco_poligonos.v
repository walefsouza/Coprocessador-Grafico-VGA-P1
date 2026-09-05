module banco_poligonos (
    input clk,
    input reset,
    input we,                     // write enable, quando 1 habilita a escrita
    input [2:0] write_addr,       // endereco de escrita (0 a 7, um pra cada poligono)
    input [31:0] write_data,      // os 32 bits de atributo do poligono a escrever
    input [2:0] read_addr,        // endereco de leitura individual
    output [31:0] read_data,      // saida com o registrador lido (so 1 poligono)
    output [255:0] read_data_all  // saida com os 8 registradores juntos (8 x 32 = 256 bits)
);

    // banco com 8 registradores de 32 bits, cada um guarda os atributos de 1 poligono
    // (posicao, forma, cor, ligado/desligado, espelhado - ver motor_poligonos pro layout dos bits)
    reg [31:0] registradores [0:7];
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            // zera todos os 8 registradores no reset
            for (i = 0; i < 8; i = i + 1)
                registradores[i] <= 32'd0;
        end else if (we) begin
            // escreve so no registrador do endereco selecionado, os outros ficam intactos
            registradores[write_addr] <= write_data;
        end
    end

    // leitura combinacional (nao registrada) de 1 registrador, direto pelo read_addr
    assign read_data = registradores[read_addr];

    // leitura de todos os 8 registradores concatenados de uma vez, do indice 7 (mais
    // significativo, la em cima nos 256 bits) ate o indice 0 (menos significativo)
    // isso e o que alimenta o poly_attr la no motor_poligonos
    assign read_data_all = {
        registradores[7], registradores[6], registradores[5], registradores[4],
        registradores[3], registradores[2], registradores[1], registradores[0]
    };

endmodule