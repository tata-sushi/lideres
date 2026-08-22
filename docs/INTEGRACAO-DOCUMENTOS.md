# Integração — Gestão de Documentos (portal) × Assinatura (app)

Contraparte deste documento: [`docs/INTEGRACAO-DOCUMENTOS.md`](https://github.com/tata-sushi/plus/blob/main/docs/INTEGRACAO-DOCUMENTOS.md)
no repo `tata-sushi/plus`. Os dois lados compartilham o **mesmo projeto Supabase**
(`aoqsbusfrffapjglpqjk`) — a integração acontece **na base** (colunas de ligação +
trigger/RPC), não por webhook.

**Status: integração PORTAL-SIDE implementada, testada ponta a ponta e em produção
(2026-08-22).** `admissao.html` (produção — a versão de teste `admissao-novo.html`
foi promovida e removida) chama `docs_enviar_para_assinatura` de verdade. Testei
manualmente contra o Supabase real: criei a linha `pendente_assinatura`, chamei
`docs_enviar_para_assinatura`, disparei o trigger deles inserindo em
`assinatura_registros` — a linha do portal virou `entregue` com `link`/`link_bucket`
corretos, sozinha. Dados de teste removidos depois.

O PDF do termo enviado pra assinatura não carrega mais linha de assinatura física
(a assinatura do colaborador é só a digital, capturada no app via rubrica+selfie).
Exceção: o "Checklist de Admissão" (documento interno de RH, não passa pelo fluxo
de assinatura do colaborador) manteve suas próprias assinaturas de Responsável
pela admissão / Gerente de RH.

**Pendência resolvida:** `doc.html` também foi convertido de sandbox pra
autenticação real (`gate.js` + sessão real), então o botão "Ver" de um documento
com `link_bucket='assinaturas'` já deve funcionar a partir dele — ainda não
re-testado ponta a ponta depois da conversão.

- **Portal de Governança** (este repo, schema `dp_rh`) — gestão de documentos:
  catálogo (`doc_tipos`), instância por colaborador (`colaborador_documentos`),
  geração via páginas de admissão/outras, upload direto, exceções por cargo/pessoa,
  eventos de ausência/sanção que viram pendência automaticamente.
- **App Tatá Plus** (repo `tata-sushi/plus`, schema `tata_plus`) — assinatura do
  colaborador (rubrica + selfie → PDF carimbado). Já pronto (Fase 1).

## Estado atual deste lado (`dp_rh`)

`colaborador_documentos` (tabela que guarda cada documento anexado/gerado por
colaborador):

```
id                        uuid (PK)
matricula                 text
tipo_id                   uuid (FK doc_tipos, null quando é evento de ausência/sanção)
competencia               text (null | 'YYYY-MM', pra documentos recorrentes)
nome_arquivo              text
link                      text  -- path dentro do bucket (ver link_bucket)
mime                      text
tamanho                   bigint
status                    text  -- check: entregue | vencido | dispensado | pendente_assinatura
validade                  date
observacao                text
enviado_por               text
enviado_em                timestamptz
evento_origem              text (null | 'ausencia' | 'sancao')
evento_id                 uuid
link_bucket                text default 'dp-documentos'   -- NOVO (ver abaixo)
assinatura_atribuicao_id  uuid                             -- NOVO (ver abaixo)
versao                    integer default 1                -- NOVO (ver abaixo)
```

Bucket próprio: `dp-documentos` (privado, mesmo padrão de RLS "acesso só por RPC
`SECURITY DEFINER`" descrito no doc de vocês — aqui as tabelas também têm RLS
ligado sem policy, tudo passa por RPCs `*_sandbox_*`).

**Já apliquei o aditivo pra viabilizar a integração** (migration
`colaborador_documentos_integracao_assinatura`, reversível):
- `link_bucket text not null default 'dp-documentos'` — de qual bucket ler `link`.
  Quando o trigger de vocês popular o resultado assinado, grava `link_bucket='assinaturas'`
  e `link = assinado_path`.
- `assinatura_atribuicao_id uuid` — referência informativa pra
  `tata_plus.assinatura_atribuicoes.id`, só pra rastreio/depuração (não é a chave
  usada pelo trigger — essa é a `referencia_externa` de vocês, ver abaixo).

**Decisão (2026-08-22): gerar de novo não sobrescreve — vira versão nova.**
`colaborador_documento_pendente_assinatura_sandbox_salvar` deixou de fazer
upsert; agora sempre faz `insert`, calculando `versao = max(versao existente)+1`
por `(matricula, tipo_id)`. Removi o índice único `colaborador_documentos_unico_uq`
que impedia isso (o fluxo de upload simples — RG/CPF etc, via
`colaborador_documentos_sandbox_salvar` — não dependia desse índice pra
funcionar, já fazia find-then-update pela própria lógica, então continua sem
duplicar). `doc.html` mostra só a versão mais recente como status principal,
com um "Ver histórico (N versões)" que expande a lista completa.

Do lado de vocês, `docs_enviar_para_assinatura` já cria uma pendência nova a
cada chamada (nunca fez upsert) — isso já era compatível com "manter tudo".
O único ajuste que fiz no `admissao.html` foi incluir a versão no `p_titulo`
(ex: "Código de Ética (v2)") pra ficar identificável pro colaborador no app.
Atenção: como vocês nunca invalidam a pendência anterior, gerar de novo cria
uma nova cobrança de assinatura pro colaborador — a antiga fica pendente pra
sempre se ele não assinar (isso é esperado agora, não é mais bug).

## Respostas às 6 decisões em aberto do doc de vocês

1. **Bucket do PDF de origem:** Opção A — `assinaturas/docs/{uuid}.pdf`. Concordo,
   mais simples e não mexe nas policies do `dp-documentos`.
2. **Formato da `referencia_externa`:** o `colaborador_documentos.id` (uuid da
   linha), não chave composta. É a forma mais direta e já é a PK estável do lado
   de cá.
3. **Push vs Pull:** os dois. Push (trigger) pra atualização imediata; a RPC
   `docs_status_por_referencia` como reconciliação/fallback (útil pra um botão
   "sincronizar agora" ou pra cobrir o caso do trigger falhar silenciosamente).
4. **Estrutura de `colaborador_documentos`:** tabela acima. Pro trigger de vocês:
   `update dp_rh.colaborador_documentos set status='entregue', link=<assinado_path>,
   link_bucket='assinaturas', updated_at=now() where id = <referencia_externa>::uuid`.
5. **Cartão de Ponto (frente 3) — DECIDIDO:** passa pelo fluxo de assinatura do
   app, igual aos termos. Regra confirmada: **todo documento do catálogo exige
   assinatura, exceto a categoria "Documentos Pessoais"** (RG, CPF, Comprovante
   de Endereço — só anexo/conferência, sem passar pela app). Isso vale pra toda
   competência do Cartão de Ponto (um envio por mês) e pros ASOs também.
6. **Frente 4 (admissão):** ainda em aberto do meu lado — não defini ainda quais
   documentos do fluxo de admissão são gerados (viram assinatura) vs. só
   anexados pelo colaborador pra validação, nem em qual página a validação
   acontece. Não bloqueia o resto da integração (frentes 1 e 2), fica pra uma
   rodada de design separada.

Categorias do catálogo (`dp_rh.doc_tipos.categoria`) hoje: **Documentos Pessoais**
(fora da assinatura — item 5), **Contratos e Termos**, **Cartão de Ponto**, **ASOs**,
**Documentos de Desligamento** (essas 4 entram no fluxo de assinatura do app).

## Próximo passo

Feito (2026-08-22): `admissao.html` (produção) sobe o PDF pra `assinaturas/docs/`,
cria a linha `pendente_assinatura` já com `link_bucket='assinaturas'`, chama
`docs_enviar_para_assinatura` com `p_referencia_externa = colaborador_documentos.id`
e grava o `atribuicao_id` de volta. `doc.html` já lê `link_bucket` ao montar o botão
"Ver" (`_docAbrirArquivo(path, bucket)`) e já roda com sessão real (`gate.js`).

Feito (2026-08-22): `armarios.html` também manda termo pro fluxo de assinatura
digital agora (mesmo pipeline de `admissao.html`). Novo `doc_tipos`: "Termo de
Resp. Armário e Vestiário" (categoria "Contratos e Termos", `requer_assinatura=
true`). Os dois botões que geravam o termo em papel — "Gerar Termo para
Assinatura" (banner de sucesso) e "Reimprimir Termo (2ª via)" (modal de
consulta) — foram convertidos pro fluxo digital; o antigo `window.print()`/
`#recibo`/`@media print` foram removidos (sem call site nenhum depois da
conversão).

Feito (2026-08-22): `estoqueadm.html` também — novo `doc_tipos`: "Termo de
Recebimento de Uniformes e EPI's" (mesma categoria, `requer_assinatura=true`).
O botão "Gerar Recibo para Assinatura" virou "Enviar para Assinatura Digital"
— só aparece quando o lançamento tem uma matrícula específica (reabastecimento/
transferência de estoque, sem colaborador, não geram recibo). O "Termo EPI
Coletivo" dessa mesma página (manutenção/higienização de EPI compartilhado por
unidade, sem colaborador individual pra assinar) ficou de fora — não é um
documento que alguém assina pessoalmente, não faz sentido no modelo atual.

Em aberto:
- Re-testar ponta a ponta o botão "Ver" do `doc.html` pra um documento
  `link_bucket='assinaturas'` depois da conversão pra `gate.js`.
- Frente 4 (admissão — anexar pra validação): ainda não desenhada.
- Cartão de Ponto/ASOs/Desligamento: só Admissão e Armários geram termos hoje;
  as outras categorias que também precisam assinar ainda não têm uma página
  que gere/envie o PDF pra assinatura — fica pra quando essas páginas forem
  construídas.

_Última atualização: 2026-08-22._
