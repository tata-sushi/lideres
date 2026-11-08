---
name: gate-login-e-registro
description: >-
  Login e registro do Portal Líderes: o gate.js (compliance/gate.js) diz QUEM é
  a pessoa e garante que toda mudança no banco fique registrada (quando e quem
  fez). A página abre só dentro do app Tatá Plus (iframe); fora dele mostra
  "Disponível pelo aplicativo". O app entrega o login por postMessage
  (gov-ready → gov-session com as duas chaves, acesso ~1h e renovação, origem
  conferida) e reenvia a cada renovação, então a página aguenta horas aberta. O
  gate cria o único cliente logado (window.__lideresSupa, evento lideres:supa) e
  publica a identidade só para mostrar (__lideresUser, __lideresSession), nunca
  para decidir nada. Registro, tudo por gatilho a partir do login e nunca pela
  página: toda tabela tem atualizado_em e atualizado_por, e toda movimentação
  (criação, alteração, exclusão) entra no log geral registro.movimentacoes (o
  que mudou, quem, quando; só admin lê; guarda 6 meses). Nada sem login: nenhuma página fora do gate, nenhum cliente próprio ou
  chave pública sem login, nenhuma API pública com dado do portal, nada sensível
  escrito no HTML (o repo é público). Mensagens entre app e página só com origem
  conferida. NÃO decide acesso (página, aba, botão, valor, contato, linha → skill
  controle-de-acessos-e-visibilidade). Use SEMPRE que for criar página nova, mexer
  no gate.js, no login, nas chaves/token, no postMessage com o app (gov-session,
  gov-ready, gov-ok, gov-denied, gov-pin), no cliente Supabase da página, em
  autor, "quem fez", atualizado_por/atualizado_em, registro ou auditoria de
  mudanças, ou quando o pedido falar em login, sessão, token, gate,
  autenticação, fraude, registro ou "sem login".
---

# Gate: login e registro

O `gate.js` responde **quem é a pessoa**, e o banco guarda **quem fez cada mudança**. Esta skill é a
fonte única desses dois assuntos. **O que a pessoa pode abrir e ver** (página, abas, botões, valores,
contato, linhas) é da skill **`controle-de-acessos-e-visibilidade`**.

| | Esta skill: login e registro | `controle-de-acessos-e-visibilidade` |
|---|---|---|
| Responde | quem é a pessoa? quem fez a mudança? | o que ela pode abrir, ver e fazer? |
| Onde | `compliance/gate.js` + colunas de registro em toda tabela | camada de acesso + funções do banco |

A aplicação (mudar o `gate.js`, as páginas e o banco) é feita por outro agente, seguindo esta skill.

---

## 1. Como o login chega na página

1. O app Tatá Plus abre a página num iframe (`GovFrame.jsx`, repo `tata-sushi/plus`).
2. O gate marca `html[data-auth="pending"]` (tela escondida). **Fora do app** (página aberta direto no
   navegador), mostra "Disponível pelo aplicativo" e para por aí.
3. O gate pede o login: manda `gov-ready` ao app a cada 300 ms, por até ~7,5 s. O app responde com
   `gov-session`, e também manda sozinho quando a página termina de carregar.
4. O gate **confere a origem** (`https://plus.tatasushi.tech`). Depois cria o cliente Supabase
   (`persistSession: false`, `autoRefreshToken: false`), aplica as chaves e publica
   `window.__lideresSupa`, disparando o evento `lideres:supa`.
5. **Renovação:** o app renova as chaves sozinho e reenvia `gov-session`. O gate aplica no mesmo
   cliente, sem renovar por conta própria (para não trocar a chave de renovação do app). Por isso a página
   aguenta horas aberta.
6. **Identidade:** `window.__lideresUser` (nome) e `window.__lideresSession` (`displayName`, `perfil`,
   `paginas`), com o evento `lideres:sessao`.
7. Se o login não chegar a tempo, a página fica negada.

### As duas chaves (decisão do dono, 08/11/2026)

O app entrega **as duas chaves**: a de acesso (~1 h) e a de renovação. Fica assim porque há usuários que
passam muito tempo numa página. Regras:

- A página **nunca renova sozinha** (`autoRefreshToken: false`); só aplica o que o app manda.
- Nunca mostre, registre ou envie as chaves para lugar nenhum: console, URL, HTML, repo, outro site.
- As chaves só vivem no cliente do gate. Nenhum outro código da página lê ou usa as chaves.

---

## 2. O cliente logado é um só

- Toda leitura e gravação da página usa `window.__lideresSupa`. Se ele ainda não existe, espere o
  evento `lideres:supa`:
  ```js
  function comSupa(cb){
    if (window.__lideresSupa) { cb(window.__lideresSupa); return; }
    window.addEventListener('lideres:supa', function(){ cb(window.__lideresSupa); }, { once: true });
  }
  ```
- **Nunca** `supabase.createClient` na página, nunca a chave pública sem login, nunca `fetch` direto ao
  Supabase, a planilhas ou a scripts públicos. Sem o cliente do gate, o banco não sabe quem é a pessoa:
  não há regra por pessoa nem registro.

---

## 3. Identidade: só para mostrar

- `window.__lideresUser` / `__lideresSession.displayName` servem para **mostrar** o nome na tela ou num PDF
  ("emitido por").
- **Não decidem nada:** o perfil na página pode ser alterado por quem abre o console. Quem decide o acesso
  é o servidor (skill de acesso).
- **Não vão para o banco como autor:** o servidor sabe quem é pelo login (`tata_plus.minha_matricula()`,
  `tata_plus.meu_nome()`).
- `localStorage.lideres_session` é uma cópia antiga. Sai do gate quando nenhuma página ler mais.

---

## 4. Registro: quem fez cada mudança (decisões do dono, 08/11/2026)

Duas camadas, as duas preenchidas **pelo banco, por gatilho**, a partir do login:

| Camada | Onde | O que guarda |
|---|---|---|
| **Última mudança** | em cada tabela: `atualizado_em` (`timestamptz`) e `atualizado_por` (`text`) | quando e quem fez a última mudança naquela linha |
| **Log geral** | `registro.movimentacoes` (schema `registro`, fora da API) | **toda movimentação** (criação, alteração, exclusão, limpeza de tabela), com histórico: quando, tabela, linha, quem (nome e matrícula) e **o que mudou** (na alteração, só os campos alterados, antes → depois; na criação e na exclusão, a linha inteira) |

- **Quem fez** é o nome de quem está logado (`meu_nome()`). Sem login, aparece `sistema` (integração),
  `sem login` ou `login sem cadastro ativo`.
- **Ninguém registra em nome de outra pessoa:** a página e a função não preenchem nada, e o gatilho
  sobrescreve qualquer valor mandado.
- Alteração que não muda nada não entra no log.
- **Quem lê o log:** só admin, pela função `tata_plus.registro_listar`. Valor (R$, CPF, nascimento, saúde) e
  Contato (e-mail, telefone) ficam mascarados para quem não tem a liberação, como no resto do portal.
- **Prazo:** 6 meses. O banco apaga sozinho, todo dia, o que passar disso (`pg_cron`).
- As colunas de autor que já existem (`criado_por`, `autor`, `responsavel`…) continuam.
- Molde completo (testado), ordem de aplicação e como conferir → `references/registro.md`.

---

## 5. Nada sem login

- **Toda página** tem o overlay `#auth-gate` e o include padrão, nesta ordem: supabase-js →
  `window.GOV_PAGE_ID` → `gate.js` → camada de acesso. O bloco completo está em
  `controle-de-acessos-e-visibilidade/references/camada-de-acesso.md`.
- **Nenhuma página fora do gate.** Decisões do dono (08/11/2026):
  - `lista.html` (lista numerada das páginas) → **apagar**.
  - App antigo de Escalas (`escalas.tatasushi.tech`, pasta `escalas/`, com API num script público do Google
    aberto para "Qualquer pessoa") → **desligar**: tirar do ar na Vercel, desativar o script, apagar a pasta
    e tirar `ESCALAS_ORIGIN` do `GovFrame.jsx` no app. A escala fica só no "Controle de Escala" do portal.
- **Nenhum cliente próprio ou chave pública sem login.** Hoje há 4 páginas assim: Abastecimento, Estoque
  semanal, Checklist de limpeza e o bloco de inventário da Admissão.
- **Nada sensível escrito no HTML ou no JS.** O repositório e o site são públicos: o gate esconde a tela e o
  servidor protege os dados, mas o código da página qualquer um baixa. Nada de nomes, e-mails, CPF,
  valores, listas de pessoas nem chaves além da pública do Supabase.
- **Nada de dado de pessoa guardado no navegador** (`localStorage`/`sessionStorage`) além da sessão do gate.

---

## 6. Mensagens entre o app e a página

| Mensagem | De → para | Conteúdo |
|---|---|---|
| `gov-ready` | página → app | "estou pronta, me mande o login" |
| `gov-session` | app → página | as duas chaves, nome e perfil |
| `gov-ok` / `gov-denied` | página → app | acesso resolvido (o app tira o carregando dele) |
| `gov-pin-query` / `gov-pin-toggle` | página → app | botão "Fixar no app" |
| `gov-pin-state` | app → página | página fixada ou não |

**Regra:** quem recebe confere a origem (a página só aceita `https://plus.tatasushi.tech`; o app só aceita
`https://lideres.tatasushi.tech`), e quem envia diz a origem de destino, **nunca `'*'`**. Hoje o script
"Fixar no app" das páginas aceita mensagem de qualquer origem e envia com `'*'` → corrigir.

---

## 7. O que o `gate.js` faz hoje e o que muda

| Hoje no `gate.js` | Fica? |
|---|---|
| `gov-ready` / `gov-session`, `estabelecer`, `setSession`, `__lideresSupa`, `lideres:supa` | **fica** (login) |
| identidade (`__lideresUser`, `__lideresSession`, `lideres:sessao`) e "Disponível pelo aplicativo" | **fica** |
| avisar o app (`gov-ok` / `gov-denied`) | **fica**, disparado quando a camada de acesso decidir |
| liberar/negar a página, esconder abas e botões, travar cards | **sai** para a camada de acesso (skill de acesso) |
| `aplicarPerfilNoBody` (`is-admin` / `is-lider`) e o chip `#header-user` | **apagar** (ninguém usa) |
| cópia `localStorage.lideres_session` | **apagar** quando nenhuma página ler |
| cache `gov_cache` (`sessionStorage`) | fica, mas **por pessoa**: se chegar login de outra pessoa no mesmo aparelho, o cache é descartado (hoje a tela pode mostrar, por instantes, as permissões da pessoa anterior) |

---

## Regras de ouro

- O gate diz **quem é**; quem decide **o que pode** é a skill de acesso, no servidor.
- **Um só cliente logado** por página: `window.__lideresSupa`.
- **Autor sempre pelo login**, nunca pela página. Toda tabela tem `atualizado_em` e `atualizado_por`, e toda
  movimentação vai para o log geral. Tudo por gatilho.
- **Nenhuma página sem login**, nenhum cliente próprio, nenhuma API pública com dado do portal.
- **Nada sensível no HTML, no JS nem no repo**: o repositório vai inteiro para o GitHub Pages.
- **Origem conferida** em toda mensagem entre app e página; nunca `'*'`.
- As chaves ficam só no cliente do gate; a página nunca renova sozinha.

## Limites (o que o gate não garante)

- **O HTML é público:** o gate esconde a tela, mas não o código. A proteção dos dados é o servidor.
- **Ações que não mudam o banco** (gerar PDF, imprimir, exportar) não ficam registradas (ok do dono).
- **O log guarda 6 meses**; depois disso a movimentação some.
- **A máscara do log é pelo nome do campo:** campo sensível novo, com outro nome, precisa entrar na lista de
  `registro.mascarar`.
