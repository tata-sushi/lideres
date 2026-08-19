-- ═══════════════════════════════════════════════════════════════════════════
-- Sincronização reversa: kanban → status da solicitação
-- ---------------------------------------------------------------------------
-- Quando o card de uma solicitação muda de coluna no quadro RH, o status em
-- dp_rh.solicitacoes é atualizado (e o front, que lê s.status via a RPC
-- solicitacoes_listar, reflete a mudança).
--
-- Mapa coluna (quadro RH) → status:
--   Solicitações Líderes (652e8e47) → Pendente
--   Em andamento         (f520c97d) → Em andamento
--   Concluído            (d5bd4558) → Finalizado  (grava data_conclusao)
--   Validadas            (94384dc0) → Finalizado  (grava data_conclusao)
--   Demais colunas                  → não alteram o status
-- Ao reabrir (voltar para Pendente/Em andamento), data_conclusao é limpa.
--
-- Aplicado em produção em 2026-08-19 (projeto TATÁ SUSHI | TATÁ POKE).
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function dp_rh.tg_card_status_solicitacao()
returns trigger
language plpgsql
security definer
set search_path to 'dp_rh','tata_kanban','tata_plus','public'
as $function$
declare v_sol uuid; v_status text; v_final boolean;
begin
  if NEW.coluna_id is distinct from OLD.coluna_id then
    select solicitacao_id into v_sol from dp_rh.solicitacoes_kanban where card_id = NEW.id;
    if v_sol is null then return NEW; end if;  -- card que não é de solicitação: ignora

    v_status := case NEW.coluna_id
      when '652e8e47-d3ec-4ef4-90c4-dcfd7c8d3c7f'::uuid then 'Pendente'      -- Solicitações Líderes
      when 'f520c97d-3ab3-4a69-b63f-f350c8b27df8'::uuid then 'Em andamento'  -- Em andamento
      when 'd5bd4558-0b7b-422d-b224-544815acb951'::uuid then 'Finalizado'    -- Concluído
      when '94384dc0-a53c-4bed-8117-ee222d164f41'::uuid then 'Finalizado'    -- Validadas
      else null
    end;
    if v_status is null then return NEW; end if;  -- coluna fora do fluxo: não mexe

    v_final := (v_status = 'Finalizado');

    update dp_rh.solicitacoes
       set status = v_status,
           data_conclusao = case when v_final then coalesce(data_conclusao, current_date) else null end,
           atualizado_em  = now()
     where id = v_sol
       and status is distinct from v_status;
  end if;
  return NEW;
end $function$;

drop trigger if exists trg_card_status_solicitacao on tata_kanban.cards;
create trigger trg_card_status_solicitacao
  after update of coluna_id on tata_kanban.cards
  for each row execute function dp_rh.tg_card_status_solicitacao();
