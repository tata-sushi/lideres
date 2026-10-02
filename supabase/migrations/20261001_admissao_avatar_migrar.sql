-- Migração automática da selfie da admissão → avatar oficial do colaborador.
--
-- Contexto:
--   * Fluxo novo de admissão (chat da Sara) guarda a selfie no bucket privado
--     `admissao-docs` (dp_rh.admissao_documentos, observacao='foto', status='entregue').
--     A chave da pessoa na admissão é o CPF (ainda sem matrícula).
--   * O app lê o avatar de tata_plus.auth_users.avatar_url (via organograma_colaboradores),
--     cujo arquivo oficial mora no bucket PÚBLICO `avatares`, nomeado {matricula}.ext na raiz.
--   * Quando a pessoa é admitida vira linha em tata_plus.profiles (matrícula + CPF),
--     permitindo casar CPF da admissão ↔ CPF do profile → matrícula.
--
-- O que falta é COPIAR os bytes de admissao-docs → avatares (só dá server-side, com
-- service_role) — feito pela Edge Function `migrar-selfies-avatar`, disparada por este cron.
-- A parte de VINCULAR (gravar auth_users.avatar_url) já existe no passo (4) da
-- sincronizar_auth_users; aqui expomos a mesma lógica escopada por matrícula, para o
-- vínculo ser imediato na mesma rodada. Nunca sobrescreve avatar existente.

-- ───────────────────────────────────────────────────────────────────────────
-- RPC 1 — worklist: quem tem selfie entregue + já virou profile (match por CPF)
--          + ainda está SEM avatar + ainda não tem arquivo no bucket avatares.
-- ───────────────────────────────────────────────────────────────────────────
create or replace function tata_plus.admissao_avatar_pendentes()
returns table(matricula text, admissao_token uuid, doc_id uuid, selfie_path text, mime text)
language sql
stable
security definer
set search_path to 'tata_plus', 'dp_rh', 'storage'
as $$
  with selfies as (
    select a.token,
           a.cpf_norm,
           d.id   as doc_id,
           d.link as selfie_path,
           d.mime,
           row_number() over (partition by a.cpf_norm order by d.created_at desc) as rn
    from (
      select token, regexp_replace(coalesce(cpf, ''), '\D', '', 'g') as cpf_norm
      from dp_rh.admissoes
    ) a
    join dp_rh.admissao_documentos d on d.admissao_token = a.token
    where d.observacao = 'foto'
      and d.status = 'entregue'
      and coalesce(d.link, '') <> ''
      and coalesce(d.link_bucket, 'admissao-docs') = 'admissao-docs'
      and a.cpf_norm <> ''
  )
  select p.matricula, s.token, s.doc_id, s.selfie_path, s.mime
  from selfies s
  join tata_plus.profiles p
    on regexp_replace(coalesce(p.cpf, ''), '\D', '', 'g') = s.cpf_norm
  left join tata_plus.auth_users u on u.matricula = p.matricula
  where s.rn = 1
    and coalesce(p.status, '') = 'Ativo'
    and coalesce(p.matricula, '') <> ''
    and coalesce(u.avatar_url, '') = ''                 -- não sobrescrever avatar existente
    and not exists (                                    -- e ainda não há arquivo no bucket avatares (raiz)
      select 1 from storage.objects o
      where o.bucket_id = 'avatares'
        and position('/' in o.name) = 0
        and split_part(o.name, '.', 1) = p.matricula
    );
$$;

revoke all on function tata_plus.admissao_avatar_pendentes() from public, anon, authenticated;
grant execute on function tata_plus.admissao_avatar_pendentes() to service_role;

-- ───────────────────────────────────────────────────────────────────────────
-- RPC 2 — vincula o avatar recém-subido (arquivo {matricula}.ext na raiz do
--          bucket avatares) em auth_users.avatar_url. Upsert igual ao
--          avatar_admin_set, mas SÓ quando está vazio (nunca sobrescreve).
-- ───────────────────────────────────────────────────────────────────────────
create or replace function tata_plus.admissao_avatar_vincular(p_matricula text)
returns text
language plpgsql
security definer
set search_path to 'tata_plus', 'public', 'storage'
as $$
declare
  v_mat   text := btrim(coalesce(p_matricula, ''));
  v_name  text;
  v_url   text;
  v_atual text;
begin
  if v_mat = '' then
    return null;
  end if;

  -- arquivo mais recente {matricula}.ext na RAIZ do bucket avatares
  select o.name into v_name
  from storage.objects o
  where o.bucket_id = 'avatares'
    and position('/' in o.name) = 0
    and split_part(o.name, '.', 1) = v_mat
  order by o.created_at desc
  limit 1;

  if v_name is null then
    return null;
  end if;

  v_url := 'https://aoqsbusfrffapjglpqjk.supabase.co/storage/v1/object/public/avatares/' || v_name;

  insert into tata_plus.auth_users as au (matricula, avatar_url)
  values (v_mat, v_url)
  on conflict (matricula) do update
    set avatar_url = excluded.avatar_url
    where au.avatar_url is null;

  select avatar_url into v_atual from tata_plus.auth_users where matricula = v_mat;
  return v_atual;
end;
$$;

revoke all on function tata_plus.admissao_avatar_vincular(text) from public, anon, authenticated;
grant execute on function tata_plus.admissao_avatar_vincular(text) to service_role;

-- ───────────────────────────────────────────────────────────────────────────
-- Cron diário (08:30 BRT = 11:30 UTC) → dispara a Edge Function migrar-selfies-avatar.
-- Idempotente: remove o job antigo (se houver) antes de recriar.
-- ───────────────────────────────────────────────────────────────────────────
select cron.unschedule('migrar-selfies-avatar-diario')
where exists (select 1 from cron.job where jobname = 'migrar-selfies-avatar-diario');

select cron.schedule(
  'migrar-selfies-avatar-diario',
  '30 11 * * *',
  $cron$
  select net.http_post(
    url := 'https://aoqsbusfrffapjglpqjk.supabase.co/functions/v1/migrar-selfies-avatar',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvcXNidXNmcmZmYXBqZ2xwcWprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5MzcxMjQsImV4cCI6MjA5ODUxMzEyNH0.Dd9Z3SR3-18mQVX_yqUbIi0PG-eltLNjmOZB1Xu7W9o'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 150000
  );
  $cron$
);
