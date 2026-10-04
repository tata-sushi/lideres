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

**Consumidas pela página Auditoria de páginas** (`compliance/auditoria/paginas.html`, só admin — `pode_publicar()`):
- `gov_auditoria_acessos()` → `jsonb` com tudo de uma vez: `pessoas` (ativas: m, nome, cargo, unidade, admin),
  `paginas` (ativas), `itens` (catálogo **ativo**), `acessos`, `bloqueios`, `liberacoes`, `valores` (pares
  `[matricula, id]`).
- `gov_auditoria_salvar(p_tipo, p_item, p_incluir[], p_tirar[])` → grava uma linha (SQL na §"Página Auditoria de páginas").

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

- **Admin (`perfil='admin'`) vê tudo** — não precisa de liberação em `aba`/`botao`. **Valor é exceção:**
  `pode_ver_valores(area)` só olha `dp_rh.perm_ver_valores` (a área ou `geral`); admin sem linha lá não vê R$.
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
- **Antes de apagar um id "só no banco"** (está no catálogo e não aparece no HTML), procure se uma função usa a
  chave: `select proname from pg_proc where pg_get_functiondef(oid) like '%<slug>%'`. Ex.: Armários
  `::incluir-excluir` não tem botão próprio — é conferido pela RPC `armario_pode_gerir`.
- **Id novo em botão que já existia:** cadastre o catálogo **e** libere para quem já abre a página **no mesmo
  comando** (senão o botão some para todo mundo no meio do caminho). Modelo:
  ```sql
  insert into tata_plus.governanca_abas (aba_id,pagina_id,label,tipo,ordem,ativo) values (...) on conflict do nothing;
  insert into tata_plus.governanca_abas_liberacoes (matricula,aba_id)
  select g.matricula, v.aba_id from (values ('<pagina>::<slug>','<pagina>')) v(aba_id,pagina_id)
  join tata_plus.governanca_acessos_paginas g on g.pagina_id=v.pagina_id
  join tata_plus.profiles p on p.matricula=g.matricula and p.status='Ativo' and coalesce(p.perfil,'')<>'admin'
  on conflict do nothing;
  ```
- **`gate.js` busca sempre a lista do que esconder** (desde 04/10/2026): botões montados depois pelo JS (linha,
  cartão, ficha) também podem levar `data-aba-id`.

## Tabela de acessos (o dono clica, o Claude aplica)

Página privada no claude.ai (Artifact com capacidade `db`) feita de `assets/matriz-acessos.html` + um
`estado.json` publicado junto. Visões:
- **Por página** — colunas Página · Abas · Botões · Valor, cada uma com as pessoas e "+ Incluir".
- **Por pessoa** — para um colaborador: páginas que abre, e em cada página as abas (✓ vê / – bloqueada), os
  botões (✓ liberado / – não) e os valores R$; páginas sem abas/botões num cartão só; "Páginas que não abre"
  com "+ Dar página". Admin: só as telas da seção App e os valores (o resto ele já vê).
- **Ids das páginas** — quais páginas têm ids (abas, botões, valor), quantas pessoas abrem e, ao abrir,
  cada id com quantos veem; filtro "Pedem atenção" mostra página no banco sem arquivo, id sem cadastro e
  HTML do repo sem `GOV_PAGE_ID` (`semId`) ou com id fora do banco (`foraDoBanco`).
- **Páginas × pessoas** — grade com uma coluna por pessoa (sem os admins). Em cada seção, a linha da página
  (quem abre) e, logo abaixo, uma linha por aba / botão / valor (● vê · ○ não vê · vazio = não abre a página);
  tocar no nome da página abre/fecha as linhas dela, "Só páginas" fecha todas, tocar no nome da pessoa leva
  para a visão Por pessoa.
- **Mudanças** — lista do que foi marcado.

Cada clique grava um documento na coleção `mudancas` da página — nada vai para o banco sozinho.

1. **Gerar o estado:** dump do banco (SQLs no topo de `scripts/relatorio-acessos.py`, confira contagens) →
   `python3 scripts/estado-acessos.py <pasta_dump> <scratchpad>/estado.json [raiz]` (use como raiz uma cópia do
   main se o repo tiver edições em andamento).
2. **Publicar:** `Artifact` com `file_path` = `assets/matriz-acessos.html`, `files: {"estado.json": <scratchpad>/estado.json}`,
   `capabilities: {db: {}}`. ⚠️ O estado.json tem nomes — fica no scratchpad, nunca no repo.
3. **Quando o dono disser que terminou:** `ArtifactData list` da coleção `mudancas`. Cada documento tem
   `tipo` (`pagina`/`aba`/`botao`/`valor`), `item`, `pagina`, `matricula` e `acao` (`incluir`/`tirar`).
   Mostre o resumo ao dono e aplique **direto nas tabelas** (nunca os setters `gov_admin_*_set`):

   | tipo | incluir | tirar |
   |---|---|---|
   | `pagina` | insert `governanca_acessos_paginas (matricula, pagina_id)` | delete da mesma (e dos bloqueios/liberações daquela página, se quiser limpar) |
   | `aba` | delete `governanca_abas_bloqueios` (desbloqueia) | insert `governanca_abas_bloqueios` |
   | `botao` | insert `governanca_abas_liberacoes` | delete `governanca_abas_liberacoes` |
   | `valor` | upsert `dp_rh.perm_ver_valores (matricula, area=item, liberado=true)` | delete da mesma linha |

4. **Fechar o ciclo:** apague os documentos aplicados (`ArtifactData batch` delete), gere de novo o estado e
   republique (mesmo `file_path`, mesma URL).



## Página Auditoria de páginas (o dono edita direto no portal)

`compliance/auditoria/paginas.html` — abas Sobre e Auditoria; ids `governanca-auditoria-paginas::{sobre,auditoria,editar-acessos}`.
Mostra a grade páginas × colaboradores lida de `gov_auditoria_acessos` e grava pelo lápis de cada linha com
`gov_auditoria_salvar`, que faz o mesmo mapeamento da tabela de acessos:

| `p_tipo` | incluir | tirar |
|---|---|---|
| `pagina` | insert `governanca_acessos_paginas` | delete dela **e** dos bloqueios/liberações daquela página (não ficam "sem efeito") |
| `aba` | dá a página se faltar + delete do bloqueio | insert `governanca_abas_bloqueios` |
| `botao` | dá a página se faltar + insert `governanca_abas_liberacoes` | delete da liberação |
| `valor` | upsert `dp_rh.perm_ver_valores (area = p_item, liberado)` | delete da área (a área `geral` fica no painel do app) |

Só matrícula **ativa** entra; `p_tirar` ignora quem também está em `p_incluir`. Admin não aparece na lista onde já
vê tudo (aba/botão/página fora da seção App); aparece nas telas da seção App e nos valores.

```sql
create or replace function tata_plus.gov_auditoria_salvar(p_tipo text, p_item text, p_incluir text[], p_tirar text[])
returns jsonb language plpgsql security definer set search_path to 'tata_plus', 'dp_rh', 'public' as $$
declare v_pagina text; v_inc text[]; v_tir text[];
begin
  if not tata_plus.pode_publicar() then raise exception 'Sem permissão para gerenciar acessos de governança'; end if;
  select coalesce(array_agg(p.matricula), '{}') into v_inc from tata_plus.profiles p
    where p.status = 'Ativo' and p.matricula = any(coalesce(p_incluir, '{}'));
  select coalesce(array_agg(p.matricula), '{}') into v_tir from tata_plus.profiles p
    where p.matricula = any(coalesce(p_tirar, '{}')) and not (p.matricula = any(v_inc));
  if p_tipo = 'pagina' then
    if not exists (select 1 from tata_plus.governanca_paginas where pagina_id = p_item) then raise exception 'Página não encontrada: %', p_item; end if;
    insert into tata_plus.governanca_acessos_paginas(matricula, pagina_id) select m, p_item from unnest(v_inc) m on conflict do nothing;
    delete from tata_plus.governanca_acessos_paginas where pagina_id = p_item and matricula = any(v_tir);
    delete from tata_plus.governanca_abas_liberacoes l using tata_plus.governanca_abas a where a.aba_id = l.aba_id and a.pagina_id = p_item and l.matricula = any(v_tir);
    delete from tata_plus.governanca_abas_bloqueios b using tata_plus.governanca_abas a where a.aba_id = b.aba_id and a.pagina_id = p_item and b.matricula = any(v_tir);
  elsif p_tipo in ('aba', 'botao') then
    select pagina_id into v_pagina from tata_plus.governanca_abas where aba_id = p_item and tipo = p_tipo;
    if v_pagina is null then raise exception 'Item não encontrado: %', p_item; end if;
    insert into tata_plus.governanca_acessos_paginas(matricula, pagina_id) select m, v_pagina from unnest(v_inc) m on conflict do nothing;
    if p_tipo = 'aba' then
      delete from tata_plus.governanca_abas_bloqueios where aba_id = p_item and matricula = any(v_inc);
      insert into tata_plus.governanca_abas_bloqueios(matricula, aba_id) select m, p_item from unnest(v_tir) m on conflict do nothing;
    else
      insert into tata_plus.governanca_abas_liberacoes(matricula, aba_id) select m, p_item from unnest(v_inc) m on conflict do nothing;
      delete from tata_plus.governanca_abas_liberacoes where aba_id = p_item and matricula = any(v_tir);
    end if;
  elsif p_tipo = 'valor' then
    if not exists (select 1 from tata_plus.governanca_abas where aba_id = p_item and tipo = 'valor') then raise exception 'Área de valores não encontrada: %', p_item; end if;
    insert into dp_rh.perm_ver_valores(matricula, area, liberado, criado_por) select m, p_item, true, tata_plus.minha_matricula() from unnest(v_inc) m
      on conflict (matricula, area) do update set liberado = true, criado_por = tata_plus.minha_matricula();
    delete from dp_rh.perm_ver_valores where area = p_item and matricula = any(v_tir);
  else raise exception 'Tipo inválido: %', p_tipo;
  end if;
  return jsonb_build_object('ok', true, 'incluidos', cardinality(v_inc), 'retirados', cardinality(v_tir));
end $$;
revoke execute on function tata_plus.gov_auditoria_salvar(text, text, text[], text[]) from public, anon;
grant execute on function tata_plus.gov_auditoria_salvar(text, text, text[], text[]) to authenticated;
```
Se a função sumir do banco, o "Salvar" da página avisa "A gravação ainda não está ativa no banco" e não muda nada.
⚠️ Nesta integração o MCP do Supabase **cancela sozinho** qualquer SQL com `delete` (o pedido de confirmação não chega ao dono):
para criar/alterar uma função assim, entregue o `.sql` para o dono rodar no SQL Editor e depois confira com
`pg_proc` + um teste dentro de um `do $$ … raise exception … $$` (desfaz tudo no fim).
