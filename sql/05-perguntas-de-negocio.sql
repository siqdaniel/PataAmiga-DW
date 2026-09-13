-- =====================================================================================
--  ARQUIVO 5:  AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 04-fato.sql
--
--  Cada pergunta e UMA consulta: um SELECT com JOIN e GROUP BY. A subconsulta
--  aparece na P2 e na P5, e serve para trazer o total da rede como denominador.
-- =====================================================================================

USE dw_pata_amiga;

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Media (AVG) dos quatro intervalos ja calculados na carga, agrupada por porte
--  de loja. AVG ignora NULL - por isso a etapa nao cumprida foi gravada como NULL.
--  dias_total_ate_entrega e o processo inteiro, nao um dos quatro intervalos.

-- >>> ESCREVA AQUI a consulta da P1
SELECT 
    dl.porte,
    ROUND(AVG(f.dias_integracao_separacao), 2) AS media_integracao_separacao,
    ROUND(AVG(f.dias_separacao_nota), 2)        AS media_separacao_nota,
    ROUND(AVG(f.dias_nota_despacho), 2)         AS media_nota_despacho,
    ROUND(AVG(f.dias_despacho_entrega), 2)      AS media_despacho_entrega,
    ROUND(AVG(f.dias_total_ate_entrega), 2)     AS media_ciclo_total
FROM fato_pedido f
JOIN dim_loja dl ON f.sk_loja = dl.sk_loja
WHERE f.sk_loja <> -1
GROUP BY dl.porte;

-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_categoria. Agrupe pelo nome_categoria
--  PADRONIZADO (nunca pela grafia crua). O percentual do total usa uma
--  subconsulta com o faturamento da rede como denominador.

-- >>> ESCREVA AQUI a consulta da P2

SELECT 
    dc.nome_categoria,
    SUM(f.vl_liquido) AS faturamento_total,
    ROUND((SUM(f.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido)) * 100, 2) AS pct_faturamento
FROM fato_pedido f
JOIN dim_categoria dc ON f.sk_categoria = dc.sk_categoria
GROUP BY dc.nome_categoria
ORDER BY faturamento_total DESC;
-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Aqui NAO ha JOIN: desconto e canal foram padronizados na carga e moram na
--  propria fato. Compare o TICKET MEDIO com e sem desconto DENTRO de cada canal.
--  Confira se o WhatsApp aparece - se nao, o CASE do arquivo 04 testou APP antes
--  de WHATS.

-- >>> ESCREVA AQUI a consulta da P3
SELECT 
    f.canal_pedido,
    f.houve_desconto,
    COUNT(f.numero_pedido) AS total_pedidos,
    ROUND(AVG(f.vl_liquido), 2) AS ticket_medio,
    SUM(f.vl_liquido) AS faturamento_total
FROM fato_pedido f
GROUP BY f.canal_pedido, f.houve_desconto
ORDER BY f.canal_pedido, f.houve_desconto;

-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_praca e a ponte.
--  Caminho: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a ponte
--  entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido, uma por
--  praca - isso esta certo. Multiplique por b.fator_publico para o faturamento
--  nao ser contado duas vezes.

-- >>> ESCREVA AQUI a consulta da P4
SELECT 
    dp.nome_praca,
    dp.regional,
    ROUND(SUM(f.vl_liquido * b.fator_publico), 2) AS faturamento_rateado
FROM fato_pedido f
JOIN dim_loja dl ON f.sk_loja = dl.sk_loja
JOIN bridge_loja_praca b ON dl.cod_loja = b.cod_loja
JOIN dim_praca dp ON b.sk_praca = dp.sk_praca
GROUP BY dp.sk_praca, dp.nome_praca, dp.regional
ORDER BY faturamento_rateado DESC;

-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  (a) Ranqueie as lojas por itens POR MIL HABITANTES (numerador na fato,
--      denominador na dimensao), calculado AQUI na consulta - nunca gravado
--      pronto. Cruze com o tempo medio de entrega.

SELECT 
    dl.nome_loja,
    SUM(f.qt_itens) AS total_itens,
    dl.populacao_cidade,
    ROUND((SUM(f.qt_itens) / dl.populacao_cidade) * 1000, 2) AS itens_por_mil_hab,
    ROUND(AVG(f.dias_total_ate_entrega), 2) AS media_dias_entrega
FROM fato_pedido f
JOIN dim_loja dl ON f.sk_loja = dl.sk_loja
WHERE f.sk_loja <> -1
GROUP BY dl.sk_loja, dl.nome_loja, dl.populacao_cidade
ORDER BY itens_por_mil_hab DESC;
--  (b) Mostre o faturamento por faixa de franquia e explique por que ele NAO
--      responde "quanto veio de lojas que JA ERAM Ouro na data do pedido": o
--      cadastro so tem a foto de hoje.

SELECT 
    dl.faixa_franquia,
    COUNT(DISTINCT dl.sk_loja) AS qtd_lojas,
    SUM(f.vl_liquido) AS faturamento_total
FROM fato_pedido f
JOIN dim_loja dl ON f.sk_loja = dl.sk_loja
WHERE f.sk_loja <> -1
GROUP BY dl.faixa_franquia
ORDER BY faturamento_total DESC;
--  (c) Meca o que ficou de fora: pedidos sem loja, entregas nao concluidas,
--      itens e valores em branco.

-- >>> ESCREVA AQUI as consultas da P5
SELECT 
    COUNT(CASE WHEN sk_loja = -1 THEN 1 END) AS pedidos_sem_loja,
    COUNT(CASE WHEN sk_tempo_entrega = -1 THEN 1 END) AS entregas_nao_concluidas,
    COUNT(CASE WHEN qt_itens IS NULL THEN 1 END) AS itens_em_branco,
    COUNT(CASE WHEN vl_liquido IS NULL THEN 1 END) AS valores_em_branco
FROM fato_pedido;