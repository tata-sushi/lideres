-- ═══════════════════════════════════════════════════════════════════════════
-- Solicitações RH → card no kanban (Tatá Plus)
-- ---------------------------------------------------------------------------
-- Toda nova solicitação (dp_rh.solicitacoes) passa a gerar automaticamente um
-- card no quadro RH, coluna "Solicitações Líderes", seguindo o mesmo padrão
-- dos demais triggers *_para_kanban (ouvidoria, sanções, ponto, etc.).
--
-- Aplicado em produção em 2026-08-19 (projeto TATÁ SUSHI | TATÁ POKE).
-- Destino:  quadro RH  = 08b636b2-7daf-444b-950a-8255e3049e5f
--           coluna     = 652e8e47-d3ec-4ef4-90c4-dcfd7c8d3c7f ("Solicitações Líderes")
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Etiquetas novas no quadro RH ────────────────────────────────────────
insert into tata_kanban.etiquetas (id, quadro_id, nome, cor, ordem)
values
  ('9a00c55a-1257-4d6a-83ad-d254b6bdb7a5','08b636b2-7daf-444b-950a-8255e3049e5f','Folha de Pagamento','#2f7d7d',
     (select coalesce(max(ordem),-1)+1 from tata_kanban.etiquetas where quadro_id='08b636b2-7daf-444b-950a-8255e3049e5f')),
  ('2fed2482-2aac-4aec-b424-b3d7d55cb7cf','08b636b2-7daf-444b-950a-8255e3049e5f','Uniforme/EPI','#6d5bb5',
     (select coalesce(max(ordem),-1)+2 from tata_kanban.etiquetas where quadro_id='08b636b2-7daf-444b-950a-8255e3049e5f'))
on conflict (id) do nothing;

-- ── 2) Tabela de vínculo solicitação ↔ card (padrão *_kanban) ──────────────
create table if not exists dp_rh.solicitacoes_kanban (
  solicitacao_id uuid primary key references dp_rh.solicitacoes(id) on delete cascade,
  card_id        uuid not null,
  criado_em      timestamptz not null default now()
);

-- ── 3) Função do trigger ───────────────────────────────────────────────────
--   Mapa tipo → etiqueta / responsável:
--     Ponto Eletrônico ....... Ponto                 · Victor (7)
--     Sanções Disciplinares .. Sanções               · Victor (7)
--     Alteração de Cargo ..... Recrutamento & Seleção· Victor (7)
--     Férias ................. Benefícios            · Victor (7)
--     Reembolso .............. Folha de Pagamento    · Victor (7)
--     Solicitação de vaga .... Recrutamento & Seleção· Sabrina (24685)
--     Uniforme ............... Uniforme/EPI          · Thamires (24332)
--     EPI's .................. Uniforme/EPI          · Thamires (24332)
--     Contratação ............ Recrutamento & Seleção· Igor V. S. Pereira (24540)
--     Vale Transporte ........ Benefícios            · Igor (24540)
--     Armário/Cadeado ........ Outros                · Igor (24540)
--     Diversos ............... Outros                · Igor (24540)
--   "criado_por" do card = matrícula do solicitante (NEW.criado_por), sem fallback.
create or replace function dp_rh.tg_solicitacao_para_kanban()
returns trigger
language plpgsql
security definer
set search_path to 'dp_rh','tata_kanban','tata_plus','public'
as $function$
declare
  v_quadro uuid := '08b636b2-7daf-444b-950a-8255e3049e5f';  -- RH
  v_col    uuid := '652e8e47-d3ec-4ef4-90c4-dcfd7c8d3c7f';  -- Solicitacoes Lideres
  v_etq uuid; v_resp text; v_ordem int; v_card uuid; v_titulo text; v_desc text; v_t text;
begin
  if exists (select 1 from dp_rh.solicitacoes_kanban where solicitacao_id = NEW.id) then
    return NEW;
  end if;
  begin
    v_t := lower(btrim(coalesce(NEW.tipo,'')));

    v_etq := case v_t
      when 'ponto eletrônico'      then '1ca9bb58-4f5c-4080-9f6c-a87082963ed2'::uuid  -- Ponto
      when 'sanções disciplinares' then '5bee39f2-3595-4eb1-9927-3bc8513990f8'::uuid  -- Sancoes
      when 'contratação'           then '53e94ee9-b332-4998-a790-93657ae1b438'::uuid  -- Recrutamento & Selecao
      when 'solicitação de vaga'   then '53e94ee9-b332-4998-a790-93657ae1b438'::uuid
      when 'alteração de cargo'    then '53e94ee9-b332-4998-a790-93657ae1b438'::uuid
      when 'férias'                then 'e8f5c391-20ab-4b78-bf05-ea39a207563e'::uuid  -- Beneficios
      when 'vale transporte'       then 'e8f5c391-20ab-4b78-bf05-ea39a207563e'::uuid
      when 'reembolso'             then '9a00c55a-1257-4d6a-83ad-d254b6bdb7a5'::uuid  -- Folha de Pagamento
      when 'uniforme'              then '2fed2482-2aac-4aec-b424-b3d7d55cb7cf'::uuid  -- Uniforme/EPI
      when 'epi''s'                then '2fed2482-2aac-4aec-b424-b3d7d55cb7cf'::uuid
      when 'armário/cadeado'       then 'afcff19e-3ba7-4b84-ac2c-2f93de9e579d'::uuid  -- Outros
      when 'diversos'              then 'afcff19e-3ba7-4b84-ac2c-2f93de9e579d'::uuid
      else 'afcff19e-3ba7-4b84-ac2c-2f93de9e579d'::uuid                              -- Outros (default)
    end;

    v_resp := case v_t
      when 'ponto eletrônico'      then '7'      -- Victor
      when 'sanções disciplinares' then '7'
      when 'alteração de cargo'    then '7'
      when 'férias'                then '7'
      when 'reembolso'             then '7'
      when 'solicitação de vaga'   then '24685'  -- Sabrina
      when 'uniforme'              then '24332'  -- Thamires
      when 'epi''s'                then '24332'
      when 'contratação'           then '24540'  -- Igor V. Santos Pereira
      when 'vale transporte'       then '24540'
      when 'armário/cadeado'       then '24540'
      when 'diversos'              then '24540'
      else null
    end;

    select coalesce(max(ordem),-1)+1 into v_ordem
      from tata_kanban.cards where coluna_id = v_col and not arquivado;

    v_titulo := 'Solicitação · ' || coalesce(nullif(NEW.tipo,''),'—')
             || ' · ' || coalesce(nullif(NEW.unidade,''),'—')
             || case when lower(coalesce(NEW.urgente,'')) = 'sim' then ' · URGENTE' else '' end;

    v_desc := 'Solicitante: ' || coalesce(nullif(NEW.solicitante,''),'—') || E'\n'
           || 'Unidade: ' || coalesce(nullif(NEW.unidade,''),'—')
              || coalesce(' · ' || nullif(NEW.departamento,''),'') || E'\n'
           || 'Tipo: ' || coalesce(nullif(NEW.tipo,''),'—') || E'\n'
           || 'Urgente: ' || coalesce(nullif(NEW.urgente,''),'—') || E'\n'
           || 'Abertura: ' || coalesce(to_char(NEW.abertura,'DD/MM/YYYY'),'—') || E'\n\n'
           || coalesce(nullif(btrim(NEW.descricao),''),'(sem descrição)');

    insert into tata_kanban.cards(quadro_id, coluna_id, titulo, descricao, ordem, criado_por)
    values (v_quadro, v_col, v_titulo, v_desc, v_ordem, nullif(NEW.criado_por,''))  -- sem fallback
    returning id into v_card;

    if v_etq is not null then
      insert into tata_kanban.card_etiquetas(card_id, etiqueta_id) values (v_card, v_etq);
    end if;
    if v_resp is not null then
      insert into tata_kanban.card_responsaveis(card_id, matricula) values (v_card, v_resp);
    end if;

    insert into dp_rh.solicitacoes_kanban(solicitacao_id, card_id) values (NEW.id, v_card);
  exception when others then
    null;  -- nunca bloqueia a gravacao da solicitacao
  end;
  return NEW;
end $function$;

-- ── 4) Trigger ─────────────────────────────────────────────────────────────
drop trigger if exists trg_solicitacao_para_kanban on dp_rh.solicitacoes;
create trigger trg_solicitacao_para_kanban
  after insert on dp_rh.solicitacoes
  for each row execute function dp_rh.tg_solicitacao_para_kanban();

-- ── 5) Backfill das solicitações abertas (Pendente / Em andamento) ─────────
--   Replica a lógica do trigger para as solicitações já existentes que ainda
--   não têm card. Idempotente: pula as que já estão vinculadas.
do $$
declare
  r record;
  v_quadro uuid := '08b636b2-7daf-444b-950a-8255e3049e5f';
  v_col    uuid := '652e8e47-d3ec-4ef4-90c4-dcfd7c8d3c7f';
  v_ordem int; v_card uuid; v_etq uuid; v_resp text; v_t text; v_titulo text; v_desc text;
begin
  select coalesce(max(ordem),-1) into v_ordem
    from tata_kanban.cards where coluna_id=v_col and not arquivado;

  for r in
    select * from dp_rh.solicitacoes s
    where s.status in ('Pendente','Em andamento')
      and nullif(btrim(s.criado_por),'') is not null
      and not exists (select 1 from dp_rh.solicitacoes_kanban k where k.solicitacao_id=s.id)
    order by s.abertura asc nulls first, s.id
  loop
    v_t := lower(btrim(coalesce(r.tipo,'')));

    v_etq := case v_t
      when 'ponto eletrônico'      then '1ca9bb58-4f5c-4080-9f6c-a87082963ed2'::uuid
      when 'sanções disciplinares' then '5bee39f2-3595-4eb1-9927-3bc8513990f8'::uuid
      when 'contratação'           then '53e94ee9-b332-4998-a790-93657ae1b438'::uuid
      when 'solicitação de vaga'   then '53e94ee9-b332-4998-a790-93657ae1b438'::uuid
      when 'alteração de cargo'    then '53e94ee9-b332-4998-a790-93657ae1b438'::uuid
      when 'férias'                then 'e8f5c391-20ab-4b78-bf05-ea39a207563e'::uuid
      when 'vale transporte'       then 'e8f5c391-20ab-4b78-bf05-ea39a207563e'::uuid
      when 'reembolso'             then '9a00c55a-1257-4d6a-83ad-d254b6bdb7a5'::uuid
      when 'uniforme'              then '2fed2482-2aac-4aec-b424-b3d7d55cb7cf'::uuid
      when 'epi''s'                then '2fed2482-2aac-4aec-b424-b3d7d55cb7cf'::uuid
      when 'armário/cadeado'       then 'afcff19e-3ba7-4b84-ac2c-2f93de9e579d'::uuid
      when 'diversos'              then 'afcff19e-3ba7-4b84-ac2c-2f93de9e579d'::uuid
      else 'afcff19e-3ba7-4b84-ac2c-2f93de9e579d'::uuid
    end;

    v_resp := case v_t
      when 'ponto eletrônico'      then '7'
      when 'sanções disciplinares' then '7'
      when 'alteração de cargo'    then '7'
      when 'férias'                then '7'
      when 'reembolso'             then '7'
      when 'solicitação de vaga'   then '24685'
      when 'uniforme'              then '24332'
      when 'epi''s'                then '24332'
      when 'contratação'           then '24540'
      when 'vale transporte'       then '24540'
      when 'armário/cadeado'       then '24540'
      when 'diversos'              then '24540'
      else null
    end;

    v_ordem := v_ordem + 1;

    v_titulo := 'Solicitação · ' || coalesce(nullif(r.tipo,''),'—')
             || ' · ' || coalesce(nullif(r.unidade,''),'—')
             || case when lower(coalesce(r.urgente,'')) = 'sim' then ' · URGENTE' else '' end;

    v_desc := 'Solicitante: ' || coalesce(nullif(r.solicitante,''),'—') || E'\n'
           || 'Unidade: ' || coalesce(nullif(r.unidade,''),'—')
              || coalesce(' · ' || nullif(r.departamento,''),'') || E'\n'
           || 'Tipo: ' || coalesce(nullif(r.tipo,''),'—') || E'\n'
           || 'Urgente: ' || coalesce(nullif(r.urgente,''),'—') || E'\n'
           || 'Abertura: ' || coalesce(to_char(r.abertura,'DD/MM/YYYY'),'—') || E'\n\n'
           || coalesce(nullif(btrim(r.descricao),''),'(sem descrição)');

    insert into tata_kanban.cards(quadro_id, coluna_id, titulo, descricao, ordem, criado_por)
    values (v_quadro, v_col, v_titulo, v_desc, v_ordem, nullif(r.criado_por,''))
    returning id into v_card;

    if v_etq is not null then
      insert into tata_kanban.card_etiquetas(card_id, etiqueta_id) values (v_card, v_etq);
    end if;
    if v_resp is not null then
      insert into tata_kanban.card_responsaveis(card_id, matricula) values (v_card, v_resp);
    end if;

    insert into dp_rh.solicitacoes_kanban(solicitacao_id, card_id) values (r.id, v_card);
  end loop;
end $$;
