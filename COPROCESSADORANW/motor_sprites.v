// o motor e responsavel pela rendenizaçao de sprites por pixel
// para cada coordenada (logic_x, logic_y) da varredura do video,
// decide se algum dos 32 sprites do banco de registradores deve ser
// desenhado no pixel da varredura. 


module motor_sprites (
    input wire clk,
    input wire reset,
    input wire [9:0] logic_x, // coordenada x atual
    input wire [8:0] logic_y, // coordenada y atual
    input wire [1023:0] sprite_attr, // banco de registradores contatenado
    output reg [12:0] rom_addr1, // endereço da rom de padroes para o sprite prioritario
    input wire [7:0] rom_data1, // dado da rom de padroes para o sprite prioritario
    output reg [12:0] rom_addr2, // endereço da rom de padroes para o sprite secundario
    input wire [7:0] rom_data2, // dado da rom de padroes para o sprite secundario
    output reg [7:0] sprite_color_out // cor final do sprite naquele pixel
);

    integer i;

	 // informaçoes do sprite com maior prioridade 
    reg prioridade_valida;
    reg [3:0] prioridade_dx, prioridade_dy; // posiçao relativa
    reg prioridade_espelho_h, prioridade_espelho_v;
    reg [4:0] prioridade_padrao;

	 // informaçoes do sprite com segunda maior prioridade
    reg prioridade2_valida;
    reg [3:0] prioridade2_dx, prioridade2_dy; // posiçao relativa
    reg prioridade2_espelho_h, prioridade2_espelho_v;
    reg [4:0] prioridade2_padrao;

	 // dados do sprite a ser avaliado no "i" atual do laço for
    reg s_en;
    reg [8:0] s_x0;
    reg [7:0] s_y0;

	 // bloco que varre os 32 sprites e determina os dois candidatos prioritarios
    always @(*) begin
	 
		  // valor padrao zerado para caso nada seja encontrado
        prioridade_valida = 1'b0;
        prioridade_dx = 4'd0; prioridade_dy = 4'd0;
        prioridade_espelho_h = 1'b0; prioridade_espelho_v = 1'b0;
        prioridade_padrao = 5'd0;

        prioridade2_valida = 1'b0;
        prioridade2_dx = 4'd0; prioridade2_dy = 4'd0;
        prioridade2_espelho_h = 1'b0; prioridade2_espelho_v = 1'b0;
        prioridade2_padrao = 5'd0;

		  // percorre os 32 sprites de 0 a 31, sobrescrevendo o anterior caso um sprite
		  // com maior prioridade seja encontrado. temos a regra maior endereço = maior
		  // prioridade, isso garante a prioridade de ate 2 sprites no mesmo pixel.
        for (i = 0; i < 32; i = i + 1) begin
		  
				// tira o sprite do barramento contatenado
            s_en = sprite_attr[i*32 + 31];
            s_x0 = sprite_attr[i*32 + 23 -: 9];
            s_y0 = sprite_attr[i*32 + 14 -: 8];

				// se o sprite esta ativo e sua posiçao relativa esta dentro do quadrado 16x16
            if (s_en && (logic_x >= s_x0) && (logic_x < s_x0 + 10'd16) &&
                (logic_y >= s_y0) && (logic_y < s_y0 + 9'd16)) begin

					 // antes de sobrescrever, guarda o sprite como segundo na ordem de prioridade
                prioridade2_valida    = prioridade_valida;
                prioridade2_dx        = prioridade_dx;
                prioridade2_dy        = prioridade_dy;
                prioridade2_espelho_h = prioridade_espelho_h;
                prioridade2_espelho_v = prioridade_espelho_v;
                prioridade2_padrao    = prioridade_padrao;

					 // o sprite atual assume a prioridade
                prioridade_valida  = 1'b1;
                prioridade_dx = logic_x - s_x0;
                prioridade_dy = logic_y - s_y0;
                prioridade_espelho_h = sprite_attr[i*32 + 25];
                prioridade_espelho_v = sprite_attr[i*32 + 24];
                prioridade_padrao = sprite_attr[i*32 + 30 -: 5];
            end
        end
    end

	 // versoes atrasadas das flags de validade usadas para esperar o
	 // dado que vem da rom
    reg prioridade_valida_r, prioridade_valida_r2;
    reg prioridade2_valida_r, prioridade2_valida_r2;
	 
	 //registra o endereço da rom de cada um e começa a atrasar as flags
	 // de prioridade em cascata
    always @(posedge clk) begin
        if (reset) begin
            prioridade_valida_r   <= 1'b0; prioridade_valida_r2  <= 1'b0;
            prioridade2_valida_r  <= 1'b0; prioridade2_valida_r2 <= 1'b0;
            rom_addr1 <= 13'd0;
            rom_addr2 <= 13'd0;
        end else begin
            prioridade_valida_r   <= prioridade_valida;
            prioridade_valida_r2  <= prioridade_valida_r;
            prioridade2_valida_r  <= prioridade2_valida;
            prioridade2_valida_r2 <= prioridade2_valida_r;

            rom_addr1 <= {
                prioridade_padrao,
                prioridade_espelho_v ? ~prioridade_dy[3:0] : prioridade_dy[3:0],
                prioridade_espelho_h ? ~prioridade_dx[3:0] : prioridade_dx[3:0]
            };
            rom_addr2 <= {
                prioridade2_padrao,
                prioridade2_espelho_v ? ~prioridade2_dy[3:0] : prioridade2_dy[3:0],
                prioridade2_espelho_h ? ~prioridade2_dx[3:0] : prioridade2_dx[3:0]
            };
        end
    end

	 // quando os dados da rom chegam, a cor final do pixel e decidida e setada na saida
    always @(posedge clk) begin
        if (reset) begin
            sprite_color_out <= 8'd0;
        end else if (prioridade_valida_r2 && rom_data1 != 8'd0) begin
            sprite_color_out <= rom_data1;
        end else if (prioridade2_valida_r2 && rom_data2 != 8'd0) begin
            sprite_color_out <= rom_data2;
        end else begin
            sprite_color_out <= 8'd0;
        end
    end

endmodule