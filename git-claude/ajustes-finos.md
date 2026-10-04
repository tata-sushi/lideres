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
- **Título no celular com várias listas na mesma aba** (Caixa, HC KPIs): hoje some e as listas ficam coladas.
  Sugestão: manter o título quando a aba tem mais de uma lista.
- **HC:** gráfico CLT×PJ não aparece na tela (função nunca chamada) — volta?
- **Aba Sobre:** acordeão `ft-acc-header` e fluxo `hflow-*` (~29–35 páginas) ainda abrem clicando em div — decidir
  em bloco (regra de clique).
- **Filtros** (`git-claude/auditoria-filtros.md` §C): busca por nome, período em atalhos × datas, uma faixa por aba,
  filtro por clique no gráfico × "Limpar", faixa sticky, maquetes (Gorjeta, Cardápio Relatórios).
- **Tabelas sem padrão** (`git-claude/auditoria-tabelas.md` §C): matrizes do Analítico (Recrutamento, Performance,
  Documentos), tabelas operacionais largas (Recrutamento Vagas/Entrevistas/Testes, Abastecimento, Cardápio), Escalas,
  HC Headcount.
- **Escolhas de agentes a confirmar:** Feriados (opções Folga/Pagamento/Não tem direito só em texto), HC (duas
  lixeiras "Remover depto/unidade" no desktop), Agenda (texto da caixa de arquivos sem "arraste"), Experiências
  ("Avaliado" deixou de ser verde), Abastecimento ("Processar Parcialmente" saiu do âmbar).
- **Acesso (relatório "ids × quem vê", 04/10/2026 — `scripts/relatorio-acessos.py` da skill de acesso):**
  - 12 ids na página sem registro no banco: 11 em páginas de Áreas/RH, Ferramentas e Fornecedores, e o
    "Enviar Cartão de Ponto" das Escalas, que hoje aparece para todos que abrem Escalas.
  - 27 páginas declaram `GOV_PAGE_ID` mas não estão no cadastro de páginas → só admins entram (Áreas/RH,
    Caixa, Gorjeta, Ferramentas, Fornecedores…). Cadastrar ou confirmar que saíram de uso.
  - 5 ids só no banco, sem botão na página: Brainstorm "Compartilhar", Armários "Incluir/Excluir armário",
    Estoque ADM "Enviar para Assinatura Digital", Cardápio "Compras" e "Preços" (esses 2 já desativados).
  - 4 pessoas inativas ainda com acesso a páginas; 3 liberações/bloqueios sem efeito (pessoa sem a página).
  - 9 páginas cadastradas que só admins abrem (Agenda, Documentos, Ouvidoria, Reclamações, Semanal, P&S…).

## 5. Ajustes feitos nesta fase (e o que foi para as skills)

| Data | Página | Ajuste | Skill atualizada? |
|---|---|---|---|
| 04/10 | (todas) | Relatório "ids × quem vê" (por página, por pessoa, pontos de atenção) — fica fora do repo (nomes) | `controle-acesso-abas-botoes`: `scripts/relatorio-acessos.py` + SKILL.md |

## 6. Bugs achados e ainda não corrigidos (regra de negócio)

- Ouvidoria: datas `AAAA-MM-DD` lidas em UTC → ocorrência do dia 1º pode cair no mês anterior.
- Estoque ADM: alerta "Itens zerados" nunca aparece (compara objeto com 0).
- Feriados: "Não tem direito" aparece como "Pendente" ao escolher um feriado.
- Escalas: trocar Departamento/semana não redesenha os KPIs até trocar de aba.
- Documentos: ids duplicados `dl-btn`/`dl-progress`/`dl-erro` entre os modais Baixar e Lote.
- Admissão: o ✕ de cancelar edição de item chama `_carregarFicha` (privada) → ReferenceError.
