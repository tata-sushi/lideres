---
name: controle-acesso-abas-botoes
description: >-
  Padroniza e orienta os IDs de controle de acesso das páginas de Governança,
  em 4 níveis: PÁGINA (window.GOV_PAGE_ID), ABA (data-aba-id, tipo aba — visível
  por padrão, denylist via gate.js), BOTÃO (data-aba-id ou data-botao-id, tipo
  botao — oculto por padrão, allowlist; botão do drawer e da página são o mesmo
  nível; botões de navegação do header NÃO têm id) e VALOR (tipo valor, mascara
  R$ no servidor). Dois repos: lideres (HTML onde vivem os ids) e plus (app onde
  o admin escolhe, por pessoa, quem acessa cada página/aba/botão/valor via o
  catálogo governanca_abas). Chave = <GOV_PAGE_ID>::<slug> (kebab-case, PT). Use
  SEMPRE que for adicionar, editar, renomear, esconder, liberar ou PADRONIZAR uma
  aba (tab-btn), um botão de ação (drawer-sam-btn, btn-avaliar, btn-copia-card,
  btn-registrar…) ou a visualização de valores; ao mexer em data-aba-id,
  data-botao-id, GOV_PAGE_ID, gate.js, GOV_BOTOES/aplicarBotoes ou no catálogo
  governanca_abas; e quando o pedido falar em "aba-id", "botão-id", "quem vê o
  quê", controle de acesso, permissão por líder/perfil, ou configurar o que o
  admin libera. Não invente ids nem troque o nível/modelo sem checar aqui.
---

# Controle de acesso por níveis de id (Governança)

As páginas de `compliance/**` abrem **só embarcadas no app Tatá Plus** (num iframe).
Além do acesso à página inteira, cada página controla **por pessoa** o que aparece
dentro dela. Todo esse controle é feito por **IDs** — atributos `data-*` no HTML que
casam com um catálogo no Supabase. **A skill existe para manter esses IDs corretos e
padronizados** entre as ~30 páginas, pra facilitar o trabalho toda vez que for invocada.

**Dois repositórios, dois papéis:**

- **`lideres`** (este repo) — o **HTML** das páginas (`compliance/**`). É onde os IDs
  vivem: você **cria/edita/padroniza** os ids de página, aba, botão e valor aqui.
- **`tata-sushi/plus`** — o **app** onde o **admin escolhe, por pessoa, quem acessa**
  cada página/aba/botão/valor. Ele lê os ids do HTML pelo catálogo no Supabase
  (`schema tata_plus`, tabela `governanca_abas`) e mostra um liga/desliga por pessoa.

> **A fonte da verdade é o HTML.** O catálogo e o painel só ligam/desligam as chaves
> que existem no HTML. Se o id do HTML e o do catálogo divergirem, o interruptor do
> admin **não controla nada**. Nunca invente uma chave e nunca renomeie um slug sem
> atualizar o catálogo.

Referências (leia conforme a tarefa):

- **`references/backend-supabase.md`** — catálogo, tabelas, RPCs, painel admin do Plus,
  registrar chave, replicar config entre pessoas. Antes de mexer no Supabase/painel.
- **`references/padronizacao.md`** — vocabulário canônico de slugs e como migrar com segurança.
- **`scripts/auditar-acessos.py`** — varre `compliance/**/*.html`, aponta problemas e
  inconsistências e imprime o vocabulário de slugs. **Rode antes de criar uma chave nova**:
  ```bash
  python3 .claude/skills/controle-acesso-abas-botoes/scripts/auditar-acessos.py
  ```

---

## Os 4 níveis de id

Todo controle cai em **um de quatro níveis**. Identificar o nível define o atributo, o
default e onde o admin liga/desliga:

| Nível | O que é / onde no HTML | id no HTML | `tipo` no catálogo | Default (quem não é admin) | Admin controla… |
|---|---|---|---|---|---|
| **Página** | a página inteira | `window.GOV_PAGE_ID` | (`governanca_paginas`) | **oculto** — precisa ser concedido | acesso à página |
| **Aba** | `tab-btn` (abas de navegação da página) | `data-aba-id` | `aba` | **VISÍVEL** — some só se bloquear (denylist) | liga/desliga por aba |
| **Botão** | **qualquer botão de ação** (drawer **ou** dentro da página) | `data-aba-id` **ou** `data-botao-id` | `botao` | **OCULTO** — aparece só se liberar (allowlist) | libera por botão |
| **Valor** | valores em R$ (salário etc.) | — (área, server-side) | `valor` | **OCULTO/mascarado** no servidor | libera ver valor, por área |

Regras dos níveis:

- **Botão é um nível só.** Não distinga botão do drawer de botão dentro da página —
  todos são "botão" (`tipo='botao'`, ocultos até liberar). Uniformize.
- **Botões de navegação do header NÃO têm id.** Zoom, fixar no menu, abrir o drawer, o
  "+" etc. entram **junto com o acesso à página** — não precisam de controle próprio,
  não recebem `data-aba-id`/`data-botao-id`.
- **Admin (`perfil='admin'`) vê tudo** nos níveis Aba/Botão/Valor. (Exceção: as features
  da seção "App" do Plus — Kanban/Escala/Limpeza — não têm bypass de admin.)

O nível **Valor** é diferente dos outros: não é atributo num elemento, é uma **área**
mascarada no servidor. Detalhe no fim e em `references/backend-supabase.md`.

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

Um mesmo slug **pode se repetir** em vários elementos (ex.: "Editar candidato" na lista
e no modal): um único interruptor no admin controla todas as instâncias.

---

## Como cada nível é aplicado (aba e botão)

- **Aba → sempre `data-aba-id`.** O `gate.js` (central, no `<head>`) esconde por CSS as
  abas que a RPC `gov_minhas_abas_bloqueadas` mandar. Visível por padrão. **Nenhum JS**
  na página; se a aba ativa cair no bloqueio, o gate ativa a primeira visível.

- **Botão → dois jeitos de implementar o mesmo nível** (ambos `tipo='botao'`, oculto por
  padrão). Escolher o errado não muda o nível, muda o *como*:

  | | `data-aba-id` (via gate.js) | `data-botao-id` (via `pode_botao`) |
  |---|---|---|
  | Quem aplica | `gate.js`, central | JS da própria página (`aplicarBotoes`) |
  | Como resolve | servidor devolve como "a esconder" até liberar | `pode_botao` por botão devolve `true`/`false` |
  | O que trava | **esconde** o botão (CSS) | **esconde E bloqueia a ação** (via `GOV_BTN_OK`) |
  | Trabalho na página | nenhum — só o atributo | atributo **+** `GOV_BOTOES` **+** checar `GOV_BTN_OK` na ação |
  | Exemplo | `recrutamento.html` | `escalas.html` |

  **Qual usar num botão:**
  - Padrão → **`data-aba-id` + `tipo='botao'`**. Menos código, o gate.js cuida. Serve
    quando **esconder o botão basta**.
  - **`data-botao-id`** → só quando **a AÇÃO precisa ser travada, não só escondida**: uma
    ação com mais de um ponto de entrada. Ex.: em `escalas.html`, "Editar semana" abre
    pelo botão (mobile) **e** clicando no nome (desktop) — esconder o botão não impediria
    o desktop. Guarda o `pode_botao` em `GOV_BTN_OK` e a função da ação consulta antes de rodar.

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
3. **Sem JS na página** — o `gate.js` já cuida.
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
3. **Trave a ação, não só o botão:** cheque `GOV_BTN_OK[id]` na função da ação.
4. Cadastre a chave no catálogo com `tipo='botao'`.

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

- **Identifique o nível primeiro** (página/aba/botão/valor) — ele define atributo e default.
- **Botões do header não recebem id** — vêm com o acesso à página.
- **Aba = visível por padrão; Botão/Valor = ocultos por padrão.** Não inverta.
- **O prefixo tem que ser o `GOV_PAGE_ID` da página**, senão o admin liga um interruptor
  que não existe.
- **Slug é contrato.** Não renomeie sem atualizar o catálogo; renomear zera a config.
- **`data-aba-id` não pede JS; `data-botao-id` pede** (`GOV_BOTOES` + `aplicarBotoes` +
  checar `GOV_BTN_OK` na ação).
- **Cadastrar no catálogo é obrigatório** — o atributo sozinho não cria o interruptor.
- **Admin vê tudo** (Aba/Botão/Valor).
- O `gate.js` só roda embarcado no Plus; fora do app mostra "Disponível pelo aplicativo".

---

## Organizar e padronizar uma página (fluxo)

1. Rode a auditoria — veja PROBLEMAS/AVISOS da página e o vocabulário de slugs do repo:
   ```bash
   python3 .claude/skills/controle-acesso-abas-botoes/scripts/auditar-acessos.py
   ```
2. Antes de criar chave nova, **reuse o slug canônico** do mesmo conceito (ex.: aba de
   KPIs = `dashboard`, não `kpis`). Ver `references/padronizacao.md`.
3. Corrija AVISOS **só quando já estiver mexendo na página** e siga "Como migrar" —
   renomear slug mexe também no catálogo e na config por pessoa.
4. Rode a auditoria de novo: o slug corrigido deve sair da lista de sinônimos.

---

## Nível Valor (visualização de R$)

O catálogo tem `tipo='valor'` para **mascarar valores em R$** (salário etc.) — oculto por
padrão, liberado por pessoa/área. Diferenças em relação a aba/botão:

- Não é atributo num elemento; o mascaramento é **server-side** (não some por CSS).
- O `aba_id` **é a própria área** (ex.: `recrutamento`), **sem** o prefixo `pagina_id::`.
- Liberação por pessoa fica em `dp_rh.perm_ver_valores`. Detalhes em `references/backend-supabase.md`.
