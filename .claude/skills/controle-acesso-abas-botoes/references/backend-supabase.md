# Backend e painel admin (Supabase `tata_plus`)

O HTML (repo `lideres`) só **declara** as chaves. Quem guarda o catálogo, resolve o
acesso por pessoa e oferece os interruptores é o **Tatá Plus** (repo `tata-sushi/plus`,
Supabase project `aoqsbusfrffapjglpqjk`, schema `tata_plus`). Leia isto antes de mexer
no Supabase ou no painel de administração.

Fonte de verdade original: `tata-sushi/plus` → `README.md` (seção "Configurar os
controles de uma página: abas, botões e valores") e `src/components/AdminGovernanca.jsx`.

## Tabelas

| Tabela | Papel |
|---|---|
| `governanca_paginas` | catálogo de páginas (`pagina_id` = `GOV_PAGE_ID`, `label`, `url`, `secao`, `sub`, `ordem`, `ativo`) |
| `governanca_acessos_paginas` | acesso à **página** por pessoa (`matricula`, `pagina_id`) |
| `governanca_abas` | catálogo dos controles internos — **`aba_id` (PK)**, `pagina_id`, `label`, `tipo`, `ordem`, `ativo` |
| `governanca_abas_bloqueios` | denylist por pessoa das **abas** (`tipo='aba'`) |
| `governanca_abas_liberacoes` | allowlist por pessoa dos **botões** (`tipo='botao'`) |
| `dp_rh.perm_ver_valores` | liberação de **valores** em R$ por área (`area`, `liberado`) |

O `aba_id` de `governanca_abas` **tem que ser idêntico** ao `data-aba-id`/`data-botao-id`
do HTML. Se divergir, o interruptor do painel não controla nada.

`tipo` decide o comportamento default:

| `tipo` | default | tabela por pessoa | inserir a linha… |
|---|---|---|---|
| `aba`   | **visível** (denylist / opt-out) | `governanca_abas_bloqueios`  | **esconde** aquela aba pra pessoa |
| `botao` | **oculto** (allowlist / opt-in)  | `governanca_abas_liberacoes` | **libera** aquele botão pra pessoa |
| `valor` | **oculto** (opt-in, por área)    | `dp_rh.perm_ver_valores`     | libera ver o valor (`liberado=true`) |

O `tipo` sai da classe do elemento no HTML: `tab-btn` → `aba`; botões de ação
(`drawer-sam-btn`, `btn-avaliar`, `btn-copia-card`, `btn-registrar`…) → `botao`.

Em `tipo='valor'` o `aba_id` **é a própria área** (ex.: `recrutamento`), **sem** o
prefixo `pagina_id::`; o valor é mascarado no servidor (salário etc.), não por CSS.

## RPCs

**Consumidas pela página** (schema `tata_plus`, via `window.__lideresSupa`):
- `gov_meus_acessos` — páginas que a pessoa vê (resolve o gate + destrava cards do menu).
- `gov_minhas_abas_bloqueadas` — lista de `aba_id` a **esconder** para a pessoa; é o que
  o `gate.js` aplica sobre todo `[data-aba-id]`. (O servidor já dobra os `tipo='botao'`
  aqui: eles voltam como "a esconder" até existir a liberação.)
- `pode_botao({ p_aba_id })` — usada pelo modelo `data-botao-id` (ex.: `escalas.html`);
  devolve `true`/`false` por botão. Guarde em `GOV_BTN_OK` e **cheque na ação**.

**Consumidas pelo painel admin** (`AdminGovernanca.jsx`, restritas a admin):
- Catálogo: `gov_catalogo`, `gov_catalogo_abas`, `gov_admin_pessoas`.
- Leitura por pessoa: `gov_admin_acessos`, `gov_admin_abas_bloqueios`,
  `gov_admin_botoes_liberados`, `perm_valores_areas`.
- Escrita por pessoa: `gov_admin_set`, `gov_admin_abas_set`, `gov_admin_botoes_set`,
  `perm_valores_sync`.
- Outras: `gov_admin_zerar_acessos` (zera tudo da pessoa), `admin_resetar_senha`.

## Registrar/atualizar os controles de uma página

Depois de pôr as chaves no HTML, cadastre-as no catálogo → **`upsert` em
`governanca_abas`** (on conflict `aba_id`) com `pagina_id`, `label`, `tipo`, `ordem`.
Só isso: o admin e a página passam a enxergar **na hora** (leitura ao vivo, sem deploy).
Sem o registro, o atributo no HTML existe mas **não aparece como interruptor** no painel.

Para extrair as chaves de uma página e conferir contra o catálogo, rode o script de
auditoria (`scripts/auditar-acessos.py`) ou:

```bash
grep -o 'data-aba-id="[^"]*"'   compliance/kpis/rh/recrutamento.html | sort -u
grep -o 'data-botao-id="[^"]*"' compliance/kpis/rh/escalas.html      | sort -u
```

## ⚠️ Cuidados ao configurar acesso

- **Admin (`perfil='admin'`) vê tudo** — não precisa de liberação em `aba`/`botao`.
  (Exceção: as features da seção **App** — Kanban/Escala/Limpeza — **não têm bypass de
  admin**; até admin precisa do grant.)
- **Os setters `gov_admin_*_set` fazem REPLACE TOTAL por pessoa**: apagam **todos** os
  acessos daquela pessoa e reinserem só o que a UI mandou. Servem para a tela de **uma**
  pessoa — **nunca** para operação em massa.
- **Replicar a config de uma pessoa para outras** (ex.: copiar a config de um líder pros
  demais) **sem apagar o resto**: mexa **direto nas tabelas**, sempre **filtrando pela
  página** (`aba_id like '<pagina_id>::%'`, `pagina_id=…`, `area=…`) — nunca os setters de
  replace total. Por pessoa-alvo: (1) garanta a linha em `governanca_acessos_paginas`;
  (2) `delete`+`insert` dos bloqueios de aba **da página**; (3) idem das liberações de
  botão; (4) acerte `dp_rh.perm_ver_valores` da **área**. Assim só aquela página é tocada.
- Renomear um `aba_id` no HTML sem atualizar `governanca_abas` (e as tabelas por pessoa)
  **órfã** a config: o interruptor antigo deixa de casar e o controle para de funcionar.
