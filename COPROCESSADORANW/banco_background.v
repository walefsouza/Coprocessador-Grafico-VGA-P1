module banco_background (
    input clk,
    input reset,

    input        cpu_write_en,     // habilita escrita no banco
    input  [2:0] cpu_write_addr,   // indice do registrador a escrever
    input  [31:0] cpu_write_data,  // valor a escrever

    output [31:0] out_video_ctrl,  // controle de video (reg 0)
    output [31:0] out_scroll_x,    // scroll horizontal (reg 1)
    output [31:0] out_scroll_y     // scroll vertical (reg 2)
);

    // banco de 8 registradores de 32 bits, endereçavel pela cpu
    reg [31:0] reg_array [0:7];
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 8; i = i + 1) begin
                reg_array[i] <= 32'd0;
            end
        end else if (cpu_write_en) begin
            reg_array[cpu_write_addr] <= cpu_write_data;
        end
    end

    // leitura assincrona: cada saida aponta pra uma posiçao fixa do banco
    assign out_video_ctrl = reg_array[0];
    assign out_scroll_x   = reg_array[1];
    assign out_scroll_y   = reg_array[2];

endmodule