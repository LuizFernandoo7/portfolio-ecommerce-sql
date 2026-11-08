/* =====================================================================
   PROJETO 1 - RECEITA POR COORTE (LTV) | SQL Server (T-SQL)
   Arquivo : analise_ltv.sql
   Pré-requisito: ter executado o database_setup.sql

   Pergunta de negócio:
     "Quanto cada cliente, em média, já gerou de receita desde a sua
      primeira compra? E como esse valor acumulado evolui mês a mês em
      cada coorte?"

   Conceitos:
     - Coorte          = mês da PRIMEIRA compra do cliente (igual à análise de retenção).
     - Receita do mês  = soma do valor dos pedidos feitos naquele mês.
     - LTV acumulado   = receita acumulada da coorte até o mês N
                         dividida pelo TAMANHO da coorte (nº de clientes
                         que fizeram a 1ª compra naquele mês).
                         Ou seja: "receita média por cliente adquirido".
     - Regra de negócio: pedidos 'Cancelado' NÃO geram receita.

   Estrutura do arquivo:
     0) View-base  vw_pedidos_cohort   (centraliza a lógica de coorte)
     1) Receita por coorte e mês       (formato longo)
     2) LTV acumulado por coorte       (formato longo, com window function)
     3) Matriz de LTV acumulado        (triângulo, pronto para o README)
     4) Resumo executivo por coorte    (KPIs)
     5) Conferência (reconciliação)    (valida os números)
   ===================================================================== */

USE Portfolio_Ecommerce;
GO


/* ---------------------------------------------------------------------
   0) VIEW-BASE: um pedido por linha, já com a coorte e o índice do mês
   Construída em cima da vw_pedidos_valor (que já traz o valor_total).
   Assim, as consultas seguintes não repetem a lógica de coorte.
   (CREATE VIEW precisa ser o primeiro comando do lote -> por isso o GO.)
   --------------------------------------------------------------------- */
DROP VIEW IF EXISTS vw_pedidos_cohort;
GO

CREATE VIEW vw_pedidos_cohort AS
WITH pedidos_validos AS (
    SELECT
        id_pedido,
        id_cliente,
        -- Trunca a data para o 1º dia do mês
        DATEFROMPARTS(YEAR(data_pedido), MONTH(data_pedido), 1) AS mes_pedido,
        valor_total
    FROM vw_pedidos_valor
    WHERE status <> 'Cancelado'
),
coorte_cliente AS (
    SELECT id_cliente, MIN(mes_pedido) AS mes_coorte
    FROM pedidos_validos
    GROUP BY id_cliente
)
SELECT
    pv.id_pedido,
    pv.id_cliente,
    cc.mes_coorte,
    pv.mes_pedido,
    DATEDIFF(MONTH, cc.mes_coorte, pv.mes_pedido) AS indice_mes,
    pv.valor_total
FROM pedidos_validos pv
JOIN coorte_cliente cc ON cc.id_cliente = pv.id_cliente;
GO


/* ---------------------------------------------------------------------
   1) RECEITA POR COORTE E MÊS (formato longo)
   Mostra, para cada coorte, quanto foi faturado em cada mês de vida,
   quantos clientes compraram, quantos pedidos e o ticket médio.
   --------------------------------------------------------------------- */
SELECT
    FORMAT(mes_coorte, 'yyyy-MM')                          AS coorte,
    indice_mes,
    COUNT(DISTINCT id_cliente)                             AS clientes_ativos,
    COUNT(*)                                               AS pedidos,
    CAST(SUM(valor_total) AS DECIMAL(10,2))                AS receita_mes,
    CAST(SUM(valor_total) / COUNT(*) AS DECIMAL(10,2))     AS ticket_medio
FROM vw_pedidos_cohort
GROUP BY mes_coorte, indice_mes
ORDER BY mes_coorte, indice_mes;
GO


/* ---------------------------------------------------------------------
   2) LTV ACUMULADO POR COORTE (formato longo)

   Detalhe importante: há meses em que a coorte NÃO comprou nada (ex.: a
   coorte de fev. no mês 3). Esses meses não existem na tabela de pedidos,
   e um SUM() OVER direto "pularia" o mês. Por isso montamos antes uma
   GRADE (coorte x índice de mês) com todos os meses observáveis e fazemos
   LEFT JOIN com a receita, trocando NULL por 0 (ISNULL).

   "Observável" = o mês existe dentro da janela de dados (até o último mês
   com pedidos). Meses futuros ficam de fora (não viram 0 falso).
   --------------------------------------------------------------------- */
WITH tamanho_coorte AS (
    SELECT mes_coorte, COUNT(DISTINCT id_cliente) AS clientes_na_coorte
    FROM vw_pedidos_cohort
    GROUP BY mes_coorte
),
ultimo_mes AS (
    SELECT MAX(mes_pedido) AS mes_final FROM vw_pedidos_cohort
),
indices AS (                       -- números de 0 a 5 (6 meses de dados)
    SELECT n AS indice_mes FROM (VALUES (0),(1),(2),(3),(4),(5)) AS v(n)
),
grade AS (                         -- todas as combinações coorte x mês observável
    SELECT t.mes_coorte, t.clientes_na_coorte, i.indice_mes
    FROM tamanho_coorte t
    CROSS JOIN ultimo_mes u
    JOIN indices i
      ON i.indice_mes <= DATEDIFF(MONTH, t.mes_coorte, u.mes_final)
),
receita_mensal AS (
    SELECT mes_coorte, indice_mes, SUM(valor_total) AS receita_mes
    FROM vw_pedidos_cohort
    GROUP BY mes_coorte, indice_mes
)
SELECT
    FORMAT(g.mes_coorte, 'yyyy-MM')                        AS coorte,
    g.clientes_na_coorte,
    g.indice_mes,
    CAST(ISNULL(r.receita_mes, 0) AS DECIMAL(10,2))        AS receita_mes,
    -- Window function: soma acumulada da receita dentro de cada coorte
    CAST(SUM(ISNULL(r.receita_mes, 0)) OVER (
             PARTITION BY g.mes_coorte
             ORDER BY g.indice_mes
             ROWS UNBOUNDED PRECEDING) AS DECIMAL(10,2))   AS receita_acumulada,
    -- LTV = receita acumulada / clientes da coorte
    CAST(SUM(ISNULL(r.receita_mes, 0)) OVER (
             PARTITION BY g.mes_coorte
             ORDER BY g.indice_mes
             ROWS UNBOUNDED PRECEDING)
         / g.clientes_na_coorte AS DECIMAL(10,2))          AS ltv_acumulado
FROM grade g
LEFT JOIN receita_mensal r
       ON r.mes_coorte = g.mes_coorte
      AND r.indice_mes = g.indice_mes
ORDER BY g.mes_coorte, g.indice_mes;
GO


/* ---------------------------------------------------------------------
   3) MATRIZ DE LTV ACUMULADO (triângulo) - valores em R$ por cliente
   Mesma grade da consulta 2, agora pivotada com MAX(CASE ...).
   Como a grade só contém meses observáveis, os meses futuros ficam NULL
   automaticamente (diferente de R$ 0,00, que significa "não comprou").
   Leitura: o LTV nunca diminui ao longo da linha (é acumulado).
   --------------------------------------------------------------------- */
WITH tamanho_coorte AS (
    SELECT mes_coorte, COUNT(DISTINCT id_cliente) AS clientes_na_coorte
    FROM vw_pedidos_cohort
    GROUP BY mes_coorte
),
ultimo_mes AS (
    SELECT MAX(mes_pedido) AS mes_final FROM vw_pedidos_cohort
),
indices AS (
    SELECT n AS indice_mes FROM (VALUES (0),(1),(2),(3),(4),(5)) AS v(n)
),
grade AS (
    SELECT t.mes_coorte, t.clientes_na_coorte, i.indice_mes
    FROM tamanho_coorte t
    CROSS JOIN ultimo_mes u
    JOIN indices i
      ON i.indice_mes <= DATEDIFF(MONTH, t.mes_coorte, u.mes_final)
),
receita_mensal AS (
    SELECT mes_coorte, indice_mes, SUM(valor_total) AS receita_mes
    FROM vw_pedidos_cohort
    GROUP BY mes_coorte, indice_mes
),
ltv AS (
    SELECT
        g.mes_coorte,
        g.clientes_na_coorte,
        g.indice_mes,
        SUM(ISNULL(r.receita_mes, 0)) OVER (
            PARTITION BY g.mes_coorte
            ORDER BY g.indice_mes
            ROWS UNBOUNDED PRECEDING) / g.clientes_na_coorte AS ltv_acumulado
    FROM grade g
    LEFT JOIN receita_mensal r
           ON r.mes_coorte = g.mes_coorte
          AND r.indice_mes = g.indice_mes
)
SELECT
    FORMAT(mes_coorte, 'yyyy-MM')   AS coorte,
    clientes_na_coorte              AS clientes,
    CAST(MAX(CASE WHEN indice_mes = 0 THEN ltv_acumulado END) AS DECIMAL(10,2)) AS [Mes_0],
    CAST(MAX(CASE WHEN indice_mes = 1 THEN ltv_acumulado END) AS DECIMAL(10,2)) AS [Mes_1],
    CAST(MAX(CASE WHEN indice_mes = 2 THEN ltv_acumulado END) AS DECIMAL(10,2)) AS [Mes_2],
    CAST(MAX(CASE WHEN indice_mes = 3 THEN ltv_acumulado END) AS DECIMAL(10,2)) AS [Mes_3],
    CAST(MAX(CASE WHEN indice_mes = 4 THEN ltv_acumulado END) AS DECIMAL(10,2)) AS [Mes_4],
    CAST(MAX(CASE WHEN indice_mes = 5 THEN ltv_acumulado END) AS DECIMAL(10,2)) AS [Mes_5]
FROM ltv
GROUP BY mes_coorte, clientes_na_coorte
ORDER BY mes_coorte;
GO


/* ---------------------------------------------------------------------
   4) RESUMO EXECUTIVO POR COORTE (KPIs)
   - ltv_atual            : receita total da coorte / nº de clientes
   - pedidos_por_cliente  : frequência média de compra
   - pct_receita_recorrente: parcela da receita vinda de recompras
                            (indice_mes > 0), ou seja, fora do mês de aquisição
   Atenção ao comparar coortes: as mais antigas tiveram mais tempo para
   comprar, então o LTV atual favorece janeiro (viés de maturidade).
   --------------------------------------------------------------------- */
SELECT
    FORMAT(mes_coorte, 'yyyy-MM')                                   AS coorte,
    COUNT(DISTINCT id_cliente)                                      AS clientes,
    COUNT(*)                                                        AS pedidos,
    CAST(SUM(valor_total) AS DECIMAL(10,2))                         AS receita_total,
    CAST(SUM(valor_total) / COUNT(DISTINCT id_cliente)
         AS DECIMAL(10,2))                                          AS ltv_atual,
    CAST(1.0 * COUNT(*) / COUNT(DISTINCT id_cliente)
         AS DECIMAL(5,2))                                           AS pedidos_por_cliente,
    CAST(SUM(valor_total) / COUNT(*) AS DECIMAL(10,2))              AS ticket_medio,
    CAST(100.0 * SUM(CASE WHEN indice_mes > 0 THEN valor_total ELSE 0 END)
         / SUM(valor_total) AS DECIMAL(5,1))                        AS pct_receita_recorrente
FROM vw_pedidos_cohort
GROUP BY mes_coorte
ORDER BY mes_coorte;
GO


/* ---------------------------------------------------------------------
   5) CONFERÊNCIA (RECONCILIAÇÃO)
   Boa prática de analista: provar que a análise "fecha" com a fonte.
   A receita total da análise de coortes deve ser IGUAL à receita total
   dos pedidos não cancelados na view original. diferenca deve ser 0.
   --------------------------------------------------------------------- */
SELECT
    (SELECT CAST(SUM(valor_total) AS DECIMAL(10,2))
       FROM vw_pedidos_valor WHERE status <> 'Cancelado')   AS receita_fonte,
    (SELECT CAST(SUM(valor_total) AS DECIMAL(10,2))
       FROM vw_pedidos_cohort)                              AS receita_coortes,
    (SELECT CAST(SUM(valor_total) AS DECIMAL(10,2))
       FROM vw_pedidos_valor WHERE status <> 'Cancelado')
  - (SELECT CAST(SUM(valor_total) AS DECIMAL(10,2))
       FROM vw_pedidos_cohort)                              AS diferenca;
GO
