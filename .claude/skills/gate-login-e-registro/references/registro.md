# Registro: `atualizado_em` e `atualizado_por` em toda tabela

Decisão do dono (08/11/2026): **cada tabela tem a sua coluna de última atualização e de quem fez.**
Quem preenche é o banco, por gatilho, a partir do login. A página e a função não preenchem.

Estado em 08/11/2026: das 188 tabelas (`tata_plus`, `dp_rh`, `tata_kanban`, `tata_abastecimento`), só 3
têm as duas colunas, 17 têm uma delas e 168 nenhuma. Onde `atualizado_por` já existe, o conteúdo mistura
matrícula e nome, preenchido pela página ou pela função. O gatilho padroniza a partir da próxima mudança.

---

## O gatilho (uma função para todas as tabelas)

```sql
-- Registro: carimba quando e quem fez em todo insert e update, a partir do login.
create or replace function tata_plus.carimbar_atualizacao()
returns trigger
language plpgsql
security definer
set search_path to 'tata_plus', 'public'
as $$
begin
  new.atualizado_em  := now();
  new.atualizado_por := coalesce(
    tata_plus.meu_nome(),                                        -- nome de quem está logado (cadastro ativo)
    case
      when auth.jwt() ->> 'role' = 'anon'        then 'sem login'
      when auth.jwt() ->> 'email' is not null    then 'login sem cadastro ativo'
      else 'sistema'                                             -- integração sem login (n8n, sincronização)
    end);
  return new;
end $$;
revoke all on function tata_plus.carimbar_atualizacao() from public, anon, authenticated;
```

## Em cada tabela

```sql
alter table <schema>.<tabela>
  add column if not exists atualizado_em  timestamptz,
  add column if not exists atualizado_por text;

drop trigger if exists carimbar_atualizacao on <schema>.<tabela>;
create trigger carimbar_atualizacao
  before insert or update on <schema>.<tabela>
  for each row execute function tata_plus.carimbar_atualizacao();
```

- **Mesmo nome de gatilho em todas as tabelas** (`carimbar_atualizacao`), para conferir fácil.
- Se a tabela já tem `atualizado_por` com outro tipo (não `text`), não mude o tipo no mesmo passo: pergunte ao dono.
- Funções e páginas que hoje mandam `atualizado_por` / `atualizado_em` podem continuar mandando sem quebrar:
  o gatilho sobrescreve. Depois, tire esses parâmetros.

## Ordem de aplicação (aprovação do dono a cada migration)

1. Crie `tata_plus.carimbar_atualizacao()`.
2. Aplique por grupo de tabelas, uma migration por grupo: RH (`dp_rh`), Plus (`tata_plus`), Kanban
   (`tata_kanban`).
3. **`tata_abastecimento` só depois** de as 4 páginas de compras e estoque passarem a usar o login (Etapa 0.1
   da skill de acesso). Antes disso, toda gravação delas sairia como "sem login".
4. Teste cada grupo: grave como `authenticated` dentro de `set local role` e confira se `atualizado_por`
   saiu com o nome. Desfaça no fim.

## Conferir

Tabelas ainda sem o gatilho:

```sql
select n.nspname || '.' || c.relname as tabela
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where c.relkind in ('r', 'p')
   and n.nspname in ('tata_plus', 'dp_rh', 'tata_kanban', 'tata_abastecimento')
   and not exists (select 1 from pg_trigger t where t.tgrelid = c.oid and t.tgname = 'carimbar_atualizacao')
 order by 1;
```

## O que este registro não cobre

- **Exclusão:** a linha apagada leva as colunas junto, então não fica quem apagou. Se precisar, a tabela
  passa a "marcar como excluído" (`excluido_em`, `excluido_por`) em vez de apagar. Isso é decisão do dono,
  tabela por tabela.
- **Histórico:** fica só a última mudança. Os registros por assunto que já existem continuam: atividade
  do Kanban, pontos da escala, quem abriu holerite.
- **Ações sem banco** (PDF, imprimir, exportar) não passam por tabela e não ficam registradas.
