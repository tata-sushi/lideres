# Camada de acesso no navegador (o que sai do `gate.js`)

> Em uma frase: **o `gate.js` diz quem é a pessoa; a camada de acesso diz o que ela pode abrir e ver.**
> A página nunca decide acesso sozinha.

Decisão do dono (08/11/2026): o `gate.js` fica só com **login e registro**. Tudo o que é **acesso e
visibilidade** é desta skill e sai dele para uma **camada de acesso** própria. O ajuste do `gate.js` é um
trabalho separado, feito depois desta skill. Até lá, a camada de acesso continua morando dentro do
`gate.js`, e esta página descreve o alvo.

---

## Quem faz o quê

| | `gate.js`: login e registro | Camada de acesso (esta skill) |
|---|---|---|
| Pergunta | quem é a pessoa? | o que ela pode abrir, ver e fazer? |
| Faz | abre a página só dentro do app; recebe o token; cria o cliente logado (`window.__lideresSupa`); publica a identidade (nome e perfil); mostra "Disponível pelo aplicativo"; garante o registro de quem fez cada ação | libera ou nega a página; esconde abas e botões; trava os cards dos menus e desenha o cadeado |
| Arquivo | `/compliance/gate.js` | alvo: `/compliance/acesso.js`, carregado logo depois do gate |

No servidor, as mesmas regras valem dentro das funções do banco → `references/servidor.md`.

---

## O que sai do `gate.js`

| Hoje no `gate.js` | O que faz | Destino |
|---|---|---|
| `gov_meus_acessos` + `temAcesso` + `libera`/`nega` + revogação (volta ao portal) | libera ou nega a página | camada de acesso (nível Página) |
| `gov_minhas_abas_bloqueadas` + `trancarAbas` | esconde abas e botões `data-aba-id` | camada de acesso (Aba e Botão) |
| `trancarCards` | trava os cards dos menus | camada de acesso, que passa também a **desenhar o cadeado** (hoje só as travas próprias das páginas desenham) |
| `permitidos` e `bloqueadas` dentro do `gov_cache` | cache do acesso | cache próprio da camada de acesso |
| `aplicarPerfilNoBody` (`is-admin` / `is-lider` no `<body>`) | nada: nenhuma página usa | apagar, sem substituto |
| cópia `localStorage.lideres_session` | ponte para páginas antigas | apagar quando nenhuma página ler |

**Fica no `gate.js`:** a conversa com o app (`gov-ready`, `gov-session`, `gov-ok`, `gov-denied`), o
`setSession` e o cliente logado (`window.__lideresSupa`, evento `lideres:supa`), a identidade
(`window.__lideresUser`, nome e perfil), a tela "Disponível pelo aplicativo" e o registro de quem fez cada ação.

---

## Contrato entre os dois

1. **Ordem no HTML:** supabase-js → `window.GOV_PAGE_ID` → `gate.js` → camada de acesso.
2. O gate publica o cliente logado e a identidade e dispara `lideres:supa`. A camada de acesso espera por
   ele: nunca cria cliente próprio e nunca usa a chave pública sem login.
3. **Sem login** (fora do app ou sem token): quem responde é o gate ("Disponível pelo aplicativo").
4. **Com login:** quem decide é a camada de acesso. Ela passa `html[data-auth]` de `pending` para `ok` ou
   `denied`, esconde abas e botões e trava os cards.
5. A página só **declara** ids (`GOV_PAGE_ID`, `data-aba-id`, `data-botao-id`, `data-access-id`). Ela não lê
   o perfil para decidir nada.

---

## Overlay da página (`#auth-gate`)

Toda página tem o overlay logo depois do `<body>`. O gate usa o mesmo overlay para "Disponível pelo
aplicativo", e a camada de acesso o usa para "Sem acesso".

```html
<style>
html[data-auth="pending"] body > *:not(#auth-gate) { visibility: hidden; }
html[data-auth="denied"]  body > *:not(#auth-gate) { display: none !important; }
html[data-auth="ok"]      #auth-gate               { display: none !important; }
html[data-auth="pending"] #auth-gate .gate-denied  { display: none; }
html[data-auth="denied"]  #auth-gate .gate-loading { display: none; }
/* visual do #auth-gate (.gate-box, .gate-spin, .gate-btn…): copiar de uma página que funciona (ex.: kpis/rh/cei.html) */
</style>
<div id="auth-gate">
  <div class="gate-box">
    <div class="gate-loading"><div class="gate-spin"></div><h2>Verificando acesso...</h2><p>Confirmando sua permissão.</p></div>
    <div class="gate-denied">
      <h2>Sem acesso</h2>
      <p>Seu perfil não possui permissão para esta página. Procure a Gestão.</p>
      <a class="gate-btn" href="https://lideres.tatasushi.tech/compliance/">← Voltar ao Portal</a>
    </div>
  </div>
</div>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>
<script>window.GOV_PAGE_ID = 'governanca-…';</script>
<script src="/compliance/gate.js"></script>
```

**Toda** página passa pelo gate e pela camada de acesso. Não existe página aberta sem login. O
`organograma2.html` era a única exceção e foi apagado em 08/11/2026.

---

## Cards dos menus

| Estado | Como fica no HTML | Quem decide |
|---|---|---|
| **Aberto** | `onclick` + `data-access-id` + `data-access-url` | a página (é navegação) |
| **Em construção** | classe `building` + badge de alerta, sem `onclick` | a página: a página de destino ainda não existe (não é acesso) |
| **Trancado** | `.locked`, sem clique, **cadeado vermelho** | **só a camada de acesso** |

- `data-access-id` = o `GOV_PAGE_ID` da página de destino. Card de seção: o id da seção.
- `data-access-url` = trecho da URL de destino, específico o bastante para não casar com subpáginas.
  O card de seção libera se a pessoa tem **qualquer** página dentro da seção.
- A camada de acesso guarda o `onclick` antes de travar e devolve se liberar depois.
- Visual do cadeado: ícone de 14px, traço 2, `#b42828`, sem caixa. É o mesmo padrão do alerta âmbar
  (skill `botoes` §8).
- **Página que existe, mas é só para algumas pessoas, é nível Página** (catálogo + liberação por pessoa).
  Nunca use "em construção para todos, menos admin". Ex.: o card Slides do menu RH.

---

## O que não pode existir na página

Lista para quem aplica a skill (outro agente). Cada item ou briga com a camada de acesso, ou não protege nada.

| Na página | Por quê | Troque por |
|---|---|---|
| Trava própria de card (lê sessão/perfil/`paginas`, põe `.locked`, tira o `onclick`) | briga com a camada de acesso: o card fica morto quando ela libera | nada: a camada trava e desenha o cadeado |
| Checar perfil para mostrar ou esconder (`perfil === 'admin'`, `__lideresPerfil`, `isAdmin`, `is-admin`) | decide fora do painel do admin e falha antes de o perfil chegar | id no catálogo (aba, botão, ou página para links) |
| Filtro de equipe ou unidade no navegador | não protege (o dado já veio) e usa campos que a sessão não tem | corte de Linha na função. **Só tire junto com o corte no servidor**, senão o líder passa a ver mais |
| Ler `localStorage.lideres_session` / `sessionStorage.gp_user` | cópia antiga, pode ser de outra pessoa | nome: `window.__lideresUser`. Acesso: nunca na página |
| Mandar nome ou matrícula de quem faz (`p_por`, `p_lider`, `p_criado_por`, `enviado_por`, `p_matricula`…) | dá para gravar em nome de outra pessoa | a função pega o autor do login (`minha_matricula()`) |
| Cliente Supabase próprio com a chave pública | sem login: sem regra por pessoa e sem registro | o cliente logado do gate (`window.__lideresSupa`) |
| `.from('<tabela>')` com dado de pessoa | foge da porta única | função do banco com as checagens (`references/servidor.md`) |
| Matrícula de teste (`sandbox_matricula`) e funções `*_sandbox_*` | identidade vinda do navegador; função provisória em produção | login + função definitiva (sem "sandbox") |
| Abrir aba pelo endereço (`#aba`) sem olhar o bloqueio | reabre aba bloqueada | a camada de acesso decide a aba inicial |
| Página sem `GOV_PAGE_ID` / gate | aberta sem login | toda página passa pelo gate e pela camada de acesso |
| Escrever no `#header-user`, botão de "sair", `PERFIL` guardado sem uso | código morto do modelo antigo | apagar |

O mapeamento página por página (08/11/2026) fica fora do repositório.
