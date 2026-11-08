# Registro: quem fez cada mudança no banco

Decisões do dono (08/11/2026):

- **Cada tabela** tem a coluna da última atualização e a de quem fez (`atualizado_em`, `atualizado_por`).
- **Um log geral** registra **qualquer movimentação** (criação, alteração, exclusão e limpeza de tabela), em
  qualquer tabela, com histórico.
  - **O que guarda:** na alteração, só os campos que mudaram (antes → depois); na criação e na exclusão, a linha inteira.
  - **Quem lê:** só admin, por função. Valor e Contato ficam mascarados para quem não tem a liberação.
  - **Prazo:** 6 meses. O banco apaga sozinho o que passar disso.
- Gerar PDF, imprimir e exportar **não** entram (ok do dono): não passam por tabela.

Os dois são preenchidos **pelo banco, por gatilho**, a partir do login. A página e as funções não preenchem,
então ninguém registra em nome de outra pessoa.

Estado em 08/11/2026:

- Das 188 tabelas (`tata_plus`, `dp_rh`, `tata_kanban`, `tata_abastecimento`), só 3 têm as duas colunas.
- Onde `atualizado_por` existe, o conteúdo mistura matrícula e nome.
- Não há log geral. Só registros soltos por assunto: atividade do Kanban, pontos da escala, quem abriu holerite.

O molde abaixo foi **testado no banco numa transação desfeita** (08/11/2026). O resultado está em "Teste".

---

## 1. Schema `registro` e "quem fez"

O log fica num schema próprio, **fora da API**: ninguém lê nem grava direto, só os gatilhos e a função de
leitura.

```sql
create schema if not exists registro;
revoke all on schema registro from public, anon, authenticated;

-- Quem fez: nome pelo login; sem login, o tipo de acesso.
create or replace function registro.quem()
returns text
language sql
stable
security definer
set search_path to 'tata_plus', 'public'
as $$
  select coalesce(
    tata_plus.meu_nome(),                                    -- nome de quem está logado (cadastro ativo)
    case
      when auth.jwt() ->> 'role' = 'anon'     then 'sem login'
      when auth.jwt() ->> 'email' is not null then 'login sem cadastro ativo'
      else 'sistema'                                         -- integração sem login (n8n, sincronização)
    end);
$$;
```

## 2. Última mudança na própria tabela

```sql
create or replace function registro.carimbar_atualizacao()
returns trigger
language plpgsql
security definer
set search_path to 'registro', 'public'
as $$
begin
  new.atualizado_em  := now();
  new.atualizado_por := registro.quem();
  return new;
end $$;
```

## 3. O log geral

```sql
create table if not exists registro.movimentacoes (
  id        bigint generated always as identity primary key,
  quando    timestamptz not null default now(),
  tabela    text not null,          -- schema.tabela
  operacao  text not null,          -- insert, update, delete, truncate
  linha     jsonb,                  -- chave da linha, ex.: {"id": 42}
  quem      text not null,          -- registro.quem()
  matricula text,                   -- matrícula pelo login, quando houver
  mudou     jsonb                   -- update: {campo: {antes, depois}}; insert/delete: a linha inteira
);
create index if not exists movimentacoes_quando on registro.movimentacoes (quando);
create index if not exists movimentacoes_tabela on registro.movimentacoes (tabela, quando);
alter table registro.movimentacoes enable row level security;
revoke all on registro.movimentacoes from public, anon, authenticated;

create or replace function registro.registrar_movimentacao()
returns trigger
language plpgsql
security definer
set search_path to 'registro', 'public'
as $$
declare
  v_antes  jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_depois jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_mudou  jsonb;
begin
  if tg_op = 'UPDATE' then
    select jsonb_object_agg(k, jsonb_build_object('antes', v_antes -> k, 'depois', v_depois -> k))
      into v_mudou
      from jsonb_object_keys(v_depois) k
     where (v_antes -> k) is distinct from (v_depois -> k)
       and k not in ('atualizado_em', 'atualizado_por');
    if v_mudou is null then
      return null;                                           -- nada mudou de verdade: não registra
    end if;
  else
    v_mudou := coalesce(v_depois, v_antes);                  -- insert e delete: a linha inteira
  end if;
  insert into registro.movimentacoes (tabela, operacao, linha, quem, matricula, mudou)
  values (tg_table_schema || '.' || tg_table_name,
          lower(tg_op),
          (select jsonb_object_agg(c, coalesce(v_depois, v_antes) -> c) from unnest(tg_argv) c),
          registro.quem(),
          tata_plus.minha_matricula(),
          v_mudou);
  return null;
end $$;

create or replace function registro.registrar_truncate()
returns trigger
language plpgsql
security definer
set search_path to 'registro', 'public'
as $$
begin
  insert into registro.movimentacoes (tabela, operacao, quem, matricula)
  values (tg_table_schema || '.' || tg_table_name, 'truncate', registro.quem(), tata_plus.minha_matricula());
  return null;
end $$;

revoke all on function registro.quem(), registro.carimbar_atualizacao(),
                       registro.registrar_movimentacao(), registro.registrar_truncate()
  from public, anon, authenticated;
```

## 4. Em cada tabela

```sql
alter table <schema>.<tabela>
  add column if not exists atualizado_em  timestamptz,
  add column if not exists atualizado_por text;

create or replace trigger carimbar_atualizacao
  before insert or update on <schema>.<tabela>
  for each row execute function registro.carimbar_atualizacao();

create or replace trigger registrar_movimentacao
  after insert or update or delete on <schema>.<tabela>
  for each row execute function registro.registrar_movimentacao('<coluna_da_chave>');   -- uma ou mais

create or replace trigger registrar_truncate
  after truncate on <schema>.<tabela>
  for each statement execute function registro.registrar_truncate();
```

Gerar os comandos de todas as tabelas, com a chave de cada uma (só leitura; revise antes de rodar):

```sql
select format($f$
alter table %1$I.%2$I add column if not exists atualizado_em timestamptz, add column if not exists atualizado_por text;
create or replace trigger carimbar_atualizacao before insert or update on %1$I.%2$I for each row execute function registro.carimbar_atualizacao();
create or replace trigger registrar_movimentacao after insert or update or delete on %1$I.%2$I for each row execute function registro.registrar_movimentacao(%3$s);
create or replace trigger registrar_truncate after truncate on %1$I.%2$I for each statement execute function registro.registrar_truncate();$f$,
  n.nspname, c.relname,
  coalesce((select string_agg(quote_literal(a.attname), ', ' order by k.ord)
              from pg_index i
              cross join lateral unnest(i.indkey::int2[]) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = i.indrelid and a.attnum = k.attnum
             where i.indrelid = c.oid and i.indisprimary), ''))
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where c.relkind in ('r', 'p') and not c.relispartition
   and n.nspname in ('tata_plus', 'dp_rh', 'tata_kanban', 'tata_abastecimento')
 order by n.nspname, c.relname;
```

- Os nomes dos gatilhos são os mesmos em todas as tabelas, para conferir fácil.
- Se a tabela já tem `atualizado_por` de outro tipo (não `text`), pergunte ao dono antes de mexer.
- Funções e páginas que hoje mandam `atualizado_por` continuam funcionando, porque o gatilho sobrescreve.
  Depois, tire esses parâmetros.

## 5. Leitura: só admin, com máscara

```sql
-- Máscara de Valor (R$, CPF, nascimento, saúde) e Contato (e-mail, telefone) pelo nome do campo.
-- Campo sensível novo com outro nome: acrescente aqui.
create or replace function registro.mascarar(p jsonb, p_valor boolean, p_contato boolean)
returns jsonb
language sql
immutable
as $$
  select case when p is null then null else coalesce((
    select jsonb_object_agg(k,
             case
               when not p_valor   and k ~ '(cpf|salario|valor|liquido|bruto|remuneracao|nascimento|atestado|exame)' then to_jsonb('•••'::text)
               when not p_contato and k ~ '(e_?mail|telefone|celular|whats)'                                          then to_jsonb('•••'::text)
               else v
             end)
      from jsonb_each(p) e(k, v)), '{}'::jsonb) end;
$$;

create or replace function tata_plus.registro_listar(
  p_tabela text        default null,
  p_desde  timestamptz default now() - interval '7 days',
  p_limite int         default 500)
returns table (quando timestamptz, tabela text, operacao text, linha jsonb, quem text, matricula text, mudou jsonb)
language plpgsql
stable
security definer
set search_path to 'registro', 'tata_plus', 'public'
as $$
declare
  v_valor   boolean := tata_plus.pode_ver_valores('geral');
  v_contato boolean := tata_plus.pode_ver_contato('geral');
begin
  if not tata_plus.pode_publicar() then                     -- só admin
    raise exception 'sem acesso ao registro';
  end if;
  return query
  select m.quando, m.tabela, m.operacao, m.linha, m.quem, m.matricula,
         registro.mascarar(m.mudou, v_valor, v_contato)
    from registro.movimentacoes m
   where (p_tabela is null or m.tabela = p_tabela)
     and m.quando >= p_desde
   order by m.quando desc
   limit least(greatest(coalesce(p_limite, 500), 1), 5000);
end $$;
revoke all on function tata_plus.registro_listar(text, timestamptz, int) from public, anon;
grant execute on function tata_plus.registro_listar(text, timestamptz, int) to authenticated;
```

Uma página de auditoria, se o dono quiser, chama `registro_listar` e segue a skill de acesso (página com
`GOV_PAGE_ID`, liberada só para admin).

## 6. Prazo: 6 meses

```sql
create or replace function registro.limpar_antigos()
returns void
language sql
security definer
set search_path to 'registro', 'public'
as $$
  delete from registro.movimentacoes where quando < now() - interval '6 months';
$$;
revoke all on function registro.limpar_antigos() from public, anon, authenticated;

select cron.schedule('registro-limpeza-6-meses', '23 4 * * *', $$select registro.limpar_antigos()$$);
```

O `pg_cron` já está instalado no projeto (1.6.4).

---

## Ordem de aplicação (aprovação do dono a cada migration)

1. Schema, funções, tabela do log, leitura e limpeza (§1, §2, §3, §5 e §6).
2. Gatilhos por grupo de tabelas, uma migration por grupo: RH (`dp_rh`), Plus (`tata_plus`), Kanban
   (`tata_kanban`). Teste cada grupo.
3. **`tata_abastecimento` só depois** de as 4 páginas de compras e estoque passarem a usar o login (Etapa 0.1 da
   skill de acesso). Antes disso, toda gravação delas sairia como "sem login".
4. ⚠️ SQL com `delete` ou `truncate` (inclusive teste): o servidor do Supabase pede confirmação ao dono e,
   sem resposta em ~60 s, cancela. Avise o dono antes de rodar.

## Teste (08/11/2026, transação desfeita)

Tabela de teste com os gatilhos:

| Passo | Resultado |
|---|---|
| Criação sem login (integração), página mandando autor falso | log `insert` com a linha inteira; `atualizado_por` = `sistema` |
| Alteração do CPF, chamada sem login | log `update` só com `{"cpf": {"antes": "111", "depois": "222"}}`, `linha` = `{"id": 1}`, `quem` = `sem login` |
| Alteração que não muda nada | nenhuma linha no log |
| Exclusão | log `delete` com a linha inteira; lida com máscara: CPF e e-mail = `•••` |
| Limpeza da tabela | log `truncate` |
| `registro_listar` por quem não é admin | negado ("sem acesso ao registro") |

## Conferir

```sql
-- tabelas ainda sem os gatilhos
select n.nspname || '.' || c.relname as tabela
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where c.relkind in ('r', 'p') and not c.relispartition
   and n.nspname in ('tata_plus', 'dp_rh', 'tata_kanban', 'tata_abastecimento')
   and not exists (select 1 from pg_trigger t where t.tgrelid = c.oid and t.tgname = 'registrar_movimentacao')
 order by 1;

-- volume do log por tabela (últimos 7 dias)
select tabela, operacao, count(*) from registro.movimentacoes
 where quando > now() - interval '7 days' group by 1, 2 order by 3 desc;
```

⚠️ O log tem dado de pessoa: resultado de consulta nele não vai para arquivo do repo.
