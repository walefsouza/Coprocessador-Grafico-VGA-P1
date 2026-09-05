module compositor (
    input [7:0] bg_index,      // indice de cor do fundo (background)
    input [7:0] poly_index,    // indice de cor vindo do motor de poligonos
    input [7:0] sprite_index,  // indice de cor vindo do sprite
    output reg [7:0] final_index // indice de cor final que vai pra tela
);

    // decide qual camada aparece em cada pixel, por prioridade:
    // sprite tem prioridade maior, depois poligono, depois o fundo
    // indice 0 e tratado como "transparente" (nao desenhado ali), por isso o
    // teste e != 8'd0 - se for 0 passa pra proxima camada
    always @(*) begin
        if (sprite_index != 8'd0)
            final_index = sprite_index;   // sprite presente, ele ganha
        else if (poly_index != 8'd0)
            final_index = poly_index;     // sem sprite, mas tem poligono, ele ganha
        else
            final_index = bg_index;       // sem sprite e sem poligono, mostra o fundo
    end
endmodule