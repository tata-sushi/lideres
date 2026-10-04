# Auditoria das tabelas de tela — dashboards (04/10/2026)

Comparação de cada tabela **de tela** dos 37 dashboards com o padrão da skill `dashboards-kpi-graficos`
(§5 pílulas, §6 tabelas e `references/tabelas.md`). Só leitura — serve de mapa para padronizar página por página.

- **Desligamentos: já padronizada** (Analítico, A enviar e Comentários) — é a referência.
- 56 tabelas de tela em 28 páginas; 8 páginas não têm tabela de tela (armários, comunicação, estoque ADM, folha,
  gorjeta, semanal, solicitações, TED).
- Mais próximas do padrão: Sanções (Analítico), Manutenção (Analítico dos KPIs), Benefícios (os 2 Analíticos) e
  Admissão (Pendente). Nenhuma tabela de tela tem cabeçalho escuro (isso só acontece nas tabelas da aba Sobre).

Critérios: 1 rolagem lateral com largura mínima · 2 fonte do cabeçalho (DM Mono 10px muted, borda 2px carbon) e do
corpo (DM Sans) · 3 ordenar + redimensionar colunas · 4 título dentro do card e nada solto fora · 5 pílulas DM Sans na
paleta · 6 datas DD/MM/AAAA (· HHhMM) · 7 "Ver mais" padrão · 8 largura cheia (sem coluna central) · 9 botões DM Sans.

## A) Resumo por página

| Página | Aba(s) | Nº | Falha em | O que mais chama atenção |
|---|---|---|---|---|
| auditoria/docsrh | KPIs | 1 | 1,2,3,5,6,7,9 | No celular vira cartões; botões "Ver" em DM Mono; mostra todas as linhas |
| caixa/index | página única | 3 | 1,2,4,5,8 | Tabela toda em DM Mono 11px; título h3 à esquerda; coluna central de 1100px |
| compras/abastecimento | Pedidos, Processamento, Recebimentos, Conferência, KPIs | 5 | 2,3,4,5,7 | Mesma tabela de 10 colunas em 4 abas, sem título; no celular vira cartões |
| estoque/estoque_semanal | Estoque Mínimo | 1 | 2,3,4,7 | Só tem título quando há vários grupos |
| limpeza/checklist-limpeza | KPIs | 2 | 1,2,3,5,6,7 | Pílula verde fora da paleta; "Ver mais" fora do padrão |
| manutencao/index | Chamados, KPIs | 2 | 2,3,4,5,6,7 | Analítico quase no padrão, mas CSS duplicado deixa a pílula em DM Mono; Chamados sem título/ordenar |
| rh/absenteismo | Pendências, KPIs | 2 | 2,3,4,5,7 | "Ver mais" improvisado dentro de uma linha da tabela |
| rh/admissao | Pendente | 1 | 2(leve),3,6 | Bem próxima; falta redimensionar e data com " · HHhMM" |
| rh/agenda | página única | 1 | 2,4,6 | Tabela solta abaixo do calendário, sem card; datas "seg, 12/09" |
| rh/bancodehoras | página única | 1 | 2,3,7 | "Ver mais" improvisado; CSS de tabela vale para a página inteira |
| rh/beneficios | Aniversariantes, TataPlus | 3 | 2,6,7 | Ordenar/redimensionar já funcionam; datas do TataPlus com ano de 2 dígitos |
| rh/cei | KPIs | 2 | 1,2,3,7 | Feedback aperta no celular; colunas em DM Mono 9px |
| rh/ces | KPIs | 1 | 2,3,7 | "Ver mais" é botão preto em DM Mono; borda do cabeçalho cinza |
| rh/demandas | página única | 1 | 2,3,7 | "Ver mais" improvisado |
| rh/doc | Pendências, Analítico | 2 | 2,3,4,5,6,7 | Analítico em matriz (pendente de padrão) |
| rh/escalas | Programação, KPIs | 2 | 2,4 | Grade editável da semana e mapa de calor feitos com `<table>` (não são listas) |
| rh/experiencias | KPIs | 1 | 2,3,5,7 | Pílula em DM Mono; "Ver mais" improvisado |
| rh/feriados | KPIs | 1 | 2,3,7 | Mesma família da Absenteísmo |
| rh/ferias | KPIs | 1 | 2,3,7 | Colunas em DM Mono; "Ver mais" em DM Mono |
| rh/hc | Headcount, Colaboradores, KPIs | 4 | 1,2,3,4,5,7,8 | Colaboradores lista todos sem "Ver mais"; Headcount de 11 colunas aperta no celular, coluna central de 900px |
| rh/medicina | KPIs | 1 | 2,3,5,7 | Pílulas fora da paleta (verde, cinza) |
| rh/ouvidoria | KPIs | 1 | 1,2,3,7,9 | Mesmo modelo da docsrh (cartões no celular; botão "Ver" em DM Mono) |
| rh/performance | Analítico, Pendentes, KPIs | 3 | 2,3,4,5,7 | Pílulas fora da paleta; Analítico em matriz (pendente de padrão) |
| rh/reclamacoes | KPIs | 1 | 1,2,5,7 | É a referência do organizador, mas no celular esconde 5 colunas em vez de rolar |
| rh/recrutamento | Agenda, Vagas, Entrevistas, Testes, Analítico, KPIs | 6 | 1,2,3,4,5,7 | Tabelas operacionais muito largas (pendente); datas já no padrão |
| rh/sancoes | KPIs | 1 | 2(leve) | A mais próxima do padrão |
| tatahouse/cardapio | Elaboração, Processamento, Relatórios | 4 | 1,2,3,4,5,6,7 | Pílulas com cores livres; um "Analítico" com dados fixos de exemplo no HTML |
| ps.html | Parceiros, Sistemas | 2 | 2,3,4,7 | Card sem título; lista inteira sem "Ver mais" |

## B) O que se repete (uma correção resolve várias)

1. **Cabeçalho 9px** (padrão 10px) em ~50 das 56 tabelas, com várias classes (`.desk-table`, `.colab-table`,
   `.ent-table`, `.tbl`, `.lk-table`, `.cruz-table`, `.cat-table`, `table` sem classe); corpo em 13px e colunas em
   DM Mono (Benefícios, Férias, HC, CEI, Demandas, Abastecimento, Cardápio).
2. **Pílulas em DM Mono** (padrão DM Sans 10px/500): `.status-badge` em absenteísmo, manutenção (regra duplicada),
   doc, hc, medicina, performance, reclamações, recrutamento; `.colab-status` (experiências), `.badge`
   (abastecimento, cardápio), `.b` (caixa), `.lk-badge` (limpeza). **Cores fora da paleta:** caixa, limpeza, medicina,
   performance, cardápio (6 cores livres).
3. **"Ver mais" fora do padrão:** botão inline em DM Mono dentro de uma `<tr>` (absenteísmo, banco de horas,
   demandas, experiências, feriados, medicina, manutenção-Chamados, recrutamento Vagas/Analítico, doc); classes
   alternativas `.btn-show-more`, `.lk-btn-vm`, `.btn-more`, `.dash-table-toggle`, `.anl-more`. **Listas grandes sem
   "Ver mais":** hc Colaboradores, doc, performance Pendentes, recrutamento Entrevistas/Testes (desktop), cardápio,
   ps, docsrh, cei Feedback, abastecimento.
4. **Organizador de colunas:** completo em manutenção-KPIs, reclamações, sanções, benefícios (2); só ordena na
   família `.colab-table` (absenteísmo, feriados, experiências, hc), banco de horas, férias, ouvidoria, admissão,
   abastecimento, recrutamento; nem ordena em docsrh, manutenção-Chamados, limpeza, cei, ces, demandas, medicina,
   doc, performance, ps, cardápio, estoque.
5. **Tabela "estilo desktop"** (`.desk-table`, `.ent-table`, `.pend-table`) **sem título** e que vira cartões no
   celular: abastecimento ×4, manutenção-Chamados, absenteísmo-Pendências, cardápio ×2, recrutamento
   Vagas/Entrevistas/Testes, performance-Pendentes.
6. **Datas:** "dd/mm/aaaa hh:mm" sem " · HHhMM" (docsrh, limpeza, admissão, doc, manutenção); dd/mm/aa (benefícios
   TataPlus); "seg, 12/09" (agenda); dd/mm sem ano (cardápio). O formatador da Recrutamento já está no padrão.
7. **CSS de tabela valendo para a página inteira** (`table{}`, `thead th{}`): banco de horas, benefícios, férias,
   medicina; na CEI o `.table-wrap` da aba Sobre vaza para os KPIs.
8. **Coluna central com max-width:** caixa (1100px), hc Headcount (900px) e hc Colaboradores (1100px).
9. **Botões com texto em DM Mono:** `.btn-ver` (docsrh, ouvidoria, cartões do abastecimento). Os demais botões de
   linha são só ícone.

## C) Decisões de design pendentes (do dono)

- **Celular: rolar de lado ou virar cartões?** A skill manda rolar; várias tabelas viram cartões (docsrh e ouvidoria
  até 580px; todas as `.desk-table`/`.ent-table` abaixo de 768px) e a reclamações esconde 5 colunas.
- **Corpo da tabela 12px ou 13px?** O catálogo usa 12px; o Analítico da Manutenção (referência antiga) usa 13px.
- **Matrizes de "Analítico"** (recrutamento, performance, doc): colunas agrupadas/recolhíveis, coluna fixa, rolagem
  interna — padrão ainda pendente.
- **Tabelas operacionais largas com botões por linha:** recrutamento Vagas/Entrevistas/Testes (10–12 colunas),
  abastecimento (10 colunas × 4 abas), cardápio Processamento.
- **Escalas:** grade editável e mapa de calor em `<table>` — o mapa de calor passa para a grade de divs da skill?
- **HC Headcount** (11 colunas por unidade numa coluna de 900px) e **Caixa** (a página inteira segue outro modelo).
- **Cardápio Relatórios:** "Analítico — cardápios" e "Pratos mais servidos" com dados fixos de exemplo — ligar ao
  banco ou remover.
- **Agenda:** a lista sob o calendário vira card com título?

## Deixadas de fora de propósito

- **Modelos de PDF/impressão:** abastecimento (`gerarRelatorioRecebimentos`, `gerarRelatorioEntregas`,
  `gerarPDFPedido`, `gerarPDFProcessamento`, `gerarPDFBaixaNF`, `gerarPDFConferencia`), checklist-limpeza
  (`_rlFinalizarPdf`), admissão (`_admSalarioFamiliaBuildPage`, `_admDependentesIrBuildPage`,
  `_admFichaRegistroBuildPage`), armários (`_armBuildTermoPageHtml`, `_gerarTermo`), doc (`_dgBuildUtensiliosPage`,
  `_dgBuildEquipamentoPage`), escalas (`imprimirEscala`), estoque ADM (`_estBuildReciboPageHtml`, `imprimirRecibo`),
  recrutamento (`gerarRelatorioVagas`, `gerarRelatorioTestes`), cardápio (`_gerarConsolidado`, `_gerarDetalhado`).
- **Aba Sobre** (todas as páginas), **`.info-table`** do botão "i", **tabelas dentro de modais** (abastecimento
  `proc-table`/`nf-table`/`view-items-table`, hc `hc-ed-tbl`, cardápio `proc-tbl`) e **código herdado que não aparece**
  (`renderEstoqueMinimoHTML` em checklist-limpeza e admissão; `renderCruzamento`/`renderTurnoverAnalyticTable` na
  semanal).
