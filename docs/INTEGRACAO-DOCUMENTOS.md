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
true`).

Feito (2026-08-22): `estoqueadm.html` também — novo `doc_tipos`: "Termo de
Recebimento de Uniformes e EPI's" (mesma categoria, `requer_assinatura=true`).
O "Termo EPI Coletivo" dessa mesma página (manutenção/higienização de EPI
compartilhado por unidade, sem colaborador individual pra assinar) ficou de
fora — não é um documento que alguém assina pessoalmente, não faz sentido no
modelo atual.

Feito (2026-09-06): `beneficios.html` também — o Contrato de Mútuo Financeiro
com Autorização de Desconto em Folha (o único termo com checkbox reativo no
modal hoje; Vale-Transporte e Assistência Médica seguem só impressão, sem
doc_tipos cadastrado). Novo `doc_tipos`: "Contrato de Mútuo Financeiro com
Autorização de Desconto em Folha" (mesma categoria, `requer_assinatura=true`).

**Correção de rumo:** na primeira tentativa foi adicionado um bloco de
assinatura física (`.rp-assinaturas`) nesse termo — errado. `admissao.html`
(Código de Ética e os demais) documenta explicitamente que **não leva linha
de assinatura física nenhuma**: a assinatura do colaborador é só a digital,
capturada no app via rubrica+selfie, sem contrapartida em papel. O Mútuo
Financeiro foi corrigido pra seguir o mesmo padrão — sem `.rp-assinaturas`,
só a declaração final ("As partes declaram ter lido...", classe
`.rp-ass-declaro`, mesmo estilo do `admissao.html`) + a linha de cidade/data.
Isso também resolveu boa parte do "vazamento" pra 2ª página, já que o bloco
de assinatura era conteúdo extra que empurrava o contrato pra além de 1
página.

Restava um transbordo residual de ~21px (medido com `page.pdf()`, motor de
impressão real — não só a tela) — só a linha final "São Paulo, DD/MM/AAAA."
sobrando sozinha numa 2ª página quase em branco. Resolvido reduzindo a
margem dessa linha (era pensada pra dar respiro antes de uma assinatura que
não existe mais). Resultado: o contrato cabe inteiro numa página só.

**Segunda causa do "vazamento" (a real, pelo relato com captura de tela):**
o CSS de impressão tirava o limite de largura da página
(`.page{width:100%;max-width:100%}`) — e o "Gerar PDF" abre a janela via
`window.open('', '_blank')`, que herda o tamanho da janela do navegador
(pode ser bem mais larga que uma A4, ex.: 1440px numa tela grande). O
conteúdo lay-outava na largura da janela inteira; na hora de imprimir/salvar
em PDF de verdade (papel bem mais estreito), o que passava da largura do
papel ficava cortado nas laterais. Corrigido travando a página em
`210mm` (`@page{size:A4;margin:0}` + `.page{width:210mm;max-width:210mm}`)
— físico, independente do tamanho da janela. Testado reproduzindo com
viewport largo (1440px) + `page.pdf()`: sem esse fix o `.page` media
1440px de largura; com o fix, ~210mm centralizado, e o PDF real saiu sem
cortar nada.

**Terceira causa (a que sobrava, confirmada pelo print de `doc.html` — "v7"
do Mútuo vs "v2" do Código de Ética):** as duas primeiras correções foram no
CSS de impressão (`@media print`, usado só pelo "Gerar PDF" via
`window.print()`). Mas "Enviar para Assinatura Digital" usa outra rota —
`_benefHtmlParaPdfBlob`, html2canvas dentro de um iframe — que rasteriza a
página como ela está **na tela** (CSS de tela, sem `@media print` nenhum).
`BENEF_TERMO_CSS` só tinha padding/largura da `.page` dentro do
`@media print`; nessa rota específica a página saía sem margem nenhuma nas
laterais. `admissao.html` já resolve isso desde sempre com um `pdfOverrides`
próprio dentro do `_admHtmlParaPdfBlob` (`ADM_CSS + pdfOverrides`, achatando
pro equivalente do `@media print`) — replicado o mesmo padrão em
`_benefHtmlParaPdfBlob`. Testado: com o fix, `.page` no iframe (800px de
largura) passa a ter `padding:24px 36px 36px` de verdade, e o conteúdo ainda
cabe numa página só (1090px de 1131px — ~40px de folga).

De passagem, também fica registrado: medi a margem lateral do PDF impresso
pixel a pixel (36px, igual em todas as páginas de termo do sistema — não é
um bug, é só uma margem fina/0.375in por design). Se algum dia quiserem
margem maior, é mudança deliberada no `BENEF_TERMO_CSS`/`ADM_CSS`/etc, não
um bug a corrigir.

Feito (2026-09-06): mais dois termos entraram no fluxo de assinatura digital —

- **Termo de Compromisso e Autorização de Desconto (Vale-Transporte)** — em
  **`beneficios.html` E `admissao.html`**, os dois apontando pro **mesmo**
  `doc_tipos` ("Termo de Compromisso e Autorização de Desconto"), pra manter
  um histórico de versões único por colaborador independente de qual página
  gerou. Em `admissao.html` era item especial (`vale_transporte`, "não vem do
  catálogo" — comentário no próprio código), só com impressão; `_admSalvarUmTermo`
  agora escolhe entre `_admBuildDocPageHtml` (termos normais) e `_admVtBuildPage`
  (Vale-Transporte, campos próprios: endereço, opção sim/não, linhas casa↔trabalho)
  conforme o `doc.id`, e `salvarTermosParaAssinatura`/`_admCarregarDocTipos` foram
  ajustados pra incluir esse item especial no fluxo. Removida a linha de
  assinatura física dos dois (mesmo padrão já estabelecido — só assinatura
  digital via app).
- **Termo de Autorização de Desconto em Folha - Plano de Saúde de Dependente**
  — novo, só em `beneficios.html`. Novo `doc_tipos` próprio.

Em `beneficios.html`, a função `enviarMutuoParaAssinatura` (que só mandava o
Mútuo) virou `enviarTermosParaAssinatura`, que percorre **todos** os termos
marcados (VT, Mútuo, Desconto de Dependente) e manda cada um pra assinatura
em sequência — mesmo padrão do `salvarTermosParaAssinatura` de
`admissao.html`. O núcleo de upload+pendência+envio foi extraído pra
`_benefEnviarUmTermo(tipoNome, pageHtml, nomeArquivo, matricula, emitidoPor)`,
reaproveitado pelos três. `_benefCarregarTipoMutuo` (fixo no Mútuo) virou
`_benefCarregarTipoPorNome(nome)`, com cache por nome.

Testado (Playwright, sem depender do gate.js real): PDF de cada termo
gerado via `page.pdf()` — cabe numa página só, sem assinatura física; fluxo
de múltipla seleção testado mockando `_benefEnviarUmTermo`/`_admSalvarUmTermo`,
confirmando que os termos marcados são todos enfileirados e enviados.

Assistência Médica segue de fora (sem checkbox reativado, sem `doc_tipos`).

Feito (2026-09-06): **Cartão de Ponto — upload em lote de documento externo,
dentro de `escalas.html`.** Fluxo diferente dos anteriores: o PDF já vem
pronto da folha (não é gerado a partir de HTML aqui), então não passa por
`html2pdf`/iframe — o `File` sobe pro bucket `assinaturas` como está. Botão
"Enviar Cartão de Ponto" no drawer abre um modal com período apurado
(data inicial + final, não um seletor de mês/ano — a folha raramente bate
com o mês calendário) e uma área de anexar múltiplos PDFs de uma vez. Cada arquivo casa
com um colaborador pela matrícula, sempre a substring antes do primeiro `_`
no nome do arquivo (padrão fixo da folha: `MATRICULA_NOME_id.pdf`) — casado
contra `hc_colaboradores_listar` (cobre a empresa inteira, ao contrário de
`ST.equipe`, que é só a equipe/semana em tela). Arquivo com matrícula não
encontrada fica marcado e fora do envio, sem travar os demais.

Isso expôs uma lacuna na RPC: `colaborador_documento_pendente_assinatura_
sandbox_salvar` não aceitava nem gravava competência nenhuma (`competencia
is null` fixo), o que quebraria o versionamento de um documento mensal
recorrente. Adicionado parâmetro opcional `p_competencia text default null`
e o escopo de versionamento passou a ser `(matricula, tipo_id, competencia)`
— compatível com todo mundo que já chama essa RPC (supabase-js sempre manda
named params, então um parâmetro novo com default não quebra ninguém). O
valor gravado em `competencia` pro Cartão de Ponto é o período exato
(`YYYY-MM-DD_YYYY-MM-DD`, início e fim escolhidos no modal), não um
"YYYY-MM" — o título mostrado no app usa o período por extenso
("Cartão de Ponto — 21/07/2026 a 20/08/2026").

`doc_tipos` "Cartão de Ponto" já existia no catálogo (categoria "Cartão de
Ponto", `periodicidade='recorrente'`) mas com `requer_assinatura=false` —
ajustado pra `true` pra refletir a decisão já registrada acima (item 5:
"todo documento do catálogo exige assinatura, exceto Documentos Pessoais").

O envio processa os arquivos casados em sequência (não em paralelo, pra não
saturar o Storage/RPCs de uma vez), mostrando progresso ("Enviando 3/40…") e
tratando falha por arquivo de forma independente — um erro num colaborador
não aborta o lote inteiro, e o resumo final mostra quantos foram e quantos
falharam (com o motivo por matrícula). Testado com Playwright mockando
`window.__lideresSupa` (sem depender do Supabase real): casamento de
matrícula certo/errado, envio completo com sucesso (upload + pendência +
`docs_enviar_para_assinatura` + atribuição, um por arquivo casado) e o caso
de falha parcial (1 de 2 falha, o outro é enviado normalmente, modal continua
aberto com o erro em vez de fechar como se tudo tivesse dado certo).

Feito (2026-09-06): **`doc.html` — botão "Baixar Documentos do Colaborador"
no drawer**, abrindo modal com um `<select>` de colaborador (roster ativo,
`docColaboradores`) e baixando **todos** os arquivos desse colaborador num
`.zip` — todas as versões de todos os tipos, não só a mais recente. Lê
direto de `colaboradorDocumentos` (já carregado inteiro em `loadAllData`,
sem RPC nova). Pra cada linha: `createSignedUrl` no bucket certo
(`link_bucket`) + `fetch` do blob, processado em sequência com progresso
("Baixando 8/40…") e falha isolada por arquivo (um PDF quebrado não derruba
o lote — fica de fora do zip e some no resumo final). Nome de cada entrada
no zip: nome do tipo + competência (com o período por extenso quando é um
período customizado tipo Cartão de Ponto, não só "YYYY-MM") + versão
quando > 1; colisão residual é desempatada com um contador.
Usa JSZip (`cdnjs`, mesmo CDN já usado pro `html2pdf.js`) carregado direto
no `<head>` — aqui não precisa do truque de iframe do `html2pdf` (não há
CSS/DOM pra rasterizar, só bytes de arquivos existentes indo pro zip).
Testado com Playwright mockando Storage/`fetch`/JSZip: seleção lista o
roster ordenado por nome, resumo mostra a contagem certa de arquivos
(somando todas as versões), zip final com os nomes de entrada esperados e
sem colisão, falha parcial isolada (reporta X de Y baixados) e uma falha
inesperada na montagem do zip (`generateAsync`) é capturada e reabilita o
botão em vez de travar o modal.

**Decisão (2026-08-22): impressão em papel e assinatura digital coexistem, não
é uma coisa OU outra.** Nas duas páginas acima cada termo tem os dois botões
lado a lado (mesmo padrão de `admissao.html` com "Gerar PDF" +
"Enviar para Assinatura Digital"): imprimir continua chamando `window.print()`
normalmente, e assinatura digital continua o pipeline completo (upload +
pendência + `docs_enviar_para_assinatura`). O botão de assinatura digital só
aparece quando há colaborador/matrícula; o de impressão aparece sempre.

Em aberto:
- Re-testar ponta a ponta o botão "Ver" do `doc.html` pra um documento
  `link_bucket='assinaturas'` depois da conversão pra `gate.js`.
- Frente 4 (admissão — anexar pra validação): ainda não desenhada.
- ASOs/Desligamento: ainda não têm uma página que gere/envie o PDF pra
  assinatura — fica pra quando essas páginas forem construídas. Cartão de
  Ponto já resolvido (2026-09-06, `escalas.html`, ver acima).
- **(2026-08-24) RLS bloqueando envio pra assinatura pra quem não é líder/admin.**
  Reproduzido em admissão: `storage.objects` policy `assinaturas_insert` só libera
  upload em `assinaturas/docs/*` se `tata_plus.docs_pode_gerir()` for `true` —
  hoje essa função é `perfil='admin' OU lider=true` em `tata_plus.profiles`. RH
  que gera/envia termos de admissão, armários e uniformes não é necessariamente
  "líder" nesse sentido (gestão de escala) nem "admin" — fica bloqueado com
  "new row violates row-level security policy" ao clicar "Enviar para Assinatura
  Digital". Decisão de quem deveria poder mandar termo pra assinatura (só
  líder/admin, ou também RH em geral) e o ajuste em si ficam pra depois — é
  função do lado `tata_plus`, então também precisa alinhar com o outro time.

_Última atualização: 2026-09-06._
