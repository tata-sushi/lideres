---
name: controle-de-acessos-e-visibilidade
description: >-
  Fonte ÚNICA do controle de acesso e visibilidade do Portal Líderes (páginas de
  Governança): quem abre cada página, o que vê e faz nela, que dado sensível vê e
  de quem são os registros. 6 níveis: PÁGINA (window.GOV_PAGE_ID), ABA
  (data-aba-id, visível por padrão, denylist), BOTÃO (data-aba-id ou
  data-botao-id; toda ação; oculto por padrão, allowlist; header sem id), VALOR
  (máscara no servidor: R$, CPF, nascimento e saúde; sem bypass de admin),
  CONTATO (máscara no servidor: e-mail e telefone; separado do Valor) e LINHA
  (organograma: o líder vê os próprios + toda a subárvore; admin e RH tudo). O
  servidor é a porta: toda função de página confere a página (gov_tenho_acesso),
  toda ação o botão (pode_botao), corta a linha, mascara Valor/Contato e pega o
  autor do login; nada sem login, nada de sandbox. No navegador, a camada de
  acesso (hoje dentro do gate.js, que fica só com login e registro) aplica
  página, abas, botões e cards; a página não decide acesso (sem checar perfil,
  sem filtro de equipe, sem trava própria de card). Chave =
  <GOV_PAGE_ID>::<slug>; o admin libera por pessoa no app plus (catálogo
  governanca_abas). Use SEMPRE que for criar, editar, esconder ou liberar página,
  aba, botão de ação, card de menu, valor ou dado sensível (CPF, e-mail,
  telefone, nascimento, saúde); ao mexer em data-aba-id, data-botao-id,
  data-access-id, GOV_PAGE_ID, gate.js, aplicarBotoes ou governanca_abas; ao
  criar ou alterar função do banco usada por página; quando a página mostrar
  dado de pessoa e o líder só puder ver a equipe; e quando o pedido falar em
  acesso, permissão, visibilidade, "quem vê o quê", perfil, hierarquia,
  subárvore, liderados, dado sensível ou LGPD. Não invente ids nem mude o
  modelo sem checar aqui.
---

# Controle de acessos e visibilidade (Governança)

**Esta é a fonte única** de tudo o que é acesso e visibilidade no portal: quem abre cada página, o que vê
e faz dentro dela, que dado sensível aparece e de quem são os registros. Os guias antigos
(`git-claude/readmeauth.md`, `readmemenu.md` e o modelo antigo do `CLAUDE.md` §1 e §3) foram apagados em
08/11/2026; o que ainda valia está aqui.

As páginas de `compliance/**` abrem **só embarcadas no app Tatá Plus** (num iframe). Cada página
controla **por pessoa** o que aparece dentro dela, por **IDs** — atributos `data-*` no HTML que casam
com um catálogo no Supabase — e o **servidor** repete as mesmas checagens dentro das funções do banco.
**A skill existe para manter isso correto e padronizado** em todas as páginas.

Dois tipos de nível não têm atributo no HTML: **Valor** e **Contato** (máscara no servidor) e **Linha**
(de quem são os registros, sai sozinho do organograma).

## Acesso × login (o `gate.js`)

| | `gate.js` — login e registro | Esta skill — acesso e visibilidade |
|---|---|---|
| Responde | quem é a pessoa? | o que ela pode abrir, ver e fazer? |
| Cuida de | abrir só dentro do app, token, cliente logado, identidade, registro de quem fez cada ação | página, abas, botões, cards dos menus, Valor, Contato e Linha — no navegador **e** no servidor |

Hoje o `gate.js` ainda faz partes de acesso (libera a página, esconde abas e botões, trava os cards).
**Elas são desta skill** e saem dele para a **camada de acesso** (decisão do dono, 08/11/2026). O ajuste
do `gate.js` é um trabalho separado, depois desta skill. O que sai, o contrato entre os dois, o overlay
`#auth-gate`, os cards dos menus e o que não pode existir na página → `references/camada-de-acesso.md`.

**Dois repositórios, dois papéis:**

- **`lideres`** (este repo) — o **HTML** das páginas (`compliance/**`). É onde os IDs
  vivem: você **cria/edita/padroniza** os ids de página, aba, botão, valor e contato aqui.
- **`tata-sushi/plus`** — o **app** onde o **admin escolhe, por pessoa, quem acessa**
  cada página/aba/botão/valor/contato. Ele lê os ids do HTML pelo catálogo no Supabase
  (`schema tata_plus`, tabela `governanca_abas`) e mostra um liga/desliga por pessoa.

> **A fonte da verdade é o HTML.** O catálogo e o painel só ligam/desligam as chaves
> que existem no HTML. Se o id do HTML e o do catálogo divergirem, o interruptor do
> admin **não controla nada**. Nunca invente uma chave e nunca renomeie um slug sem
> atualizar o catálogo.

Referências (leia conforme a tarefa):

- **`references/camada-de-acesso.md`** — o que sai do `gate.js`, o contrato gate × acesso, o overlay
  `#auth-gate`, os cards dos menus e **o que não pode existir na página**. Antes de mexer no HTML.
- **`references/servidor.md`** — o servidor é a porta: as 8 regras e os moldes de função (leitura e
  escrita) com página, botão, linha, máscaras e autor do login. Antes de criar ou alterar função do banco.
- **`references/backend-supabase.md`** — catálogo, tabelas, RPCs, painel admin do Plus,
  registrar chave, replicar config entre pessoas. Antes de mexer no Supabase/painel.
- **`references/padronizacao.md`** — vocabulário canônico de slugs e como migrar com segurança.
- **`references/hierarquia.md`** — nível Linha: quem vê quais registros pelo organograma, a função
  `minha_subarvore()`, os moldes de RPC (leitura e escrita), o eixo de cada página e o estado atual.
  Antes de mexer em página que mostra dado de pessoa.
- **`scripts/auditar-acessos.py`** — varre `compliance/**/*.html`, aponta problemas e
  inconsistências e imprime o vocabulário de slugs. **Rode antes de criar uma chave nova**:
  ```bash
  python3 .claude/skills/controle-de-acessos-e-visibilidade/scripts/auditar-acessos.py
  ```
- **`scripts/relatorio-acessos.py`** — quando o dono pedir **"quais ids temos e quem vê o quê"**:
  cruza os ids do HTML com o banco e gera uma página com a visão **por página** (cada aba/botão
  e quem vê), a visão **por pessoa** e os **pontos de atenção** (id sem registro no banco, nome
  antigo, id só no banco, pessoa inativa com acesso, liberação sem efeito, página fora do
  cadastro). Os 4 SQLs que geram os dados estão no topo do script; confira as contagens antes de
  mostrar. ⚠️ **Tem nome de pessoas: gere no scratchpad e entregue como arquivo — nunca commite
  nem publique** (o repo vai inteiro para o GitHub Pages).
  ```bash
  python3 .claude/skills/controle-de-acessos-e-visibilidade/scripts/relatorio-acessos.py <pasta_dump> <saida.html>
  ```
- **`assets/matriz-acessos.html` + `scripts/estado-acessos.py`** — a **tabela de acessos** onde o dono clica
  para incluir/tirar pessoas (por página, por pessoa, ids das páginas, grade páginas × pessoas).
  Fluxo completo em `references/backend-supabase.md` §"Tabela de acessos".
- **`compliance/auditoria/paginas.html` (Auditoria de páginas, menu Compliance do app)** — a mesma grade
  páginas × colaboradores, **ao vivo no portal e só para admin**: linha da página (quem abre) + uma linha por
  aba / botão / valor (quem vê) em cascata (seção › subseção › página › item, só pelo recuo), pílula do tipo à direita
  do nome (página e aba azul · botão âmbar · valor carbon), coluna **Total** (quantos veem, admins incluídos) e lápis na **última coluna (fixa à direita)**
  que abre a lista de colaboradores com chaves; "Salvar" grava só o que mudou. **Por colaborador:** botão na 1ª linha da
  tabela, coluna Editar (ícone de pessoas no computador, "Colaborador" no celular), ou Menu › "Editar por colaborador":
  a janela tem um seletor do colaborador (só o nome, em ordem alfabética; inclui quem ainda não tem acesso) e abre tudo da pessoa em cascata, com chaves; o "Salvar" chama `gov_auditoria_salvar` uma vez por mudança, na
  ordem páginas que entram › abas/botões/valores › páginas que saem. Colunas em ordem alfabética, admins junto (só o nome), com
  ● carbon (igual aos demais) onde veem automaticamente (fora da seção App, menos valores). Lê `gov_auditoria_acessos` e
  grava `gov_auditoria_salvar` (backend §"Página Auditoria de páginas"). Não tem lista própria de ids: página,
  aba ou botão novo aparece nela assim que entra no catálogo (`ativo`).

---

## Os 6 níveis

Todo controle cai em **um de seis níveis**: cinco que o admin liga/desliga por pessoa e a **Linha**,
automática pelo organograma. Identificar o nível define o atributo, o default e onde (ou se) o admin
liga/desliga:

| Nível | O que é / onde no HTML | id no HTML | `tipo` no catálogo | Default (quem não é admin) | Admin controla… |
|---|---|---|---|---|---|
| **Página** | a página inteira | `window.GOV_PAGE_ID` | (`governanca_paginas`) | **oculto** — precisa ser concedido | acesso à página |
| **Aba** | `tab-btn` (abas de navegação da página) | `data-aba-id` | `aba` | **VISÍVEL** — some só se bloquear (denylist) | liga/desliga por aba |
| **Botão** | **qualquer botão de ação** (drawer **ou** dentro da página) | `data-aba-id` **ou** `data-botao-id` | `botao` | **OCULTO** — aparece só se liberar (allowlist) | libera por botão |
| **Valor** | **R$** (salário, recibos…), **CPF**, **data de nascimento** e **saúde** (atestados, exames) | — (área, máscara no servidor) | `valor` | **mascarado** no servidor | libera por pessoa e área |
| **Contato** | **e-mail** e **telefone** | — (área, máscara no servidor) | `contato` | **mascarado** no servidor | libera por pessoa e área, separado do Valor |
| **Linha** | quais registros (linhas de dado) aparecem | — (corte na função) | — (sem catálogo) | **só os próprios + a subárvore** | nada — vem do organograma |

Regras dos níveis:

- **Botão é um nível só.** Não distinga botão do drawer de botão dentro da página —
  todos são "botão" (`tipo='botao'`, ocultos até liberar). Uniformize.
- **Botões de navegação do header NÃO têm id.** Zoom, fixar no menu, abrir o drawer, o
  "+" etc. entram **junto com o acesso à página** — não precisam de controle próprio,
  não recebem `data-aba-id`/`data-botao-id`.
- **Admin (`perfil='admin'`) vê tudo** nos níveis Página/Aba/Botão. **Valor e Contato não:** só com a
  liberação da área (ou `geral`), sem bypass de admin. (Outra exceção: as features da seção "App" do
  Plus — Kanban/Escala/Limpeza — não têm bypass de admin.) Na **Linha**, admin e RH veem todas as linhas.

**Valor** e **Contato** não são atributo num elemento: são **áreas** mascaradas no servidor (detalhe no
fim e em `references/backend-supabase.md`). A **Linha** é um corte nas funções do banco, decidido pelo
organograma (resumo no fim e detalhe em `references/hierarquia.md`).

---

## Que botões levam id (decisão do dono, 04/10/2026)

**Toda aba e todo botão que começa uma ação** levam id — o admin libera tudo pelo app.
- **Leva:** criar, editar, excluir, enviar, gerar (PDF/documento/relatório), exportar/baixar, imprimir,
  registrar, aprovar/reprovar/homologar/avaliar, importar/atualizar dados — no drawer, no topo da aba, na linha
  da tabela, no cartão do celular ou dentro de uma ficha que abre só para leitura. Cópias do mesmo botão
  (linha + cartão + ficha, texto + ícone) levam **o mesmo** id.
- **Não leva:** header, "i" dos cards, filtros, "Limpar", "Ver mais", fechar/cancelar, abas internas de janela,
  olho/visualizar (ver não é ação), e botões **dentro de uma janela que só abre por um botão que já tem id**.
- **Id em botão que já existia:** cadastrar + liberar para quem já abre a página no mesmo comando (SQL modelo em
  `references/backend-supabase.md`), para ninguém perder o botão no dia.

---

## Formato da chave: `<GOV_PAGE_ID>::<slug>`

Abas e botões usam uma chave com duas partes separadas por **`::`** (dois-pontos duplo):

```
governanca-kpis-rh-recrutamento :: nova-vaga
└────────── GOV_PAGE_ID ───────┘   └─ slug ─┘
```

- **`GOV_PAGE_ID`** — o id da página, o **mesmo** valor de `window.GOV_PAGE_ID` (declarado
  logo antes do `gate.js`). Deriva do caminho: `compliance/kpis/rh/recrutamento.html` →
  `governanca-kpis-rh-recrutamento` (`compliance`→`governanca`, segmentos com `-`, sem
  `.html`/`index`). O prefixo de **toda** chave da página tem que ser igual ao
  `GOV_PAGE_ID` dela. ⚠️ Exceção real: `escalas.html` usa `governanca-app-escala`.
  Sempre confira o `window.GOV_PAGE_ID` real em vez de deduzir pelo caminho.
- **`slug`** — nome curto em **kebab-case**, sem acento nem espaço, em **português**
  (`nova-vaga`, `editar-candidato`). É a chave que vive no catálogo: **estável**.
  Renomear **órfã** a config existente. Reuse o slug canônico (`references/padronizacao.md`).

`include` padrão no HTML (copie de uma página que funciona):

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>
<script>window.GOV_PAGE_ID = 'governanca-kpis-rh-recrutamento';</script>
<script src="/compliance/gate.js"></script>
```

Antes desses scripts vem o overlay `#auth-gate`. Quando a camada de acesso sair do `gate.js`, entra
uma linha a mais, logo depois dele (`references/camada-de-acesso.md`).

Um mesmo slug **pode se repetir** em vários elementos (ex.: "Editar candidato" na lista
e no modal): um único interruptor no admin controla todas as instâncias.

---

## Como cada nível é aplicado (aba e botão)

- **Aba → sempre `data-aba-id`.** A camada de acesso (hoje dentro do `gate.js`) esconde por CSS
  as abas que a RPC `gov_minhas_abas_bloqueadas` mandar. Visível por padrão. **Nenhum JS**
  na página; se a aba ativa cair no bloqueio, ela ativa a primeira visível.

- **Botão → dois jeitos de implementar o mesmo nível** (ambos `tipo='botao'`, oculto por
  padrão). Escolher o errado não muda o nível, muda o *como*:

  | | `data-aba-id` (via gate.js) | `data-botao-id` (via `pode_botao`) |
  |---|---|---|
  | Quem aplica | camada de acesso (hoje no `gate.js`) | JS da própria página (`aplicarBotoes`) |
  | Como resolve | servidor devolve como "a esconder" até liberar | `pode_botao` por botão devolve `true`/`false` |
  | O que trava | **esconde** o botão (CSS) | **esconde E bloqueia a ação** (via `GOV_BTN_OK`) |
  | Trabalho na página | nenhum — só o atributo | atributo **+** `GOV_BOTOES` **+** checar `GOV_BTN_OK` na ação |
  | Exemplo | `recrutamento.html` | `escalas.html` |

  **Qual usar num botão:**
  - Padrão → **`data-aba-id` + `tipo='botao'`**. Menos código, a camada de acesso cuida. Serve
    quando **esconder o botão basta**.
  - **`data-botao-id`** → só quando **a AÇÃO precisa ser travada, não só escondida**: uma
    ação com mais de um ponto de entrada. Ex.: em `escalas.html`, "Editar semana" abre
    pelo botão (mobile) **e** clicando no nome (desktop) — esconder o botão não impediria
    o desktop. Guarda o `pode_botao` em `GOV_BTN_OK` e a função da ação consulta antes de rodar.

  **Nos dois jeitos, a função do banco da ação confere `pode_botao('<chave>')`**
  (`references/servidor.md`). Esconder o botão não impede quem chama a função direto.

---

## Como adicionar um controle

### Nível Aba, e Botão pelo padrão `data-aba-id`

1. Confirme `window.GOV_PAGE_ID` + `gate.js` na página (bloco acima).
2. Ponha o atributo com a chave `<GOV_PAGE_ID>::<slug>`:
   ```html
   <button class="tab-btn" id="tab-vagas"
           data-aba-id="governanca-kpis-rh-recrutamento::vagas"
           onclick="setTab('vagas')">Vagas</button>

   <button class="drawer-sam-btn"
           data-aba-id="governanca-kpis-rh-recrutamento::nova-vaga"
           onclick="closeDrawer(); openNewVaga()">Abrir Vaga</button>
   ```
3. **Sem JS na página** — a camada de acesso já cuida.
4. Cadastre a chave em `governanca_abas` com o `tipo` certo (`aba` p/ abas, `botao` p/
   ações). Sem isso o admin não tem o que ligar/desligar → `references/backend-supabase.md`.

### Nível Botão pelo padrão `data-botao-id` (ação a ser travada)

1. Atributo no botão, mesma convenção de chave:
   ```html
   <button class="drawer-sam-btn"
           data-botao-id="governanca-app-escala::cadastrar-horario"
           onclick="closeDrawer(); abrirCadastroHorario();">Cadastrar horário</button>
   ```
2. Liste a chave em `GOV_BOTOES` e rode `aplicarBotoes()` (padrão do `escalas.html`):
   esconde tudo por padrão (sem flash) e libera só o que `pode_botao` aprovar:
   ```js
   var GOV_BOTOES = ['governanca-app-escala::cadastrar-horario', /* … */];
   var GOV_BTN_OK = {};
   function aplicarBotoes(){
     var st = document.getElementById('gov-btn-css')
       || Object.assign(document.head.appendChild(document.createElement('style')), {id:'gov-btn-css'});
     var repintar = function(){
       st.textContent = GOV_BOTOES.filter(function(id){ return GOV_BTN_OK[id] !== true; })
         .map(function(id){ return '[data-botao-id="'+id+'"]{display:none!important}'; }).join('');
     };
     repintar();
     GOV_BOTOES.forEach(function(id){
       TP().rpc('pode_botao', { p_aba_id: id }).then(function(r){
         GOV_BTN_OK[id] = (!r.error && r.data === true); repintar();
       }, function(){ GOV_BTN_OK[id] = false; repintar(); });
     });
   }
   ```
3. **Trave a ação, não só o botão:** cheque `GOV_BTN_OK[id]` na função da ação (navegador) e
   `pode_botao` na função do banco (servidor).
4. Cadastre a chave no catálogo com `tipo='botao'`.

---

## O servidor é a porta

Tudo o que a página esconde, a função do banco tem que negar: quem tem login no app chama a função
direto, sem passar pela página. Toda função chamada por página:

- confere a **página** (`gov_tenho_acesso('<GOV_PAGE_ID>')`) e, se for ação, o **botão** (`pode_botao('<chave>')`);
- corta a **Linha** e mascara **Valor** e **Contato** na própria função;
- pega o **autor do login** (`minha_matricula()` para a matrícula, `meu_nome()` para o nome), nunca da página;
- é a única porta: `security definer`, sem acesso para `anon`, tabela sem leitura direta;
- não é "sandbox" e não depende de identidade vinda do navegador.

Moldes de leitura e escrita, checklist e como conferir as funções de uma página → `references/servidor.md`.

---

## Página de referência: `recrutamento.html`

`GOV_PAGE_ID = governanca-kpis-rh-recrutamento`. Exemplo canônico do padrão `data-aba-id`:

- **Abas** (`tab-btn`, `tipo='aba'`, visíveis): `::sobre` · `::agenda` · `::vagas` ·
  `::entrevistas` · `::testes` · `::analitico` · `::dashboard`
- **Botões** (`drawer-sam-btn` e botões de linha/modal, `tipo='botao'`, ocultos até liberar):
  `::nova-vaga` · `::novo-candidato` · `::nova-solicitacao` · `::relacao-vagas` ·
  `::relatorio-testes` · `::recibos-testes` · `::editar-candidato` · `::enviar-devolutiva` ·
  `::editar-teste` · `::avaliar-teste` · `::editar-vaga` · `::copiar-proposta`

Listar as chaves reais de qualquer página:

```bash
grep -o 'data-aba-id="[^"]*"'   compliance/kpis/rh/recrutamento.html | sort -u
grep -o 'data-botao-id="[^"]*"' compliance/kpis/rh/escalas.html      | sort -u
```

---

## Regras de ouro

- **Identifique o nível primeiro** (página/aba/botão/valor/contato/linha) — ele define atributo e default.
- **Botões do header não recebem id** — vêm com o acesso à página.
- **Aba = visível por padrão; Botão/Valor/Contato = ocultos por padrão.** Não inverta.
- **O prefixo tem que ser o `GOV_PAGE_ID` da página**, senão o admin liga um interruptor
  que não existe.
- **Slug é contrato.** Não renomeie sem atualizar o catálogo; renomear zera a config.
- **Botão que já era usado e ganha id agora** (ex.: "Editar" da linha sem id) passa a ficar **oculto** para quem não é
  admin. Antes de publicar, **libere o id para quem já usava** (quem abre a página e tem as outras ações dela), senão o
  botão some para essas pessoas. A mesma ação dentro de um modal leva **o mesmo slug** do botão da linha
  (ex.: "Enviar agenda" na linha e no modal = `::enviar-agenda`).
- **`data-aba-id` não pede JS; `data-botao-id` pede** (`GOV_BOTOES` + `aplicarBotoes` +
  checar `GOV_BTN_OK` na ação).
- **Cadastrar no catálogo é obrigatório** — o atributo sozinho não cria o interruptor.
- **Admin vê tudo** em Página/Aba/Botão (não em Valor nem Contato: precisa da área ou de `geral`). Em Linha,
  admin e RH veem todas.
- **Dado de pessoa só sai por função escopada** (nível Linha): o servidor corta pela hierarquia.
  Filtro no navegador não protege nada.
- **O servidor é a porta:** toda função de página confere página/botão, corta a linha, mascara Valor e
  Contato e pega o autor do login (`references/servidor.md`).
- **A página não decide acesso:** nada de checar perfil, filtro de equipe, trava própria de card ou ler
  `lideres_session` (lista completa em `references/camada-de-acesso.md`).
- **Nada sem login e nada de sandbox:** nenhuma página com a chave pública sem login, nenhuma função ou
  tabela liberada para `anon`, nenhuma função `*_sandbox_*` em uso e nenhuma matrícula de teste.
- O `gate.js` só roda embarcado no Plus; fora do app mostra "Disponível pelo aplicativo".
- **Sem exceção:** toda página tem `GOV_PAGE_ID` e passa pelo gate e pela camada de acesso. O
  `compliance/areas/organograma2.html` (antiga exceção aberta) foi apagado em 08/11/2026.
- **Exceção ao nível Linha (decisão do dono, 08/11/2026):** `compliance/areas/organograma.html` mostra a
  árvore inteira para quem abre a página — é a função dela. Página, botão e Valor valem normalmente;
  o corte por subárvore **não** se aplica ali. Não mexer.
- **Números do drawer Sobre** (colaboradores, unidades, departamentos) continuam saindo da leitura direta
  que já existe nas páginas; o dono decidiu não mexer (08/11/2026).

---

## Organizar e padronizar uma página (fluxo)

1. Rode a auditoria — veja PROBLEMAS/AVISOS da página e o vocabulário de slugs do repo:
   ```bash
   python3 .claude/skills/controle-de-acessos-e-visibilidade/scripts/auditar-acessos.py
   ```
2. Antes de criar chave nova, **reuse o slug canônico** do mesmo conceito (ex.: aba de
   KPIs = `dashboard`, não `kpis`). Ver `references/padronizacao.md`.
3. Corrija AVISOS **só quando já estiver mexendo na página** e siga "Como migrar" —
   renomear slug mexe também no catálogo e na config por pessoa.
4. Rode a auditoria de novo: o slug corrigido deve sair da lista de sinônimos.

---

## Nível Valor (R$ e dados sensíveis)

O catálogo tem `tipo='valor'` para **mascarar no servidor**: valores em **R$** (salário, recibos, líquido…),
**CPF**, **data de nascimento** e **saúde** (atestados, exames) — decisão do dono, 08/11/2026. Oculto por
padrão, liberado por pessoa e área. Diferenças em relação a aba/botão:

- Não é atributo num elemento; o mascaramento é **na função do banco** (`pode_ver_valores('<área>')`),
  que devolve `null` sem permissão. A página só mostra o marcador (`R$ •••`, `•••`). Nunca mascarar só por CSS.
- O `aba_id` **é a própria área** (ex.: `recrutamento`), **sem** o prefixo `pagina_id::`.
- Liberação por pessoa fica em `dp_rh.perm_ver_valores`; `geral` libera todas as áreas. **Sem bypass de
  admin.** Detalhes em `references/backend-supabase.md`.

---

## Nível Contato (e-mail e telefone)

**E-mail** e **telefone** têm interruptor **próprio**, separado do Valor (decisão do dono, 08/11/2026):
quem vê R$ e CPF não vê contato automaticamente, e vice-versa. Mesma mecânica do Valor (migration
`supabase/migrations/20261125_nivel_contato.sql`):

- catálogo `tipo='contato'`, uma linha por área, com `aba_id = 'contato-<área>'` (para não colidir com o id da
  área de Valor);
- liberação por pessoa e área em `dp_rh.perm_ver_contato` (`matricula`, `area`, `liberado`); `geral` libera
  todas as áreas;
- `tata_plus.pode_ver_contato('<área>')` na função do banco, que devolve `null` sem permissão; **sem bypass de
  admin**;
- interruptor no painel do app plus e na Auditoria de páginas, ao lado do Valor.

---

## Nível Linha (hierarquia)

Decide **de quem são os registros** que aparecem numa página (as férias de quem, as vagas de
quem). Não tem id nem catálogo: **sai do organograma** (`tata_plus.profiles`,
`id_superior → id_pessoa`), e o admin não configura nada.

- **Líder** vê os próprios registros + os de toda a subárvore abaixo dele (N níveis).
- **Sem equipe** vê só os próprios. **Admin e RH** veem todos.
- **Quem vê, grava**, inclusive o próprio registro. Se o botão da ação aparece é o nível Botão.
- **Corte no servidor**, na RPC, com `tata_plus.minha_subarvore()`. O navegador nunca recebe
  linha de fora da equipe.
- **Não filtra** o Sobre (aba e drawer) nem conteúdo institucional. KPIs e gráficos saem das
  linhas já filtradas.
- **Valor e Contato** continuam com a trava própria **e** passam pelo corte de linha.
- **Visibilidade errada = organograma errado:** a correção é no RHID, não no portal.

Função, moldes de leitura e escrita, eixo por página, estado atual e teste em
`references/hierarquia.md`.
