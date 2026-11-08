# Roteiro de padronização das páginas (Portal Líderes)

Mapa de **todas as páginas HTML** de `compliance/**` com o estado de cada **skill** do repo. Serve para a skill
`controle-de-acessos-e-visibilidade` agora e para as demais (`botoes`, `header-abas-footer`, `drawer-sobre`,
`modal-formulario`, `dashboards-kpi-graficos`) depois. **Uma página (ou um grupo pequeno) por PR**, mostrar
antes/depois ao dono e mergear só com "merge" explícito.

> Regra de trabalho (dono, 08/11/2026): só o que a skill delimita. O que estiver fora da skill não entra no PR.
> Não registrar aqui funções ou tabelas abertas nem dado de pessoa: este arquivo vai para o GitHub Pages.

## Como usar

1. Escolha a próxima página na ordem dos grupos abaixo (dentro do grupo, de cima para baixo).
2. Rode a skill pedida na página inteira e marque a coluna com ✅ e a data. Status: ✅ feito · 🔶 parcial · ⏳ pendente · ⏸ aguardando decisão do dono · — não se aplica.
3. Atualize este arquivo no mesmo PR da página.

## Roteiro da skill `controle-de-acessos-e-visibilidade` (por página)

1. **HTML**: `GOV_PAGE_ID` + gate; abas (`tab-btn`) com `data-aba-id`; todo botão de ação com `data-aba-id`/`data-botao-id`; nada de perfil, `lideres_session`, filtro de equipe, trava própria de card, sandbox, autor vindo da página. `python3 .claude/skills/controle-de-acessos-e-visibilidade/scripts/auditar-acessos.py`.
2. **Catálogo**: cada id do HTML em `governanca_abas` com o `tipo` certo; id novo em botão que já existia → liberar para quem já abre a página no mesmo comando.
3. **Servidor** (`references/servidor.md`): toda função chamada pela página confere a página (`gov_tenho_acesso` / `gov_tenho_alguma`), toda ação o botão (`pode_botao`), corta a Linha (`minha_subarvore`), mascara Valor (`pode_ver_valores`) e Contato (`pode_ver_contato`), grava o autor do login (`minha_matricula()` / `meu_nome()`), sem execute para `anon`. Migration em `supabase/migrations/`, testada; edge function que a página chama confere login e botão antes do service role.
4. **Validar**: `node git-claude/testes/jscheck.js <arq>` e `oncheck.js`; abrir no app; testar como pessoa logada por matrícula (contagens).

Legenda das colunas de componentes (do inventário automático): Abas = `tab-btn`; Ids = `data-aba-id`/`data-botao-id` distintos; RPC = funções do banco chamadas; Drawer / Modal / Gráfico = componente presente.

| Página | GOV_PAGE_ID | Abas | Ids | RPC | Acessos | Botões | Header/abas/footer | Drawer Sobre | Modal/form | Dashboards KPI |
|---|---|---|---|---|---|---|---|---|---|---|
| **1. Dashboards de RH com ação e dado de pessoa (prioridade alta)** | | | | | | | | | | |
| `kpis/rh/ferias.html` | `governanca-kpis-rh-ferias` | 3 | 6 | 4 | ✅ 08/11 | ⏳ | ⏳ | ⏳ | — | ⏳ |
| `kpis/rh/recrutamento.html` | `governanca-kpis-rh-recrutamento` | 7 | 21 | 17 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/doc.html` | `governanca-kpis-rh-doc` | 4 | 13 | 22 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/rh/admissao.html` | `governanca-kpis-rh-admissao` | 3 | 15 | 18 | ⏸ item 3 (cliente próprio) | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/rh/desligamentos.html` | `governanca-kpis-rh-desligamentos` | 3 | 11 | 13 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/sancoes.html` | `governanca-kpis-rh-sancoes` | 2 | 6 | 6 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/ces.html` | `governanca-kpis-rh-ces` | 2 | 6 | 4 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/folha.html` | `governanca-kpis-rh-folha` | 2 | 3 | 4 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/rh/beneficios.html` | `governanca-kpis-rh-beneficios` | 6 | 10 | 20 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/medicina.html` | `governanca-kpis-rh-medicina` | 3 | 5 | 4 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/performance.html` | `governanca-kpis-rh-performance` | 4 | 6 | 27 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/experiencias.html` | `governanca-kpis-rh-experiencias` | 3 | 4 | 2 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/rh/absenteismo.html` | `governanca-kpis-rh-absenteismo` | 3 | 4 | 4 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/bancodehoras.html` | `governanca-kpis-rh-bancodehoras` | 0 | 0 | 1 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/ouvidoria.html` | `governanca-kpis-rh-ouvidoria` | 2 | 3 | 3 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/escalas.html` | `governanca-app-escala` | 3 | 10 | 27 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/armarios.html` | `governanca-kpis-rh-armarios` | 5 | 8 | 9 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/rh/estoqueadm.html` | `governanca-kpis-rh-estoqueadm` | 6 | 10 | 8 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/rh/agenda.html` | `governanca-kpis-rh-agenda` | 0 | 3 | 7 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/rh/feriados.html` | `governanca-kpis-rh-feriados` | 3 | 4 | 2 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/hc.html` | `governanca-kpis-rh-hc` | 4 | 5 | 7 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/solicitacoes.html` | `governanca-kpis-rh-solicitacoes` | 3 | 4 | 2 | 🔶 parcial (Etapa 5) | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/demandas.html` | `governanca-kpis-rh-demandas` | 0 | 0 | 1 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/reclamacoes.html` | `governanca-kpis-rh-reclamacoes` | 2 | 4 | 3 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/semanal.html` | `governanca-kpis-rh-semanal` | 3 | 3 | 3 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/rh/sam.html` | `governanca-kpis-rh-sam` | 2 | 2 | 0 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/rh/cei.html` | `governanca-kpis-rh-cei` | 2 | 2 | 5 | ⏳ | ⏳ | ⏳ | ⏳ | — | — |
| `kpis/rh/ted.html` | `governanca-kpis-rh-ted` | 2 | 2 | 1 | ⏳ | ⏳ | ⏳ | ⏳ | — | — |
| `kpis/rh/comunicacao.html` | `governanca-kpis-rh-comunicacao` | 2 | 2 | 1 | ⏳ | ⏳ | ⏳ | ⏳ | — | — |
| **2. Dashboards operacionais (compras, estoque, limpeza, manutenção, Tatá House, parceiros)** | | | | | | | | | | |
| `kpis/compras/abastecimento.html` | `governanca-kpis-compras-abastecimento` | 6 | 15 | 0 | ⏸ item 3 (cliente próprio) | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/estoque/estoque_semanal.html` | `governanca-kpis-estoque-semanal` | 3 | 5 | 6 | ✅ 08/11 | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/limpeza/checklist-limpeza.html` | `governanca-kpis-limpeza-checklist` | 2 | 3 | 4 | ✅ 08/11 | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `kpis/manutencao/index.html` | `governanca-kpis-manutencao` | 3 | 7 | 4 | ✅ 08/11 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `kpis/tatahouse/cardapio.html` | `governanca-kpis-tatahouse-cardapio` | 5 | 11 | 15 | ✅ 08/11 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `ps.html` | `governanca-parceiros-sistemas` | 3 | 7 | 3 | ✅ 08/11 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| **3. Auditoria e organograma** | | | | | | | | | | |
| `auditoria/paginas.html` | `governanca-auditoria-paginas` | 2 | 3 | 2 | ✅ 08/11 | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `auditoria/docsrh.html` | `governanca-auditoria-docsrh` | 2 | 3 | 2 | ✅ 08/11 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| `areas/organograma.html` | `governanca-areas-organograma` | 0 | 1 | 5 | ✅ 08/11 (Linha: exceção, árvore inteira) | ⏳ | ⏳ | ⏳ | ⏳ | — |
| **4. Menus (cards com data-access-id) — entram juntos na Etapa 2+3** | | | | | | | | | | |
| `areas/institucional/index.html` | `governanca-institucional` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| `auditoria/index.html` | `governanca-auditoria` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| `conceitos/index.html` | `governanca-conceitos` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| `index.html` | `governanca` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| `kpis/estoque/index.html` | `governanca-kpis-estoque` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| `kpis/index.html` | `governanca-kpis` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| `kpis/limpeza/index.html` | `governanca-kpis-limpeza` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| `kpis/rh/index.html` | `governanca-kpis-rh` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| `kpis/tatahouse/index.html` | `governanca-kpis-tatahouse` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| `menucompliance.html` | `governanca-menu` | 0 | 0 | 0 | ⏸ Etapa 2+3 | ⏳ | ⏳ | ⏳ | — | — |
| **5. Conteúdo institucional e conceitos (só nível Página; sem função de dado)** | | | | | | | | | | |
| `areas/institucional/idconceitual.html` | `governanca-institucional-idconceitual` | 0 | 0 | 0 | ✅ 08/11 (só página) | ⏳ | ⏳ | ⏳ | — | — |
| `areas/institucional/idvisual.html` | `governanca-institucional-idvisual` | 0 | 0 | 0 | ✅ 08/11 (só página) | ⏳ | ⏳ | ⏳ | — | — |
| `areas/institucional/papelaria.html` | `governanca-institucional-papelaria` | 0 | 1 | 1 | ✅ 08/11 | ⏳ | ⏳ | ⏳ | ⏳ | — |
| `areas/rh/papeis.html` | `governanca-areas-rh-papeis` | 0 | 0 | 0 | ✅ 08/11 (só página) | ⏳ | ⏳ | — | — | — |
| `areas/rh/ouvidoria-qrcode.html` | `governanca-areas-rh-ouvidoria-qrcode` | 0 | 0 | 0 | ✅ 08/11 (só página) | ⏳ | ⏳ | — | — | — |
| `areas/tatahouse/papeis.html` | `governanca-areas-tatahouse-papeis` | 0 | 0 | 0 | ✅ 08/11 (só página) | ⏳ | ⏳ | — | — | — |
| `conceitos/5s.html` | `governanca-conceitos-5s` | 0 | 0 | 0 | ✅ 08/11 (só página) | ⏳ | ⏳ | ⏳ | — | — |
| `conceitos/governanca.html` | `governanca-conceitos-governanca` | 0 | 0 | 0 | ✅ 08/11 (só página) | ⏳ | ⏳ | ⏳ | — | — |
| `conceitos/kanban.html` | `governanca-conceitos-kanban` | 0 | 0 | 0 | ✅ 08/11 (só página) | ⏳ | ⏳ | ⏳ | — | — |

## Ordem sugerida para a skill de acessos

1. **Grupo 1** (RH) fica por último: só quando o dono pedir (decisão de 08/11/2026). Dentro dele, primeiro as páginas com ação e dado sensível — Sanções, Documentos, Recrutamento, Desligamentos, Cargos e Salários, Folha, Benefícios, Medicina, Performance — depois as demais.
2. **Grupo 2**: Manutenção e Parceiros & Sistemas feitos. Abastecimento, Estoque semanal e Checklist de limpeza: **liberados pelo dono em 08/11** (item 3, cliente próprio) — um PR por página, tudo pela porta do servidor, sem Apps Script (não existe mais).
3. **Grupo 3**: Auditoria e Organograma — feito em 08/11 (migration 20261130). Organograma: **Linha é exceção** (mostra a árvore inteira; decisão do dono, 08/11). A máscara de **saúde** (próximo exame) é da função compartilhada com Medicina e entra na passagem dessa página (grupo 1).
4. **Grupo 4**: todos os menus de uma vez, junto com a camada de acesso (Etapa 2+3). **Só depois que a skill do `gate.js` estiver pronta** (decisão do dono, 08/11).
5. **Grupo 5**: só conferir página e gate; não têm função de dado — conferido em 08/11 (gate, `GOV_PAGE_ID` e catálogo ok nas oito). Papelaria corrigida em 08/11: o papel timbrado pré-preenche unidade e departamento por função do servidor (só os dados da própria pessoa; migration 20261201), sem planilha publicada.

**Números do drawer Sobre:** leem uma view direto; o dono decidiu **não mexer** (08/11).

## Histórico

- 08/11/2026 — Checklist de limpeza pelo servidor (migration 20261203): removido o cliente próprio e o bloco morto de inventário/estoque (sem aba nem botão); KPIs conferem a página, relatório confere o botão; lista de colaboradores fecha para anon.
- 08/11/2026 — Estoque semanal pelo servidor (migration 20261202): sem cliente próprio, catálogo e estoque mínimo por função com porta da página, cadastro/contagem/pedido automático por função com porta do botão e autor do login.
- 08/11/2026 — Decisões do dono: menus só depois da skill do gate; Abastecimento, Estoque semanal, Checklist e Papelaria corrigir (sem Apps Script); Organograma é exceção ao nível Linha; números do drawer não mexer. Papelaria corrigida (migration 20261201).
- 08/11/2026 — Grupo 5 conferido (só página): sete páginas ✅; Papelaria aguarda o item 3.
- 08/11/2026 — Auditoria de páginas, Auditoria de documentos e Organograma (grupo 3) para a skill de acessos (migration 20261130): porta da página e do botão no servidor, nascimento não sai mais do servidor, nada para anon.

- 08/11/2026 — Manutenção e Parceiros & Sistemas (grupo 2) concluídos para a skill de acessos (migrations 20261128 e 20261129).
- 08/11/2026 — Férias (piloto do nível Linha), Cardápio Tatá House e ouvidoria-qrcode concluídos para a skill de acessos. Etapas 1 e 5 (código morto; identidade e fim do sandbox) aplicadas em todas as páginas — por isso várias estão "parcial": falta a passagem página a página de botão, Linha e máscaras.
