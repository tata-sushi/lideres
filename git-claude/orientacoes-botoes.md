# Orientações — migrar os BOTÕES do front do Portal Líderes

**Para:** outro agente.
**Tarefa:** aplicar o **padrão canônico de botões** (já definido) nas páginas do portal — a **migração do front-end**. Você **NÃO** cria o padrão: ele já existe.

## Fonte da verdade (já pronta — só seguir)
- **Skill:** `.claude/skills/botoes/SKILL.md` — o conjunto `.btn` + modificadores, estados, loading e o **mapa de migração** completo.
- **Catálogo visual:** `git-claude/catalogo-botoes.html` — como cada botão/estado deve ficar.

## O que fazer
Trocar as ~40 classes antigas de botão pelas canônicas, página por página (ou por grupo pequeno), **sem mudar o comportamento**. Use a tabela "classe antiga → nova" da skill `botoes` (§5). Resumo:
- `btn-gerar`/`btn-primary`/`modal-btn-save`/`btn-submit`/`btn-avaliar`/`btn-nova`/… → `.btn.btn--primary` (+ `.btn--block` se full-width, `.btn--sm` se de tabela).
- `btn-cancel`/`modal-btn-cancel`/`btn-secondary`/`btn-show-more`/… → `.btn.btn--primary` (⚠️ o botão **secundário foi descartado** — ações tipo "Cancelar"/"Ver mais" usam o **primário**).
- `modal-btn-del`/`btn-excluir`/`tool-delete-btn` → `.btn--danger` ou `.btn-icon--naked` vermelho.
- `btn-clear` → `.btn-link`. `btn-ver-mais` → `.btn--primary` (paginação) ou `.btn--primary.btn--pill` (CTA).
- `btn-editar`/`btn-dt-edit` → `.btn-icon--primary`; `tbl-fotos-btn` → `.btn-icon--ghost`; `btn-copia-card`/`chart-info-btn` → `.btn-icon--naked`.
- **Raio 6px**, DM Mono 10px uppercase, loading com `.btn-spin`/`btnRot`/`setBtnLoading` + gerúndio.

## Regras / cuidados (IMPORTANTES)
1. **NÃO quebrar o comportamento:** preserve TODOS os `onclick="…"`, os `id="…"` referenciados pelo JS, e os `data-aba-id`/`data-botao-id` (controle de acesso — skill `controle-acesso-abas-botoes`). Só troque as **classes CSS** e, se precisar, adicione o CSS do `.btn` na página.
2. **NÃO mexer** em `.header-plus` (header), `.tab-btn`/`.dash-subtab` (abas) nem `.drawer-sam-btn` (drawer) — são botões de componente, têm skill própria (header-abas-footer / dashboards-kpi-graficos / drawer-sobre).
3. **Loading:** onde hoje usa `.spin`/`.ns-spin`/`rot`/`setLoad`, padronize pra `.btn-spin`/`btnRot`/`setBtnLoading` (mantendo o gerúndio). Onde o loading é overlay de página (`.loading-overlay`), **deixe como está** (é padrão de página, readmeload.md).
4. **Fechar modal:** se a página fecha modal clicando fora (manutenção faz), alinhe com o padrão do `modal-formulario` (fecha só no ✕/Esc) **só se o usuário pedir** — não é parte da migração de botão.
5. **Valide o JS** (`node`, sem erro de sintaxe) e **teste os estados** (hover/disabled/loading) antes de commitar.
6. **Um PR por página ou grupo pequeno** (facilita revisão e reduz conflito).
7. **⚠️ Tem outros agentes no repo:** reancore em `origin/main` antes de cada commit; se divergir, stash/rebase sem sobrescrever trabalho alheio.
8. **Mostre o antes/depois pro usuário** e **só faça squash-merge com "merge" explícito** dele. Rodapé de atribuição do Claude Code nos commits/PR.

## Decisões já travadas (não reabrir)
- Raio **6px**. Padrão **novo + migração** (sem reinventar classes). O `.btn-help` âmbar (`#E8A020`) é a única cor fora da paleta — trate caso a caso, pergunte ao usuário.

## Referências (ler, não reescrever)
`compliance/kpis/rh/recrutamento.html`, `compliance/kpis/manutencao/index.html`, `compliance/areas/institucional/papelaria.html`, `git-claude/readmemodal.md`, `git-claude/readmehefdash.md`, `git-claude/readmeload.md`, e a skill `.claude/skills/botoes/SKILL.md` (+ catálogo `git-claude/catalogo-botoes.html`).
