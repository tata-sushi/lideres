# Catálogo de Gráficos — specs (anexo do HTML)

Documento de referência que acompanha **`git-claude/catalogo-graficos.html`**.

O **HTML é a página visual** — feito para parecer uma página real do portal (mesmos
tokens, mesmo layout, sem "andaime" de catálogo), para servir de referência fiel quando
a skill `dashboards-kpi-graficos` for invocada. **Este `.md` guarda as especificações**:
o que cada bloco é, o tipo, onde é usado no portal e se é padrão ou desvio.

Todos os dados no HTML são **fictícios** (demonstração). Referência canônica de
implementação: `compliance/kpis/rh/recrutamento.html`.

## Layout (regras da página)

- **Full-width, sem centralizar.** Nada de `max-width`/coluna estreita centralizada.
- **KPIs e filtros = faixas full-bleed:** encostam nas laterais (100% da largura,
  `padding:14px 20px`), sem margem externa.
- **Divisória entre faixas = 1 linha só:** cada faixa usa **apenas `border-bottom`**
  (nunca `border-top`), senão as bordas somam e viram uma linha grossa de 2px.
- **Filtros em `flex-wrap`:** cada campo com `flex: 1 1 130px; min-width:0` — **cabem
  até ~5 numa linha** e quebram sozinhos no mobile (igual à view de entrevistas do
  recrutamento, que usa `.anl-filters-line`). Nada de grid de colunas fixas.
- **Gráficos = respiro lateral pequeno** (12px no mobile / 24px no desktop), não centralizados.
- **Título de cada gráfico centralizado** (`.chart-title { text-align:center }`), igual ao
  `.chart-title` do recrutamento — não alinhado à esquerda.
- **Barra vertical de série temporal = largura fixa + rolagem lateral.** As barras
  **nunca comprimem**: cada barra ocupa largura fixa (~46px) e o gráfico ganha **scroll
  horizontal** (assim como as barras horizontais mantêm altura fixa). Padrão Chart.js:
  `chart-scroll.style.minWidth = nº_barras * 46 + 'px'` dentro de `.chart-wrap`
  (`overflow-x:auto`); em barra CSS, a coluna é `flex: 0 0 42px` num container `overflow-x:auto`.
- **Rótulo do eixo X sempre com data:** **dia/mês** (`09/03`) ou **mês/ano** (`09/2026`),
  nunca só o nome do mês. (Ver `getMonthDataRecrut` no recrutamento: `MM/AAAA`.)
- **Respiro no topo dos gráficos:** a 1ª seção de gráficos (`.hero`) tem `padding-top`
  (16px no mobile / 24px no desktop), separando-a da faixa de filtros — o 1º gráfico
  **não fica colado** na divisória (igual ao `padding-top` do `.content` no recrutamento).
- **Cores invertidas na zona de KPI/filtros:** faixa **branca** (`--surface`) com
  **card/campo cinza** (`--bg`) — o inverso dos chart-cards (card branco sobre fundo cinza).
- **Cor dos gráficos = carbon (monocromático).** O **único** gráfico com cor (matiz)
  diferente é o **radar** (2 séries: Geral × Liderança). Todos os outros — barras,
  linha/área, pizza, doughnut, rating, heatmap, nuvem — usam **tons de carbon**
  (variação por opacidade de `#35383F`), nunca hue própria. No portal real alguns
  desvios aparecem coloridos (pizza semântica, rating vermelho→verde), mas o **padrão
  da casa é carbon** — e é isso que o catálogo mostra. Pílulas/badges de status em
  tabela continuam com cor semântica (não são gráfico).
- Tokens, tipografia (DM Sans + DM Mono) e paleta: ver a skill `dashboards-kpi-graficos`.

## Mapeamento dos blocos (na ordem da página)

| Bloco (título no HTML) | Tipo | Onde é usado no portal | Situação |
|---|---|---|---|
| **Cards de KPI** | número em destaque (28px tabular) | quase todas as páginas | **padrão** |
| **Filtros** | Unidade · Departamento · Competência + De/Até | páginas com dados filtráveis | **padrão** |
| **Entrevistas por Mês** (subtabs Entrevistas/Testes) | barra vertical (Chart.js), carbon, **largura fixa 46px + scroll lateral**, rótulo mês/ano, clique-filtra, cfOutline | recrutamento, feriados, solicitações, medicina, absenteísmo, benefícios, hc | **PADRÃO** (referência) |
| **Status das Entrevistas / dos Testes** | status em tabela + pílulas | recrutamento, absenteísmo, cardápio | **padrão** |
| **Vagas por Unidade** | barra horizontal (`indexAxis:'y'`) | reclamações, benefícios (TataPlus), desligamentos | desvio de tipo |
| **Status das Demandas** | pizza (cores semânticas) | demandas2, desligamentos, recrutamento-novo | **desvio** (padrão manda tabela) |
| **Identificou-se?** | doughnut | ouvidoria | **desvio** (legenda visível + plugin datalabels externo) |
| **Avaliação por Nota** | barra multicolor (nota 1→5, vermelho→verde) | desligamentos (avaliações) | desvio de cor |
| **Turnover Mensal** | linha + área | semanal, hc, hc2 | hoje em **SVG à mão** (não Chart.js) |
| **Chamados por Categoria** | barras em CSS/div (`.bar-fill`) | medicina, demandas, absenteísmo, solicitações, manutenção | sem Chart.js |
| **Funil de Recrutamento** | funil em `<div>` | recrutamento, recrutamento-novo | sem Chart.js |
| **Clima por Tema** | radar (2 séries: Geral × Liderança) | cei (Cultura & Clima) | hoje em **SVG à mão** |
| **Banco de Horas** | multi-linha (2 séries: + sólido / − tracejado) | performance, hc | hoje em **SVG à mão** |
| **Absenteísmo por Mês** | barra vertical em CSS/div | performance | sem Chart.js |
| **Picos de Abertura** | heatmap dia × hora (opacidade do carbon) | manutenção | sem Chart.js |
| **Brainstorm de Líderes** | nuvem de palavras (tamanho por frequência, tons de carbon) | cei | sem Chart.js |
| **Analítico — candidaturas** | tabela | páginas com aba Analítico | **padrão** |

## Padrão x desvio (resumo)

- **Padrão** = barra vertical carbon (Chart.js), sem legenda/tooltip/grid, rótulo por
  plugin, clique-filtra; status em **tabela** (nunca pizza); KPIs/filtros full-bleed invertidos.
- **Desvios** recorrentes no portal: pizza/doughnut para status, barra horizontal,
  tooltip nativo/legenda ligados, cores fora do carbon, e várias viz feitas em **SVG à mão**
  ou **barras CSS** em vez de Chart.js. O inventário completo (18 páginas, 34 gráficos) e as
  recomendações de padronização estão na skill `dashboards-kpi-graficos`.
