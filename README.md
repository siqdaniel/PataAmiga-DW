# Pet Shop Pata Amiga - Modelagem Dimensional e Análise de Vendas (SQL)

##  Contexto do Projeto
A Pata Amiga é uma rede catarinense de pet shops com 32 lojas. Este projeto consolida 7 meses de dados (4.044 pedidos) provenientes de três sistemas legados em um modelo dimensional (Star Schema) para responder a 5 perguntas estratégicas de negócio.

---

##  Diagrama do Modelo Dimensional (Star Schema)
![Diagrama Star Schema](./docs/diagrama_modelo.png)

> **Grão da Fato (`fato_pedido`):** 1 linha = 1 pedido (Total: 4.044 linhas).

---

##  Tarefa 1: Diagnóstico da Base de Origem
- **Grafias de Loja:** Múltiplas variações com erros ortográficos, acentos, sufixos (/SC) e apelidos.
- **Grafias de Categoria:** 18 grafias distintas na origem reduzidas a 7 categorias padronizadas.
- **Pedidos sem Código de Loja:** 1.575 pedidos (~39%).
- **Pedidos sem Nome de Loja:** 3 pedidos (vinculados à linha -1 "Nao Informado").
- **Marcos de Processo em Branco:**
  - Separação: 1.077
  - Nota Fiscal: 1.338
  - Despacho: 1.665
  - Entrega: 1.953 (pedidos ainda não concluídos)

---

##  Regras de Negócio e Tratamento (ETL)
1. **Datas:** Conversão da data do pedido (`MM/DD/AAAA HH:MI AM/PM`) via `STR_TO_DATE`. Marcos em formato `AAAA-MM-DD` convertidos com `DATE()`.
2. **Números e Valores:** Remoção de `R$`, pontos de milhar e substituição de textos vazios/`-` por `NULL`.
3. **De-Para de Categoria:** Aplicação de regra condicional com prioridade estrita (`MED` > `PETISC` > `RA` > `HIG` > `BRINQ` > `ACESS` > `SERV`).
4. **Padronização de Lojas:** Remoção do sufixo `/SC`, espaços duplos e correção de 3 casos críticos (`BLUMENAL` -> `BLUMENAU`, `FLORIPA` -> `FLORIANOPOLIS`, `JGUA` -> `JARAGUA`).
5. **Canais e Desconto:** Resolução da precedência `WHATS` antes de `APP`.
6. **Rateio por Praça:** Aplicação do `fator_publico` via `bridge_loja_praca` para garantir a integridade do faturamento.

---

## Ordem de Execução dos Scripts
1. `01-carga-staging.sql` - Criação e carga das tabelas brutas.
2. `02-dimensoes-prontas.sql` - Criação e carga de `dim_tempo` e `dim_loja`.
3. `03-dimensoes-e-ponte.sql` - Criação de `dim_categoria`, `dim_praca` e `bridge_loja_praca` (com inserção do registro `-1`).
4. `04-carga-fato.sql` - População da `fato_pedido` com 4.044 registros.
5. `05-perguntas-de-negocio.sql` - Consultas de análise e validação dos totais.

---

##  Respostas às Perguntas de Negócio

### P1: Gargalo da Entrega
- **Tempo Médio Total:** X,XX dias.
- **Intervalo Mais Lento:** [Separação Nota / Nota Despacho / etc.]
- **Comportamento por Porte:** [Análise comparativa em Pequena, Média e Grande]

### P2: Concentração de Faturamento por Categoria
| Categoria | Faturamento (R$) | % do Total | Categoria Campeã por Porte |
| :--- | :--- | :--- | :--- |
| ... | ... | ... | ... |

### P3: Desconto por Canal de Venda
| Canal | Ticket Médio COM Desconto | Ticket Médio SEM Desconto | % do Faturamento |
| :--- | :--- | :--- | :--- |
| App | ... | ... | ... |
| WhatsApp | ... | ... | ... |
| ... | ... | ... | ... |

### P4: Faturamento Rateado por Praça de Atendimento
| Praça | Faturamento Rateado (R$) | Domicílios com Pet | Faturamento / Pet |
| :--- | :--- | :--- | :--- |
| ... | ... | ... | ... |
- **Reconciliação:** Soma total por praça + pedidos sem loja = **R$ 1.793.309,00**

### P5: Expansão e Limitações dos Dados
- **a) Ranking por Vendas/1k Habs:** [Resultado e correlação com tempo de entrega]
- **b) Análise por Faixa de Franquia:** Explicação técnica de por que a faixa atual no cadastro sobrescreve o histórico (SCD Tipo 1/Foto Atual) e impede análise retroativa.
- **c) O que ficou de fora:** 3 pedidos sem loja, 1.953 entregas em aberto, itens/valores em branco.
- **Recomendação Final:** [ Sugestão de praça para nova loja com base nos dados ]

---

##  Vídeo de Apresentação
[Assista ao vídeo no Google Drive](LINK_DO_SEU_GOOGLE_DRIVE_AQUI)