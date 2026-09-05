// O banco de sprites e responsavel por guardar as informaçoes de cada sprite,
// usamos a seguinte codificaçao das informaçoes nos registradores de 32 bits:

// [31] ativo
// [30:26] indice do padrao (tile)
// [25] espelho horizontal
// [24] espelho vertical
// [23:15] posicao X (9 bits)
// [14:7] posicao Y (8 bits)
// [6:0] nao usado/reservado

// em resumo, temos 32 registradores de 32 bits, os pixels do desenho ficam na 
// rom separada deste modulo.

module banco_sprites (
    input clk,
    input reset,
    input we, 
    input [4:0] write_addr, // endreço do sprite que esta sendo escrito
    input [31:0] write_data, // dados dos sprites a serem enviados
    input [4:0] read_addr, // endereço do sprite a ser lido
    output [31:0] read_data, // realiza a leitura de um endereço de determinado sprite
    output [1023:0] read_data_all // realiza a leitura de todos os 32 sprites
);

    reg [31:0] registradores [0:31];
    integer i;

    always @(posedge clk) begin
	 
		  // reset sincrono, reseta todos os registradores de uma vez	
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registradores[i] <= 32'd0;
					 
		  // escreve em um unico registrador, os outros mantem seus dados
        end else if (we) begin
            registradores[write_addr] <= write_data;
        end
    end

    assign read_data = registradores[read_addr];

	 // contatena os 32 registradores em um unico barramento de 1024 bits
    assign read_data_all = {
        registradores[31], registradores[30], registradores[29], registradores[28],
        registradores[27], registradores[26], registradores[25], registradores[24],
        registradores[23], registradores[22], registradores[21], registradores[20],
        registradores[19], registradores[18], registradores[17], registradores[16],
        registradores[15], registradores[14], registradores[13], registradores[12],
        registradores[11], registradores[10], registradores[9],  registradores[8],
        registradores[7],  registradores[6],  registradores[5],  registradores[4],
        registradores[3],  registradores[2],  registradores[1],  registradores[0]
    };

endmodule