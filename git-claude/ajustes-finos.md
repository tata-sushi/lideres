# Ajustes finos — dashboards, página por página (a partir de 04/10/2026)

Documento vivo. O dono entra numa página, aponta o que ajustar; Claude corrige a página e, **se o ajuste servir para
outras páginas, atualiza a skill** na mesma hora e anota aqui. Merge só com "merge"/"sim" do dono.

## 1. Onde estamos

Tudo no `main`:
- **#2990** — skill `dashboards-kpi-graficos` aplicada em 33 páginas (KPIs/filtros full-bleed, chart-card + "i",
  Chart.js, tabelas com organizador + cartões no celular, pílulas pela regra "de quem é a vez").
- **#2991** — skills `botoes` (≈450 botões, regra de clique, 40px, loading canônico) e `controle-acesso-abas-botoes`
  (nomes de controle padronizados, ids novos, catálogo no Supabase) em 35 páginas.
- Antes: Desligamentos = página-piloto (#2977–#2985); regra das pílulas (#2986); Admissão Pendente (#2988).

## 2. Fluxo de cada ajuste

1. O dono diz a página e o que mudar (print ajuda).
2. Corrigir a página. Validar: `node git-claude/testes/jscheck.js <arq>`, `node git-claude/testes/oncheck.js <arq>`
   e o teste de fumaça antes × depois (`git-claude/testes/smoke.js`, instruções no topo do arquivo).
3. **Replicável?** Atualizar a skill certa e registrar na tabela da §5:
   - visual de gráfico/KPI/filtro/tabela/pílula → `.claude/skills/dashboards-kpi-graficos/` (SKILL.md ou `references/tabelas.md`);
   - botão/clique/loading → `.claude/skills/botoes/SKILL.md` (+ `git-claude/catalogo-botoes.html`);
   - id de acesso/catálogo → `.claude/skills/controle-acesso-abas-botoes/`;
   - header/abas/footer → `header-abas-footer`; drawer → `drawer-sobre`; modal → `modal-formulario`.
4. PR → merge com o "merge" do dono → sincronizar o branch com `git merge origin/main` (nunca `-s ours`: o main
   recebe commits de outras sessões).

## 3. Pendente no banco (fase 2 do #2991)

**04/10:** os 14 nomes antigos foram **desativados** (`ativo = false`): não estão em nenhum HTML nem em função do banco,
e assim somem do painel do app e da Auditoria de páginas. Falta só apagar de vez.

**04/10:** `tata_plus.gov_auditoria_salvar` criada pelo dono no SQL Editor (o MCP do Supabase cancela sozinho todo comando
com `delete` nesta sessão — quando for assim, entregue o `.sql` para o dono rodar). Testada numa transação desfeita:
recusa sem admin; botão dá a página junto; tirar a página tira as liberações dela; valor inclui e tira.

Quando o dono confirmar que o app já mostra a versão nova (ex.: "Ver mais (N)" escuro), apagar os 14 nomes antigos.
Os bloqueios antigos saem junto (FK `on delete cascade`); os novos já têm a cópia (62 bloqueios).
```sql
delete from tata_plus.governanca_abas where aba_id in (
 'governanca-kpis-compras-abastecimento::kpis','governanca-kpis-rh-admissao::kpis','governanca-app-escala::kpis',
 'governanca-kpis-rh-experiencias::kpis','governanca-kpis-rh-feriados::kpis','governanca-kpis-rh-ferias::kpis',
 'governanca-kpis-rh-solicitacoes::kpis','governanca-kpis-rh-performance::geral','governanca-kpis-rh-semanal::indicadores',
 'governanca-kpis-rh-armarios::all','governanca-kpis-rh-estoqueadm::all','governanca-kpis-tatahouse-cardapio::extrair-csv',
 'governanca-parceiros-sistemas::editar','governanca-parceiros-sistemas::excluir');
delete from tata_plus.governanca_abas_liberacoes where aba_id in (/* mesma lista — hoje 0 linhas */);
```

## 4. Decisões em aberto (do dono)

- **Pílulas que mudaram de cor** pela regra "de quem é a vez" (confirmar ou reverter): Abastecimento (Aguardando
  compra → azul; Aguardando recebimento → âmbar; Recebido → azul; Não recebido → azul; Pedido não realizado →
  vermelho), Reclamações (Acordo/Procedente → vermelho; Aguardando audiência/julgamento → âmbar), Armários
  (Manutenção → âmbar), Solicitações (Pendente → azul), Benefícios (Solicitado → azul), Documentos (Pendente → âmbar),
  Experiências (Pendente → azul), Férias (Validação → azul), Medicina (Dispensado → escuro; Agendado → âmbar).
- **Título no celular com várias listas na mesma aba** (HC KPIs): hoje some e as listas ficam coladas.
  Sugestão: manter o título quando a aba tem mais de uma lista.
- **HC:** gráfico CLT×PJ não aparece na tela (função nunca chamada) — volta?
- **Aba Sobre:** acordeão `ft-acc-header` e fluxo `hflow-*` (~29–35 páginas) ainda abrem clicando em div — decidir
  em bloco (regra de clique).
- **Filtros** (`git-claude/auditoria-filtros.md` §C): busca por nome, período em atalhos × datas, uma faixa por aba,
  filtro por clique no gráfico × "Limpar", faixa sticky, maquete (Cardápio Relatórios).
- **Tabelas sem padrão** (`git-claude/auditoria-tabelas.md` §C): matrizes do Analítico (Recrutamento, Performance,
  Documentos), tabelas operacionais largas (Recrutamento Vagas/Entrevistas/Testes, Abastecimento, Cardápio), Escalas,
  HC Headcount.
- **Escolhas de agentes a confirmar:** Feriados (opções Folga/Pagamento/Não tem direito só em texto), HC (duas
  lixeiras "Remover depto/unidade" no desktop), Agenda (texto da caixa de arquivos sem "arraste"), Experiências
  ("Avaliado" deixou de ser verde), Abastecimento ("Processar Parcialmente" saiu do âmbar).
- **Acesso — feito em 04/10/2026** (banco + HTML + app; tabela de clicar em `assets/matriz-acessos.html` da skill
  de acesso, publicada como página privada do dono):
  - Banco: tirado o acesso de 4 pessoas inativas; apagadas 3 sobras (Brainstorm "Compartilhar", Cardápio
    "Compras"/"Preços") e 3 liberações/bloqueios sem efeito. Armários `::incluir-excluir` **fica** (é conferido
    pela RPC `armario_pode_gerir`). Cópia para desfazer guardada fora do repo.
  - 27 páginas cadastradas (seção nova "Áreas & Processos", Caixa, Gorjeta, Matriz D/E/B, Ferramentas,
    Fornecedores) sem ninguém liberado, e postas no menu do app Plus. Nomes das páginas no banco iguais aos do menu.
  - **Depois:** as 21 páginas de processo antigas de `compliance/areas/**` (índices + RH + Estoque + Limpeza + Tatá
    House) foram **apagadas** — o conteúdo já estava na aba Sobre de cada dashboard (97–100% do texto). Ficam:
    `areas/rh/ouvidoria-qrcode.html` (link da Ouvidoria em 79 páginas), `papeis.html` (RH e Tatá House),
    `organograma*.html` e os PDFs/imagens. Em seguida saíram também `gestaodocs` (texto levado para a nova aba
    **Sobre** de Uniformes & EPIs), Ferramentas, Fornecedores, Caixa Pulse, Gorjeta e Matriz D/E/B (decisão do
    dono). O menu do app voltou ao que era antes (só ganhou "Papéis Tatá House").
  - 58 ids novos (12 que estavam sem cadastro + 46 de botões de ação/abas), cada botão liberado para quem já abria
    a página — ninguém perdeu nada no dia. "Enviar Cartão de Ponto" das Escalas agora obedece o painel.
  - `gate.js` busca sempre a lista do que esconder (antes, botão montado por JS escapava).
- **Acesso — pendente / para decidir:**
  - Fase 2: apagar os 14 nomes antigos (SQL na §3) quando o app mostrar a versão nova.
  - Documentos: a bolinha "✕" da aba Analítico ainda abre o anexar sem id (pôr id esconderia o indicador);
    "aplica/não aplica" + "usar padrão do cargo" estão num id só (`editar-excecao-documento`), e "quebrar
    período" + "desfazer quebra" em outro (`quebrar-periodo`) — separar exige renomear.
  - Admissão: `validar-informacao-ficha` está numa caixa de seleção (é um "aprovar").
  - Desligamentos: os 5 cartões que geram modelos em branco (pedido de demissão, acordo mútuo) ficaram sem id.
  - Escalas: sem `editar-dia` a pessoa ainda abre a janela do dia, só sem Salvar/Voltar ao padrão.
  - Férias: Validar/Aprovar ainda têm a trava antiga por perfil (RH/admin) — liberado sem esse perfil vê o
    botão desabilitado.
  - Botão escondido deixa rodapé/coluna de ações vazio (Cardápio, ficha de Armários, cartão de Desligamentos,
    ficha de Cargos) — só visual.
  - Código morto achado: Semanal "Editar" HC (desenha em `#content`, que não existe), Admissão e Limpeza (janelas
    de estoque que nada abre), Cardápio `modal-servir`, Medicina "Editar Exame", Férias `openDevModal`.

## 5. Ajustes feitos nesta fase (e o que foi para as skills)

| Data | Página | Ajuste | Skill atualizada? |
|---|---|---|---|
| 04/10 | Auditoria de páginas | Busca sai da grade de filtros e vai para a faixa própria abaixo de "Limpar filtros" (input branco sobre cinza, sem rótulo), como no Analítico do Recrutamento; filtros em 3 colunas | `dashboards-kpi-graficos` (SKILL.md, regra do campo de busca) |
| 04/10 | Auditoria de páginas | Total passa a contar os admins (= soma das ● da linha); aba "Auditoria" vira "Analítico" (slug `::analitico`, catálogo atualizado no banco) | `dashboards-kpi-graficos` (`tabelas.md` §4) + `controle-acesso-abas-botoes` (backend) |
| 04/10 | Banco | Apagada a página `governanca-kpis-brainstorm` (sem arquivo) e os 3 acessos dela; a do app (`governanca-app-brainstorm`) fica | — |
| 04/10 | Organograma 2 | Fica aberto, sem `GOV_PAGE_ID`/gate, por decisão do dono | `controle-acesso-abas-botoes` (exceção + `estado-acessos.py`) |
| 04/10 | Auditoria de páginas | Bolinha dos admins (e de quem vê valores de todas as áreas) em carbon, igual às demais — sem cinza; "i" e Sobre sem a linha do ● cinza | `dashboards-kpi-graficos` (`tabelas.md` §4) + `controle-acesso-abas-botoes` |
| 04/10 | Auditoria de páginas | Sai o aviso verde "Salvo…" em cima da tabela; a confirmação de salvar vira o alerta do navegador (padrão do portal) | `modal-formulario` (regra "Salvou") |
| 04/10 | Auditoria de páginas | Seletor do colaborador só com o nome (sem cargo, unidade, contagem e grupos), em ordem alfabética | `dashboards-kpi-graficos` (`tabelas.md` §4) + `controle-acesso-abas-botoes` |
| 04/10 | Auditoria de páginas | Colunas em ordem alfabética, admins junto e sem "admin" no nome; sem lápis no cabeçalho. Editar por colaborador vira botão na 1ª linha da tabela (ícone de pessoas no computador, "Colaborador" no celular) e a janela ganha seletor do colaborador; Menu › "Editar por colaborador" | `dashboards-kpi-graficos` (`tabelas.md` §4) + `controle-acesso-abas-botoes` + `botoes` (ícone pessoas) |
| 04/10 | Auditoria de páginas | Admins nas últimas colunas (● cinza = vê automaticamente); lápis do cabeçalho sempre no topo | `dashboards-kpi-graficos` (`tabelas.md` §4) + `controle-acesso-abas-botoes` |
| 04/10 | Auditoria de páginas | Edição por colaborador: lápis em cima do nome (computador) e Menu › "Adicionar ou editar colaborador" (qualquer tela); janela com tudo da pessoa em cascata e chaves | `controle-acesso-abas-botoes` |
| 04/10 | Auditoria de páginas (banco) | Sem seção "Admin": Auditoria, Auditoria de páginas e Gestão de Documentos passam para a seção **Compliance** (como no menu do app), ordem 730/740/750, depois de Parceiros & Sistemas | — (banco) |
| 04/10 | Auditoria de páginas | Cabeçalho "Página" centralizado; KPIs viram 2 cards: Páginas (abas / botões) e Acessos liberados (admins) | — (página) |
| 04/10 | Auditoria de páginas | Total em coluna própria, entre o último colaborador e Editar (saiu da célula do nome); coluna dos nomes no celular volta a 195px | `dashboards-kpi-graficos` (`tabelas.md` §4) |
| 04/10 | Auditoria de páginas | Pílula "Página" azul; linhas verticais entre as colunas (contínuas nas seções); tabela na largura toda (1ª coluna fixa 260px / 212px no celular) | `dashboards-kpi-graficos` (`tabelas.md` §4) |
| 04/10 | Auditoria de páginas | Desktop também sem cartão branco; "i" no cabeçalho "Editar" (canto superior direito); seções em cascata só pelo recuo (seção › subseção › página › item); pílulas aba azul · botão âmbar · valor carbon | `dashboards-kpi-graficos` (`tabelas.md` §4) + `controle-acesso-abas-botoes` |
| 04/10 | Auditoria de páginas | Sem a legenda em cima da tabela (fica no "i" e no Sobre); nome da seção preso na 1ª coluna, não rola de lado com os nomes | — (página) |
| 04/10 | Auditoria de páginas | Tabela no padrão: no celular direto no fundo cinza (sem fundo branco, título e "i") e "Editar" em texto; no desktop, lápis | `dashboards-kpi-graficos` (`tabelas.md` §4) |
| 04/10 | Auditoria de páginas (nova) | Página nova em Compliance: abas Sobre e Auditoria; grade páginas × colaboradores ao vivo (linha da página + abas/botões/valores), pílula do tipo à direita do nome, lápis na última coluna (fixa à direita) para incluir/excluir. RPCs `gov_auditoria_acessos`/`gov_auditoria_salvar`. Menu do app: "Auditoria de páginas" abre a página nova. Drawer: 19 pág / 36 dash | `controle-acesso-abas-botoes` (SKILL.md + backend) + `drawer-sobre` |
| 04/10 | (todas) | Relatório "ids × quem vê" (por página, por pessoa, pontos de atenção) — fica fora do repo (nomes) | `controle-acesso-abas-botoes`: `scripts/relatorio-acessos.py` + SKILL.md |
| 04/10 | (todas) | Botões que começam uma ação ganharam id (46) + cadastro/liberação no banco; Escalas: ordem do `comSupa` corrigida | `controle-acesso-abas-botoes`: SKILL.md §"Que botões levam id", backend §SQL modelo |
| 04/10 | (todas) | Tabela de clicar (Página · Abas · Botões · Valor) — o dono marca, o Claude aplica | `controle-acesso-abas-botoes`: `assets/matriz-acessos.html`, `scripts/estado-acessos.py`, backend §"Tabela de acessos" |
| 04/10 | (todas) | Valor em R$ não tem bypass de admin (corrigido na skill) | `controle-acesso-abas-botoes`: SKILL.md + backend |
| 04/10 | (portal) | Apagadas 21 páginas antigas de `areas/**`; ids de desligamentos escritos por inteiro; auditoria e relatório leem chaves escritas no JS | `controle-acesso-abas-botoes` (scripts) + `botoes` §4 (`_acao(chave…)`) |
| 04/10 | Uniformes & EPIs | Ganhou a aba **Sobre** (padrão das outras: abre nela) com o texto de Gestão de Estoque e Documentos; 6 páginas antigas apagadas | — (página) |
| 04/10 | (todas) | Ações de linha de tabela: varridas 21 páginas — todas já eram ícone (só Desligamentos tinha texto). Mesmo desenho para a mesma ação: Enviar devolutiva = avião (Absenteísmo, Feriados), Avaliar = prancheta (Experiências, Performance); `aria-label` em 31 ícones (Documentos, Escalas, Recrutamento, Cardápio) | `botoes` §3: +8 ícones (baixar, avaliar, filtrar, tirar filtro, agendar, remarcar, validar, aprovar) e lixeira = desenho do portal |
| 04/10 | (todas, 33 com botões) | Botões no padrão novo por script: peso 400, 34px no celular, ícone 28×28 (desktop: canto 4px, desenho 12px), "Ver mais" 24px no desktop. Drawer: 19 pág / 35 dash em 52 páginas | `botoes` (já tinha) + `drawer-sobre` (conta nova) |
| 04/10 | Desligamentos (piloto, 3ª rodada) | Desktop (opção B do dono): ícone com desenho 12px e canto 4px; "Ver mais" fonte 8px e canto 4px. Celular sem mudança | `botoes` §1/§3 + catálogo + orientações |
| 04/10 | Desligamentos (piloto, 2ª rodada) | Ícone 28×28; "Ver mais" 40% menor no desktop (24px, fonte 9px); botão de texto 34px no celular | `botoes` §1/§3/§4 + catálogo + orientações + `tabelas.md` |
| 04/10 | Desligamentos (piloto) | Botões: peso 400 (era negrito falso), 36px no celular, ícone 30×30; ações da tabela no desktop viram ícone (avião/corrente/copiar/balão/seta) e coluna Ações estreita | `botoes` (§1, §3 tabela de ícones, §4 ações de linha) + `catalogo-botoes.html` + `orientacoes-botoes.md` + `dashboards-kpi-graficos/references/tabelas.md` |

## 6. Bugs achados e ainda não corrigidos (regra de negócio)

- Ouvidoria: datas `AAAA-MM-DD` lidas em UTC → ocorrência do dia 1º pode cair no mês anterior.
- Estoque ADM: alerta "Itens zerados" nunca aparece (compara objeto com 0).
- Feriados: "Não tem direito" aparece como "Pendente" ao escolher um feriado.
- Escalas: trocar Departamento/semana não redesenha os KPIs até trocar de aba.
- Documentos: ids duplicados `dl-btn`/`dl-progress`/`dl-erro` entre os modais Baixar e Lote.
- Admissão: o ✕ de cancelar edição de item chama `_carregarFicha` (privada) → ReferenceError.
