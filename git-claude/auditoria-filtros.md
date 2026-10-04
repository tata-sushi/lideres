# Auditoria dos filtros — dashboards (04/10/2026)

Comparação da **faixa de filtros** de cada aba dos 37 dashboards com o padrão da skill `dashboards-kpi-graficos`
(§2 "Filtros" + §4). Só leitura — mapa para padronizar página por página. Referência aprovada:
`compliance/kpis/rh/desligamentos.html` (abas KPIs e A enviar).

Critérios: 1 faixa branca full-bleed logo abaixo dos KPIs · 2 grade 2 colunas no celular / 3 no desktop · 3 rótulo
DM Sans 10px/500 uppercase carbon · 4 campo cinza `9px 36px 9px 12px` DM Sans 13px · 5 "Limpar filtros" + contagem
(5f = existem, mas em DM Mono) · 6 começa em "Todos/Todas" (conjunto RH: Unidade · Depto · Mês · De/Até) · 7 o filtro
atualiza a aba toda · 8 nada solto fora do card / sem filtro duplicado · 9 abas da mesma página no mesmo padrão.
Os critérios **3** e **5f** falham em quase todas — na tabela só aparecem quando há algo além da fonte.

## A) Página × aba

| Página | Aba | Filtros | Onde estão | Falham | O que mais chama atenção |
|---|---|---|---|---|---|
| auditoria/docsrh | KPIs | nenhum (só "Limpar" + contagem) | faixa vazia | 5, 7 | Faixa sem campos; "Limpar" não faz nada (stub) |
| caixa/index | — | Turno, Operador, Período (7d/30d/mês) | faixa, conteúdo centralizado em 1100px | 1, 3, 4, 5f | Selects brancos em DM Mono 11px; classes próprias |
| compras/abastecimento | 5 abas (faixa única) | Unidade, Depto, Categoria, Status, Fornecedor + 6 datas | faixa | 2, 4, 5f, 7 | 11 campos (5–6 colunas); na aba KPIs os filtros não mudam nada |
| estoque/estoque_semanal | Estoque Mínimo | Unidade, Depto | faixa | 3, 5 | Sem "Limpar" e sem contagem |
| limpeza/checklist-limpeza | KPIs | Unidade, Banheiro, Período (7/30/90/Tudo) | faixa acima dos KPIs | 1, 2, 3, 5, 6 | Ordem invertida; "Todas as unidades"; 1 coluna no celular |
| manutencao/index | Chamados | Unidade, Depto, Solicitante, Status, Prioridade | faixa | 2, 3, 4 | 1 coluna no celular → 5 no desktop; campo maior |
| manutencao/index | KPIs | Unidade, Depto, Status, Categoria | faixa | 2, 3, 4 | Igual à aba Chamados |
| rh/absenteismo | Pendências | Unidade, Depto, Tipo de ausência | faixa | 3, 5f | Estrutura certa |
| rh/absenteismo | KPIs | Unidade, Depto, De, Até | faixa | 2, 3, 5f, 9 | 4 colunas; diferente da aba Pendências |
| rh/armarios | (abas = unidades, exceção aprovada) | busca | solta no cinza | 1, 3, 4, 5 | Busca branca sem rótulo, sem Limpar/contagem |
| rh/bancodehoras | — | Unidade, Depto | faixa | 2, 3, 5f | 2 colunas no desktop |
| rh/beneficios | Aniv. Empresa/Mês, Assist. Médica | Unidade, Depto | faixa (`.filter-bar`) | 2, 5, 6 | Rótulo certo; sem Limpar/contagem; "Todas as unidades" |
| rh/beneficios | TataPlus | Unidade, Depto, Status, Data inicial/final | faixa | 2, 4, 5, 6 | Sem Limpar/contagem |
| rh/cei | KPIs | Unidade, Depto | faixa acima dos KPIs | 1, 2, 3, 5, 6 | Sem Limpar/contagem; 1 coluna no celular |
| rh/ces | KPIs | Unidade, Depto, Cargo, Nível | faixa | 2, 3, 5f | 4 colunas |
| rh/doc | Pendências | Unidade, Depto + busca | faixa + busca | 2, 3, 4, 5f | Busca branca sem rótulo |
| rh/doc | Analítico | Status ("Ativos"), Unidade, Depto + busca | faixa + busca | 2, 3, 4, 5f, 6 | Começa em "Ativos" |
| rh/escalas | Programação + KPIs | Unidade (obrigatória), Depto, setas de semana | barra de ferramentas | 1, 3, 4, 5f, 6 | Navegador de semana dentro da faixa |
| rh/estoqueadm | (abas = unidades, exceção) | — | — | — | Ok como exceção |
| rh/experiencias | Pendências | Fase, Unidade, "Lider" (é Depto) | faixa dentro do `.main` | 1, 2, 3, 5f | Rótulo "Lider" errado |
| rh/experiencias | KPIs | Unidade, Depto | faixa | 3, 5, 9 | Sem contagem |
| rh/feriados | Devolutivas + KPIs | Feriado, Unidade, Depto | faixa | 3, 5f | A mais próxima do padrão |
| rh/ferias | Pendências + KPIs | Unidade, Depto, Status | faixa (`.filter-bar`) | 3, 5f, 6 | "Todas as unidades" |
| rh/gorjeta | — | Unidade | barra acima dos KPIs | 1–7 | Maquete: select sem ação |
| rh/hc | KPIs | Unidade, Depto | faixa | 2, 3, 5, 9 | "Limpar" só com filtro ativo; sem contagem |
| rh/hc | Colaboradores | Status, Unidade, Depto + busca | solto no cinza, coluna de 1100px | 1, 2, 3, 4, 5f, 8, 9 | Contagem solta no cinza |
| rh/medicina | Pendências | Unidade, Depto, Tipo de exame, Status | faixa | 2, 3, 5f | 2 colunas no desktop |
| rh/medicina | KPIs | Unidade, Depto, Status | faixa | 2, 3, 5, 9 | Sem contagem |
| rh/ouvidoria | KPIs | Identificado, Devolutiva, Período | faixa | 2, 3, 4, 5f | Grade 3→2→1; campo maior |
| rh/performance | KPIs / Analítico / Pendentes | Unidade, Depto (+ busca no Analítico) | faixa | 3, 4, 5f, 6, 9 | "Todos" no KPIs, "Todas as unidades" nas outras |
| rh/reclamacoes | KPIs | Status, Ano, Unidade, Depto | faixa recuada 24px | 1, 2, 3, 5f, 6 | 4 colunas; Status/Ano antes da Unidade |
| rh/recrutamento | Vagas / Entrevistas / Testes / KPIs | Unidade, Depto, Status, Data, Entrevistador, Competência, De/Até | faixa | 3, 5f | Estrutura modelo, mas em DM Mono |
| rh/recrutamento | Analítico | 9 selects + De/Até + busca | faixa + busca | 2, 3, 4, 5f | A faixa mais carregada do portal |
| rh/sancoes | KPIs | Unidade, Depto, Tipo, Status, De, Até | faixa fixa (sticky) acima dos KPIs | 1, 4 | Visual quase perfeito; só ordem e sticky |
| rh/solicitacoes | Pendências | Solicitante, Unidade, Depto, Status | faixa | 2, 3, 4, 5f | Rótulo 9px; campo menor |
| rh/solicitacoes | KPIs | Unidade, Depto | dentro da grade de cards | 1, 2, 3, 4, 5, 9 | Pior caso de posição |
| tatahouse/cardapio | Elaboração / Processamento | Unidade, Status, Cardápio do dia + setas | faixa (flex) | 2, 3, 4, 5f, 6 | Campos em DM Mono 11px |
| tatahouse/cardapio | Relatórios | Unidade, Status, Cardápio | acima dos KPIs | 1, 3, 4, 5f, 6, 7 | Maquete: números fixos e filtros sem ação |

**Abas sem filtro que precisam de um (sugestão):** docsrh KPIs (Unidade, Tipo de documento, De/Até) · demandas
(Responsável, Etiqueta, Competência) · ps Parceiros/Sistemas (Categoria, Depto, busca) · semanal KPIs (Unidade/Depto —
o código existe sem a faixa no HTML) · admissão Pendente e hc Headcount (opcional).

## B) O que se repete (uma correção resolve várias)

1. **Rótulo em DM Mono cinza** em 24 páginas (só benefícios e sanções certas). Causa: o texto da skill dizia "rótulo
   DM Mono" e o CSS dizia DM Sans — **texto corrigido para DM Sans** (04/10).
2. **"Limpar filtros" e contagem em DM Mono** em 19 páginas (só manutenção e sanções em DM Sans).
3. **Grade fora de 2→3:** 5–6 colunas (abastecimento, manutenção); 4 (ces, reclamações, absenteísmo, escalas); 2 no
   desktop (medicina, performance, banco de horas, solicitações, hc); 1 no celular (cei, limpeza, manutenção,
   experiências, docsrh/ouvidoria); flex-wrap (benefícios, cardápio, doc, recrutamento-Analítico).
4. **"Todas as unidades"/"Todos os departamentos"** no lugar de "Todas"/"Todos": benefícios, cei, limpeza,
   performance, férias, cardápio.
5. **Sem Limpar e/ou contagem:** estoque semanal, limpeza, cei, gorjeta, benefícios (os dois); experiências,
   medicina, hc, solicitações (só a contagem).
6. **Faixa antes dos KPIs:** cei, sanções, limpeza, gorjeta, cardápio.
7. **Faixa recuada/centralizada:** caixa (1100px), hc Colaboradores, reclamações, solicitações, experiências.
8. **Campos fora do padrão:** DM Mono 11px (caixa, gorjeta, cardápio, datas do abastecimento); 10/14px (docsrh,
   ouvidoria, manutenção); 8/30px (solicitações); datas com 8px (benefícios, sanções).
9. **Classes divergentes** (`.filter-bar`, `.filter-actions`, `.btn-clear-filters`, `.result-count`, `.snc-*`,
   `.lk-filters`, `.esc-toolbar`, `.colab-filtros`, `.filter`/`.counter`, `#dash-filters`) — padronizar para
   `.filters-wrap / .filters-row / .filter-group / .filter-label / .filter-select / .filters-actions / .btn-clear /
   .results-count`.

## C) Decisões pendentes (do dono)

- **Busca por nome:** vira um `.filter-group` "Busca" no padrão (cinza, com rótulo) ou oficializa a faixa de busca
  branca sem rótulo (doc, recrutamento-Analítico, performance-Analítico, hc-Colaboradores, armários)?
- **Período em atalhos ou em datas:** caixa (7d/30d/mês) e limpeza (7/30/90) × De/Até + Competência do RH;
  abastecimento usa 6 datas.
- **Navegação por semana** (escalas, cardápio): dentro da faixa ou linha própria?
- **Filtros obrigatórios sem "Todos"** (escalas, doc-Analítico "Ativos", cardápio-Relatórios).
- **Filtro por clique no gráfico** (absenteísmo, banco de horas, demandas, benefícios, experiências, feriados,
  medicina, solicitações, ouvidoria, estoque ADM): entra na contagem e é zerado pelo "Limpar"?
- **Faixa fixa no topo (sticky):** só sanções — generalizar ou remover?
- **Uma faixa para várias abas** (abastecimento, feriados, férias, escalas) × uma por aba (padrão da Desligamentos).
- **Maquetes** (gorjeta, cardápio-Relatórios): ligar ao banco ou esconder?

## Outros achados (a verificar)

- **semanal:** `render()` chama `renderFilters()`, que escreve em `#filters-wrap` — elemento que não existe na
  página. Pelo código pode dar erro e interromper o resto da carga (não testado com dados reais).
- **admissão:** a aba KPIs mostra "KPIs de estoque em construção" (texto copiado de outra página).
- **experiências:** o rótulo "Lider" filtra o Departamento.
