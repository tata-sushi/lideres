-- Papelaria (governanca-institucional-papelaria): o papel timbrado pré-preenche unidade e departamento de
-- quem está logado. Antes vinha de uma planilha publicada (nome, matrícula, cargo, unidade, departamento de
-- todos, sem login). Agora sai do servidor, só os dados da própria pessoa, para quem abre a página.
create or replace function tata_plus.papelaria_meus_dados()
 returns jsonb
 language sql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
  select jsonb_build_object('nome', p.nome, 'cargo', p.cargo, 'unidade', p.unidade, 'departamento', p.departamento)
  from tata_plus.profiles p
  where p.matricula = tata_plus.minha_matricula()
    and tata_plus.gov_tenho_acesso('governanca-institucional-papelaria')
  limit 1;
$function$;
revoke execute on function tata_plus.papelaria_meus_dados() from public, anon;
grant execute on function tata_plus.papelaria_meus_dados() to authenticated;
