# Padronização das chaves de acesso

Objetivo: que o **mesmo conceito use o mesmo slug em todas as páginas**. Isso deixa o
catálogo (`governanca_abas`) legível, o painel admin previsível e evita duplicar
interruptores que fazem a mesma coisa. Aplique este padrão em **toda chave nova**; para
chaves existentes, veja "Como migrar" no fim (renomear tem custo).

Para levantar o estado atual e achar divergências, rode:

```bash
python3 .claude/skills/controle-acesso-abas-botoes/scripts/auditar-acessos.py
```

## 1. Formato (revisão)

`<GOV_PAGE_ID>::<slug>` — prefixo = o `window.GOV_PAGE_ID` da página; slug em
**kebab-case** (minúsculas, sem acento, palavras separadas por `-`). Ver o `SKILL.md`.

## 2. `tipo` pela classe do elemento

Mantenha a correspondência classe → `tipo` do catálogo, para não misturar default:

| Classe no HTML | `tipo` | Default |
|---|---|---|
| `tab-btn` (aba de navegação) | `aba` | visível |
| `drawer-sam-btn`, `btn-avaliar`, `btn-copia-card`, `btn-registrar`, botões de ação | `botao` | oculto |
| (área de valor R$, sem elemento próprio) | `valor` | oculto |

## 3. Vocabulário canônico de abas

Padronize as abas comuns nestes slugs (são os mais espalhados hoje):

| Conceito | Slug canônico | Evite |
|---|---|---|
| Página "Sobre"/introdução | `sobre` | — |
| Indicadores / KPIs | **`dashboard`** | `kpis`, `indicadores`, `geral` |
| Visão analítica / tabela crua | `analitico` | — |
| Filtro "todos" | `todos` | `all` |

> **KPIs → `dashboard`.** Hoje 14 páginas usam `dashboard` e 7 ainda usam `kpis` (mais
> `geral`, `indicadores` avulsos). O rótulo visível pode continuar "KPI's"; o **slug** é
> que padroniza em `dashboard`.

## 4. Vocabulário canônico de ações (botões)

Regra geral: **`verbo-substantivo`**, verbo no infinitivo ou no par de gênero PT. Nunca
verbo "pelado" (`editar`, `excluir`) — fica ambíguo entre páginas e polui o catálogo.

| Intenção | Padrão | Exemplos bons | Evite |
|---|---|---|---|
| Criar registro | `nova-<coisa>` / `novo-<coisa>` | `nova-vaga`, `novo-candidato`, `nova-solicitacao` | `cadastrar-*`/`criar-*` para o mesmo fim |
| Editar registro | `editar-<coisa>` | `editar-vaga`, `editar-candidato`, `editar-hc` | `editar` (sem objeto) |
| Excluir/remover | `excluir-<coisa>` | `excluir-parceiro` | `excluir` (sem objeto) |
| Gerar documento/saída | `gerar-<coisa>` | `gerar-relatorios`, `gerar-cardapio`, `gerar-termos` | — |
| Exportar CSV | `exportar-csv[-<escopo>]` | `exportar-csv`, `exportar-csv-catalogo` | `extrair-csv`, `export-csv-*` (inglês) |
| Relatório (abrir/baixar) | `relatorio-<coisa>` | `relatorio-testes`, `relatorio-entregas` | `relatorios` (plural pelado) |

Notas:
- **`cadastrar-` vs `nova-/novo-`**: as duas famílias convivem hoje (`cadastrar-sistema`,
  `cadastrar-horario` × `nova-vaga`). Para chave nova, prefira `nova-/novo-` (concordância
  de gênero PT). `gerar-` é diferente: reserve para **produzir uma saída** (PDF, CSV,
  documento), não para criar registro.
- **Idioma: português.** Nada de `all`, `export`, `new`. O portal é PT.
- **Unidade/loja como aba**: use o slug da unidade (`itaim-bibi`, `pinheiros`,
  `poke-pinheiros`, `tata-house`) — mantenha a mesma grafia em todas as páginas.

## 5. Inconsistências conhecidas (estado atual)

Achadas pela auditoria — corrija **quando já for mexer na página**, seguindo §6:

- Aba de KPIs: `kpis` (abastecimento, admissao, escalas, experiencias, feriados, ferias,
  solicitacoes), `geral` (performance), `indicadores` (semanal) → `dashboard`.
- Filtro "todos": `all` (armarios, estoqueadm) → `todos`.
- Export CSV: `extrair-csv` (cardapio) e `export-csv-processamento`/`export-csv-catalogo`
  (abastecimento) → `exportar-csv[-<escopo>]`.
- Verbo pelado: `editar`, `excluir` em `ps.html` → `editar-<coisa>`, `excluir-<coisa>`.

## 6. Como migrar uma chave existente (com cuidado)

Renomear um slug **não é grátis**: o `aba_id` é a chave que casa HTML ↔ catálogo ↔
config por pessoa. Trocar só o HTML **quebra** o controle daquela chave. Faça os quatro
passos juntos, na mesma janela:

1. **HTML** (`lideres`): renomeie o `data-aba-id`/`data-botao-id` no(s) elemento(s).
2. **Catálogo** (`governanca_abas`): `update` do `aba_id` antigo → novo (ou `upsert` do
   novo + `delete` do antigo), mantendo `pagina_id`/`tipo`/`label`.
3. **Config por pessoa**: migre as linhas que referenciam o `aba_id` antigo em
   `governanca_abas_bloqueios` e/ou `governanca_abas_liberacoes` para o novo.
4. **Confira**: rode a auditoria; garanta que o novo slug some da lista de sinônimos e
   que ninguém perdeu acesso.

Se não puder tocar no Supabase agora, **não renomeie só o HTML** — deixe a chave como
está e registre a pendência. Uma chave inconsistente que funciona é melhor que uma
padronizada que quebrou o acesso.
