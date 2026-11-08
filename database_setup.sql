/* =====================================================================
   PROJETO 1 - ANÁLISE DE RETENÇÃO (COHORT) EM E-COMMERCE
   Arquivo : database_setup.sql
   Objetivo: Criar o esquema (Clientes, Produtos, Pedidos, Itens_Pedido)
             e popular com dados fictícios de 6 meses (jan/2026 a jun/2026).

   Banco de dados: Microsoft SQL Server (T-SQL), versão 2016 ou superior
   (necessária para o DROP ... IF EXISTS).

   Características propositais da base (para a análise de cohort):
     - 20 clientes, divididos em 6 coortes de primeira compra (jan a jun).
     - 39 pedidos, sendo que vários clientes compram mais de uma vez
       (recorrentes) e outros compram uma única vez (churn).
     - 2 pedidos 'Cancelado' -> lembre de filtrá-los na análise!
     - data_cadastro sempre <= data da primeira compra.
   ===================================================================== */


/* ---------------------------------------------------------------------
   0) BANCO DE DADOS - cria (se não existir) e passa a usar o banco do projeto
   O GO separa os "lotes" (batches) do T-SQL: o USE só vale a partir do
   lote seguinte.
   --------------------------------------------------------------------- */
IF DB_ID('Portfolio_Ecommerce') IS NULL
    CREATE DATABASE Portfolio_Ecommerce;
GO

USE Portfolio_Ecommerce;
GO


/* ---------------------------------------------------------------------
   1) LIMPEZA - remove as tabelas se já existirem (ordem respeita as FKs)
   --------------------------------------------------------------------- */
DROP VIEW  IF EXISTS vw_pedidos_valor;
DROP TABLE IF EXISTS Itens_Pedido;
DROP TABLE IF EXISTS Pedidos;
DROP TABLE IF EXISTS Produtos;
DROP TABLE IF EXISTS Clientes;


/* ---------------------------------------------------------------------
   2) CRIAÇÃO DAS TABELAS
   --------------------------------------------------------------------- */

-- Clientes: quem compra na loja
CREATE TABLE Clientes (
    id_cliente     INTEGER       PRIMARY KEY,
    nome           VARCHAR(100)  NOT NULL,
    email          VARCHAR(120)  NOT NULL UNIQUE,
    cidade         VARCHAR(60)   NOT NULL,
    estado         CHAR(2)       NOT NULL,
    data_cadastro  DATE          NOT NULL
);

-- Produtos: catálogo da loja
CREATE TABLE Produtos (
    id_produto  INTEGER        PRIMARY KEY,
    nome        VARCHAR(100)   NOT NULL,
    categoria   VARCHAR(50)    NOT NULL,
    preco       DECIMAL(10,2)  NOT NULL CHECK (preco > 0)
);

-- Pedidos: cabeçalho de cada compra (uma linha por pedido)
CREATE TABLE Pedidos (
    id_pedido    INTEGER      PRIMARY KEY,
    id_cliente   INTEGER      NOT NULL,
    data_pedido  DATE         NOT NULL,
    status       VARCHAR(20)  NOT NULL
                 CHECK (status IN ('Entregue', 'Enviado', 'Cancelado')),
    FOREIGN KEY (id_cliente) REFERENCES Clientes (id_cliente)
);

-- Itens_Pedido: produtos de cada pedido (relação N:N entre Pedidos e Produtos).
-- O preço unitário é copiado para cá para preservar o valor praticado na
-- data da compra, mesmo que o preço do produto mude depois.
CREATE TABLE Itens_Pedido (
    id_item         INTEGER        PRIMARY KEY,
    id_pedido       INTEGER        NOT NULL,
    id_produto      INTEGER        NOT NULL,
    quantidade      INTEGER        NOT NULL CHECK (quantidade > 0),
    preco_unitario  DECIMAL(10,2)  NOT NULL,
    FOREIGN KEY (id_pedido)  REFERENCES Pedidos  (id_pedido),
    FOREIGN KEY (id_produto) REFERENCES Produtos (id_produto)
);


/* ---------------------------------------------------------------------
   3) CARGA DE DADOS - PRODUTOS (12 itens em 5 categorias)
   --------------------------------------------------------------------- */
INSERT INTO Produtos (id_produto, nome, categoria, preco) VALUES
(1,  'Fone de Ouvido Bluetooth',      'Eletrônicos', 189.90),
(2,  'Smartwatch Fit',                'Eletrônicos', 349.90),
(3,  'Carregador Portátil 10000mAh',  'Eletrônicos', 129.90),
(4,  'Camiseta Básica Algodão',       'Moda',         59.90),
(5,  'Tênis de Corrida',              'Moda',        279.90),
(6,  'Mochila Urbana',                'Moda',        149.90),
(7,  'Cafeteira Elétrica',            'Casa',        219.90),
(8,  'Jogo de Panelas Antiaderente',  'Casa',        399.90),
(9,  'Luminária LED de Mesa',         'Casa',         89.90),
(10, 'Whey Protein 900g',             'Saúde',       139.90),
(11, 'Kit Yoga (Tapete + Faixa)',     'Saúde',        99.90),
(12, 'Livro SQL na Prática',          'Livros',       79.90);


/* ---------------------------------------------------------------------
   4) CARGA DE DADOS - CLIENTES (20 clientes)
   A data de cadastro coincide com o mês da primeira compra (coorte).
   --------------------------------------------------------------------- */
INSERT INTO Clientes (id_cliente, nome, email, cidade, estado, data_cadastro) VALUES
-- Coorte de Janeiro
(1,  'Mariana Alves',      'mariana.alves@email.com',     'São Paulo',      'SP', '2026-01-05'),
(2,  'Rafael Souza',       'rafael.souza@email.com',      'Rio de Janeiro', 'RJ', '2026-01-08'),
(3,  'Camila Ferreira',    'camila.ferreira@email.com',   'Belo Horizonte', 'MG', '2026-01-13'),
(4,  'Lucas Martins',      'lucas.martins@email.com',     'Curitiba',       'PR', '2026-01-21'),
(5,  'Beatriz Costa',      'beatriz.costa@email.com',     'Porto Alegre',   'RS', '2026-01-27'),
-- Coorte de Fevereiro
(6,  'Gustavo Lima',       'gustavo.lima@email.com',      'São Paulo',      'SP', '2026-02-02'),
(7,  'Fernanda Rocha',     'fernanda.rocha@email.com',    'Salvador',       'BA', '2026-02-06'),
(8,  'Thiago Barbosa',     'thiago.barbosa@email.com',    'Recife',         'PE', '2026-02-14'),
(9,  'Juliana Mendes',     'juliana.mendes@email.com',    'Fortaleza',      'CE', '2026-02-20'),
(10, 'Pedro Henrique Dias','pedro.dias@email.com',        'Campinas',       'SP', '2026-02-26'),
-- Coorte de Março
(11, 'Larissa Teixeira',   'larissa.teixeira@email.com',  'Rio de Janeiro', 'RJ', '2026-03-03'),
(12, 'Bruno Cardoso',      'bruno.cardoso@email.com',     'Brasília',       'DF', '2026-03-11'),
(13, 'Aline Nogueira',     'aline.nogueira@email.com',    'Goiânia',        'GO', '2026-03-21'),
-- Coorte de Abril
(14, 'Diego Ribeiro',      'diego.ribeiro@email.com',     'São Paulo',      'SP', '2026-04-04'),
(15, 'Patrícia Gomes',     'patricia.gomes@email.com',    'Florianópolis',  'SC', '2026-04-15'),
(16, 'Rodrigo Pinto',      'rodrigo.pinto@email.com',     'Belo Horizonte', 'MG', '2026-04-26'),
-- Coorte de Maio
(17, 'Vanessa Araújo',     'vanessa.araujo@email.com',    'Curitiba',       'PR', '2026-05-02'),
(18, 'Felipe Moreira',     'felipe.moreira@email.com',    'Manaus',         'AM', '2026-05-18'),
-- Coorte de Junho
(19, 'Isabela Duarte',     'isabela.duarte@email.com',    'Rio de Janeiro', 'RJ', '2026-06-03'),
(20, 'Leonardo Batista',   'leonardo.batista@email.com',  'São Paulo',      'SP', '2026-06-17');


/* ---------------------------------------------------------------------
   5) CARGA DE DADOS - PEDIDOS (39 pedidos, em ordem cronológica)
   Clientes recorrentes aparecem em mais de uma linha.
   Obs.: pedidos 7 e 36 estão 'Cancelado' (o cliente 7 nunca concluiu
   uma compra - um caso de borda interessante para a análise).
   --------------------------------------------------------------------- */
INSERT INTO Pedidos (id_pedido, id_cliente, data_pedido, status) VALUES
-- Janeiro
(1,  1,  '2026-01-05', 'Entregue'),
(2,  2,  '2026-01-09', 'Entregue'),
(3,  3,  '2026-01-14', 'Entregue'),
(4,  4,  '2026-01-22', 'Entregue'),
(5,  5,  '2026-01-28', 'Entregue'),
-- Fevereiro
(6,  6,  '2026-02-03', 'Entregue'),
(7,  7,  '2026-02-07', 'Cancelado'),
(8,  1,  '2026-02-12', 'Entregue'),
(9,  8,  '2026-02-15', 'Entregue'),
(10, 4,  '2026-02-18', 'Entregue'),
(11, 9,  '2026-02-21', 'Entregue'),
(12, 10, '2026-02-27', 'Entregue'),
-- Março
(13, 11, '2026-03-04', 'Entregue'),
(14, 6,  '2026-03-10', 'Entregue'),
(15, 12, '2026-03-12', 'Entregue'),
(16, 2,  '2026-03-15', 'Entregue'),
(17, 1,  '2026-03-20', 'Entregue'),
(18, 13, '2026-03-22', 'Entregue'),
(19, 8,  '2026-03-25', 'Entregue'),
-- Abril
(20, 4,  '2026-04-02', 'Entregue'),
(21, 14, '2026-04-05', 'Entregue'),
(22, 11, '2026-04-09', 'Entregue'),
(23, 6,  '2026-04-14', 'Entregue'),
(24, 15, '2026-04-16', 'Entregue'),
(25, 10, '2026-04-20', 'Entregue'),
(26, 16, '2026-04-27', 'Entregue'),
-- Maio
(27, 17, '2026-05-03', 'Entregue'),
(28, 14, '2026-05-06', 'Entregue'),
(29, 1,  '2026-05-08', 'Entregue'),
(30, 11, '2026-05-12', 'Entregue'),
(31, 18, '2026-05-19', 'Entregue'),
(32, 16, '2026-05-30', 'Entregue'),
-- Junho
(33, 6,  '2026-06-01', 'Entregue'),
(34, 19, '2026-06-04', 'Entregue'),
(35, 17, '2026-06-07', 'Entregue'),
(36, 13, '2026-06-10', 'Cancelado'),
(37, 20, '2026-06-18', 'Entregue'),
(38, 16, '2026-06-25', 'Enviado'),
(39, 20, '2026-06-28', 'Enviado');


/* ---------------------------------------------------------------------
   6) CARGA DE DADOS - ITENS DOS PEDIDOS
   Alguns pedidos têm 2 itens ou quantidade > 1 para dar realismo.
   preco_unitario = preço do catálogo na data da compra.
   --------------------------------------------------------------------- */
INSERT INTO Itens_Pedido (id_item, id_pedido, id_produto, quantidade, preco_unitario) VALUES
(1,  1,  4,  2,  59.90),
(2,  2,  1,  1, 189.90),
(3,  3,  12, 1,  79.90),
(4,  4,  10, 1, 139.90),
(5,  5,  9,  1,  89.90),
(6,  5,  12, 1,  79.90),   -- pedido 5 com 2 itens
(7,  6,  3,  1, 129.90),
(8,  7,  11, 1,  99.90),
(9,  8,  3,  1, 129.90),
(10, 9,  7,  1, 219.90),
(11, 10, 10, 1, 139.90),
(12, 11, 6,  1, 149.90),
(13, 12, 2,  1, 349.90),
(14, 13, 8,  1, 399.90),
(15, 13, 9,  1,  89.90),   -- pedido 13 com 2 itens
(16, 14, 4,  3,  59.90),
(17, 15, 9,  1,  89.90),
(18, 16, 12, 2,  79.90),
(19, 17, 1,  1, 189.90),
(20, 17, 3,  1, 129.90),   -- pedido 17 com 2 itens
(21, 18, 5,  1, 279.90),
(22, 19, 10, 1, 139.90),
(23, 20, 10, 1, 139.90),
(24, 21, 2,  1, 349.90),
(25, 21, 4,  1,  59.90),   -- pedido 21 com 2 itens
(26, 22, 6,  1, 149.90),
(27, 23, 10, 1, 139.90),
(28, 24, 7,  1, 219.90),
(29, 25, 4,  2,  59.90),
(30, 26, 1,  1, 189.90),
(31, 27, 11, 1,  99.90),
(32, 28, 3,  1, 129.90),
(33, 29, 5,  1, 279.90),
(34, 30, 9,  1,  89.90),
(35, 31, 8,  1, 399.90),
(36, 32, 10, 1, 139.90),
(37, 33, 12, 1,  79.90),
(38, 34, 6,  1, 149.90),
(39, 35, 4,  1,  59.90),
(40, 36, 1,  1, 189.90),
(41, 37, 5,  1, 279.90),
(42, 38, 3,  1, 129.90),
(43, 39, 9,  2,  89.90);


/* ---------------------------------------------------------------------
   7) VIEW AUXILIAR - valor total de cada pedido
   Evita guardar o total na tabela (e correr o risco de ficar inconsistente
   com os itens). Soma quantidade * preço unitário por pedido.
   No SQL Server, CREATE VIEW precisa ser o PRIMEIRO comando do lote,
   por isso o GO antes e depois.
   --------------------------------------------------------------------- */
GO
CREATE VIEW vw_pedidos_valor AS
SELECT
    p.id_pedido,
    p.id_cliente,
    p.data_pedido,
    p.status,
    SUM(i.quantidade * i.preco_unitario) AS valor_total
FROM Pedidos p
JOIN Itens_Pedido i ON i.id_pedido = p.id_pedido
GROUP BY p.id_pedido, p.id_cliente, p.data_pedido, p.status;
GO


/* ---------------------------------------------------------------------
   8) CONSULTAS DE VALIDAÇÃO (rode após o script para conferir a carga)
   Resultados esperados: 20 clientes | 12 produtos | 39 pedidos | 43 itens
   --------------------------------------------------------------------- */
SELECT 'Clientes'     AS tabela, COUNT(*) AS total FROM Clientes
UNION ALL
SELECT 'Produtos',               COUNT(*)          FROM Produtos
UNION ALL
SELECT 'Pedidos',                COUNT(*)          FROM Pedidos
UNION ALL
SELECT 'Itens_Pedido',           COUNT(*)          FROM Itens_Pedido;

-- Quantos clientes compraram mais de uma vez? (ignora cancelados)
SELECT COUNT(*) AS clientes_recorrentes
FROM (
    SELECT id_cliente
    FROM Pedidos
    WHERE status <> 'Cancelado'
    GROUP BY id_cliente
    HAVING COUNT(*) > 1
) AS recorrentes;
