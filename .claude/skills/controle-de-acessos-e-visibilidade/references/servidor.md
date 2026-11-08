# O servidor é a porta (funções do banco)

> Em uma frase: **o que o navegador esconde, o servidor tem que negar.** Esconder a página, a aba ou o
> botão não protege nada: quem tem login no app consegue chamar a função do banco direto.

Por isso **toda função chamada por uma página** repete, no banco, as checagens da skill.

---

## As 8 regras

1. **Página:** toda função começa conferindo a página, com `tata_plus.gov_tenho_acesso('<GOV_PAGE_ID>')`
   (admin passa). Sem acesso, a função para.
2. **Botão:** toda ação (gravar, apagar, enviar, gerar…) confere o botão, com
   `tata_plus.pode_botao('<GOV_PAGE_ID>::<slug>')` (o mesmo id do HTML; ela já confere a página e libera admin).
3. **Linha:** dado de pessoa passa pelo corte da hierarquia (`minha_subarvore()`; admin e RH veem todas)
   → `references/hierarquia.md`.
4. **Valor e Contato:** a própria função mascara. Valor (R$, CPF, nascimento e saúde) com
   `pode_ver_valores('<área>')`; Contato (e-mail e telefone) com `pode_ver_contato('<área>')`, a criar.
   Sem permissão, a função devolve `null` e a página mostra `R$ •••` / `•••`.
5. **Quem fez vem do login:** o autor é sempre `tata_plus.minha_matricula()`. Nunca aceite nome ou matrícula
   de quem faz vindo da página (`p_por`, `p_lider`, `p_criado_por`, `enviado_por`, `p_matricula`…). O
   registro das movimentações é do gate; a função só não pode aceitar autor de fora.
6. **A função é a única porta:** `security definer` + `search_path` fixo +
   `revoke all on function … from public, anon` + `grant execute … to authenticated`. Nas tabelas e views:
   RLS ligado e `revoke all … from anon, authenticated`.
7. **Nada sem login:** nenhuma tabela ou função de dado do portal fica liberada para `anon`, e nenhuma
   página usa cliente próprio com a chave pública.
8. **Nada de sandbox:** nenhuma função `*_sandbox_*` em uso no dia a dia (vira a versão definitiva) e
   nenhuma identidade vinda do navegador (matrícula de teste).

**Seção App** (Kanban, Escala, Limpeza): não tem bypass de admin. A função confere com a regra da própria
feature (ex.: `escala_sou_admin`), não com `gov_tenho_acesso`.

---

## Molde de leitura

```sql
-- <página>: lista <o quê>. Porta única: página + linha + máscaras.
create or replace function tata_plus.<pagina>_listar()
returns table (matricula text, nome text, salario numeric, cpf text, email text)
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'public'
as $$
declare
  v_mt      text    := tata_plus.minha_matricula();
  v_todas   boolean := dp_rh.ferias_eh_rh(v_mt);               -- admin ou RH: todas as linhas
  v_sub     text[]  := tata_plus.minha_subarvore();            -- a criar (references/hierarquia.md)
  v_valor   boolean := tata_plus.pode_ver_valores('<área>');   -- R$, CPF, nascimento, saúde
  v_contato boolean := tata_plus.pode_ver_contato('<área>');   -- e-mail, telefone (a criar)
begin
  if not tata_plus.gov_tenho_acesso('<GOV_PAGE_ID>') then
    raise exception 'sem acesso a esta página';
  end if;
  return query
  select t.matricula, t.nome,
         case when v_valor   then t.salario end,
         case when v_valor   then t.cpf     end,
         case when v_contato then t.email   end
    from dp_rh.<tabela> t
   where v_todas or t.matricula = any(v_sub);
end $$;
revoke all on function tata_plus.<pagina>_listar() from public, anon;
grant execute on function tata_plus.<pagina>_listar() to authenticated;
```

- Calcule permissões e subárvore **uma vez**, no `declare`, não por linha.
- Conteúdo institucional (Sobre, números do portal) não passa pelo corte de linha, mas a função continua
  sem acesso para `anon`.

---

## Molde de escrita

```sql
-- <página>: <ação>. Porta única: botão (inclui página) + linha + autor do login.
create or replace function tata_plus.<pagina>_<acao>(p_alvo text, p_dados jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'tata_plus', 'dp_rh', 'public'
as $$
declare
  v_mt text := tata_plus.minha_matricula();                    -- quem fez: sempre do login
begin
  if v_mt is null then
    return jsonb_build_object('ok', false, 'erro', 'sem login');
  end if;
  if not tata_plus.pode_botao('<GOV_PAGE_ID>::<slug>') then
    return jsonb_build_object('ok', false, 'erro', 'sem permissão para esta ação');
  end if;
  if not dp_rh.ferias_eh_rh(v_mt) and not (p_alvo = any(tata_plus.minha_subarvore())) then
    return jsonb_build_object('ok', false, 'erro', 'colaborador fora da sua equipe');
  end if;
  -- grava, sempre com o autor do login:
  -- update dp_rh.<tabela> set …, atualizado_por = v_mt, atualizado_em = now() where matricula = p_alvo;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function tata_plus.<pagina>_<acao>(text, jsonb) from public, anon;
grant execute on function tata_plus.<pagina>_<acao>(text, jsonb) to authenticated;
```

- Ação que é só do RH (ajustar direito, quitar, cancelar agendamento…): troque a checagem de linha por
  `dp_rh.ferias_eh_rh(v_mt)`.
- O slug de `pode_botao` é o mesmo `data-aba-id` / `data-botao-id` do botão no HTML.

---

## Conferir as funções de uma página

1. Liste as funções que a página chama:
   ```bash
   grep -oE "\.rpc\(\s*['\"][a-zA-Z0-9_]+" compliance/kpis/rh/<pagina>.html | sed -E "s/.*['\"]//" | sort -u
   ```
2. Veja quais não conferem página nem botão (no SQL do Supabase, só leitura):
   ```sql
   select p.proname
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('tata_plus', 'public')
      and p.proname = any(array['<funcao_1>', '<funcao_2>'])
      and p.prosrc !~ '(gov_tenho_acesso|pode_botao)';
   ```
3. Confira também `anon`: `has_function_privilege('anon', '<schema>.<funcao>(<args>)', 'execute')` e
   `has_table_privilege('anon', '<schema>.<tabela>', 'select')` têm que dar `false`.

⚠️ O resultado é um mapa do que está aberto: **não cole em arquivo do repo** (o repo vai inteiro para o
GitHub Pages).

---

## Checklist de uma função

- [ ] Começa com `gov_tenho_acesso('<GOV_PAGE_ID>')` (leitura) ou `pode_botao('<GOV_PAGE_ID>::<slug>')` (ação).
- [ ] Dado de pessoa com corte de linha (admin/RH todas).
- [ ] Valor (R$, CPF, nascimento, saúde) e Contato (e-mail, telefone) mascarados na própria função.
- [ ] Autor pelo login; nenhum parâmetro de "quem sou eu".
- [ ] `security definer`, `search_path` fixo, `revoke … from public, anon`, `grant … to authenticated`.
- [ ] Tabela e view com RLS ligado e sem acesso direto de `anon`/`authenticated`.
- [ ] Nome definitivo (sem `sandbox`).
