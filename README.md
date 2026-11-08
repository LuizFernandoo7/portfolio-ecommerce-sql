# Análise de Retenção (Cohort) e Receita/LTV em E-commerce

> Projeto de Business Intelligence em **SQL Server (T-SQL)** que responde a duas perguntas centrais para qualquer e-commerce: **"quantos clientes voltam a comprar?"** e **"quanto cada cliente adquirido vale ao longo do tempo?"**

---

## 1. Contexto de negócio

Em e-commerce, adquirir um cliente custa caro e o lucro costuma vir da **recompra**. Olhar apenas para o faturamento mensal total esconde o que importa: o faturamento de um mês mistura clientes novos com clientes que voltaram, e não mostra se a base está ficando mais ou menos fiel.

A **análise de coortes** resolve isso. Ela agrupa os clientes pelo **mês da primeira compra** e acompanha cada grupo ao longo do tempo. Assim dá para responder, com dados, perguntas como:

- Que percentual dos clientes volta a comprar no mês seguinte? E três meses depois?
- Os clientes adquiridos em um mês geram mais ou menos valor do que os de outro mês?
- Qual parte da receita vem de clientes novos e qual vem de recompra?

## 2. Objetivo

| Frente | Pergunta de negócio | Arquivo |
|---|---|---|
| **Retenção** | De cada grupo de clientes que fez a 1ª compra em um mês, qual % volta a comprar 1, 2, 3… meses depois? | `analise_cohort.sql` |
| **Receita / LTV** | Quanto cada cliente, em média, já gerou de receita desde a 1ª compra, e como esse valor acumulado evolui mês a mês? | `analise_ltv.sql` |

## 3. Ferramentas e técnicas

- **Banco de dados:** Microsoft SQL Server 2016+ (T-SQL)
- **Modelagem:** esquema relacional com 4 tabelas (`Clientes`, `Produtos`, `Pedidos`, `Itens_Pedido`), chaves estrangeiras e `CHECK` constraints
- **Técnicas de SQL:**
  - CTEs encadeadas para separar a lógica em etapas legíveis
  - Views reutilizáveis (`vw_pedidos_valor`, `vw_pedidos_cohort`) para centralizar regras de negócio
  - Window functions (`SUM() OVER (PARTITION BY ... ORDER BY ... ROWS UNBOUNDED PRECEDING)`) para receita acumulada
  - Pivot manual com agregação condicional (`SUM/MAX + CASE`) para gerar a matriz em triângulo
  - Grade `coorte × mês` (`CROSS JOIN` + `LEFT JOIN`) para não "pular" meses sem compra
  - Funções de data (`DATEFROMPARTS`, `DATEDIFF`, `FORMAT`)
  - **Reconciliação** da análise com a tabela de origem (diferença = R$ 0,00)

## 4. Estrutura do projeto

```
├── database_setup.sql   # Cria o banco, as tabelas, carrega os dados e a view de valor do pedido
├── analise_cohort.sql   # Retenção: coorte de cada cliente → atividade mensal → matriz de retenção
├── analise_ltv.sql      # Receita: view de coorte → receita mensal → LTV acumulado → KPIs → reconciliação
└── README.md
```

**Ordem de execução:** `database_setup.sql` → `analise_cohort.sql` → `analise_ltv.sql`.

### Base de dados

Dados fictícios de **jan/2026 a jun/2026**: 20 clientes cadastrados, 12 produtos em 5 categorias, 39 pedidos e 43 itens de pedido. A base foi desenhada com casos que testam a análise: clientes recorrentes, clientes que compraram uma única vez e pedidos cancelados.

### Regras de negócio aplicadas

1. **Pedidos `Cancelado` não contam**, nem como compra nem como receita.
2. **Coorte** = mês da primeira compra válida do cliente.
3. **Índice do mês** = meses decorridos desde a coorte (0 = mês da 1ª compra).
4. Um cliente com vários pedidos no mesmo mês conta **uma única vez** nesse mês (`DISTINCT`).
5. **Meses futuros ficam `NULL`**, e não 0%. Isso separa "ninguém voltou" de "ainda não dá para medir".
6. Pedidos com status `Enviado` contam como receita, porque a venda já foi concluída.

---

## 5. Resultados

### 5.1 Matriz de retenção (% de clientes da coorte que compraram no mês N)

| Coorte | Clientes | Mês 0 | Mês 1 | Mês 2 | Mês 3 | Mês 4 | Mês 5 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 2026-01 | 5 | 100% | 40,0% | 40,0% | 20,0% | 20,0% | 0,0% |
| 2026-02 | 4 | 100% | 50,0% | 50,0% | 0,0% | 25,0% | — |
| 2026-03 | 3 | 100% | 33,3% | 33,3% | 0,0% | — | — |
| 2026-04 | 3 | 100% | 66,7% | 33,3% | — | — | — |
| 2026-05 | 2 | 100% | 50,0% | — | — | — | — |
| 2026-06 | 2 | 100% | — | — | — | — | — |

*"—" = período ainda não observável (a base termina em junho).*

### 5.2 Matriz de LTV acumulado (R$ de receita por cliente adquirido)

| Coorte | Clientes | Mês 0 | Mês 1 | Mês 2 | Mês 3 | Mês 4 | Mês 5 |
|---|:-:|--:|--:|--:|--:|--:|--:|
| 2026-01 | 5 | 139,86 | 193,82 | 289,74 | 317,72 | 373,70 | 373,70 |
| 2026-02 | 4 | 212,40 | 292,30 | 357,23 | 357,23 | 377,20 | — |
| 2026-03 | 3 | 286,53 | 336,50 | 366,47 | 366,47 | — | — |
| 2026-04 | 3 | 273,20 | 363,13 | 406,43 | — | — | — |
| 2026-05 | 2 | 249,90 | 279,85 | — | — | — | — |
| 2026-06 | 2 | 304,80 | — | — | — | — | — |

### 5.3 Resumo executivo por coorte

| Coorte | Clientes | Pedidos | Receita total | LTV atual | Pedidos/cliente | Ticket médio | % receita recorrente |
|---|:-:|:-:|--:|--:|:-:|--:|:-:|
| 2026-01 | 5 | 11 | R$ 1.868,50 | R$ 373,70 | 2,20 | R$ 169,86 | 62,6% |
| 2026-02 | 4 | 9 | R$ 1.508,80 | R$ 377,20 | 2,25 | R$ 167,64 | 43,7% |
| 2026-03 | 3 | 5 | R$ 1.099,40 | R$ 366,47 | 1,67 | R$ 219,88 | 21,8% |
| 2026-04 | 3 | 6 | R$ 1.219,30 | R$ 406,43 | 2,00 | R$ 203,22 | 32,8% |
| 2026-05 | 2 | 3 | R$ 559,70 | R$ 279,85 | 1,50 | R$ 186,57 | 10,7% |
| 2026-06 | 2 | 3 | R$ 609,60 | R$ 304,80 | 1,50 | R$ 203,20 | 0,0% |
| **Total** | **19** | **37** | **R$ 6.865,30** | **R$ 361,33** | **1,95** | **R$ 185,55** | **36,8%** |

**Reconciliação:** a receita da análise de coortes (R$ 6.865,30) é igual à receita dos pedidos não cancelados na fonte. A diferença é **R$ 0,00**.

---

## 6. Insights para a gestão

**1. A retenção cai forte depois da primeira compra, mas se estabiliza.**
No mês 1, cerca de **47% dos clientes voltam** (8 de 17 nas coortes que já têm esse mês observável). No mês 2 são **40%** (6 de 15). Ou seja, mais da metade dos clientes compra uma única vez. A maior perda acontece logo no primeiro mês, e é aí que ações de pós-venda e reengajamento têm mais retorno.

**2. Recompra é relevante, mas não é a maior parte da receita.**
**11 de 19 clientes (58%)** compraram mais de uma vez. Mesmo assim, a receita de recompra responde por **36,8%** do total (R$ 2.527,80). Em contrapartida, **63%** da receita ainda vem do mês de aquisição, o que indica um negócio dependente de captação contínua.

**3. A coorte de janeiro é a mais fiel.**
Ela tem 62,6% da receita vinda de recompra e continua com 20% dos clientes ativos até o mês 4. Vale investigar o que foi diferente nessa safra (canal, campanha, mix de produtos) para tentar replicar.

**4. A coorte de abril tem o maior LTV da base e a melhor retenção no mês 1.**
Chegou a R$ 406,43 por cliente em apenas 3 meses de vida, com 66,7% de retenção no mês 1. Para efeito de comparação, janeiro precisou de 5 meses para chegar a R$ 373,70.

**5. Há um padrão de "mês morto" na recompra.**
As coortes de fevereiro e março têm **0% de atividade no mês 3**, e a de fevereiro volta a comprar no mês 4 (25%). Isso sugere que alguns clientes voltam em ciclos espaçados, e não de forma contínua. Uma campanha de reativação programada para esse intervalo pode recuperar compras.

**6. Ticket médio e frequência puxam o LTV de formas diferentes.**
Março tem o maior ticket (R$ 219,88), mas só 1,67 pedidos por cliente. Janeiro e fevereiro têm ticket menor (~R$ 168) e compensam com frequência acima de 2,2 pedidos. Para elevar o LTV há duas alavancas distintas: aumentar a frequência (janeiro/fevereiro) ou elevar o valor por pedido (março).

**7. Receita bem distribuída entre categorias.**
Eletrônicos (R$ 1.919,00), Moda (R$ 1.828,50) e Casa (R$ 1.779,00) concentram juntas 80% da receita. Saúde soma R$ 939,30 e Livros R$ 399,50. Não há dependência de uma única categoria.

**8. Pedidos cancelados não entram na conta (e isso importa).**
Os dois cancelamentos somam R$ 289,80. Um deles é de um cliente (cadastrado em fevereiro) que **nunca concluiu uma compra**, por isso ela não pertence a nenhuma coorte: são 19 clientes analisados, não 20. Esse tratamento evita inflar o tamanho das coortes e a retenção.

---

## 7. Limitações e cuidados de leitura

- **Dados fictícios e amostra pequena** (19 clientes com compra válida). Coortes de 2 a 5 clientes variam muito: um único cliente representa de 20% a 50% de uma coorte. Os percentuais servem para demonstrar a metodologia, não para tirar conclusões estatísticas.
- **Viés de maturidade:** coortes antigas tiveram mais meses para comprar, então o LTV atual favorece janeiro. Para comparar coortes de forma justa, olhe o LTV **no mesmo índice de mês** (por exemplo, o mês 2 de cada uma), e não o LTV atual.
- **LTV de receita, não de lucro:** o cálculo usa receita bruta. Margem, frete e custo de aquisição (CAC) não estão na base, e seriam o próximo passo para medir retorno sobre a aquisição.
- **Janela curta:** 6 meses não permitem identificar sazonalidade.

## 8. Próximos passos sugeridos

1. Conectar as consultas em formato longo (passo 3 da retenção e consulta 2 do LTV) ao **Power BI** ou **Tableau** e montar um dashboard com mapa de calor de retenção.
2. Incluir **CAC e margem** para calcular LTV/CAC e payback por coorte.
3. Segmentar as coortes por **canal de aquisição, estado ou categoria da 1ª compra**.
4. Evoluir para **segmentação RFM** dos clientes recorrentes.

---

## 9. Como reproduzir

1. Abra o SQL Server Management Studio (SSMS) ou Azure Data Studio.
2. Execute `database_setup.sql` (cria o banco `Portfolio_Ecommerce` e carrega os dados). Confira se a validação final retorna: 20 clientes | 12 produtos | 39 pedidos | 43 itens.
3. Execute `analise_cohort.sql` e depois `analise_ltv.sql`.
4. Confira a consulta de reconciliação no fim de `analise_ltv.sql`: `diferenca` deve ser `0`.

> **Atenção:** o `database_setup.sql` remove e recria as tabelas do banco `Portfolio_Ecommerce` a cada execução.
