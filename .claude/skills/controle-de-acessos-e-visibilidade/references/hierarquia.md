# Nível Linha — visibilidade por hierarquia

Os níveis Página, Aba, Botão e Valor decidem **o que** a pessoa usa na página, e o admin
configura pessoa a pessoa. O nível **Linha** decide **de quem são os registros** que aparecem
(as férias de quem, as vagas de quem), e **ninguém configura**: sai do organograma.

> Em uma frase: **o líder vê os próprios dados e os de toda a equipe abaixo dele, em qualquer
> nível; admin e RH veem tudo; o corte é feito no servidor.**

---

## Quem vê quais linhas

| Quem | Como o servidor reconhece | Linhas que vê |
|---|---|---|
| **Admin** | `perfil = 'admin'` | todas |
| **RH** | `perfil = 'analista-rh'` ou `departamento = 'rh'` | todas |
| **Líder** | tem alguém abaixo dele no organograma | as próprias + as de toda a subárvore (N níveis) |
| **Sem equipe** | ninguém abaixo | só as próprias |

- **O nível Linha só filtra.** Nunca abre página, aba ou botão. Quem não tem a página liberada
  (nível Página) não chega a ver linha nenhuma, mesmo sendo RH.
- **Valor e Contato têm as duas travas:** precisam da área liberada (`pode_ver_valores` /
  `pode_ver_contato`, sem bypass de admin) **e** passam pelo corte de linha. Admin sem a área não vê R$,
  CPF, nascimento, saúde, e-mail nem telefone, mesmo vendo todas as linhas.
- **Quem vê, grava.** Se a pessoa vê a linha, pode agir nela (agendar, editar…), inclusive na
  própria. **Se o botão da ação aparece** é decisão do nível Botão, não deste.

---

## O que é filtrado e o que não é

| Conteúdo | Exemplos | Filtro |
|---|---|---|
| Institucional | aba Sobre, drawer Sobre (versão, "o que é", números do portal, responsável), textos de ajuda | nenhum: igual para todos que abrem a página |
| Dado de pessoa | lista, kanban, ficha do colaborador e os **KPIs e gráficos calculados a partir dessas linhas** | nível Linha |
| Valor | R$ (recibos, líquido, salário), CPF, data de nascimento, saúde (atestados, exames) | nível Valor **e** nível Linha |
| Contato | e-mail, telefone | nível Contato **e** nível Linha |

Os KPIs e gráficos não precisam de nada a mais: são calculados no navegador a partir das
linhas que a RPC devolveu, então já saem só da equipe.

---

## Fonte da verdade: o organograma

- **`tata_plus.profiles`**: `id_pessoa` (a pessoa), `id_superior` (o `id_pessoa` do chefe
  imediato), `matricula`, `status`. Raiz = `id_superior` vazio.
- O dado vem do **RHID** → planilha "Colaboradores" (`git-claude/sincronizarColaboradores.gs`)
  → Supabase. O portal não edita a hierarquia.
- **Quem está logado:** `tata_plus.minha_matricula()` (e-mail do JWT → matrícula, só
  `status = 'Ativo'`). Inativo não tem matrícula e não vê nada.
- **Visibilidade errada = organograma errado.** Chefe errado no RHID muda quem vê; a correção é
  lá, nunca no portal. Quem fica sem chefe só aparece para admin, RH e para a própria pessoa.

---

## A função: `tata_plus.minha_subarvore()`

Devolve as matrículas que o usuário logado alcança pela hierarquia: **ele + todos abaixo**.

```sql
-- matrículas que o usuário logado alcança pelo organograma: ele + toda a subárvore
create or replace function tata_plus.minha_subarvore()
returns text[]
language sql
stable
security definer
set search_path to 'tata_plus', 'public'
as $$
  with recursive eu as (
    select nullif(btrim(id_pessoa), '') as id_pessoa, matricula
      from tata_plus.profiles
     where matricula = tata_plus.minha_matricula()
  ),
  sub as (
    select id_pessoa, matricula from eu
    union                       -- sem "all": linha repetida é descartada, então ciclo não trava
    select nullif(btrim(p.id_pessoa), ''), p.matricula
      from tata_plus.profiles p
      join sub s on nullif(btrim(p.id_superior), '') = s.id_pessoa
  )
  select coalesce(array_agg(matricula), '{}') from sub;
$$;
revoke all on function tata_plus.minha_subarvore() from public;
grant execute on function tata_plus.minha_subarvore() to authenticated;
```

- **Atravessa inativos.** Se um chefe é desligado antes de o RHID trocar o chefe da equipe dele,
  o líder de cima continua vendo essa equipe. Quem filtra ativo/inativo é a RPC da página.
- **Ciclo não trava:** `union` (sem `all`) descarta a linha repetida.
- **Sem `id_pessoa`:** devolve só a própria matrícula (cai no caso "sem equipe").
- **Sem login:** devolve `{}`.
- **Não decide admin/RH.** Isso fica na RPC (próxima seção), para a função servir a qualquer página.

---

## Molde da RPC de leitura

```sql
with eu as (
  select tata_plus.minha_subarvore() as sub,
         dp_rh.ferias_eh_rh(tata_plus.minha_matricula()) as todas   -- admin ou RH
)
select …
  from dp_rh.<tabela> t
  join eu on true
 where eu.todas or t.matricula = any(eu.sub);
```

- **Calcule a subárvore uma vez** (no `with eu`), não por linha.
- A função também confere a **página** (`gov_tenho_acesso`) e mascara **Valor** e **Contato**: molde
  completo em `references/servidor.md`.
- `security definer` + `search_path` fixo + `revoke … from public, anon` e `grant … to authenticated`,
  o mesmo padrão das migrations de Férias.
- **A RPC não recebe "quem sou eu".** O servidor descobre pelo JWT. Nunca aceite matrícula do
  líder vinda do navegador.
- **Admin/RH:** a regra é a de `dp_rh.ferias_eh_rh` (`perfil` admin ou analista-rh, ou
  `departamento` rh). Quando a segunda área adotar o nível Linha, vale promover essa regra para
  uma função genérica.

---

## Molde da escrita

Antes de gravar, a mesma pergunta da leitura:

```sql
if not dp_rh.ferias_eh_rh(v_mt) and not (v_alvo = any(tata_plus.minha_subarvore())) then
  return jsonb_build_object('ok', false, 'erro', 'sem permissão: colaborador fora da sua equipe');
end if;
```

Ações que são só do RH (ajustar direito, quitar, cancelar agendamento…) continuam só do RH. O molde
completo da escrita (botão com `pode_botao` + linha + autor do login) está em `references/servidor.md`.

---

## Eixo de cada página

O registro precisa ligar a uma **matrícula** para entrar no corte.

| Página | O registro liga em | Regra | Situação |
|---|---|---|---|
| Férias | `matricula` do colaborador | `matricula = any(sub)` | piloto (ver "Estado atual") |
| Vagas / Recrutamento | `lider_responsavel` (é um **nome**) | líder responsável na subárvore | pendente: casar nome → matrícula antes |
| Admissão, Ausências, outras | a definir ao aplicar | — | — |

---

## No HTML

- **Dado de pessoa só sai pela RPC escopada.** Nada de `.from()` em tabela ou view de dado
  sensível, e nada de filtrar no navegador: filtro no front não protege, o dado inteiro já trafegou.
- **Sem parâmetro de identidade** na chamada: `supa.schema('tata_plus').rpc('ferias_listar')`.
- **Sem id e sem catálogo.** O nível Linha não aparece no painel do admin nem na Auditoria de páginas.
- **Estado vazio:** "sem equipe" pode ver só a própria linha, ou nenhuma. A página precisa de uma
  mensagem de vazio, e o Sobre continua lá.
- Filtros de equipe no navegador **não protegem nada** e dependem de campos que a sessão do `gate.js`
  não tem. Mapeamento de 08/11/2026: só o `_liderMatchVaga` do `recrutamento.html` ainda age (o líder vê
  0 vagas ou todas, conforme o caminho); os filtros por unidade de Armários e Sanções já não fazem nada.
  Tire cada um **só junto** com o corte de linha no servidor, senão o líder passa a ver mais.

---

## Estado atual (08/11/2026)

- **Férias (piloto):** a migration `supabase/migrations/20261118_ferias_subarvore.sql` cria
  `tata_plus.minha_subarvore()` e troca o corte de `ferias_listar`, `ferias_valores_listar` e
  `ferias_gravar` de 1 nível (`id_superior = meu id_pessoa`, sem o próprio) para **subárvore + o
  próprio**, com página (`gov_tenho_acesso`) e botão (`pode_botao` em `::agendar-ferias` e
  `::ajustar-ferias`). **Aplicada em 08/11/2026.** A pendência "Férias pendente" do líder no app
  (`minhas_pendencias`, tipo `ferias_lider`) usa a mesma subárvore (migration `20261119`); os demais
  tipos de pendência de líder seguem em 1 nível até cada página adotar o nível Linha.
- Nenhuma outra página corta por hierarquia no servidor.
- `dp_rh.ferias`, `dp_rh.ferias_recibos` e as views `agente.*` não são legíveis por `anon` nem
  por `authenticated`: a RPC é a única porta. `tata_plus.profiles` só deixa ler a própria linha.
- Organograma: só 3 pessoas ativas sem chefe (as raízes); nenhuma ativa com chefe inexistente
  ou inativo.

---

## Testar sem logar como a pessoa

No SQL do Supabase, troque `minha_matricula()` pela matrícula de teste:

```sql
with recursive eu as (
  select nullif(btrim(id_pessoa), '') as id_pessoa, matricula
    from tata_plus.profiles where matricula = '<matricula>' and status = 'Ativo'
), sub as (
  select id_pessoa, matricula from eu
  union
  select nullif(btrim(p.id_pessoa), ''), p.matricula
    from tata_plus.profiles p join sub s on nullif(btrim(p.id_superior), '') = s.id_pessoa
)
select count(*) as na_subarvore,
       count(*) filter (where p.status = 'Ativo') as ativos
  from sub join tata_plus.profiles p using (matricula);
```

⚠️ O resultado é dado de pessoa: não cole em arquivo do repo (o repo vai inteiro para o GitHub Pages).

---

## Checklist

- [ ] A página lê dado de pessoa **só** por RPC `security definer`, sem parâmetro de identidade.
- [ ] A função confere a página (`gov_tenho_acesso`) e, se for ação, o botão (`pode_botao`).
- [ ] A RPC calcula `minha_subarvore()` uma vez e filtra `todas or matricula = any(sub)`.
- [ ] A escrita faz a mesma checagem antes de gravar.
- [ ] Admin/RH pela regra de `ferias_eh_rh`; Valor e Contato continuam exigindo `pode_ver_valores` /
  `pode_ver_contato`.
- [ ] Tabela e view do dado com `revoke … from anon, authenticated` (a RPC é a única porta).
- [ ] O Sobre não passa pelo corte; KPIs e gráficos saem das linhas já filtradas.
- [ ] Estado vazio tratado ("sem equipe").
- [ ] Testado com a matrícula de um líder (subárvore) e de alguém sem equipe.
