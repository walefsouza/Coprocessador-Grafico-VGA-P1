module motor_poligonos (
    input wire clk,
    input wire reset,
    input wire [9:0] logic_x,      // posicao x atual do pixel sendo desenhado (vem do vga_driver)
    input wire [8:0] logic_y,      // posicao y atual do pixel sendo desenhado (vem do vga_driver)
    input wire [255:0] poly_attr,  // os 8 poligonos concatenados, 32 bits cada (vem do banco_poligonos)
    output reg [7:0] poly_color_out // cor final que vai sair pra tela nesse pixel
);

    integer i;

    // variaveis temporarias, uma "fatia" de 32 bits desmembrada do poly_attr a cada
    // iteracao do loop (atributos do poligono atual sendo testado)
    reg p_enable;               // poligono ligado(1) ou desligado(0)
    reg [2:0] p_shape;          // qual forma (0=quadrado,1=retangulo,2=iso,3=equilatero,4=escaleno)
    reg [7:0] p_color;          // cor do poligono
    reg p_espelho_h, p_espelho_v; // espelhado na horizontal / vertical
    reg [8:0] p_base_x;         // posicao x de referencia (canto) do poligono na tela
    reg [7:0] p_base_y;         // posicao y de referencia (canto) do poligono na tela

    // layout dos 32 bits de cada poligono dentro do poly_attr (bit 31 e o mais alto):
    // [31]    p_enable
    // [30:28] p_shape (3 bits)
    // [27:20] p_color (8 bits)
    // [19]    p_espelho_h
    // [18]    p_espelho_v
    // [17:9]  p_base_x (9 bits)
    // [8:1]   p_base_y (8 bits)
    // [0]     nao usado (sobra 1 bit de padding)

    reg signed [11:0] lx, ly;         // posicao do pixel relativa ao poligono (ja subtraido o base_x/base_y)
    reg signed [11:0] lx_ef, ly_ef;   // mesma coisa só que depois de aplicar o espelhamento
    reg signed [7:0] largura, altura; // tamanho (bounding box) da forma atual

    // resultado do teste de cada forma, se o pixel cai dentro dela ou nao
    reg hit_quad, hit_rect, hit_iso, hit_equi, hit_esca;
    reg hit_final_i; // resultado do teste da forma que o poligono atual realmente e

    reg prioridade_valida;      // se algum poligono valido (ligado + hit) foi achado nessa rodada
    reg [7:0] prioridade_color; // cor do poligono que ganhou a prioridade

    // bloco combinacional que roda pra TODOS os 8 poligonos, pra cada pixel (logic_x, logic_y)
    // e decide qual cor pintar ali (ou nenhuma, se nao tiver poligono em cima do pixel)
    always @(*) begin
        prioridade_valida = 1'b0;
        prioridade_color  = 8'd0;

        // varre os 8 poligonos do banco, um por um
        for (i = 0; i < 8; i = i + 1) begin
            // pega a fatia de 32 bits do poligono i e separa nos campos
            p_enable    = poly_attr[i*32 + 31];
            p_shape     = poly_attr[i*32 + 30 -: 3];
            p_color     = poly_attr[i*32 + 27 -: 8];
            p_espelho_h = poly_attr[i*32 + 19];
            p_espelho_v = poly_attr[i*32 + 18];
            p_base_x    = poly_attr[i*32 + 17 -: 9];
            p_base_y    = poly_attr[i*32 + 8  -: 8];

            // subtrai a posicao base do poligono da posicao do pixel, pra "zerar" a
            // posicao - assim a formula de cada forma funciona igual não importa
            // onde o poligono esteja na tela (fica tudo relativo ao canto dele)
            lx = logic_x - p_base_x;
            ly = logic_y - p_base_y;

            // pega o tamanho (largura/altura) de acordo com a forma, pra saber o
            // limite/bounding box que a forma ocupa
            case (p_shape)
                3'd0: begin largura = 8'sd50;  altura = 8'sd50;  end  // quadrado 50x50
                3'd1: begin largura = 8'sd100; altura = 8'sd50;  end  // retangulo 100x50
                3'd2: begin largura = 8'sd100; altura = 8'sd100; end  // triangulo isosceles 100x100
                3'd3: begin largura = 8'sd100; altura = 8'sd86;  end  // triangulo equilatero 100x86
                3'd4: begin largura = 8'sd100; altura = 8'sd100; end  // triangulo escaleno 100x100
                default: begin largura = 8'sd100; altura = 8'sd100; end // shape invalido, usa 100x100
            endcase

            // espelha: inverte a leitura da coordenada dentro da forma sem mexer na
            // posicao base - se p_espelho_h ta ligado, ao inves de ler da esquerda
            // pra direita, le de tras pra frente (largura - 1 - lx), e o mesmo pra
            // vertical com a altura
            lx_ef = p_espelho_h ? (largura - 1 - lx) : lx;
            ly_ef = p_espelho_v ? (altura  - 1 - ly) : ly;

            // testa as retas/limites de cada forma, pra ver se o pixel (lx_ef, ly_ef)
            // cai dentro dela ou nao

            // quadrado: so bounding box 50x50
            hit_quad = (lx_ef >= 0 && lx_ef < 50 && ly_ef >= 0 && ly_ef < 50);

            // retangulo: bounding box 100x50
            hit_rect = (lx_ef >= 0 && lx_ef < 100 && ly_ef >= 0 && ly_ef < 50);

            // triangulo isosceles: dentro da faixa de altura (0-100) e dentro das
            // duas retas inclinadas dos lados (uma testa o lado esquerdo, outra o direito)
            hit_iso  = (ly_ef >= 0 && ly_ef < 100) &&
                       ((2 * lx_ef + ly_ef) >= 100) &&
                       ((2 * lx_ef - ly_ef) <= 100);

            // triangulo equilatero: mesma ideia do isosceles, so que com a inclinacao
            // certa pra dar 60 graus (172 e 8600 sao so os coeficientes multiplicados
            // pra nao precisar trabalhar com numero quebrado/fracao)
            hit_equi = (ly_ef >= 0 && ly_ef < 86) &&
                       ((172 * lx_ef + 100 * ly_ef) >= 8600) &&
                       ((172 * lx_ef - 100 * ly_ef) <= 8600);

            // triangulo escaleno: cada lado com uma inclinacao diferente (nao e
            // simetrico como o isosceles), por isso os coeficientes das duas retas
            // sao diferentes entre si (5 e 1 numa reta, 5 e 4 na outra)
            hit_esca = (ly_ef >= 0 && ly_ef < 100) &&
                       ((5 * lx_ef + ly_ef) >= 100) &&
                       ((5 * lx_ef - 4 * ly_ef) <= 100);

            // escolhe qual resultado de hit vale, de acordo com a forma configurada
            // nesse poligono (os outros hits calculados acima sao descartados)
            case (p_shape)
                3'd0: hit_final_i = hit_quad;
                3'd1: hit_final_i = hit_rect;
                3'd2: hit_final_i = hit_iso;
                3'd3: hit_final_i = hit_equi;
                3'd4: hit_final_i = hit_esca;
                default: hit_final_i = 1'b0;
            endcase

            // prioridade: se o poligono ta ligado e o pixel cai dentro dele, essa cor
            // "ganha" - como o for vai de 0 a 7 e aqui so sobrescreve, quem tiver
            // indice MAIOR (mais pra frente no banco) e o que fica valendo por ultimo,
            // entao poligono de indice mais alto pinta por cima dos de indice mais baixo
            if (p_enable && hit_final_i) begin
                prioridade_valida = 1'b1;
                prioridade_color  = p_color;
            end
        end
    end

    // primeiro estagio de pipeline: registra a cor decidida (ou 0 se nenhum poligono
    // bateu naquele pixel) - serve pra dar tempo do bloco combinacional grande (o for
    // dos 8 poligonos) acomodar antes de virar saida
    reg [7:0] poly_color_r1;

    always @(posedge clk) begin
        if (reset) begin
            poly_color_r1 <= 8'd0;
        end else begin
            if (prioridade_valida) begin
                poly_color_r1 <= prioridade_color;
            end else begin
                poly_color_r1 <= 8'd0; // nenhum poligono aqui, fundo/cor 0
            end
        end
    end

    // segundo estagio de pipeline: so passa a cor pra frente mais um ciclo de clock
    // (2 ciclos de atraso no total ate a cor sair em poly_color_out, pra casar com o
    // timing do resto do datapath de video)
    always @(posedge clk) begin
        if (reset) begin
            poly_color_out <= 8'd0;
        end else begin
            poly_color_out <= poly_color_r1;
        end
    end

endmodule