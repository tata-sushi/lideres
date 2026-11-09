-- ═══════════════════════════════════════════════════════════════════════════
-- Painel de pendências do app (tata_plus.minhas_pendencias): a pendência
-- "Férias pendente" do líder (tipo ferias_lider) passa a usar a mesma equipe
-- da página de Férias — toda a subárvore (tata_plus.minha_subarvore(), N
-- níveis), sem o próprio (o próprio já aparece como ferias_colab).
-- Antes: só liderados diretos (id_superior = meu id_pessoa).
-- Os demais tipos de pendência de líder continuam em 1 nível até cada página
-- adotar o nível Linha (skill controle-de-acessos-e-visibilidade).
-- Função usada pelo app Tatá Plus (PainelPendencias.jsx): assinatura e
-- retorno iguais.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function tata_plus.minhas_pendencias()
returns table(tipo text, colaborador_matricula text, colaborador_nome text, descricao text, criado_em timestamp with time zone)
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare
  v_mat text := tata_plus.minha_matricula();
  a_assinatura boolean; a_exp_colab boolean; a_exp_lider boolean; a_lideranca boolean;
  a_absenteismo boolean; a_exame_colab boolean; a_exame_lider boolean; a_feriado boolean; a_recrutamento boolean;
  a_assinatura_lider boolean; a_desempenho boolean; a_ferias_colab boolean; a_ferias_lider boolean;
  v_lid jsonb; v_gov boolean := false; v_idpessoa text; v_nkey text;
  v_sub text[] := '{}';   -- eu + minha subárvore (nível Linha), só para ferias_lider
begin
  if v_mat is null then return; end if;

  select coalesce(bool_or(ativo) filter (where slug='assinatura'),  false),
         coalesce(bool_or(ativo) filter (where slug='exp_colab'),   false),
         coalesce(bool_or(ativo) filter (where slug='exp_lider'),   false),
         coalesce(bool_or(ativo) filter (where slug='lideranca'),   false),
         coalesce(bool_or(ativo) filter (where slug='absenteismo'), false),
         coalesce(bool_or(ativo) filter (where slug='exame_colab'), false),
         coalesce(bool_or(ativo) filter (where slug='exame_lider'), false),
         coalesce(bool_or(ativo) filter (where slug='feriado'),     false),
         coalesce(bool_or(ativo) filter (where slug='recrutamento'),false),
         coalesce(bool_or(ativo) filter (where slug='assinatura_lider'),false),
         coalesce(bool_or(ativo) filter (where slug='desempenho'),  false),
         coalesce(bool_or(ativo) filter (where slug='ferias_colab'),false),
         coalesce(bool_or(ativo) filter (where slug='ferias_lider'),false)
    into a_assinatura, a_exp_colab, a_exp_lider, a_lideranca, a_absenteismo, a_exame_colab, a_exame_lider, a_feriado, a_recrutamento, a_assinatura_lider, a_desempenho, a_ferias_colab, a_ferias_lider
  from tata_plus.pendencia_tipos;

  if a_lideranca then v_lid := tata_plus.av_lideranca_pendente(); end if;
  if a_exp_lider or a_absenteismo or a_exame_lider or a_feriado or a_recrutamento or a_assinatura_lider or a_desempenho or a_ferias_lider then
    v_gov := (tata_plus.acesso_governanca() is not null);
    select nullif(trim(p2.id_pessoa),''), tata_plus.norm_nome(p2.nome)
      into v_idpessoa, v_nkey from tata_plus.profiles p2 where p2.matricula = v_mat;
  end if;
  if a_ferias_lider then v_sub := tata_plus.minha_subarvore(); end if;

  return query
  select 'assinatura'::text, v_mat, null::text, ('Assinatura: '||coalesce(d.titulo,'documento'))::text, a.atribuido_em
  from tata_plus.assinatura_atribuicoes a join tata_plus.assinatura_documentos d on d.id=a.documento_id
  where a_assinatura and a.matricula = v_mat and a.status='pendente'

  union all
  select 'assinatura_lider'::text, sub.matricula, sub.nome, ('Assinatura: '||coalesce(d.titulo,'documento'))::text, a.atribuido_em
  from tata_plus.assinatura_atribuicoes a
    join tata_plus.assinatura_documentos d on d.id=a.documento_id
    join tata_plus.profiles sub on sub.matricula=a.matricula
  where a_assinatura_lider and v_idpessoa is not null
    and sub.id_superior=v_idpessoa and sub.matricula<>v_mat
    and coalesce(sub.status,'')='Ativo' and a.status='pendente'

  union all
  select 'exp_colab'::text, v_mat, null::text, ('Auto-avaliação de experiência ('||t.marco||')')::text, null::timestamptz
  from (select data_admissao,(current_date-data_admissao)::int dias from tata_plus.profiles where matricula=v_mat and coalesce(status,'')='Ativo') me
  cross join (values (11,'11 dias','exp14_colab'),(40,'40 dias','exp60_colab')) as t(min_dias,marco,slug)
  where a_exp_colab and me.data_admissao>=date '2026-09-01' and me.dias>=t.min_dias
    and not exists (select 1 from dp_rh.avaliacoes av join dp_rh.avaliacao_modelos m on m.id=av.modelo_id where av.alvo_matricula=v_mat and m.slug=t.slug)

  union all
  select 'lideranca'::text, v_mat, null::text, ('Avaliação de liderança: '||coalesce(v_lid->>'lider_nome','sua liderança'))::text, null::timestamptz
  where a_lideranca and coalesce((v_lid->>'pendente')::boolean,false)

  union all
  select 'exp_lider'::text, sub.matricula, sub.nome, ('Avaliar experiência ('||t.marco||')')::text, null::timestamptz
  from (select p.matricula,p.nome,(current_date-p.data_admissao)::int dias from tata_plus.profiles p
        where coalesce(p.status,'')='Ativo' and p.data_admissao>=date '2026-09-01' and p.id_superior=v_idpessoa) sub
  cross join (values (11,'11 dias','exp14_lider'),(40,'40 dias','exp60_lider')) as t(min_dias,marco,slug)
  where a_exp_lider and v_gov and v_idpessoa is not null and sub.dias>=t.min_dias
    and not exists (select 1 from dp_rh.avaliacoes av join dp_rh.avaliacao_modelos m on m.id=av.modelo_id where av.alvo_matricula=sub.matricula and m.slug=t.slug)

  union all
  select 'absenteismo'::text, sub.matricula, sub.nome, ('Falta em '||to_char(au.data_falta,'DD/MM/YYYY'))::text, au.created_at
  from dp_rh.ausencias au join tata_plus.profiles sub on sub.matricula=au.matricula
  where a_absenteismo and v_gov and v_idpessoa is not null and sub.id_superior=v_idpessoa
    and coalesce(sub.status,'')='Ativo' and au.tipo='Falta' and coalesce(au.devolutiva,'')=''

  union all
  select 'exame_colab'::text, v_mat, null::text,
         ('Exame periódico '||case when ex.proxima_realizacao<current_date then 'vencido ('||to_char(ex.proxima_realizacao,'DD/MM/YYYY')||')' else 'vence em '||to_char(ex.proxima_realizacao,'DD/MM/YYYY') end)::text, null::timestamptz
  from dp_rh.exames ex
  where a_exame_colab and ex.matricula=v_mat and ex.realiza_exame and ex.proxima_realizacao is not null and ex.proxima_realizacao<=current_date+30

  union all
  select 'exame_lider'::text, sub.matricula, sub.nome,
         ('Exame periódico '||case when ex.proxima_realizacao<current_date then 'vencido ('||to_char(ex.proxima_realizacao,'DD/MM/YYYY')||')' else 'vence em '||to_char(ex.proxima_realizacao,'DD/MM/YYYY') end)::text, null::timestamptz
  from dp_rh.exames ex join tata_plus.profiles sub on sub.matricula=ex.matricula
  where a_exame_lider and v_gov and v_idpessoa is not null and sub.id_superior=v_idpessoa and coalesce(sub.status,'')='Ativo'
    and ex.realiza_exame and ex.proxima_realizacao is not null and ex.proxima_realizacao<=current_date+30

  union all
  select 'feriado'::text, sub.matricula, sub.nome,
         ('Decidir horas — '||coalesce(nullif(trim(fh.feriado_nome),''),'feriado')||' ('||to_char(fh.data_feriado,'DD/MM/YYYY')||')')::text, fh.created_at
  from dp_rh.feriados_horas fh join tata_plus.profiles sub on sub.matricula=fh.matricula
  where a_feriado and v_gov and v_idpessoa is not null and sub.id_superior=v_idpessoa and coalesce(sub.status,'')='Ativo' and coalesce(fh.decisao,'')=''

  union all
  select 'recrutamento'::text, e.candidatura_id::text, coalesce(c.nome,'candidato'),
         'Devolutiva de entrevista'::text, e.created_at
  from dp_rh.rec_entrevistas e left join dp_rh.rec_candidaturas c on c.id=e.candidatura_id
  where a_recrutamento and v_gov and v_nkey <> '' and e.status='Aguardando devolutiva'
    and tata_plus.norm_nome(e.entrevistador) = v_nkey

  union all
  select 'recrutamento'::text, t.candidatura_id::text, coalesce(c.nome,'candidato'),
         'Devolutiva de teste'::text, t.created_at
  from dp_rh.rec_teste_dias t left join dp_rh.rec_candidaturas c on c.id=t.candidatura_id
  where a_recrutamento and v_gov and v_nkey <> '' and t.status='Aguardando aprovação' and t.devolutiva_em is null
    and tata_plus.norm_nome(t.responsavel) = v_nkey

  union all
  select 'desempenho'::text, sub.matricula, sub.nome,
         ('Avaliação de desempenho ('||d.proxima_rodada||'ª rodada)')::text, null::timestamptz
  from tata_plus.av_desempenho_listar() d
    join tata_plus.profiles sub on sub.matricula=d.matricula
  where a_desempenho and v_gov and v_idpessoa is not null
    and sub.id_superior=v_idpessoa and d.due

  union all
  select 'ferias_colab'::text, v_mat, null::text,
         ('Férias pendente — período '||to_char(f.ini_aqui,'DD/MM/YY')||' a '||to_char(f.fim_aqui,'DD/MM/YY'))::text, f.atualizado_em
  from dp_rh.ferias f
  where a_ferias_colab and f.matricula = v_mat
    and exists (select 1 from tata_plus.profiles pp where pp.matricula=v_mat and coalesce(pp.status,'')='Ativo')
    and f.quitado_motivo is null and f.ini1 is null and f.fim_aqui <= current_date
    and dp_rh.ferias_direito_efetivo(f) > 0

  union all
  -- férias de um liderado a agendar: toda a subárvore (mesma equipe da página de Férias), sem o próprio
  select 'ferias_lider'::text, sub.matricula, sub.nome,
         ('Férias pendente — período '||to_char(f.ini_aqui,'DD/MM/YY')||' a '||to_char(f.fim_aqui,'DD/MM/YY'))::text, f.atualizado_em
  from dp_rh.ferias f
    join tata_plus.profiles sub on sub.matricula=f.matricula
  where a_ferias_lider and v_gov
    and sub.matricula = any(v_sub) and sub.matricula <> v_mat and coalesce(sub.status,'')='Ativo'
    and f.quitado_motivo is null and f.ini1 is null and f.fim_aqui <= current_date
    and dp_rh.ferias_direito_efetivo(f) > 0;
end $function$;
revoke all on function tata_plus.minhas_pendencias() from public, anon;
grant execute on function tata_plus.minhas_pendencias() to authenticated;

-- ── Teste: sem login não devolve nada ───────────────────────────────────────
do $$
begin
  if exists (select 1 from tata_plus.minhas_pendencias()) then
    raise exception 'TESTE FALHOU: minhas_pendencias sem login devolveu linhas';
  end if;
  if has_function_privilege('anon', 'tata_plus.minhas_pendencias()', 'execute') then
    raise exception 'TESTE FALHOU: anon executa minhas_pendencias';
  end if;
end $$;
