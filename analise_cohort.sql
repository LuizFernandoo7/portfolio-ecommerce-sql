/* =====================================================================
   PROJETO 1 - ANÁLISE DE RETENÇÃO (COHORT) | SQL Server (T-SQL)
   Arquivo : analise_cohort.sql
   Pré-requisito: ter executado o database_setup.sql

   Pergunta de negócio:
     "De cada grupo de clientes que fez a 1ª compra em um determinado mês,
      qual % volta a comprar 1, 2, 3... meses depois?"

   Conceitos:
     - Coorte        = mês da PRIMEIRA compra do cliente.
     - Índice do mês = quantos meses se passaram desde a 1ª compra
                       (0 = o próprio mês da 1ª compra, 1 = mês seguinte...).
     - Retenção      = clientes ativos no índice N / tamanho da coorte.
   ===================================================================== */

USE Portfolio_Ecommerce;
GO


/* ---------------------------------------------------------------------
   PASSO 1 - Coorte de cada cliente (mês da primeira compra)
   Regras de negócio: pedidos 'Cancelado' NÃO contam como compra.
   DATEFROMPARTS(ano, mês, 1) "trunca" a data para o 1º dia do mês,
   facilitando agrupar e comparar meses.
   --------------------------------------------------------------------- */
WITH pedidos_validos AS (
    SELECT
        id_cliente,
        DATEFROMPARTS(YEAR(data_pedido), MONTH(data_pedido), 1) AS mes_pedido
    FROM Pedidos
    WHERE status <> 'Cancelado'
)
SELECT
    id_cliente,
    MIN(mes_pedido) AS mes_coorte
FROM pedidos_validos
GROUP BY id_cliente
ORDER BY mes_coorte, id_cliente;
GO


/* ---------------------------------------------------------------------
   PASSO 2 - Atividade mensal de cada cliente em relação à sua coorte
   DATEDIFF(MONTH, início, fim) retorna a diferença em meses de calendário.
   O DISTINCT garante que um cliente com 2 pedidos no mesmo mês conte
   apenas uma vez naquele mês.
   --------------------------------------------------------------------- */
WITH pedidos_validos AS (
    SELECT
        id_cliente,
        DATEFROMPARTS(YEAR(data_pedido), MONTH(data_pedido), 1) AS mes_pedido
    FROM Pedidos
    WHERE status <> 'Cancelado'
),
coorte_cliente AS (
    SELECT id_cliente, MIN(mes_pedido) AS mes_coorte
    FROM pedidos_validos
    GROUP BY id_cliente
)
SELECT DISTINCT
    pv.id_cliente,
    cc.mes_coorte,
    DATEDIFF(MONTH, cc.mes_coorte, pv.mes_pedido) AS indice_mes
FROM pedidos_validos pv
JOIN coorte_cliente cc ON cc.id_cliente = pv.id_cliente
ORDER BY pv.id_cliente, indice_mes;
GO


/* ---------------------------------------------------------------------
   PASSO 3 - Retenção em formato "longo" (uma linha por coorte x mês)
   Bom para alimentar ferramentas de BI (Power BI, Tableau etc.).
   --------------------------------------------------------------------- */
WITH pedidos_validos AS (
    SELECT
        id_cliente,
        DATEFROMPARTS(YEAR(data_pedido), MONTH(data_pedido), 1) AS mes_pedido
    FROM Pedidos
    WHERE status <> 'Cancelado'
),
coorte_cliente AS (
    SELECT id_cliente, MIN(mes_pedido) AS mes_coorte
    FROM pedidos_validos
    GROUP BY id_cliente
),
atividade AS (
    SELECT DISTINCT
        pv.id_cliente,
        cc.mes_coorte,
        DATEDIFF(MONTH, cc.mes_coorte, pv.mes_pedido) AS indice_mes
    FROM pedidos_validos pv
    JOIN coorte_cliente cc ON cc.id_cliente = pv.id_cliente
),
tamanho_coorte AS (
    SELECT mes_coorte, COUNT(*) AS clientes_na_coorte
    FROM coorte_cliente
    GROUP BY mes_coorte
)
SELECT
    FORMAT(a.mes_coorte, 'yyyy-MM')                     AS coorte,
    t.clientes_na_coorte,
    a.indice_mes,
    COUNT(DISTINCT a.id_cliente)                        AS clientes_ativos,
    CAST(100.0 * COUNT(DISTINCT a.id_cliente)
         / t.clientes_na_coorte AS DECIMAL(5,1))        AS pct_retencao
FROM atividade a
JOIN tamanho_coorte t ON t.mes_coorte = a.mes_coorte
GROUP BY a.mes_coorte, t.clientes_na_coorte, a.indice_mes
ORDER BY a.mes_coorte, a.indice_mes;
GO


/* ---------------------------------------------------------------------
   PASSO 4 - MATRIZ DE RETENÇÃO FINAL (formato "triângulo" clássico)
   Usa agregação condicional (SUM + CASE) para transformar os índices
   de mês em colunas. Células NULL = período ainda não observável
   (ex.: a coorte de junho não tem "mês 1", pois a base termina em junho).
   --------------------------------------------------------------------- */
WITH pedidos_validos AS (
    SELECT
        id_cliente,
        DATEFROMPARTS(YEAR(data_pedido), MONTH(data_pedido), 1) AS mes_pedido
    FROM Pedidos
    WHERE status <> 'Cancelado'
),
coorte_cliente AS (
    SELECT id_cliente, MIN(mes_pedido) AS mes_coorte
    FROM pedidos_validos
    GROUP BY id_cliente
),
atividade AS (
    SELECT DISTINCT
        pv.id_cliente,
        cc.mes_coorte,
        DATEDIFF(MONTH, cc.mes_coorte, pv.mes_pedido) AS indice_mes
    FROM pedidos_validos pv
    JOIN coorte_cliente cc ON cc.id_cliente = pv.id_cliente
),
contagem AS (
    SELECT
        mes_coorte,
        indice_mes,
        COUNT(DISTINCT id_cliente) AS clientes_ativos
    FROM atividade
    GROUP BY mes_coorte, indice_mes
),
base_coorte AS (
    -- Tamanho da coorte = clientes ativos no mês 0
    SELECT mes_coorte, clientes_ativos AS tamanho
    FROM contagem
    WHERE indice_mes = 0
),
-- Quantos meses cada coorte já "viveu" dentro da janela dos dados.
-- Serve para distinguir "0% de retenção" (ninguém voltou) de
-- "período futuro" (ainda não dá para medir -> NULL).
ultimo_mes AS (
    SELECT MAX(DATEFROMPARTS(YEAR(data_pedido), MONTH(data_pedido), 1)) AS mes_final
    FROM Pedidos
    WHERE status <> 'Cancelado'
)
SELECT
    FORMAT(b.mes_coorte, 'yyyy-MM') AS coorte,
    b.tamanho                       AS clientes,
    -- Para cada mês N: se já é observável, calcula o %; senão, NULL.
    CASE WHEN DATEDIFF(MONTH, b.mes_coorte, u.mes_final) >= 0
         THEN CAST(100.0 * ISNULL(SUM(CASE WHEN c.indice_mes = 0 THEN c.clientes_ativos END), 0) / b.tamanho AS DECIMAL(5,1)) END AS [Mes_0],
    CASE WHEN DATEDIFF(MONTH, b.mes_coorte, u.mes_final) >= 1
         THEN CAST(100.0 * ISNULL(SUM(CASE WHEN c.indice_mes = 1 THEN c.clientes_ativos END), 0) / b.tamanho AS DECIMAL(5,1)) END AS [Mes_1],
    CASE WHEN DATEDIFF(MONTH, b.mes_coorte, u.mes_final) >= 2
         THEN CAST(100.0 * ISNULL(SUM(CASE WHEN c.indice_mes = 2 THEN c.clientes_ativos END), 0) / b.tamanho AS DECIMAL(5,1)) END AS [Mes_2],
    CASE WHEN DATEDIFF(MONTH, b.mes_coorte, u.mes_final) >= 3
         THEN CAST(100.0 * ISNULL(SUM(CASE WHEN c.indice_mes = 3 THEN c.clientes_ativos END), 0) / b.tamanho AS DECIMAL(5,1)) END AS [Mes_3],
    CASE WHEN DATEDIFF(MONTH, b.mes_coorte, u.mes_final) >= 4
         THEN CAST(100.0 * ISNULL(SUM(CASE WHEN c.indice_mes = 4 THEN c.clientes_ativos END), 0) / b.tamanho AS DECIMAL(5,1)) END AS [Mes_4],
    CASE WHEN DATEDIFF(MONTH, b.mes_coorte, u.mes_final) >= 5
         THEN CAST(100.0 * ISNULL(SUM(CASE WHEN c.indice_mes = 5 THEN c.clientes_ativos END), 0) / b.tamanho AS DECIMAL(5,1)) END AS [Mes_5]
FROM base_coorte b
CROSS JOIN ultimo_mes u
LEFT JOIN contagem c ON c.mes_coorte = b.mes_coorte
GROUP BY b.mes_coorte, b.tamanho, u.mes_final
ORDER BY b.mes_coorte;
GO
