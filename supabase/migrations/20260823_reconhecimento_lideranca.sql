-- ═══════════════════════════════════════════════════════════════════════════
-- Reconhecimento entre Pares — adiciona o motivo "Liderança" (mantém "Outro")
-- ---------------------------------------------------------------------------
-- Passa de 7 → 8 motivos. "Liderança" (slug lideranca) entra antes de "Outro",
-- que segue como catch-all no fim. Idempotente. Grants preservados (replace).
-- ═══════════════════════════════════════════════════════════════════════════

-- 1) CHECK da tabela
alter table dp_rh.reconhecimentos drop constraint if exists reconhecimentos_motivo_check;
alter table dp_rh.reconhecimentos add constraint reconhecimentos_motivo_check
  check (motivo in ('equipe','proatividade','atendimento','qualidade','apoio','cultura','lideranca','outro'));

-- 2) RPC de escrita (CHECK interno)
create or replace function tata_plus.reconhecimento_registrar(
  p_para_matricula text, p_motivo text, p_mensagem text default null
) returns uuid
language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $$
declare v_de text := tata_plus.minha_matricula(); v_id uuid;
begin
  if v_de is null then raise exception 'sem matrícula ativa'; end if;
  if coalesce(trim(p_para_matricula),'') = '' then raise exception 'destinatário obrigatório'; end if;
  if trim(p_para_matricula) = v_de then raise exception 'não é possível reconhecer a si mesmo'; end if;
  if p_motivo not in ('equipe','proatividade','atendimento','qualidade','apoio','cultura','lideranca','outro')
     then raise exception 'motivo inválido'; end if;
  if not exists (select 1 from tata_plus.profiles p
                 where p.matricula = trim(p_para_matricula) and coalesce(p.status,'')='Ativo')
     then raise exception 'colaborador destinatário inválido'; end if;

  insert into dp_rh.reconhecimentos (de_matricula, para_matricula, motivo, mensagem)
  values (v_de, trim(p_para_matricula), p_motivo, nullif(trim(coalesce(p_mensagem,'')),''))
  returning id into v_id;
  return v_id;
end $$;

-- 3) Catálogo de motivos (pro seletor do app)
create or replace function tata_plus.reconhecimento_motivos()
returns table(slug text, label text, ordem int)
language sql immutable as $$
  select * from (values
    ('equipe','Trabalho em Equipe',1),
    ('proatividade','Proatividade',2),
    ('atendimento','Atendimento',3),
    ('qualidade','Qualidade',4),
    ('apoio','Apoio',5),
    ('cultura','Cultura',6),
    ('lideranca','Liderança',7),
    ('outro','Outro',8)
  ) as t(slug,label,ordem)
$$;
