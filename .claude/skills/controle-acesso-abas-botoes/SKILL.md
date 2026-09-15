---
name: controle-acesso-abas-botoes
description: >-
  Sistema de controle de acesso granular por elemento das páginas de Governança
  (repo lideres, compliance/**): os atributos data-aba-id (abas e ações —
  VISÍVEL por padrão, denylist central via gate.js) e data-botao-id (botões —
  OCULTO por padrão, allowlist via RPC pode_botao no JS da própria página),
  mais o tipo valor (mascara R$ no servidor). O prefixo GOV_PAGE_ID e o slug
  seguem <GOV_PAGE_ID>::<slug>. Use SEMPRE que for adicionar, editar, renomear,
  esconder ou liberar uma aba (tab-btn), um botão de ação (drawer-sam-btn,
  btn-avaliar, btn-copia-card, btn-registrar…) ou qualquer elemento que deva
  aparecer/sumir por pessoa ou perfil numa página de governança/KPI; ao mexer em
  data-aba-id, data-botao-id, GOV_PAGE_ID, gate.js, GOV_BOTOES/aplicarBotoes ou
  no catálogo governanca_abas; e quando o pedido falar em "aba-id", "botão-id",
  "quem vê o quê", controle de acesso, permissão por líder/perfil, ou configurar
  o que o admin libera. Serve também para ORGANIZAR e PADRONIZAR essas chaves
  entre as ~30 páginas (vocabulário de slugs, auditoria de inconsistências).
  Não invente ids nem troque o modelo sem checar aqui.
---

# Controle de acesso por aba e por botão (Governança)

As páginas de `compliance/**` do repo `lideres` abrem **só embarcadas no app Tatá
Plus** (dentro de um iframe). Além do acesso à página inteira, cada página controla
**por pessoa** o que aparece dentro dela: abas, botões de ação e valores em R$. Esse
controle é feito por **atributos `data-*` no HTML** que casam com um catálogo no
Supabase (`schema tata_plus`, tabela `governanca_abas`).

> **A fonte da verdade é o HTML.** Cada elemento controlável carrega a chave; o
> catálogo e o painel admin só ligam/desligam essas chaves. Se o id do HTML e o id
> do catálogo divergirem, o interruptor do admin **não controla nada**. Por isso:
> nunca invente uma chave, e nunca renomeie um slug sem também atualizar o catálogo.

Este guia serve para **dois fins**: (1) aplicar as chaves certas ao mexer numa página;
(2) **organizar e padronizar** o uso delas entre as ~30 páginas do portal. Referências:

- **`references/backend-supabase.md`** — tabelas, RPCs, painel admin, registrar chave no
  catálogo, replicar config entre pessoas. Leia antes de mexer no Supabase ou no painel.
- **`references/padronizacao.md`** — vocabulário canônico de slugs, `tipo` por classe,
  inconsistências conhecidas e como migrar uma chave com segurança.
- **`scripts/auditar-acessos.py`** — varre `compliance/**/*.html`, extrai as chaves,
  aponta problemas (prefixo errado, slug fora do kebab, `data-botao-id` sem fiação) e
  avisos de padronização, e imprime o vocabulário de slugs do repo. **Rode antes de
  criar uma chave nova** (pra reusar o slug que já existe) e ao padronizar uma página:
  ```bash
  python3 .claude/skills/controle-acesso-abas-botoes/scripts/auditar-acessos.py
  ```

---

## Os dois modelos — a decisão mais importante

Há **duas** formas de controlar visibilidade, com defaults **opostos**. Escolher a
errada inverte quem vê o quê. Antes de tocar em qualquer elemento, decida:

| | `data-aba-id` | `data-botao-id` |
|---|---|---|
| **Default** | **VISÍVEL** (denylist / opt-out) | **OCULTO** (allowlist / opt-in) |
| **Quem aplica** | `gate.js`, central (carrega no `<head>`) | O **JS da própria página** (`aplicarBotoes`) |
| **Como resolve** | esconde o que a RPC `gov_minhas_abas_bloqueadas` devolver | mostra só se a RPC `pode_botao` devolver `true` |
| **O que trava** | só **esconde** o elemento (CSS) | **esconde E bloqueia a ação** (via `GOV_BTN_OK`) |
| **Trabalho na página** | nenhum — só o atributo | atributo **+** cadastrar em `GOV_BOTOES` **+** checar `GOV_BTN_OK` na ação |
| **`tipo` no catálogo** | `aba` (abas) ou `botao` (ações) | `botao` |
| **Exemplo canônico** | `recrutamento.html` (todas as abas e ações) | `escalas.html` (botões de ação) |

**Admin (`perfil='admin'`) vê tudo** nos dois modelos — não precisa de liberação.

### Qual usar?

- **Quase sempre `data-aba-id`.** É o padrão do portal (usado em ~30 páginas). Serve
  para **abas** (`tab-btn`) e também para **botões de ação** que o `gate.js` esconde
  quando o servidor manda. Não exige nenhum JS na página — é só pôr o atributo. Um
  botão marcado com `data-aba-id` e catalogado como `tipo='botao'` fica **oculto até
  ser liberado** (o servidor devolve ele na lista de bloqueadas até existir a
  liberação); catalogado como `tipo='aba'`, fica **visível até ser bloqueado**.

- **`data-botao-id` só quando esconder não basta e a AÇÃO também precisa ser travada.**
  O caso real: uma ação que tem **mais de um ponto de entrada**. Em `escalas.html` o
  "Editar semana" abre pelo botão no mobile **e** clicando no nome no desktop — se a
  gente só escondesse o botão, o desktop ainda executaria a ação. Por isso o padrão
  `data-botao-id` guarda o resultado do `pode_botao` em `GOV_BTN_OK` e a função da
  ação consulta esse mapa antes de rodar. Também é o modelo quando você quer resolver
  o opt-in **no cliente** (via `pode_botao`) em vez de depender da denylist central.

Na dúvida entre os dois para um botão comum (um único ponto de entrada, oculto por
padrão): use `data-aba-id` + `tipo='botao'` no catálogo. É menos código e o `gate.js`
cuida de tudo.

---

## Formato da chave: `<GOV_PAGE_ID>::<slug>`

Toda chave tem duas partes separadas por **`::`** (dois-pontos duplo):

```
governanca-kpis-rh-recrutamento :: nova-vaga
└────────── GOV_PAGE_ID ───────┘   └─ slug ─┘
```

- **`GOV_PAGE_ID`** — o id único da página, o **mesmo** valor que a página declara em
  `window.GOV_PAGE_ID` logo antes de carregar o `gate.js`. Deriva do caminho do
  arquivo: `compliance/kpis/rh/recrutamento.html` → `governanca-kpis-rh-recrutamento`
  (`compliance` vira `governanca`, os segimentos juntam com `-`, sem `.html`/`index`).
  O prefixo de **toda** chave da página **tem que ser igual** ao `GOV_PAGE_ID` dela.
  ⚠️ Exceção existente: `escalas.html` usa `governanca-app-escala` (feature do app),
  não `governanca-kpis-rh-escalas`. Sempre confira o `window.GOV_PAGE_ID` real da
  página em vez de deduzir pelo caminho.

- **`slug`** — nome curto em **kebab-case**, sem acento nem espaço (`nova-vaga`,
  `editar-candidato`, `relatorio-testes`). É a chave que vive no catálogo e no banco:
  **estável**. Renomear um slug **órfã** a configuração de acesso existente (o admin
  terá que reconfigurar). Escolha bem na primeira vez.

O `include` padrão no HTML (copie de uma página que funciona):

```html
<!-- Gate modelo novo: abre só via Tatá Plus, com checagem de acesso ao vivo. -->
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>
<script>window.GOV_PAGE_ID = 'governanca-kpis-rh-recrutamento';</script>
<script src="/compliance/gate.js"></script>
```

Um mesmo slug **pode se repetir** em vários elementos da página (ex.: um botão
"Editar candidato" que aparece na lista e no modal). É intencional: um único
interruptor no admin controla **todas** as instâncias daquela chave.

---

## Como adicionar um controle

### Modelo `data-aba-id` (padrão — abas e a maioria dos botões)

1. Confirme que a página tem `window.GOV_PAGE_ID` e carrega o `gate.js` (bloco acima).
2. Ponha o atributo no elemento, com a chave `<GOV_PAGE_ID>::<slug>`:
   ```html
   <button class="tab-btn" id="tab-vagas"
           data-aba-id="governanca-kpis-rh-recrutamento::vagas"
           onclick="setTab('vagas')">Vagas</button>

   <button class="drawer-sam-btn"
           data-aba-id="governanca-kpis-rh-recrutamento::nova-vaga"
           onclick="closeDrawer(); openNewVaga()">Abrir Vaga</button>
   ```
3. **Nada de JS na página.** O `gate.js` já varre todo `[data-aba-id]` e esconde
   (via CSS, sem flash) o que a RPC mandar; se a aba ativa cair no bloqueio, ele
   ativa a primeira visível.
4. Cadastre a chave no catálogo `governanca_abas` com o `tipo` certo (`aba` para abas,
   `botao` para ação oculta-por-padrão) → ver `references/backend-supabase.md`. Sem
   isso o admin não tem o que ligar/desligar.

### Modelo `data-botao-id` (ação que também precisa ser travada)

1. Atributo no botão, mesma convenção de chave:
   ```html
   <button class="drawer-sam-btn"
           data-botao-id="governanca-app-escala::cadastrar-horario"
           onclick="closeDrawer(); abrirCadastroHorario();">Cadastrar horário</button>
   ```
2. Registre a chave na lista da página e rode `aplicarBotoes()` (padrão do
   `escalas.html`): esconde tudo por padrão (sem flash) e libera só o que o
   `pode_botao` aprovar, guardando em `GOV_BTN_OK`:
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
3. **Trave a ação, não só o botão.** Na função que executa a ação, cheque
   `GOV_BTN_OK[id]` antes de rodar — é isso que protege os pontos de entrada
   alternativos (ex.: clicar no nome no desktop). Só esconder o botão não basta.
4. Cadastre a chave no catálogo com `tipo='botao'`.

---

## Página de referência: `recrutamento.html`

`compliance/kpis/rh/recrutamento.html` (`GOV_PAGE_ID = governanca-kpis-rh-recrutamento`)
é o exemplo canônico do modelo `data-aba-id`. Chaves existentes:

**Abas** (`tab-btn`, `tipo='aba'` — visíveis por padrão):
`::sobre` · `::agenda` · `::vagas` · `::entrevistas` · `::testes` · `::analitico` ·
`::dashboard`

**Ações** (`drawer-sam-btn` e botões de linha/modal, `tipo='botao'` — ocultas até liberar):
`::nova-vaga` · `::novo-candidato` · `::nova-solicitacao` · `::relacao-vagas` ·
`::relatorio-testes` · `::recibos-testes` · `::editar-candidato` · `::enviar-devolutiva` ·
`::editar-teste` · `::avaliar-teste` · `::editar-vaga` · `::copiar-proposta`

(Repare que `::editar-candidato`, `::copiar-proposta` etc. aparecem em mais de um
elemento — mesma chave, um interruptor só.)

Para listar as chaves reais de qualquer página:

```bash
grep -o 'data-aba-id="[^"]*"'   compliance/kpis/rh/recrutamento.html | sort -u
grep -o 'data-botao-id="[^"]*"' compliance/kpis/rh/escalas.html      | sort -u
```

---

## Regras de ouro

- **Não confunda os dois atributos** — os defaults são opostos. `data-aba-id` mostra
  por padrão; `data-botao-id` esconde por padrão.
- **O prefixo tem que ser o `GOV_PAGE_ID` da página.** Prefixo errado = o admin liga
  um interruptor que não existe na página.
- **Slug é contrato.** Não renomeie sem atualizar o catálogo; renomear zera a config.
- **`data-aba-id` não pede JS; `data-botao-id` pede** (`GOV_BOTOES` + `aplicarBotoes`
  + checagem de `GOV_BTN_OK` na ação).
- **Cadastrar no catálogo é obrigatório** para o controle aparecer no painel admin —
  o atributo sozinho no HTML não cria o interruptor. Ver `references/backend-supabase.md`.
- **Admin vê tudo** nos dois modelos.
- O `gate.js` só roda embarcado no Plus; aberto direto no navegador mostra "Disponível
  pelo aplicativo". Não dá pra testar acesso fora do app.

## Organizar e padronizar uma página (fluxo)

1. `python3 .claude/skills/controle-acesso-abas-botoes/scripts/auditar-acessos.py`
   — veja os PROBLEMAS e AVISOS da página e o vocabulário de slugs do repo.
2. Antes de criar uma chave nova, **reuse o slug que já existe** para o mesmo conceito
   (ex.: aba de KPIs = `dashboard`, não `kpis`). Consulte `references/padronizacao.md`.
3. Corrija AVISOS **só quando já estiver mexendo na página** e siga "Como migrar" do
   guia de padronização — renomear slug mexe também no catálogo e na config por pessoa.
4. Rode a auditoria de novo: o slug corrigido deve sair da lista de sinônimos.

## Terceiro tipo: `valor` (bônus)

O mesmo catálogo tem um `tipo='valor'`, para **mascarar valores em R$** (salário etc.)
no servidor — opt-in por área, liberado por pessoa. Aqui o `aba_id` **é a própria
área** (ex.: `recrutamento`), **sem** o prefixo `pagina_id::`. Não é atributo de HTML
como os outros dois; o mascaramento é server-side. Detalhes em
`references/backend-supabase.md`.
