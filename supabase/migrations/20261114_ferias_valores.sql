-- ═══════════════════════════════════════════════════════════════════════════
-- Férias: valor líquido dos recibos (KPIs: analítico e gráficos)
--
--   • dp_rh.ferias_recibos — uma linha por recibo de férias da folha, com o
--     valor LÍQUIDO (total de proventos − total de descontos, o "TOTAL LÍQUIDO"
--     do recibo). Chave: (matricula, ini_aqui, ini_gozo). Quem alimenta: a
--     importação dos arquivos de recibos e, daqui pra frente, o agente de
--     rateio (upsert pela chave). Férias indenizadas na rescisão não entram.
--   • Área de VALOR "ferias" (governanca_abas, tipo 'valor'): o R$ só sai do
--     banco para quem tem a área liberada em dp_rh.perm_ver_valores ('ferias'
--     ou 'geral') — sem bypass de admin (skill controle-acesso-abas-botoes).
--   • tata_plus.ferias_valores_listar() → { pode_ver, recibos[] }. Sem a
--     liberação, devolve pode_ver=false e nenhuma linha. Com a liberação, o RH
--     vê todos (inclusive desligados); o líder, só a própria equipe ativa.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists dp_rh.ferias_recibos (
  id            uuid primary key default gen_random_uuid(),
  matricula     text not null,
  ini_aqui      date not null,              -- período aquisitivo a que o recibo pertence
  ini_gozo      date not null,
  fim_gozo      date,
  dias_gozo     numeric(5,1),
  dias_abono    numeric(5,1),               -- dias vendidos neste recibo
  valor_liquido numeric(12,2) not null,     -- total de proventos − total de descontos
  origem        text not null,              -- arquivo/recibo/agente que trouxe o valor
  criado_por    text,
  criado_em     timestamptz not null default now(),
  unique (matricula, ini_aqui, ini_gozo)
);
comment on table dp_rh.ferias_recibos is
  'Recibos de férias da folha: valor líquido por recibo. Upsert por (matricula, ini_aqui, ini_gozo). Leitura só via tata_plus.ferias_valores_listar (área de valor "ferias").';
create index if not exists ferias_recibos_gozo_idx on dp_rh.ferias_recibos (ini_gozo);
alter table dp_rh.ferias_recibos enable row level security;
revoke all on dp_rh.ferias_recibos from anon, authenticated;

-- ── Área de valor "ferias" ──────────────────────────────────────────────────
insert into tata_plus.governanca_abas (aba_id, pagina_id, label, tipo, ordem, ativo)
values ('ferias', 'governanca-kpis-rh-ferias', 'Valores financeiros', 'valor', 8, true)
on conflict (aba_id) do update
   set pagina_id = excluded.pagina_id, label = excluded.label, tipo = excluded.tipo, ativo = true;

-- ── Leitura (mascarada no servidor) ─────────────────────────────────────────
create or replace function tata_plus.ferias_valores_listar()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_mt  text := tata_plus.minha_matricula();
  v_rh  boolean;
  v_idp text;
begin
  if v_mt is null or not tata_plus.pode_ver_valores('ferias') then
    return jsonb_build_object('pode_ver', false, 'recibos', '[]'::jsonb);
  end if;
  v_rh := dp_rh.ferias_eh_rh(v_mt);
  select nullif(btrim(id_pessoa), '') into v_idp from tata_plus.profiles where matricula = v_mt;
  return jsonb_build_object('pode_ver', true, 'recibos', coalesce((
    select jsonb_agg(jsonb_build_object(
             'mt', r.matricula,
             'nome', coalesce(p.nome, f.nome_hist, r.matricula),
             'unidade', p.unidade, 'departamento', p.departamento,
             'ativo', coalesce(p.status, '') = 'Ativo',
             'ini_aqui', r.ini_aqui, 'fim_aqui', f.fim_aqui,
             'ini_gozo', r.ini_gozo, 'fim_gozo', r.fim_gozo,
             'dias_gozo', r.dias_gozo, 'dias_abono', r.dias_abono,
             'liquido', r.valor_liquido)
           order by r.ini_gozo, coalesce(p.nome, f.nome_hist))
      from dp_rh.ferias_recibos r
      left join dp_rh.ferias f on f.matricula = r.matricula and f.ini_aqui = r.ini_aqui
      left join tata_plus.profiles p on p.matricula = r.matricula
     where v_rh or (v_idp is not null and p.status = 'Ativo' and p.id_superior = v_idp)
  ), '[]'::jsonb));
end $function$;
revoke all on function tata_plus.ferias_valores_listar() from public;
grant execute on function tata_plus.ferias_valores_listar() to authenticated;

-- ── Teste: sem usuário logado (contexto da migration) não sai valor ─────────
do $$
begin
  if coalesce((tata_plus.ferias_valores_listar()->>'pode_ver')::boolean, true)
     or jsonb_array_length(tata_plus.ferias_valores_listar()->'recibos') <> 0 then
    raise exception 'TESTE FALHOU: valores sem liberação';
  end if;
  if not exists (select 1 from tata_plus.governanca_abas where aba_id = 'ferias' and tipo = 'valor' and ativo) then
    raise exception 'TESTE FALHOU: área de valor ferias';
  end if;
end $$;
