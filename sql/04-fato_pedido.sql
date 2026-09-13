-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  UMA fato, UM unico INSERT ... SELECT. A tabela ja existe, vazia (arquivo 02).
--  4.044 linhas = 4.044 pedidos.
--
--  Regra geral: a limpeza dos dados fica nas dimensoes; a fato apenas procura a
--  linha correta (por JOIN). Nenhuma FK fica nula: quando o dado falta, ela
--  aponta para a linha -1 (CASE WHEN ... IS NULL THEN -1).
--
--  Sugestao: comece pelo esqueleto (numero_pedido + as duas FKs de tempo +
--  FROM), rode e confira 4.044 linhas; depois acrescente as colunas aos poucos.
-- =====================================================================================

USE dw_pata_amiga;

INSERT INTO fato_pedido (
    numero_pedido,
    sk_tempo_pedido,
    sk_tempo_entrega,
    sk_loja,
    sk_categoria,
    houve_desconto,
    canal_pedido,
    dt_pedido,
    qt_itens,
    vl_liquido,
    dias_integracao_separacao,
    dias_separacao_nota,
    dias_nota_despacho,
    dias_despacho_entrega,
    dias_total_ate_entrega
)
SELECT 
    -- 1. Código do pedido
    p.`NumeroPedido` AS numero_pedido,

    -- 2. FK Tempo Pedido (Formato AAAAMMDD via máscara AMERICANA)
    CAST(DATE_FORMAT(
        CASE 
            WHEN p.`DtHoraPedido` IS NOT NULL AND TRIM(p.`DtHoraPedido`) != '' 
            THEN STR_TO_DATE(p.`DtHoraPedido`, '%m/%d/%Y %h:%i %p') 
            ELSE NULL 
        END, '%Y%m%d') AS SIGNED) AS sk_tempo_pedido,

    -- 3. FK Tempo Entrega (-1 se a data de entrega estiver em branco)
    COALESCE(
        CAST(DATE_FORMAT(
            CASE 
                WHEN p.`DtEntregaCliente` IS NOT NULL AND TRIM(p.`DtEntregaCliente`) != '' 
                THEN STR_TO_DATE(p.`DtEntregaCliente`, '%Y-%m-%d') 
                ELSE NULL 
            END, '%Y%m%d') AS SIGNED), 
        -1
    ) AS sk_tempo_entrega,

    -- 4. FK Loja (Caso não encontre par no LEFT JOIN, assume -1)
    COALESCE(dl.sk_loja, -1) AS sk_loja,

    -- 5. FK Categoria (Caso não encontre par no LEFT JOIN, assume -1)
    COALESCE(dc.sk_categoria, -1) AS sk_categoria,

    -- 6. houve_desconto (Padronização de domínio)
    CASE 
        WHEN UPPER(TRIM(p.`HouveDesconto`)) IN ('SIM', 'S', 'TRUE', '1') THEN 'Sim'
        WHEN UPPER(TRIM(p.`HouveDesconto`)) IN ('NAO', 'NÃO', 'N', 'FALSE', '0') THEN 'Nao'
        ELSE 'Nao Informado'
    END AS houve_desconto,

    -- 7. canal_pedido (Padronização com ordem de precedência: WHATS antes de APP)
    CASE 
        WHEN UPPER(p.`CanalPedido`) LIKE '%WHATS%' THEN 'WhatsApp'
        WHEN UPPER(p.`CanalPedido`) LIKE '%APP%' THEN 'App'
        WHEN UPPER(p.`CanalPedido`) LIKE '%SITE%' OR UPPER(p.`CanalPedido`) LIKE '%WEB%' THEN 'Site'
        WHEN UPPER(p.`CanalPedido`) LIKE '%FÍSICA%' OR UPPER(p.`CanalPedido`) LIKE '%FISICA%' OR UPPER(p.`CanalPedido`) LIKE '%LOJA%' THEN 'Loja Fisica'
        WHEN UPPER(p.`CanalPedido`) LIKE '%TELEFONE%' OR UPPER(p.`CanalPedido`) LIKE '%TEL%' THEN 'Telefone'
        ELSE 'Nao Informado'
    END AS canal_pedido,

    -- 8. Data e Hora original convertida para DATETIME
    CASE 
        WHEN p.`DtHoraPedido` IS NOT NULL AND TRIM(p.`DtHoraPedido`) != '' 
        THEN STR_TO_DATE(p.`DtHoraPedido`, '%m/%d/%Y %h:%i %p') 
        ELSE NULL 
    END AS dt_pedido,

    -- 9. Quantidade de Itens (Limpeza de caracteres nulos/vazios)
    CASE 
        WHEN p.`QTD.Itens` IN ('', '-', 'NULL') OR p.`QTD.Itens` IS NULL THEN NULL
        ELSE CAST(p.`QTD.Itens` AS SIGNED)
    END AS qt_itens,

    -- 10. Valor Líquido (Tratamento de 'R$', pontos de milhar e vírgula decimal)
    CASE 
        WHEN p.`ValorLiquidoPedido(R$)` IN ('', '-', 'NULL') OR p.`ValorLiquidoPedido(R$)` IS NULL THEN NULL
        ELSE CAST(
            REPLACE(
                REPLACE(
                    REPLACE(p.`ValorLiquidoPedido(R$)`, 'R$', ''), 
                '.', ''), 
            ',', '.') AS DECIMAL(15,2)
        )
    END AS vl_liquido,

    -- 11. Lags em dias (DATEDIFF). Protegidos contra strings vazias para evitar Warning 1411.
    DATEDIFF(
        CASE WHEN p.`Dt Separacao Estoque` IS NOT NULL AND TRIM(p.`Dt Separacao Estoque`) != '' THEN STR_TO_DATE(p.`Dt Separacao Estoque`, '%Y-%m-%d') END,
        DATE(CASE WHEN p.`DtHoraPedido` IS NOT NULL AND TRIM(p.`DtHoraPedido`) != '' THEN STR_TO_DATE(p.`DtHoraPedido`, '%m/%d/%Y %h:%i %p') END)
    ) AS dias_integracao_separacao,

    DATEDIFF(
        CASE WHEN p.`DtNotaFiscal` IS NOT NULL AND TRIM(p.`DtNotaFiscal`) != '' THEN STR_TO_DATE(p.`DtNotaFiscal`, '%Y-%m-%d') END,
        CASE WHEN p.`Dt Separacao Estoque` IS NOT NULL AND TRIM(p.`Dt Separacao Estoque`) != '' THEN STR_TO_DATE(p.`Dt Separacao Estoque`, '%Y-%m-%d') END
    ) AS dias_separacao_nota,

    DATEDIFF(
        CASE WHEN p.`Dt_Despacho_Transportadora` IS NOT NULL AND TRIM(p.`Dt_Despacho_Transportadora`) != '' THEN STR_TO_DATE(p.`Dt_Despacho_Transportadora`, '%Y-%m-%d') END,
        CASE WHEN p.`DtNotaFiscal` IS NOT NULL AND TRIM(p.`DtNotaFiscal`) != '' THEN STR_TO_DATE(p.`DtNotaFiscal`, '%Y-%m-%d') END
    ) AS dias_nota_despacho,

    DATEDIFF(
        CASE WHEN p.`DtEntregaCliente` IS NOT NULL AND TRIM(p.`DtEntregaCliente`) != '' THEN STR_TO_DATE(p.`DtEntregaCliente`, '%Y-%m-%d') END,
        CASE WHEN p.`Dt_Despacho_Transportadora` IS NOT NULL AND TRIM(p.`Dt_Despacho_Transportadora`) != '' THEN STR_TO_DATE(p.`Dt_Despacho_Transportadora`, '%Y-%m-%d') END
    ) AS dias_despacho_entrega,

    DATEDIFF(
        CASE WHEN p.`DtEntregaCliente` IS NOT NULL AND TRIM(p.`DtEntregaCliente`) != '' THEN STR_TO_DATE(p.`DtEntregaCliente`, '%Y-%m-%d') END,
        DATE(CASE WHEN p.`DtHoraPedido` IS NOT NULL AND TRIM(p.`DtHoraPedido`) != '' THEN STR_TO_DATE(p.`DtHoraPedido`, '%m/%d/%Y %h:%i %p') END)
    ) AS dias_total_ate_entrega

FROM stg_pedido p
-- JOIN com dim_loja alinhado com a padronização oficial da dimensão
LEFT JOIN dim_loja dl 
    ON dl.nome_loja = CASE 
        WHEN REPLACE(REPLACE(TRIM(p.`Loja-Nome`), '/SC', ''), '  ', ' ') IN ('Pata Amiga Jgua do Sul', 'Jaraguá do Sul') 
            THEN 'Pata Amiga Jaragua do Sul'
        WHEN REPLACE(REPLACE(TRIM(p.`Loja-Nome`), '/SC', ''), '  ', ' ') IN ('Pata Amiga Blumenal Centro', 'Blumenau Shopping', 'Filial Blumenau') 
            THEN 'Pata Amiga Blumenau Centro'
        WHEN REPLACE(REPLACE(TRIM(p.`Loja-Nome`), '/SC', ''), '  ', ' ') IN ('Pata Amiga Floripa Norte', 'Floripa Norte') 
            THEN 'Pata Amiga Florianopolis Norte'
        WHEN REPLACE(REPLACE(TRIM(p.`Loja-Nome`), '/SC', ''), '  ', ' ') IN ('Matriz Central', 'Loja Matriz', 'Centro SC') 
            THEN 'Matriz - Centro'
        WHEN REPLACE(REPLACE(TRIM(p.`Loja-Nome`), '/SC', ''), '  ', ' ') IN ('Filial Timbó', 'Timbo') 
            THEN 'Filial Timbó'
        ELSE REPLACE(REPLACE(TRIM(p.`Loja-Nome`), '/SC', ''), '  ', ' ')
    END

-- JOIN com dim_categoria (1 para 1 pela categoria de origem)
LEFT JOIN dim_categoria dc 
    ON dc.categoria_origem = p.`CategoriaProduto`;

SHOW WARNINGS;