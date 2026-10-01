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
com `link_bucket='assinaturas'` funciona a partir dele — testado e confirmado
funcionando pelo usuário (2026-09-30).

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

**Bug encontrado (2026-09-06) e corrigido:** o checklist mensal de "Cartão de
Ponto" em `doc.html` (uma linha por mês desde a admissão) sempre ficava
"Pendente" mesmo depois de enviar pelo `escalas.html`, porque `_docVersoes`
comparava a `competencia` por **igualdade exata de string** — e o Cartão de
Ponto passou a gravar o período customizado (`YYYY-MM-DD_YYYY-MM-DD`), não
o "YYYY-MM" que o checklist itera mês a mês, então nunca batia.
Corrigido com `_docCompetenciaCobre(rowCompetencia, mesAlvo)`: quando a
`competencia` da linha é um período (tem `_`), ela conta só pro mês em que
o período FECHA — a referência da folha (ex.: 21/07–20/08 é "referente a
agosto", conta só pra Ago/2026). Pra todo o resto do catálogo (`competencia`
já em "YYYY-MM" ou `null`) o comportamento é idêntico ao de antes.

**Ajuste (2026-09-06):** a primeira versão do fix acima fazia o período
cobrir os dois meses que ele toca (Jul/2026 **e** Ago/2026) — reportado como
confuso, já que a folha só reconhece isso como "referente a agosto".
Também trocado o rótulo exibido: quando a linha do checklist bate com um
documento de período customizado, mostra o período real
("Cartão de Ponto — 21/07/2026 a 20/08/2026") em vez do mês genérico
iterado ("Cartão de Ponto — Ago/2026"), pra ficar óbvio que não é um mês
fechado normal. Novo helper `_docFmtCompetenciaPeriodo(c)` — nome
deliberadamente diferente do `_docFmtPeriodo(evento)` já existente (usado
pros eventos de ausência/sanção, assinatura de função diferente), que
tinha o mesmo nome e foi pego de sobreposição na primeira tentativa.

**Refinamento (2026-09-06):** a mesma nomenclatura foi estendida pra **toda**
linha de Cartão de Ponto no checklist, não só a que já tem documento
enviado — inclusive as ainda "Pendente" mostram o período assumido pela
folha (dia 21 do mês anterior a dia 20 do mês de competência, novo helper
`_docPeriodoPadraoCartaoPonto(comp)`) em vez de "Mês/Ano" genérico. Assim
que um documento real bate, `_docItemHtml` troca esse período assumido
pelo período de verdade gravado na linha (podem não coincidir se RH
enviar um período fora do padrão). Escopo: só a categoria "Cartão de
Ponto" — o resto do catálogo recorrente continua com "Mês/Ano" normal.
De passagem, o modal "pasta do colaborador" (`doc-colab-overlay`) ganhou
+20% de largura (480px → 576px) pra caber os rótulos mais longos sem
quebrar linha.

Feito (2026-09-06): **`folha.html` — "Enviar Holerites" em lote, mesmo
mecanismo do Cartão de Ponto, mas SEM assinatura.** Botão no drawer ("Ações",
seção nova nessa página — `folha.html` não tinha nenhuma até então) abre
modal com competência (mês/ano — holerite fecha com o mês calendário,
diferente do Cartão de Ponto; não precisou de período inicial/final) e
anexo múltiplo de PDFs. Casamento de arquivo↔colaborador idêntico ao Cartão
de Ponto: matrícula é a substring antes do primeiro `_` no nome do arquivo,
casada contra `hc_colaboradores_listar`.

Diferença central: holerite não passa pelo pipeline de assinatura do app.
Em vez de `colaborador_documento_pendente_assinatura_sandbox_salvar` +
`docs_enviar_para_assinatura` (bucket `assinaturas`), usa o mesmo caminho do
anexo manual "Documentos Pessoais" de `doc.html`
(`colaborador_documentos_sandbox_salvar`, bucket `dp-documentos`) — grava
`status='entregue'` direto, sem rubrica/selfie. Bônus: `dp-documentos` não
tem a política de RLS restritiva de `assinaturas` (`docs_pode_gerir()` —
ver "Em aberto" abaixo), então quem usa `folha.html` não esbarra nesse
bloqueio. Também não versiona (a RPC é update-or-insert por
`(matricula, tipo_id, competencia)`) — reenviar o holerite do mesmo mês
substitui o arquivo, não empilha histórico; não tem por que preservar
versões de um documento que não é assinado.

Novo `doc_tipos`: "Holerite" (categoria própria "Holerites",
`categoria_ordem=6`, `periodicidade='recorrente'`, `intervalo_meses=1`,
`requer_assinatura=false`) — aparece em `doc.html` como mais uma seção do
checklist mensal, igual Cartão de Ponto.

`folha.html` não tinha nenhuma infra de modal/drawer-ação/upload (era só
uma página estática de framework/governança) — todo o CSS de modal e as
funções `comSupa`/`escH` foram portadas pra lá nessa mudança, adaptadas pro
próprio conjunto de variáveis CSS da página (`--t1/--t2/--t3/--white/--r`
em vez de `--text/--mid/--muted/--surface/--radius`).

**⚠️ Achado de segurança (2026-09-07), ainda em aberto:** a policy
`dp_documentos_select` do bucket `dp-documentos` libera SELECT pra
`{anon, authenticated}` sem nenhum filtro de dono — qualquer sessão logada
(e hoje até anônima) consegue gerar signed URL e ler **qualquer** arquivo
desse bucket bastando saber/adivinhar o caminho. Isso já existia antes do
Holerite (mesmo bucket usado pelo anexo manual de `doc.html`), mas ficou
mais crítico agora com dado de salário nele. Correção real ainda **não
aplicada** — precisa ser feita com cuidado: travar "só a própria matrícula"
quebraria `doc.html`/`folha.html`/`escalas.html` (ferramentas de RH que
precisam ver/baixar documento de *qualquer* colaborador), não só o dono.
A policy certa libera leitura quando (a) o caminho é da própria matrícula
de quem pede **OU** (b) quem pede é RH/admin — mesmo tipo de checagem que
`assinaturas_insert` já faz com `tata_plus.docs_pode_gerir()`. Decisão do
usuário: priorizar a criptografia do PDF (abaixo) primeiro; RLS fica pra
depois.

**Feito (2026-09-07) como mitigação: PDF do Holerite sai criptografado com
senha.** Enquanto a policy do bucket não é corrigida, cada holerite sai do
navegador já protegido — mesmo que alguém consiga a signed URL, o PDF pede
senha pra abrir. Senha = **4 primeiros dígitos do CPF** do colaborador
(convenção comum de holerite por e-mail no Brasil). Implementado com
[qpdf.js](https://github.com/j3k0/qpdf.js) (QPDF real compilado pra WASM,
roda 100% no navegador via Web Worker — o PDF nunca sai da máquina de quem
envia sem senha). `QPDF.encrypt({ arrayBuffer, userPassword, ownerPassword,
keyLength: 256, callback })` — AES-256 (R6), não 128.

**Duas correções de rumo descobertas só ao testar de verdade** (a primeira
tentativa, mergeada na PR anterior, só tinha sido testada com `QPDF`
mockado):
1. **CDN não funciona pra isso.** `qpdf.js` cria um Web Worker clássico
   (`new Worker(url)`) pra rodar o WASM — e um Worker clássico não pode ser
   instanciado com script de outra origem, mesmo com CORS liberado no CDN
   ("Script cannot be accessed from origin"). Corrigido **vendorizando** a
   lib inteira pra dentro do próprio repo
   (`compliance/kpis/rh/vendor/qpdf/`: `qpdf.js`, `qpdf-worker.js`,
   `lib/qpdf.js`, `lib/qpdf.wasm` — baixados de
   github.com/j3k0/qpdf.js @ master, Apache-2.0, ~1.9MB), servida do mesmo
   domínio do site. `QPDF.path` aponta pro path relativo local.
2. **`keyLength: 128` não é "AES-128 compatível"** — nessa lib, o parâmetro
   mapeia direto pro terceiro argumento do `qpdf --encrypt user owner
   key-length`, onde `128` significa o modo legado **RC4-128**, não AES. O
   qpdf atual **recusa escrever** arquivo com RC4 ("refusing to write a
   file with RC4, a weak cryptographic algorithm"), então todo envio
   falhava com "Command failed". Corrigido usando `keyLength: 256` (default
   da própria lib), que é AES-256 de verdade e bem suportado por qualquer
   leitor de PDF atual.

Precisou de CPF por matrícula, que `hc_colaboradores_listar` (usada em
várias outras páginas) não expõe — criada RPC própria e estreita
`holerite_colaboradores_listar()` (`{matricula, nome, status, cpf}`), só
usada aqui, pra não alargar a exposição de CPF nas páginas que só listam
colaborador sem precisar dele (hc.html, performance.html, semanal.html,
Cartão de Ponto). Arquivo cujo colaborador não tem CPF cadastrado fica
marcado como não reconhecido (mesmo tratamento de matrícula não
encontrada) — sem CPF não dá pra gerar senha, não entra no lote. O aviso
visível no modal sobre a senha foi removido a pedido do usuário (fica só
documentado aqui, não na tela).

**Testado de ponta a ponta de verdade** (não só mockado): subiu um servidor
estático local servindo o repo, rodou `folha.html` de verdade contra ele
(mesma origem que o `vendor/qpdf/`, reproduzindo o ambiente de produção), e
deixou o `QPDF.encrypt` real rodar (sem mock) contra um PDF de verdade
(gerado via `page.pdf()` do Playwright) através do fluxo completo
(`_holOnFilesSelected` → `enviarHoleritesLote` → upload). O arquivo que
seria enviado pro Storage foi capturado e aberto com **pikepdf** (biblioteca
Python independente, sem nenhuma relação com o código deste projeto) pra
confirmar de verdade: recusa abrir sem senha, recusa abrir com senha errada,
abre com a senha certa (`1234`, derivada do CPF de teste), e reporta
`R=6, V=5, aesv3, bits=256` — AES-256 de verdade, não só a aparência de
criptografia. Também testado (mockado) casamento de matrícula/CPF, falha
isolada por arquivo e falha de criptografia isolada.

**Feito (2026-09-07): colaborador inativo (ou `Bot`) barrado no casamento
de arquivo, nos dois lotes (Cartão de Ponto em `escalas.html` e Holerite em
`folha.html`).** Antes só checava se a matrícula existia — um arquivo com
matrícula de alguém desligado passava como "reconhecido" normalmente. Os
dois `_.*OnFilesSelected` agora também checam `colab.status !== 'Ativo'` e
marcam como não reconhecido ("Colaborador inativo — não recebe X por
aqui"), com o mesmo tratamento visual/de bloqueio de matrícula não
encontrada — fica fora do lote, não trava os demais arquivos.

**Bug encontrado (2026-09-07) e corrigido, testado com arquivos reais de
RH:** o casamento de matrícula assumia que o nome do arquivo sempre usa
`_` como separador ("7_NOME_id.pdf"), mas um lote real de holerite veio
nomeado "24416 – NOME.pdf" (espaço, travessão, espaço) — `split('_')[0]`
pegava o nome do arquivo inteiro (com ".pdf" e tudo) como se fosse a
matrícula, e todos os arquivos do lote saíam como "não reconhecido".
Corrigido nos dois lotes (Cartão de Ponto e Holerite): a matrícula agora é
extraída como a sequência de dígitos no início do nome do arquivo
(`file.name.match(/^\d+/)`), não depende de qual separador vem depois —
funciona tanto pra "7_NOME_id.pdf" quanto "24416 – NOME.pdf" (ou qualquer
outro separador).

Testado com Playwright mockando `window.__lideresSupa`: casamento de
matrícula certo/errado, envio completo (upload + `colaborador_documentos_
sandbox_salvar`, confirmando que NENHUMA chamada de assinatura acontece) e
falha parcial (1 de 2 falha, modal continua aberto com o erro).

**Feito (2026-09-07): "Tipo de Pagamento" no envio de Holerite
(`folha.html`).** Faltava distinguir Pagamento de Adiantamento do mesmo
mês (e o 13º salário, que também tem as duas parcelas) — sem isso, mandar
o Adiantamento depois do Pagamento (ou vice-versa) do mesmo mês
sobrescreveria o outro (a RPC é update-or-insert por
`(matricula, tipo_id, competencia)`, e os dois usavam a mesma
`competencia`). Novo `<select>` no modal com 4 opções: Pagamento,
Adiantamento, Adiantamento 13º, Pagamento 13º (`HOL_TIPOS_PAGAMENTO`). O
tipo entra na chave de versionamento como `"YYYY-MM:tipo"` (ex.:
`"2026-08:adiantamento"`) — cada combinação mês+tipo agora é uma linha
própria, e entra também no path do Storage e no nome do arquivo pra não
colidir.

Isso teria quebrado de novo o checklist mensal do `doc.html` (mesmo bug do
período customizado do Cartão de Ponto: comparação por igualdade exata
nunca bateria com o "YYYY-MM" que o checklist itera) — corrigido de
antemão em `_docCompetenciaCobre`: quando a `competencia` tem `:`, o mês
antes dos dois-pontos é o que conta pro checklist (ignora o tipo pra fins
de "esse mês tem holerite ou não" — **decisão deliberada de não separar
Pagamento/Adiantamento em linhas próprias no checklist**, qualquer um dos
dois já marca o mês como entregue; seria preciso um `doc_tipos` por tipo
pra rastrear os dois independentemente, fica pra depois se for pedido). O
rótulo do item também mostra o tipo quando disponível ("Holerite —
Adiantamento (Ago/2026)"), em vez de só o mês.

Testado com Playwright: `<select>` default "Pagamento", envio com
"Adiantamento" grava `competencia="2026-08:adiantamento"` e nome de
arquivo/path corretos; checklist do `doc.html` reconhece o mês como
"Entregue" com o rótulo do tipo certo.

**Ajuste (2026-09-07):** o formato `"YYYY-MM:tipo"` acima quebrava numa
tela do **app** (`tata_plus`, outro repo — sem acesso pra corrigir a
renderização por lá): ela mostra a `competencia` crua como título do
documento, e um código tipo `"2026-08:pagamento"` aparecia literalmente
na tela em vez de algo legível. Corrigido gravando a competencia **já no
formato de exibição final**: `"Pagamento Agosto/2026"`,
`"Adiantamento Agosto/2026"`, `"Adiantamento 13º Novembro/2026"`,
`"Pagamento 13º Dezembro/2026"` — em vez de um código que só faz sentido
sendo reformatado por quem lê. `_docCompetenciaCobre`/`_docItemHtml` em
`doc.html` ajustados pra reconhecer esse formato (novo
`_docCompetenciaMesDoHolerite(c)`, que tenta casar um dos 4 rótulos de
tipo conhecidos no início da string e devolve o mês em ISO pro checklist
mensal) em vez do split por `:`. Testado: os 4 tipos gravam exatamente o
texto esperado, e o parser de volta pra "YYYY-MM" bate certo pros 4,
inclusive distinguindo "Pagamento" de "Pagamento 13º" (ordem de checagem
importa — os rótulos com "13º" são checados primeiro).

**Bug de infraestrutura encontrado (2026-09-07) e corrigido:** reenviar o
Holerite pro **mesmo** matrícula+competência+tipo (ex.: testar de novo
depois do ajuste acima, no mesmo mês) falhava com
`"new row violates row-level security policy"`. Causa: o bucket
`dp-documentos` tinha policy de **INSERT** (`dp_documentos_upload`) e de
**SELECT** (`dp_documentos_select`), mas nenhuma de **UPDATE** — e
`storage.upload(path, file, {upsert:true})` faz um UPDATE quando o objeto
já existe naquele path (reenvio pro mesmo mês sempre bate no mesmo path).
Sem policy de UPDATE, RLS nega por padrão. Corrigido com uma policy nova
`dp_documentos_update` (`for update ... using/with check bucket_id =
'dp-documentos'`), espelhando a mesma abertura da policy de insert já
existente — não é regressão de nenhuma mudança deste projeto, só nunca
tinha sido exercitado (era o primeiro reenvio pro mesmo path desde que
esse bucket existe).

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

**Feito (2026-09-17): envio em lote de Certificados, em `agenda.html`.**
Terceira instância do mecanismo de upload em lote (Cartão de Ponto em
`escalas.html`, Holerite em `folha.html`), agora pra certificados de
curso/treinamento (NR-35, brigada de incêndio etc.) anexados ao perfil de
documentos da pessoa (`doc.html`). Botão "Enviar Certificado" dentro do
drawer "Sobre" (seção "Ações") de `agenda.html` — não uma aba nova no
calendário, só o ponto de entrada do upload mora lá.

Diferenças de propósito em relação aos outros dois:
- **Sem assinatura** (como Holerite): certificado é comprovante emitido por
  terceiro, não algo que o colaborador assina — upload direto pro bucket
  `dp-documentos` + RPC única `colaborador_documentos_sandbox_salvar`.
- **Tipo de certificado é campo livre**, não fixo como os 4 tipos de
  Holerite: `<input list="cert-tipos-datalist">` sugere os já cadastrados
  (categoria "Certificados" em `dp_rh.doc_tipos`) mas aceita qualquer nome
  novo — cria o `doc_tipo` na hora (`doc_tipo_sandbox_criar`,
  `periodicidade:'unico'`, `obrigatorio:false`, `requer_assinatura:false`)
  casando por nome (trim + case-insensitive) antes de decidir se cria ou
  reaproveita, pra não duplicar tipo dentro do mesmo lote nem entre lotes.
- **Data única do certificado, sem versionamento.** Tipo fica
  `periodicidade:'unico'` (1 slot atual por colaborador, igual RG/CPF/ASO em
  `doc.html`) — e isso **exige `p_competencia = null`** em todo envio: pra
  tipos `unico`, `doc.html` sempre busca a linha com
  `_docVersoes(matricula, tipoId, null)`, e `_docCompetenciaCobre(row, null)`
  só bate se `row.competencia` também for vazio. Guardar a data ali quebraria
  a exibição (o certificado ficaria "Pendente" pra sempre, mesmo enviado).
  Por isso a data digitada não vai pra `competencia`: vai pro nome do arquivo
  gravado (`certificado-<tipo>-<data-iso>-<nome>.<ext>` no Storage,
  `"<Nome> - <Tipo> - <data BR>.<ext>"` como `nome_arquivo`) e pro campo
  `p_observacao` (`"Emitido em dd/mm/aaaa"`) — coluna que a RPC já aceita e
  que `doc.html` já carrega (`select *`), só não renderiza ainda.
  **Consequência aceita:** reenviar o mesmo tipo de certificado pra mesma
  pessoa **substitui** o certificado anterior (upsert por
  matrícula+tipo+competência-nula, sem histórico de versão) — igual
  Holerite, diferente do Cartão de Ponto. Faz sentido pro caso de uso
  (saber se o certificado *atual* está válido), mas é uma limitação
  deliberada, não um bug: se um dia precisar do histórico de renovações
  (ex.: NR-35 renovada todo ano), vai precisar de um desenho novo (chave de
  versionamento que não seja `competencia`, ou mudança em `doc.html`).
- **Arquivo aceita PDF ou foto** (`application/pdf,image/jpeg,image/png`),
  não só PDF — certificado físico às vezes só existe fotografado.

Testado com Playwright + mock de `window.__lideresSupa` (sem rede real):
matrícula reconhecida/inativa/inexistente no nome do arquivo, tipo novo
(cria) e tipo já cadastrado (reaproveita, não duplica), payload da RPC e do
Storage confere byte a byte com o esperado, modal fecha só quando todo o
lote sobe sem falha.

**Backlog — Certificados (`agenda.html`), pendente de teste real:**
- PR #2798 mesclado (2026-09-17), mas só validado com mock até agora — falta
  testar um envio de verdade (upload real, ver o certificado aparecendo em
  `doc.html` na categoria "Certificados" da pessoa).
- Data do certificado não aparece em lugar nenhum da tela hoje — só no nome
  do arquivo e na coluna `observacao` (banco). Se o RH quiser ver a data sem
  abrir o arquivo, precisa de um ajuste pequeno em `doc.html`
  (`_docItemHtml`) pra exibir `doc.observacao` no rótulo, tipo já existe
  precedente (competencia do Holerite/Cartão de Ponto entra no rótulo do
  mesmo jeito).
- Sem histórico de renovação: reenviar o mesmo tipo de certificado pra
  mesma pessoa substitui o anterior (upsert, sem versão) — ver decisão
  registrada acima. Só vira problema se o RH precisar comparar certificados
  antigos (ex.: comprovar que a NR-35 de 2025 também foi feita).
- Fica pausado enquanto `agenda.html` é editado por outro motivo — checar
  se a próxima mudança na página não desfaz nada do bloco de Certificados
  (CSS `.cert-*`, modal `#cert-overlay`, botão no drawer).

**Feito (2026-09-18): categoria "Movimentações & Pagamentos" + botão/modal
"Novo Evento" em `agenda.html`.**

Categoria nova (`id: 'movimentacao'`) pra marcar no calendário datas de
movimentação de pessoal e de pagamento. Igual "Feriado", ela não dispara o
card automático que o cron `agenda-eventos-kanban` (roda todo dia às 12h,
`dp_rh.agenda_eventos_para_kanban()`) cria pra avisar sobre eventos
próximos — essa função só processa `categoria='evento'`, então qualquer
outra categoria já fica de fora por natureza, sem precisar de exceção.
Precisou de migration (`agenda_eventos_categoria_movimentacao`): a
constraint `agenda_eventos_categoria_check` só aceitava os 5 valores
antigos (`reuniao`, `treinamento`, `evento`, `feriado`, `outro`).

Até aqui `dp_rh.agenda_eventos` não tinha NENHUMA RPC de criação — só
listagem (`agenda_rh_eventos_listar`) e o toggle "mostrar no app”
(`agenda_evento_app_set`, restrito a `categoria='evento'`). Os eventos
existentes foram todos inseridos direto no banco. Criada
`tata_plus.agenda_evento_sandbox_criar` (mesmo padrão SECURITY DEFINER +
`grant ... to authenticated` das outras RPCs da agenda) e um botão "Novo
Evento" no drawer "Sobre" de `agenda.html` (seção "Ações", acima de
"Enviar Certificado") abrindo um modal com os campos da tabela (título,
data, horário início/fim, local, responsável, descrição) + um select de
categoria alimentado direto do array `CATEGORIAS` já usado no calendário
(assim as duas listas nunca desalinham) + o toggle "Mostrar na agenda do
app", que só aparece quando a categoria selecionada é "Evento" — mesma
regra que já existia no modal de detalhe do evento (`e.categoria ===
'evento'`), porque `agenda_evento_app_set` também só liberava esse toggle
pra essa categoria. Como defesa em profundidade, a própria RPC ignora
`p_mostrar_no_app=true` se `p_categoria` não for `'evento'` (gravei o valor
condicionado a isso na hora do insert), então mesmo que o front mude e pare
de esconder esse campo condicionalmente, não dá pra ligar o toggle numa
categoria errada direto pela RPC.

**Bug pego antes de subir:** a função recém-criada saiu com `EXECUTE`
liberado pra `PUBLIC` (Postgres concede isso por padrão em função nova,
diferente de `CREATE OR REPLACE` numa função que já existia) — ou seja,
`anon` conseguiria chamar e inserir evento sem estar autenticado. Corrigido
com `revoke execute ... from public` na sequência, deixando só
`postgres`/`authenticated`, igual as outras RPCs da agenda. Vale de lição
pra qualquer função NOVA criada por aqui daqui pra frente: sempre conferir
`information_schema.routine_privileges` depois de criar.

Testado: Playwright + mock (categoria certa esconde/mostra o toggle,
validação de título/data, payload da RPC correto, modal só fecha com
sucesso) e uma chamada real da RPC direto no banco (linha de teste criada
e apagada na sequência).

**Ajuste (2026-09-18): "Movimentações & Pagamentos" separada em duas
categorias** (`movimentacao` e `pagamento`, cada uma com cor própria no
calendário) — o usuário já tinha usado o "Novo Evento" pra cadastrar 6
eventos reais nessa categoria combinada (VT, salário, janelas de
transferência/admissão) antes de pedir a separação. Reclassificados pelo
texto da própria descrição (`"Pagamentos e comemorações."` →
`pagamento`, `"Janela de movimentações."` → `movimentacao`) — os 3 de
cada lado bateram exatamente com o título de cada evento, sem
ambiguidade. Constraint `agenda_eventos_categoria_check` ampliada de novo
pra incluir `pagamento`. Nenhuma RPC mudou (a de criar/listar já são
genéricas por categoria) — só o array `CATEGORIAS`/`CAT_COLOR` do front e
o dado já gravado.

**Feito (2026-09-22): botão "Gerar Documento" em `doc.html` — Passo 1 de
"incluir mais um termo para assinatura digital".** Réplica independente
(não compartilhada, por decisão explícita) do mecanismo de "Gerar
Documentos de Admissão" (`admissao.html`): texto jurídico em HTML ->
`html2pdf.js` rodando num iframe isolado -> PDF, com dois caminhos —
"Gerar PDF" (abre aba nova e chama `window.print()`, sem tocar no fluxo
de assinatura) e "Enviar p/ Assinatura" (upload pro bucket `assinaturas`
+ a mesma cadeia de 3 RPCs de sempre:
`colaborador_documento_pendente_assinatura_sandbox_salvar` ->
`tata_plus.docs_enviar_para_assinatura` ->
`colaborador_documento_definir_atribuicao_sandbox`). `admissao.html` não
foi tocado.

Só 2 termos entraram (por escolha do usuário — os outros de
`admissao.html`, tipo Vale Transporte/Lista de EPIs/Checklist, são
específicos do momento de admissão e não fazem sentido aqui): **Termo de
Resp. sobre a Marcação de Ponto** e **Termo de Resp. sobre Uso da Japona
Térmica** (esse último pede o número do CA num campo que só aparece
quando o termo é marcado). Os dois já existiam no catálogo
(`dp_rh.doc_tipos`, `requer_assinatura=true`) — não precisou criar tipo
novo, só reaproveitar o `id` pelo nome exato (`sectionLabel`), igual
`admissao.html` já faz.

**O texto jurídico dos dois termos foi copiado byte a byte** de
`ADM_DOCS_CONTENT` (`admissao.html`) — nenhuma palavra reescrita.
Conferido programaticamente (comparação de string) que bate 100% com o
original antes de considerar pronto.

Reaproveitado o que `doc.html` já tinha: `docColaboradores` (roster já
carregado, com matrícula/nome/cargo/unidade/data de admissão — não
precisou de RPC nova de listagem), `docTipos` (catálogo já em memória,
usado pra achar o `tipo_id` sem chamada extra), `escH`/`_usuarioLogadoNome`/
`_sandboxMatricula` (helpers já existentes), e o padrão de modal
(`.modal-overlay`/`.modal`/`class="active"`) já usado pelos modais
"Baixar Documentos"/"Cadastrar Documento".

Testado com Playwright + mock: modal abre com o roster certo, campo do
CA aparece/some só pra Japona Térmica, valida colaborador/termo/CA antes
de enviar, o HTML de cada página gerada contém os dados certos
(colaborador, CA, texto do termo), o payload de upload e das 3 RPCs bate
exatamente com o formato usado por `admissao.html`, "Gerar PDF" duplica
a página pra termos com `vias:2` (impressão em papel) enquanto "Enviar
p/ Assinatura" nunca duplica (não faz sentido pro digital), e o modal só
fecha depois que o lote todo é enviado com sucesso. Confirmado no banco
que os dois `doc_tipos` existem com o nome exato usado no código.

**Limitação de teste, importante:** a renderização de verdade do PDF
(`_dgHtmlParaPdfBlob`, que carrega `html2pdf.js` via CDN
`cdnjs.cloudflare.com` dentro do iframe) não pôde ser exercitada neste
ambiente — o proxy de rede da sandbox bloqueia esse domínio. O código
é cópia exata do mecanismo já em produção em `admissao.html`
(mesma URL de CDN, mesma técnica de iframe, mesmas opções de
`html2canvas`/`jsPDF`), então não há motivo pra esperar comportamento
diferente — mas ninguém gerou um PDF de verdade com esse botão ainda.
Antes de usar pra valer (principalmente o botão "Enviar p/ Assinatura",
que manda notificação real pro colaborador assinar), vale gerar um PDF
de teste e comparar visualmente com o que `admissao.html` gera pro
mesmo termo.

**Feito (2026-09-22): Passo 2 — 3º termo em "Gerar Documento"
(`doc.html`): Termo de Resp. de Utilização de Utensílios Profissionais.**
Primeiro termo do mecanismo que não é texto fixo — tem uma tabela de
itens preenchida na hora (Utensílio, Marca, Modelo, Quantidade, Valor
Unitário, Valor Total calculado) mais um campo de observações livre.
Diferente de `marcacao_ponto`/`japona_termica` (que vêm de
`DG_DOCS_CONTENT`), esse termo tem sua própria função de montagem de
página (`_dgBuildUtensiliosPage`), no mesmo espírito de como
`admissao.html` trata o Vale Transporte à parte (`_admVtBuildPage`) —
`_dgBuildDocPageHtml` já checa `doc.id === 'utensilios'` e desvia pra lá.

**Modal:** novo checkbox abre uma lista de itens dinâmica (`+ Item`
insere linha, `Remover` tira — mesmo padrão de
`admissao.html`/`_admVtAddRow`: `insertAdjacentHTML` por linha, lida
direto do DOM na hora de gerar/enviar, sem estado JS paralelo) + um
campo de observações. Exige nome, quantidade e valor unitário de cada
item (marca e modelo ficam opcionais, viram "—" na tabela se vazios) —
sem isso o cálculo de ressarcimento do termo não faz sentido.

**Texto jurídico:** as 6 cláusulas + os 3 parágrafos de abertura foram
digitados a partir do texto que o usuário mandou (não veio de um
arquivo pra extrair programaticamente, diferente dos outros 2 termos) —
por isso, depois de escrito, rodei uma comparação automática (as 31
linhas do texto original, uma a uma, normalizada e comparada contra o
HTML gerado) confirmando que todas batem 100% antes de considerar
pronto. A declaração final ("Declaro que li, compreendi...") já vem
dentro da Cláusula 6 do texto original, então esse termo NÃO usa o
`<p class="rp-ass-declaro">` genérico que os outros dois adicionam à
parte — evita duplicar a frase.

**Catálogo:** criado o `doc_tipo` novo via `doc_tipo_sandbox_criar`
(categoria "Contratos e Termos", `periodicidade:'unico'`,
`obrigatorio:true` — só esse é obrigatório, os outros dois entraram como
já existentes no catálogo com `obrigatorio:true` também — `requer_assinatura:true`),
já que esse termo não existia antes. Nome conferido bate exatamente com
a `sectionLabel` usada no código.

**CSS nova:** `.rp-table`/`.rp-table th`/`.rp-table td`/`.rp-table tfoot`
adicionada em `DG_CSS` (só existe em `doc.html` — `admissao.html` não
tem termo com tabela hoje, não precisou tocar lá).

Testado com Playwright + mock: lista de itens abre/fecha certo, "+ Item"
e "Remover" funcionam, valida item incompleto (bloqueia envio),
cálculo de valor total por linha e total geral bate (2 × R$45,90 =
R$91,80 confirmado no teste), observações aparecem no HTML gerado,
payload das 3 RPCs resolve o `tipo_id` certo pelo nome. Confirmado no
banco que o `doc_tipo` novo foi criado com o nome exato.

**Ajuste (2026-09-22), a partir de teste real do usuário em produção:**
dois problemas visuais no termo de Utensílios, cada um corrigido e
confirmado pelo usuário no app de verdade (a limitação de teste do
html2pdf citada acima deixou de valer — geração real testada e
funcionando):
- Tabela saiu com grid completo (borda em toda célula) — trocada pelo
  mesmo padrão visual de `estoqueadm.html` (cabeçalho escuro `#35383F`,
  linhas zebradas, coluna `#` numerando os itens, sem grid completo).
- Termo passa de uma folha (tabela + 6 cláusulas) e o conteúdo saía
  colado na borda no corte entre páginas. Causa: `margin:0` na
  configuração do `html2pdf` — o respiro só vinha do `padding` do
  `.page`, que cobre o topo/fim do documento INTEIRO, não os cortes que
  o próprio html2pdf faz ao fatiar o canvas em alturas de A4. Corrigido
  com margem de 24pt em cima/embaixo direto no `html2pdf`
  (`margin:[24,0,24,0]`) — vale pra qualquer termo que cresça além de
  uma página, não só Utensílios. Só em `doc.html`; `admissao.html` tem
  a mesma configuração `margin:0` mas não foi tocado (fora do escopo
  desta cópia independente).

**Ajuste (2026-09-22): botão de excluir na aba Pendências (`doc.html`).**
Ícone de lixeira em cada linha, pra apagar um documento AINDA NÃO
assinado (status `pendente_assinatura`) direto da lista.

RPC nova `colaborador_documento_pendente_sandbox_excluir(p_id)` — nunca
confia só no status já carregado na tela (pode estar desatualizado);
antes de apagar, confere de novo no banco, nessa ordem:
1. `dp_rh.colaborador_documentos.status = 'pendente_assinatura'` (senão
   recusa: "só é possível excluir documentos com status
   pendente_assinatura").
2. Se tem `assinatura_atribuicao_id`, confere que
   `tata_plus.assinatura_atribuicoes.status` ainda é `'pendente'`
   (senão recusa: "a atribuição de assinatura não está mais pendente").
3. Confere que não existe nenhum `tata_plus.assinatura_registros` pra
   essa atribuição (senão recusa: "existe um registro de assinatura...
   não é seguro excluir") — a checagem final, a que realmente importa.

Só depois de passar pelas 3 apaga dos dois lados: o
`assinatura_documentos`/`assinatura_atribuicoes` (lado do app, pra o
colaborador não continuar vendo uma pendência de assinatura de um
documento que já não existe mais aqui) e a linha em
`dp_rh.colaborador_documentos` (lado do portal).

Testado: Playwright + mock (botão abre confirmação, chama a RPC com o
id certo, remove a linha da tela em caso de sucesso) e 3 cenários reais
direto no banco — (1) linha `status='entregue'` recusada corretamente,
(2) linha genuinamente pendente apagada com sucesso, conferido que
sumiu dos dois lados (portal + app), (3) linha com atribuição já
`status='assinado'` recusada corretamente, mesmo a linha do portal
ainda dizendo `pendente_assinatura` (situação de dado desatualizado).
Dados de teste limpos depois (o cenário 3 precisou do protocolo de
exclusão segura — desabilitar `trg_assinatura_registros_imutavel`,
apagar, reabilitar, conferir `tgenabled` — porque inclui um
`assinatura_registros` de teste).

**Feito (2026-09-24): novo termo "Dados Bancários" — dessa vez direto em
`admissao.html`** (não em `doc.html` — usuário pediu explicitamente pra
criar termos novos na tela de admissão). Primeira vez que
`admissao.html` é editado nesta sequência de trabalho (`doc.html` até
aqui era sempre cópia independente, sem tocar em admissao.html).

Termo com formulário próprio (Banco — pré-preenchido "341", Agência,
Conta, Tipo de conta — select Corrente/Salário), no mesmo mecanismo já
usado pelo CA da Japona/Luva Térmica: `hasBanco` no loop de
`_admBuildDocList`, chave nova `admdoc_dados_bancarios`, bloco de campos
escondido/mostrado por `_admToggleBancoRow`. Ao contrário do Vale
Transporte (que é um item especial FORA do catálogo `ADM_DOCS`), esse
entrou como uma entrada NORMAL de `ADM_DOCS` — só a função que monta a
página é especial-casada dentro de `_admBuildDocPageHtml`
(`_admDadosBancariosBuildPage`), então não precisou duplicar a lógica
de resolução de tipo/validação/fluxo de assinatura em vários lugares
como o Vale Transporte precisou — só 1 ponto de dispatch.

"Tipo de conta" vira parte do rótulo da linha no PDF (`'Conta ' +
tipoConta`) — "Conta Corrente" ou "Conta Salário", conforme escolhido
no select, exatamente como decidido antes de implementar.

doc_tipo novo criado no catálogo (`doc_tipo_sandbox_criar`, categoria
"Contratos e Termos", `requer_assinatura=true`) — passa pelo fluxo de
assinatura digital igual aos outros termos.

Testado com Playwright + mock: campos de banco aparecem/somem certo
(banco pré-preenchido "341"), validação bloqueia envio sem
agência/conta, "Gerar PDF" duplica a página (vias:2) com banco/agência/
conta/tipo corretos no HTML, "Enviar para Assinatura Digital" resolve
o tipo_id certo e manda o payload das 3 RPCs correto.

**Feito (2026-09-24): novo termo "Autorização de Desconto da
Contribuição Sindical" — também direto em `admissao.html`.** Segundo
termo novo da sequência (depois de Dados Bancários), mesmo padrão de
1 entrada normal em `ADM_DOCS` + dispatch especial em
`_admBuildDocPageHtml` (`_admContribuicaoSindicalBuildPage`).

Formulário próprio com 2 campos: "Unidade / CNPJ" (select) e "Autoriza
o desconto?" (Sim/Não) — chave `hasSindical`, linha escondida/mostrada
por `_admToggleSindicalRow`. O pedido original falava em 3 campos
("Seletor de CNPJ", "Unidade", "check Sim/Não"), mas CNPJ e Unidade
estão numa relação 1:1 fixa nos dados da empresa — em vez de 2 selects
redundantes, virou 1 select combinado ("<Unidade> — CNPJ <número>").
Fica pendente de confirmação do usuário se preferem 2 campos separados.

Reaproveitados os dados de CNPJ/endereço por unidade já existentes e
testados em `estoqueadm.html` (`EPC_UNIDADES`), copiados (não
importados) para `admissao.html` como `ADM_RAZAO_SOCIAL` /
`ADM_UNIDADES_CNPJ` — mesma duplicação intencional já usada para evitar
dependência entre arquivos, com CNPJ/endereço conferidos batendo com o
documento-modelo enviado.

Texto legal reproduzido com o parágrafo do Art. 579 da CLT (Lei
13.467/2017) + parágrafo da empresa/CNPJ/endereço + pergunta Sim/Não
renderizada com o mesmo estilo de checkbox (`boxOn`/`boxOff`) já usado
no Vale Transporte. A parte sobre CTPS que aparecia no rascunho inicial
foi removida a pedido do usuário antes de finalizar. Página termina com
"Sem mais." (texto original), sem a declaração genérica padrão dos
outros termos.

doc_tipo novo criado no catálogo (`doc_tipo_sandbox_criar`, categoria
"Contratos e Termos", `requer_assinatura=true`).

Testado com Playwright + mock: options do select Unidade/CNPJ batendo
com `ADM_UNIDADES_CNPJ`, linha escondida/mostrada certo, validação
bloqueia envio sem unidade selecionada, PDF final contém CNPJ/endereço
da unidade escolhida, nome do colaborador, texto do Art. 579, "Sem
mais.", marca "Não" corretamente selecionada quando é essa a opção, 2
páginas (vias:2), e nenhuma menção a CTPS. Payload das 3 RPCs da
assinatura confirmado com `p_tipo_id` correto.

**Feito (2026-09-24): novo termo "Termo de Responsabilidade — Salário-
Família" (Portaria MPAS nº 3.040/82) — terceiro termo novo direto em
`admissao.html`.** Mesmo padrão dos dois anteriores: 1 entrada normal
em `ADM_DOCS` + dispatch especial em `_admBuildDocPageHtml`
(`_admSalarioFamiliaBuildPage`).

Campo próprio no modal: tabela dinâmica de filhos ("Nome do Filho" +
"Data do Nascimento"), chave `hasFilhos`, com botão "+ filho"
(`_admFilhoAddRow`/`_admFilhoReadRows`/`_admToggleFilhosRow`) — mesmo
mecanismo de linhas dinâmicas já usado pelo Vale Transporte
(`_admVtAddRow`), só que lido como tabela (`.rp-table`) na página do
PDF em vez de linhas soltas, a pedido do usuário ("a Tabela pega
referência em uniformes"). Essa é a primeira vez que `.rp-table` entra
em `ADM_CSS` — CSS copiado do mesmo padrão já usado pro termo de
Utensílios em `doc.html` (cabeçalho escuro `#35383F`, linhas
zebradas), que por sua vez veio de `estoqueadm.html`.

Campo de CTPS/Série/UF que aparecia no documento-modelo foi
propositalmente deixado de fora, a pedido do usuário. Texto legal
(fatos que cancelam o Salário-Família + penalidades do art. 171 do
Código Penal / art. 482 da CLT) copiado sem reescrever, inclusive a
caixa alta dos itens da lista. Sem `rp-ass-declaro` genérico — o texto
já termina com a declaração de ciência sobre as penalidades, mesmo
critério da Contribuição Sindical.

doc_tipo novo criado no catálogo (`doc_tipo_sandbox_criar`, categoria
"Contratos e Termos", `requer_assinatura=true`, nome batendo
exatamente com o `sectionLabel` do termo).

Testado com Playwright + mock: checkbox/linha aparecem certo, 1ª linha
de filho é criada automaticamente ao marcar o termo, "+ filho"
adiciona linhas extras, botão de remover funciona, validação bloqueia
envio sem nenhum filho preenchido, PDF final contém a tabela com os
filhos na ordem certa e a data já formatada (dd/mm/aaaa), nome do
colaborador, razão social da empresa, referência à Portaria
3.040/82, os 3 itens da lista e os dois artigos de lei — e nenhuma
menção a CTPS. Conferência visual da página renderizada (screenshot)
confirmando o layout e o estilo da tabela batendo com o padrão de
uniformes. Payload das 3 RPCs da assinatura confirmado com
`p_tipo_id` correto.

**Feito (2026-09-24): novo termo "Declaração de Dependentes (IR)" —
quarto termo novo direto em `admissao.html`.** Mesmo padrão dos
anteriores: 1 entrada normal em `ADM_DOCS` + dispatch especial em
`_admBuildDocPageHtml` (`_admDependentesIrBuildPage`).

Campos próprios no modal: select "Unidade / CNPJ" (reaproveita
`ADM_UNIDADES_CNPJ`, mesmo mecanismo do termo de Contribuição
Sindical) + tabela dinâmica de dependentes (Nome completo, Relação de
Dependência, Data de Nascimento), chave `hasDependentes`, com botão
"+ dependente" (`_admDepAddRow`/`_admDepReadRows`/
`_admToggleDependentesRow`) — mesmo mecanismo de linhas dinâmicas do
termo de Salário-Família, só que com um select a mais por linha
(`ADM_DEP_RELACOES`: Filho(a), Cônjuge/Companheiro(a), Pai, Mãe — sem
opção "Outro", a pedido). Tabela do PDF reaproveita a `.rp-table` já
usada no Salário-Família.

Campo de CTPS/Série/UF do documento-modelo deixado de fora, a pedido
(mesmo padrão do Salário-Família). Texto legal (declaração de
dependentes sob as penas da Lei, ciência da vedação de dedução do
mesmo dependente por ambos os cônjuges) copiado sem reescrever.

doc_tipo novo criado no catálogo (`doc_tipo_sandbox_criar`, categoria
"Contratos e Termos", `requer_assinatura=true`, nome batendo
exatamente com o `sectionLabel` do termo).

Testado com Playwright + mock: checkbox/campos aparecem certo, select
de Unidade/CNPJ com as opções corretas, select de relação sem a opção
"Outro", 1ª linha de dependente criada automaticamente ao marcar o
termo, "+ dependente" adiciona linhas, validação bloqueia envio sem
unidade selecionada e sem nenhum dependente preenchido, PDF final
contém a tabela com os dependentes na ordem certa (nome, relação por
extenso, data formatada dd/mm/aaaa), CNPJ da unidade escolhida, nome
do colaborador, texto da declaração legal — e nenhuma menção a CTPS.
Conferência visual da página renderizada (screenshot) confirmando o
layout. Payload das 3 RPCs da assinatura confirmado com `p_tipo_id`
correto.

**Feito (2026-09-24): novo termo "Contrato de Experiência" — quinto e
mais complexo termo novo direto em `admissao.html`.** Primeiro dos
novos termos que é um contrato de trabalho de verdade (13 cláusulas +
bloco de assinatura CONTRATADO(A)/CONTRATANTE), não um termo
administrativo — texto jurídico copiado sem reescrever de um
contrato-modelo real (Lugarh/Clicksign) fornecido pelo usuário.

Duas decisões de arquitetura tomadas com o usuário antes de
implementar (`AskUserQuestion`):
- **CTPS/série**: não existe NENHUMA coluna pra isso no banco (nem em
  `tata_plus.profiles`, nem em qualquer outra tabela) — usuário disse
  que vai criar esse dado depois ("deixa anotado, já vou criar").
  Enquanto isso, ficou como 2 campos manuais no modal (`adm-ctr-ctps`,
  `adm-ctr-serie`), a serem trocados por auto-preenchimento assim que
  o campo existir no cadastro.
- **Horário de trabalho**: usuário disse que a lista real de opções
  vem depois ("criar fictícios") — implementado como `<select>` já
  no formato final, só com uma lista de exemplos provisória
  (`ADM_HORARIOS_OPCOES`, claramente comentada como fictícia/
  provisória no código) fácil de trocar quando a lista real chegar.

Dados que JÁ existiam e foram aproveitados (depois de investigar o
banco antes de implementar):
- **CPF**: existia em `tata_plus.profiles.cpf` mas a RPC
  `tata_plus.colaboradores_listar()` não selecionava essa coluna.
  Ampliada (com autorização do usuário, já que é uma RPC usada em
  várias telas) pra trazer `cpf` e `cargo_id` também — mudança
  aditiva, sem quebrar quem já usa. **Atenção**: o `DROP FUNCTION` +
  `CREATE FUNCTION` (necessário pra mudar o tipo de retorno) resetou
  os grants pro padrão do schema — que incluiu `PUBLIC` (mesmo
  comportamento de "grant automático" já documentado antes pro schema
  `public`, aqui pegou `tata_plus` também). Corrigido na hora com
  `REVOKE EXECUTE ... FROM PUBLIC`, voltando ao estado original
  (só `postgres` + `authenticated`). Lição: depois de qualquer
  `DROP FUNCTION`/`CREATE FUNCTION` (não `CREATE OR REPLACE`) numa RPC
  de `tata_plus`, sempre conferir `information_schema.routine_privileges`
  antes de considerar terminado.
- **Salário (cargo + unidade)**: já existe em `dp_rh.cargos` /
  view `dp_rh.cargos_salarios`, consumido hoje só por `ces.html`
  (Cargos e Salários) via `tata_plus.cargos_salarios_listar()`. Essa
  RPC mascara os valores (`salario_fixo=null` etc.) pra quem não tem
  `tata_plus.pode_ver_valores('cargos')` — por isso o campo de salário
  no Contrato de Experiência é **auto-preenchido quando disponível,
  mas sempre editável**: não bypassa a máscara de permissão (seria
  regressão de segurança), só não bloqueia quem não tem a permissão —
  essa pessoa digita o valor na mão. Usado `salario_fixo` (não
  `bruto`, que inclui gorjeta/prêmio) por ser o valor mais próximo do
  conceito de "remuneração bruta" contratual em CLT — gorjeta
  legalmente não é salário (Art. 457 §3 CLT pós-reforma).
- **Endereço/CNPJ/CEP da unidade**: reaproveita `ADM_UNIDADES_CNPJ`
  (mesmo mecanismo dos termos anteriores), ampliado com campos
  `logradouro`/`numero`/`bairro`/`cep` separados (sem mexer no campo
  `endereco` já usado pelos outros termos) pra montar o formato
  "Av. X, N. 120, Bairro, São Paulo – SP" do contrato.

Prazo do contrato: radio "14 + 46 dias" (padrão) ou "Outros" (2 campos
numéricos, até 3 dígitos). Cálculo de datas em `_admAddDiasISO`
(aritmética em UTC): "n dias" conta o dia inicial, então término =
início + (n-1) dias; o 2º período começa no dia seguinte ao fim do
1º. Testado batendo exatamente com o contrato-modelo real (14 dias a
partir de 25/09/2026 termina 08/10/2026; +46 dias termina 23/11/2026)
— os mesmos números do documento fornecido pelo usuário.

Valor por extenso: `_admExtensoInt`/`_admExtensoReais`, cópia
independente do utilitário já existente em `beneficios.html`
(mesma disciplina de duplicar em vez de importar entre arquivos).

Endereço residencial do EMPREGADO deixado em branco (", - – CEP:
-/") — não existe esse dado no cadastro, e é exatamente esse o
mesmo padrão de campo vazio que já aparece no contrato-modelo real
fornecido (não é uma lacuna introduzida aqui).

Testado com Playwright + mock (incluindo mock de
`tata_plus.cargos_salarios_listar`): salário auto-preenchido a partir
do `cargo_id` do colaborador, campos de unidade/horário com as opções
certas, alternância do prazo "Outros" funcionando, validação bloqueia
envio com qualquer campo obrigatório faltando, PDF final contém as 13
cláusulas, endereço/CNPJ corretos da unidade escolhida, CPF formatado,
cargo em maiúsculas, salário formatado + por extenso, datas do prazo
batendo com o cálculo (testado também com o cenário "Outros": 30+60
dias a partir de 10/01/2026 → 08/02/2026 → 09/04/2026), e o bloco de
fechamento CONTRATADO(A)/CONTRATANTE. Conferência visual da página
renderizada (screenshot) confirmando o layout. Payload das 3 RPCs da
assinatura confirmado com `p_tipo_id` correto.

doc_tipo novo criado no catálogo (`doc_tipo_sandbox_criar`, categoria
"Contratos e Termos", `requer_assinatura=true`).

**Feito (2026-09-28): 1º passo da vinculação com a ficha de admissão
(Sara) — Dados Bancários auto-preenchidos.** Outro agente (frente de
migração) criou `dp_rh.admissao_respostas` (EAV, 1 linha por campo,
`grupo`/`campo`/`valor`, ver `git-claude/migracao.md`) alimentada pelo
formulário que o candidato preenche com a Sara antes da admissão. A
chave de vínculo é o **CPF** (não matrícula — matrícula só existe
depois que a pessoa vira `profile`), o que já tínhamos disponível em
`colabData.cpf` desde a ampliação da RPC `colaboradores_listar` pro
Contrato de Experiência.

Nova RPC `tata_plus.admissao_respostas_por_cpf(p_cpf text)`
(`SECURITY DEFINER`, grant só `authenticated`): resolve o CPF pro
`token` mais recente em `dp_rh.admissoes` e devolve todas as
respostas daquele token (todos os grupos, não só bancário — dá pra
reaproveitar pros próximos termos sem RPC nova). Front: cache por CPF
(`_admAdmissaoRespostasCache`) + helper `_admAdmissaoValor(respostas,
grupo, campo)`.

Dados Bancários: `_admBancoAutoFill()` busca `grupo=bancario`
(agência, conta, tipo_conta) e preenche os campos ao marcar o termo
— **sempre editável**, é sugestão, não trava nada. Banco continua
fixo em 341 (confirmado com o usuário: o formulário sempre resulta em
conta Itaú, o campo `conta_itau` do formulário foi propositalmente
ignorado). Também refaz a busca se o RH trocar de colaborador com o
termo já marcado (mesmo padrão do salário do Contrato de Experiência).
Colaborador sem ficha de admissão (CPF sem match) simplesmente não
preenche nada — sem erro, sem travar o fluxo.

Testado com Playwright + mock: agência/conta/tipo de conta
preenchidos certo, banco continua 341, reset ao desmarcar o termo,
reaproveitamento do cache (mesma CPF não dispara 2ª chamada), troca de
colaborador com termo marcado refaz a busca, colaborador sem ficha não
quebra nem preenche nada.

**Feito (2026-09-28): 2º passo — Salário-Família auto-preenchido.**
Mesma RPC `admissao_respostas_por_cpf` (já criada no passo anterior),
mesmo cache client-side. Novidade: `grupo=dependente` vem em linhas
soltas (1 linha por campo: nome/nascimento/parentesco/cpf, agrupadas
pelo `ordem` 1..5 que já vem da ficha) — `_admDependentesAgrupar()`
junta essas linhas em 1 objeto por dependente. `_admFilhosAutoFill()`
filtra só `parentesco="filho"` (case-insensitive) — o termo é
especificamente sobre filhos, não sobre dependentes em geral (isso é
o próximo passo, no termo "Declaração de Dependentes"). Datas vêm em
dd/mm/yyyy (formato da ficha); novo helper `_admParaISO()` (inverso
de `_admFmtAdmissao`) converte pra yyyy-mm-dd, que é o que o
`<input type="date">` das linhas de filho entende.

Mesmo comportamento do Dados Bancários: some a linha vazia inicial se
achar filhos na ficha, fica editável, e se o colaborador não tiver
ficha correspondente simplesmente não mexe em nada (sem erro, sem
travar). Refaz a busca ao trocar de colaborador com o termo já
marcado.

Testado com Playwright + mock (3 dependentes fictícios: 2 filhos +
1 cônjuge): só os 2 filhos entram na tabela, cônjuge fica de fora,
datas convertidas certo pro formato do `<input type="date">`, cache
reaproveitado ao desmarcar/remarcar, colaborador sem ficha não quebra
(mantém o que já estava preenchido).

**Feito (2026-09-28): 3º passo — CPF do dependente + Declaração de
Dependentes (IR) auto-preenchida.** Usuário pediu pra trazer também o
CPF do dependente (nem o modelo do Salário-Família nem o de
Dependentes IR tinham coluna de CPF originalmente — confirmado com o
usuário: adicionar mesmo assim, é comum em declaração de dependentes
de IR na prática) e aproveitar que a Declaração de Dependentes tem a
mesma estrutura de dados.

- **CPF na tabela de filhos (Salário-Família):** campo novo
  `.filho-cpf` na linha editável, lido em `_admFilhoReadRows()`,
  preenchido em `_admFilhosAutoFill()`, e nova coluna "CPF" na tabela
  do PDF (`_admSalarioFamiliaBuildPage`).
- **Declaração de Dependentes (IR) — auto-preenchida pela 1ª vez:**
  mesmo mecanismo dos outros dois termos (RPC `admissao_respostas_por_cpf`
  + `_admDependentesAgrupar`), mas **sem filtro de parentesco** — ao
  contrário do Salário-Família, que é só sobre filhos, esse termo é
  sobre TODOS os dependentes (filho, cônjuge, pai, mãe). Nova função
  `_admDependentesAutoFill()` + `_admDepParentescoParaRelacao()`
  (normaliza acento/caixa e casa o `parentesco` da ficha com o value
  do select `ADM_DEP_RELACOES` — os dois já usam a mesma codificação
  sem acento: filho/conjuge/pai/mae). Campo `.dep-cpf` novo na linha,
  nova coluna "CPF" na tabela do PDF
  (`_admDependentesIrBuildPage`). Refaz a busca ao trocar de
  colaborador com o termo marcado, mesmo padrão dos outros.

Testado com Playwright + mock: Salário-Família só traz o filho (com
CPF), Dependentes IR traz os dois (filho + cônjuge) com CPF e relação
mapeada certa em cada um. Conferência visual das duas tabelas
renderizadas (screenshot) confirmando a coluna CPF integrada ao
padrão visual já usado.

**Feito (2026-09-28): ajustes de layout no Salário-Família e
Dependentes (IR), a pedido do usuário via print.**

- **Removido o subtítulo do cabeçalho** dos dois termos ("Concessão
  de Salário-Família — Portaria MPAS nº 3.040/82" e "Do Imposto de
  Renda na Fonte") — o texto completo já aparece no `rp-section-label`
  logo abaixo, o subtítulo era redundante.
- **Título do Salário-Família** trocado de "TERMO DE
  RESPONSABILIDADE" pra "TERMO DE RESPONSABILIDADE SALÁRIO-FAMÍLIA".
- **Cabeçalho de identificação padronizado** nos dois termos pro
  mesmo padrão usado no resto do app (Colaborador/Matrícula/Cargo/
  Unidade — o mesmo bloco que `_admBuildDocPageHtml` já usa pros
  termos genéricos), no lugar do bloco customizado que cada um tinha
  antes (Empregado+Empresa no Salário-Família; Nome+Empresa(CNPJ) no
  Dependentes). O CNPJ, que saiu do cabeçalho do Dependentes, foi pro
  corpo do texto (ver próximo item) — sem perda de informação.
- **Dependentes IR:** trocado "não cabendo a V.Sa. (Fonte Pagadora)"
  por "não cabendo à empresa **TATÁ SUSHI COMÉRCIO DE ALIMENTOS
  LTDA** (CNPJ **&lt;número da unidade selecionada&gt;**)" — usa
  `ADM_RAZAO_SOCIAL` + `unidadeInfo.cnpj` (já resolvidos por
  `ctx.depUnidade`), mesmo padrão de negrito nos valores preenchidos
  usado no resto do documento.
- **Coluna "Grau de Parentesco" nova nos dois PDFs** — nenhum dos
  dois modelos originais tinha essa coluna. No Salário-Família (que é
  só sobre filhos) o valor é fixo "Filho(a)" em toda linha, já que
  não existe seletor de parentesco nesse termo. No Dependentes IR é a
  mesma coluna que já existia (antes rotulada "Relação Dependência"),
  só renomeada pro termo pedido.

Testado com Playwright + mock: cabeçalho com os 4 campos certos
(Colaborador/Matrícula/Cargo/Unidade) nos dois termos, ausência do
subtítulo antigo, novo título do Salário-Família, coluna "Grau de
Parentesco" presente nos dois PDFs (fixa "Filho(a)" no Salário-
Família), texto do Dependentes IR com empresa+CNPJ em negrito e sem
menção a "Fonte Pagadora". Conferência visual das duas páginas
renderizadas (screenshot).

**Feito (2026-09-28): mesmo cabeçalho padronizado na Contribuição
Sindical.** Faltava o campo "Cargo" nesse termo (só tinha Colaborador/
Matrícula/Unidade). Adicionado `ctx.colabCargo` como 3º campo, e
"Unidade" trocou de mostrar `ctx.sindicalUnidade` (a unidade/CNPJ
selecionada pro termo) pra `ctx.colabUnidade` (a unidade registrada do
colaborador) — mesmo critério já usado no Dependentes IR: o CNPJ/
endereço da unidade selecionada continuam no corpo do texto (parágrafo
"A empresa... inscrita no CNPJ..."), então não há perda de informação,
só padronização do cabeçalho de identificação com os outros termos.

Testado com Playwright + mock e conferência visual: cabeçalho agora
com Colaborador/Matrícula/Cargo/Unidade, CNPJ da unidade selecionada
continua aparecendo certo no corpo do texto.

**Feito (2026-09-28): 4º passo — Contrato de Experiência, CTPS
auto-preenchido.** Usuário pediu pra puxar 4 campos desse termo:
CTPS número, série, salário fixo e data de admissão. Levantamento:

- **CTPS número**: existe na ficha (`grupo=pessoais.ctps_numero`) —
  agora auto-preenchido (`_admContratoCtpsAutoFill()`, mesmo padrão
  dos outros: busca por CPF, preenche `#adm-ctr-ctps`, editável, não
  quebra sem ficha correspondente).
- **CTPS série**: **não existe em lugar nenhum da ficha** — só o
  número foi capturado pela Sara até agora (confirmado varrendo todas
  as chaves de `admissao_respostas`/`admissoes.dados`). Continua
  campo manual, igual já era.
- **Salário fixo**: já estava auto-preenchido desde a criação do
  termo (`_admContratoSalarioAutoFill()`), mas **não vem da ficha** —
  vem de `dp_rh.cargos_salarios` pelo `cargo_id` do colaborador. Não
  existe um campo de salário limpo na ficha (só um texto livre
  `trabalho/proposta` com a proposta inteira formatada em Markdown,
  sem estrutura pra extrair valor de forma confiável) — a fonte
  `cargos_salarios` continua sendo a correta/mais confiável pra esse
  campo.
- **Data de admissão**: já estava preenchida desde a criação do
  termo (`ctx.admissaoIso = colabData.admissao`) — vem de
  `tata_plus.profiles.data_admissao` (o cadastro oficial do
  colaborador), não da ficha (que também não tem esse campo — é a
  data em que a pessoa vira profile, não algo que ela preenche).

Ou seja: dos 4 campos pedidos, só o CTPS número precisava de trabalho
novo; os outros 3 já estavam cobertos (2 por fontes mais adequadas que
a ficha, 1 [série] segue indisponível em qualquer fonte por enquanto).

Testado com Playwright + mock: CTPS preenchido certo a partir do CPF,
salário continua vindo de cargos_salarios, série continua manual,
colaborador sem ficha não quebra.

**Feito (2026-09-28): 2 correções no Contrato de Experiência, achadas
em teste real pelo usuário.**

1. **Campo "Série / UF" removido.** Na prática o que a ficha captura
   em `ctps_numero` já vem tudo junto (número + série, como o
   candidato digitou pra Sara) — ter um campo separado no modal só
   duplicava informação. Campo, leitura, validação e ctx (`ctrSerie`)
   removidos por completo; o modal agora só tem "CTPS" (rótulo
   simplificado). O texto do contrato também mudou: a frase "portador
   da CTPS n.º X, série Y" virou só "portador da CTPS n.º X" — o valor
   único do campo entra ali inteiro, sem repetir a palavra "série".

2. **Bug real encontrado: salário fixo nunca aparecia auto-preenchido
   pra quase ninguém.** Causa: `tata_plus.profiles.cargo_id` e
   `dp_rh.cargos_salarios.cargo_id` têm **capitalização diferente no
   nível do cargo** (ex.: profiles tem "Garçom **Pl**-Salão-Pinheiros",
   cargos_salarios tem "Garçom **PL**-Salão-Pinheiros"). O lookup
   exato (`mapa[cargoId]`) batia certo só pra **10 dos 136**
   colaboradores ativos — os outros 126 ficavam sempre com o campo em
   branco, mesmo tendo permissão de ver valores. Corrigido no front
   (`_admCarregarCargosSalarios`/`_admContratoSalarioAutoFill`):
   chave do mapa e da busca normalizadas pra minúsculo
   (`.toLowerCase()`) — não precisou mexer no banco. Confirmado com
   uma query direta no banco que 125/136 batem case-insensitive (os
   11 restantes provavelmente têm cargo sem entrada em
   `dp_rh.cargos`, não é problema de capitalização).

Testado com Playwright + mock reproduzindo o bug real (cargo_id do
colaborador em "Pl", da tabela de cargos em "PL"): salário agora bate
mesmo com a diferença de caixa; campo série confirmado removido do
modal; PDF final sem menção solta a "série".

**Feito (2026-09-28): mais 4 ajustes no Contrato de Experiência, de
teste real.**

1. **Cabeçalho padronizado** — igual aos outros termos ajustados
   (Colaborador/Matrícula/Cargo/Unidade), no lugar do bloco anterior
   (Empregado/Matrícula/Unidade (CNPJ)). CNPJ da unidade selecionada
   continua na cláusula 1 do texto, sem perda de informação.
2. **Texto da cláusula 1**: "mediante a remuneração bruta de" virou
   "mediante a salário de registro de" (mesmo valor/extenso,
   só o texto antes mudou).
3. **Bloco final removido**: as linhas "CONTRATADO(A): ... CPF: ..." /
   "CONTRATANTE: ... CNPJ: ..." saíram do documento — o texto agora
   termina em "São Paulo, DATA." (o resto era redundante com o que já
   aparece no início do contrato e no fluxo de assinatura digital).
4. **Bug de verdade encontrado: cargo administrativo com nome
   abreviado no cadastro não batia com o catálogo, mesmo depois do
   fix de capitalização do PR anterior.** Ex.: `profiles.cargo_id` =
   "Gerente **De Rh**-RH-Administrativo", mas
   `dp_rh.cargos_salarios.cargo_id` só tem "Gerente **de Recursos
   Humanos**-RH-Administrativo" — não é diferença de caixa, é um nome
   diferente mesmo (abreviação "RH" vs nome completo), não dá pra
   normalizar por código com segurança. Solução: **fallback pro texto
   livre da proposta** (`grupo=trabalho.proposta`, que a Sara já monta
   casando corretamente cargo+unidade — ver item "Proposta → salário
   via casamento de cargo" no `git-claude/migracao.md`). Nova função
   `_admExtrairSalarioFixoProposta()` extrai só o valor do **fixo**
   via regex ("Salário fixo de R\$ X") — deliberadamente não usa a
   "remuneração bruta aproximada" que aparece na mesma frase, porque
   esse valor já inclui prêmio/gorjeta variável, e o correto pro
   contrato é o fixo. `_admContratoSalarioAutoFill()` agora tenta
   `cargos_salarios` primeiro e só cai nesse fallback se não achar
   nada — sem regressão pros casos que já funcionavam.

Testado com Playwright + mock reproduzindo o caso real (cargo_id
abreviado sem match no catálogo, proposta com "Salário fixo de R$
10.000,00 + prêmio e/ou gorjeta, com remuneração bruta aproximada de
R$ 21.000,00"): salário preenchido certo via fallback (10.000,00, não
21.000,00), cabeçalho no padrão novo, texto da cláusula 1 atualizado,
bloco final removido, documento termina em "São Paulo, DATA.".
Conferência visual da página renderizada (screenshot).

**Feito (2026-09-28): margem do rodapé corrigida ("São Paulo, DATA."
colado na borda da página).** Depois de remover o bloco
CONTRATADO(A)/CONTRATANTE (item anterior), a linha "São Paulo, DATA."
virou o último parágrafo dentro de `.rp-section-body` — e a regra
`.rp-p:last-child{margin-bottom:0;}` (usada em todos os termos pra
não sobrar espaço extra no fim do texto corrido) zerava a margem
inferior dela, deixando a linha raspando no rodapé da página.

Todos os OUTROS termos já colocam essa linha numa div separada
(`.rp-cidade-data`, com `margin:20px 0 24px` própria, FORA de
`.rp-section`) — só o Contrato de Experiência tinha ficado diferente
porque foi escrito com um `<p class="rp-p">` a mais no lugar.
Corrigido pra usar o mesmo padrão `<div class="rp-cidade-data">` dos
demais, restaurando a margem de baixo.

Conferência visual da página renderizada confirmando o espaço
correto antes da borda inferior.

**Feito (2026-09-28): novo termo "Termo de Responsabilidade de Fundo
Fixo" — primeiro termo criado direto no `doc.html`, não no
`admissao.html`.** Diferença de escopo importante: `doc.html` é o
fluxo "Gerar Documento" pra colaboradores **já ativos** (não passa
pela ficha de admissão da Sara), então esse termo não usa a
vinculação por CPF explorada nos itens anteriores — os dados vêm do
cadastro atual do colaborador + de 2 campos preenchidos na hora
(valor do Fundo Fixo, CPF).

Texto fornecido pelo usuário tinha um campo "documento de identidade
nº [RG]" além do CPF — like nos outros termos, `doc.html` não tem RG
cadastrado em nenhuma fonte disponível hoje. Perguntei, resposta do
usuário foi objetiva: **tirar o RG, manter só CPF** na cláusula de
identificação. Texto final: "Eu, NOME, portador do CPF nº CPF,
declaro ter recebido da empresa Tata Sushi, o valor de R$ X (VALOR
POR EXTENSO)...".

**CPF: achado de segurança, não estendi a RPC errada.** O modal
"Gerar Documento" já carrega a lista de colaboradores via
`public.doc_colaboradores_sandbox_listar()` (`docColaboradores`
global). Conferi as grants dessa RPC no Supabase antes de mexer:
**PUBLIC + anon + authenticated + service_role** — ela é
deliberadamente aberta (é o padrão "sandbox" desse fluxo, mesma
lógica de outras RPCs `_sandbox_` já documentadas nesse arquivo).
Adicionar CPF nela vazaria CPF de todos os colaboradores pra sessão
anônima. Em vez disso, o CPF do Fundo Fixo é buscado numa chamada
separada pra `tata_plus.colaboradores_listar()` (grants
postgres+authenticated só — já confirmadas certas em item anterior),
cacheada em `_dgColaboradoresCpfCache` por matrícula. Campo vem
pré-preenchido mas editável (mesmo padrão "sugestão, nunca trava" dos
outros termos) — se a busca falhar ou o colaborador não tiver CPF
cadastrado, o campo fica em branco e o usuário preenche na mão; a
validação só exige que o campo não esteja vazio.

Infra nova, tudo isolada dentro de `doc.html` (arquivo não compartilha
utilitários com `admissao.html`, seguindo o padrão já estabelecido de
duplicar em vez de importar entre páginas): `_dgFmtCpf`,
`_dgExtensoInt`, `_dgExtensoReais` (formatação de CPF e valor por
extenso), `_dgCarregarColaboradoresCpf()` /
`_dgFundoFixoCpfAutoFill()` (busca + cache do CPF),
`_dgBuildFundoFixoPage()` (monta a página do PDF, cabeçalho no mesmo
padrão Colaborador/Matrícula/Cargo/Unidade dos outros termos). Novo
`doc_tipo` criado no catálogo (`categoria` "Contratos e Termos",
`requer_assinatura=true`). Checkbox some por padrão no modal; ao
marcar, aparecem os 2 campos (valor + CPF) e o CPF tenta
auto-preencher.

Testado com Playwright + mock completo (8 RPCs de `loadAllData` +
`colaboradores_listar` + `docs_enviar_para_assinatura` +
`colaborador_documento_pendente_assinatura_sandbox_salvar`): checkbox
aparece, campos aparecem ao marcar, CPF auto-preenchido a partir da
matrícula selecionada, validação bloqueia sem valor/CPF preenchidos,
título/cabeçalho/CPF formatado/valor formatado/valor por extenso/nome
"Tata Sushi"/menção à Lei 12.846/2013 todos presentes no HTML gerado,
texto **não** menciona RG/documento de identidade em nenhum ponto,
espaçamento do rodapé (`rp-cidade-data`) correto. Conferência visual
da página renderizada (screenshot com dados de teste).

**Feito (2026-09-28): mais 3 termos novos em `doc.html`, enviados em
sequência pelo usuário — "Termo de Compromisso de Utilização de
Chaves", "Termo de Responsabilidade de Uso de Imagens de Segurança"
e "Termo de Entrega, Uso e Responsabilidade de Equipamento".**

1. **Chaves.** Igual ao Fundo Fixo, o texto original pedia RG **e**
   CPF na cláusula de identificação — mas dessa vez, diferente da
   decisão anterior (onde o usuário optou por tirar o RG por falta de
   fonte), mantive os dois campos, com o RG como **campo manual**
   (mesmo padrão "sugestão editável, nunca trava" dos outros campos
   sem fonte, ex.: valor do Fundo Fixo) e o CPF auto-preenchido via
   `tata_plus.colaboradores_listar()` (mesma infra já existente). Não
   perguntei de novo ao usuário porque a estrutura de "campo manual
   quando não há fonte" já está estabelecida — a diferença aqui é que
   o texto original desse termo trata RG como parte central da
   identificação (não dá pra simplesmente cortar como no Fundo Fixo).
   Corrigido também um typo do texto original ("cópias não autorizada"
   → "não autorizadas", concordância).

2. **Imagens de Segurança.** Termo mais simples — só precisa do CPF
   (a versão que o usuário colou já vinha sem RG). Reaproveitei o
   `_dgCpfAutoFillPara()` genérico (extraído do que antes era
   `_dgFundoFixoCpfAutoFill` específico — refatorado pra aceitar
   qualquer `id` de campo, já usado agora por Fundo Fixo/Chaves/
   Imagens/Equipamento). Texto jurídico (4 cláusulas numeradas)
   copiado do que o usuário mandou, sem reescrever.

3. **Equipamento — o mais complexo dos quatro termos de `doc.html`
   até agora.** Precisa nomear as duas partes do contrato:
   EMPREGADOR (razão social + CNPJ + endereço da unidade) e
   EMPREGADO(A) (nome + RG + CPF + CTPS + série), mais uma tabela
   dinâmica de itens entregues. Pra resolver o CNPJ/endereço,
   **reaproveitei a mesma fonte `ADM_UNIDADES_CNPJ` de
   `admissao.html`** (Contrato de Experiência/Contribuição Sindical),
   copiada pra `doc.html` como `DG_UNIDADES_CNPJ` — mesmo padrão de
   duplicar utilitário entre os dois arquivos independentes. Como no
   Contrato de Experiência, o usuário escolhe a unidade/CNPJ num
   select no modal (não dá pra inferir com segurança a partir do
   campo livre `unidade` do colaborador, que pode não bater
   exatamente com as chaves do mapa). RG, CTPS e série são campos
   manuais (sem fonte); CPF auto-preenchido. Lista de equipamentos é
   dinâmica (`+ Item`), mesmo padrão de `_dgBuildUtensiliosPage`, só
   que sem coluna de valor (Quantidade + Descrição). O texto original
   tinha um bloco de assinatura física no fim ("_____________" +
   nome) — **removido**, seguindo o mesmo padrão já aplicado em todos
   os outros termos do portal: a assinatura é só a digital, capturada
   no app via rubrica+selfie, quando o termo é enviado por esse fluxo.

Os 3 `doc_tipo` correspondentes foram criados no catálogo (categoria
"Contratos e Termos", `requer_assinatura=true`), com o `nome` batendo
exatamente com o `sectionLabel` de cada termo em `DG_DOCS` (é assim
que `_dgValidar`/`_dgSalvarUmTermo` casam o termo gerado com o tipo do
catálogo).

Testado com Playwright + mock completo (mesmas 8 RPCs de
`loadAllData` + `colaboradores_listar`): os 3 checkboxes aparecem, os
campos corretos aparecem/desaparecem ao marcar/desmarcar cada um, CPF
auto-preenchido em todos, validação bloqueia cada termo com campo
obrigatório vazio (RG+CPF em Chaves, CPF em Imagens, unidade+RG+CPF+
CTPS+item em Equipamento), HTML gerado de cada termo conferido
(título, cabeçalho padrão, texto legal completo, CNPJ/endereço da
unidade escolhida no caso do Equipamento, ausência de linha de
assinatura física, `rp-cidade-data` presente). Conferência visual dos
3 PDFs renderizados lado a lado (screenshot).

**Feito (2026-09-28): 2 rodadas de ajustes nos termos novos de
`doc.html`, achados em teste real pelo usuário.**

1. **Cabeçalho padrão da template genérica de `doc.html` estava fora
   do padrão do resto do portal.** `_dgBuildDocPageHtml` (usada por
   Termo de Marcação de Ponto, Japona Térmica, Chaves e Imagens de
   Segurança) tinha um 5º campo "Admissão" no cabeçalho de
   identificação, junto de Colaborador/Matrícula/Cargo/Unidade — os
   outros termos do portal (Salário-Família, Dependentes IR,
   Contribuição Sindical, Contrato de Experiência, Fundo Fixo,
   Equipamento) já usam só os 4 campos. Removido o campo "Admissão"
   do cabeçalho genérico, unificando o padrão em todos os termos dos
   dois arquivos (`admissao.html`/`doc.html`). Como o Termo de Uso de
   Imagens de Segurança citava a data de admissão de forma relevante
   pro texto, a informação não foi simplesmente descartada: movida
   pra dentro da própria frase de identificação — "...inscrito(a) no
   CPF sob o nº X, admitido(a) em DD/MM/AAAA, declaro...".

2. **CPF não precisa mais aparecer como campo editável no modal —
   só no PDF final.** Diferente do RG/CTPS (sem fonte de dados,
   genuinamente precisam de entrada manual) ou do valor do Fundo
   Fixo (dado que só existe na hora), o CPF já vem 100% confiável do
   cadastro (`tata_plus.colaboradores_listar`), então expor um campo
   de texto editável pra ele no modal era redundante e só adicionava
   ruído visual. Trocado `<input type="text">` por
   `<input type="hidden">` nos 4 termos que usam CPF (Fundo Fixo,
   Chaves, Imagens de Segurança, Equipamento) — o auto-preenchimento
   client-side continua rodando exatamente igual (mesmo
   `_dgCpfAutoFillPara`), só não aparece mais na tela; o valor segue
   embutido no PDF gerado normalmente. Mensagens de validação também
   foram ajustadas: antes pediam pra "informar o CPF" (não fazia mais
   sentido sem campo visível), agora avisam que o **CPF não foi
   encontrado no cadastro** — sinal de um problema de dado real
   (colaborador sem CPF cadastrado), não de um campo esquecido.

3. **Termo de Equipamento simplificado: RG e CTPS/série removidos
   por completo** (campo do modal, leitura, validação e cláusula de
   identificação no texto) — ficou só CNPJ/unidade (selecionada) +
   CPF (auto, oculto) + lista de equipamentos. Nome do termo também
   ajustado: "Termo de Entrega, Uso e Responsabilidade de
   Equipamento" → **"Termo de Entrega e Responsabilidade de
   Equipamento"** (tirado o "Uso,"), tanto no `sectionLabel` de
   `DG_DOCS` quanto no `doc_tipo` correspondente no catálogo
   (`UPDATE` direto, já que é só metadado do catálogo, sem RPC
   dedicada de rename).

Testado com Playwright + mock: cabeçalho sem campo Admissão em todos
os termos que usam a template genérica, frase de Imagens de Segurança
com a data de admissão embutida, CPF confirmado como `<input
type="hidden">` (não visível, mas com valor auto-preenchido) nos 4
termos, validações com as mensagens novas, campos RG/CTPS/série
confirmados removidos do modal e do texto do Termo de Equipamento,
título do PDF batendo com o nome novo. Conferência visual dos PDFs
renderizados (screenshot).

**Feito (2026-09-28): RG removido do Termo de Compromisso de Chaves —
achado de teste real pelo usuário.** Mesma decisão já tomada no Fundo
Fixo (RG sem fonte de dados no fluxo de `doc.html`, campo manual
descartado a pedido do usuário), agora aplicada também em Chaves —
identificação passa a ser só por CPF (auto-preenchido, oculto). Campo
RG, leitura, validação e cláusula "portador dos documentos RG: X e
CPF: Y" removidos; texto agora abre com "Eu, NOME, portador do CPF nº
X, declaro que nesta data, recebi uma cópia da chave...". Com essa
mudança, `doc.html` já não tem nenhum campo de RG manual sobrevivendo
em termo algum (Fundo Fixo, Chaves e Equipamento já passaram por essa
mesma simplificação).

O usuário também reportou que o CPF ainda aparecia como campo visível
no modal do Chaves — mas isso já tinha sido corrigido no PR anterior
(`input type="hidden"`); o screenshot mostrado era de uma versão
antiga em cache do navegador, não código desatualizado. Confirmado
lendo o `doc.html` atual antes de mexer em qualquer coisa — nenhuma
mudança de código foi necessária pra esse ponto.

Testado com Playwright: campo RG confirmado ausente do modal e do
texto gerado, CPF confirmado como `input type="hidden"` (auto-
preenchido, sem label visível no wrap), validação com a mensagem de
"CPF não encontrado no cadastro". Conferência visual do PDF
renderizado.

**Feito (2026-09-28): texto do Termo de Compromisso de Chaves
substituído pela versão final do usuário + novo termo "Termo de
Responsabilidade pelo Recebimento de Chave de Acesso".**

1. **Chaves — texto trocado por completo.** O usuário mandou a versão
   final e oficial do termo ("TERMO DE COMPROMISSO DE RECEBIMENTO E
   UTILIZAÇÃO DE CHAVE DO CLAVICULÁRIO"), com 5 parágrafos, mais
   específica que a anterior: deixa claro que a chave dá acesso ao
   **claviculário onde ficam as chaves reserva dos armários dos
   colaboradores** (não mais "chave do prédio" genérica). Trocado o
   corpo inteiro de `DG_DOCS_CONTENT.chaves` e o `sectionLabel` em
   `DG_DOCS` pro título oficial novo; catálogo (`doc_tipo`)
   atualizado via `UPDATE` direto pra manter o casamento
   `nome === sectionLabel`. Identificação continua só por CPF (mesmo
   padrão já estabelecido — oculto no modal, embutido no PDF).

2. **Novo termo: "Termo de Responsabilidade pelo Recebimento de
   Chave de Acesso"** — sobre a chave do **restaurante em si**
   (abertura/fechamento da unidade), diferente do Termo de Chaves
   acima (chave do claviculário/armários). Texto original tinha
   placeholders em branco (`___`) pra Nome/CPF/Unidade — preenchidos
   via `ctx.colabNomeLimpo`/CPF auto-preenchido (mesmo padrão
   `_dgCpfAutoFillPara`, oculto no modal desde o início, sem repetir
   o problema do RG visível)/`ctx.colabUnidade` (já disponível no
   cabeçalho padrão, reaproveitado no corpo do texto também). Lista
   de 6 compromissos do texto original (marcadores "*") convertida
   pro padrão lettered `a)`-`f)` já usado em Utensílios/Equipamento —
   o CSS do portal não tem estilo pra `<ul>`/`<li>`, então manter o
   padrão de parágrafos com letra em negrito evita introduzir uma
   lista sem o espaçamento/indentação corretos. Novo `doc_tipo`
   criado no catálogo.

Testado com Playwright: texto novo do Chaves confirmado (menção às
"chaves reservas dos armários", ausência do texto antigo), novo termo
Chave de Acesso com CPF auto-preenchido e oculto, unidade citada
corretamente no corpo, as 6 cláusulas a-f presentes, validação com a
mensagem de CPF não encontrado no cadastro. Conferência visual dos 2
PDFs renderizados lado a lado (screenshot).

**Feito (2026-09-28): título do Termo de Chaves igualado em todo
lugar.** `DG_DOCS.nome` (usado no checkbox do modal e no título do
cabeçalho do PDF, `rp-header-title`) ainda estava com o rótulo curto
antigo "Termo de Compromisso de Chaves", enquanto `sectionLabel`
(rótulo da seção dentro do corpo) já tinha o título oficial completo
desde a troca de texto do item anterior. Igualados os dois campos
pro mesmo texto — "Termo de Compromisso de Recebimento e Utilização
de Chave do Claviculário" — tanto no checkbox quanto no cabeçalho do
PDF. Catálogo (`doc_tipo`) já estava certo, não precisou de update.

Testado com Playwright: label do checkbox e `rp-header-title` do PDF
confirmados batendo com o título oficial.

**Feito (2026-09-28): novo termo em `admissao.html` — Ficha de Registro de
Empregados. De longe o mais complexo até agora: replica um formulário
oficial em "caixas" (RG, filiação, CTPS, título de eleitor, FGTS, PIS,
cargo, dependentes) a partir de um PDF de referência que o usuário
enviou.**

**Investigação prévia (antes de escrever qualquer código):** mapeei os
~30 campos do formulário contra as duas fontes disponíveis
(`tata_plus.profiles`/`colaboradores_listar` e
`dp_rh.admissao_respostas` via CPF) fazendo uma query `group by grupo,
campo` na tabela de respostas real. Resultado:

- **Com fonte automática:** Filiação (nome_pai/nome_mae), RG
  (rg_numero — "Célula de Identidade" no formulário), CTPS número
  (ctps_numero), Carteira de Reservista (reservista_tipo/ra/uf/
  expedicao, combinados num campo só), Data de Nascimento, Estado
  Civil, Grau de Instrução, Telefone, Endereço completo, PIS número,
  PCD, e claro Matrícula/Nome/Cargo/Departamento/Data de Admissão/
  Salário (mesmo mecanismo de cargos_salarios + fallback de proposta
  já usado no Contrato de Experiência).
- **Sem fonte em lugar nenhum hoje** (nem cadastro, nem ficha da
  Sara): Série/UF da CTPS, Categoria (CTPS), Título de Eleitor,
  Local/País de Nascimento, CBO, PIS (banco/agência/endereço/data de
  cadastro). Viram campos manuais no modal, com placeholder "sem
  fonte — preencher manualmente" (diferente do placeholder "preenchido
  automaticamente — confira" dos campos com fonte, pra deixar claro
  pro usuário RH qual é qual). Horário de Trabalho reaproveitou uma
  lista pronta que já existia no código (`ADM_HORARIOS_OPCOES`,
  criada antes pro Contrato de Experiência) — não é mais um campo sem
  fonte, é um select com opções pré-definidas.

Reportei esse mapeamento pro usuário antes de escrever código (RG/CPF
tem fonte, mas ~9 campos não têm) — resposta foi "faz o PDF enquanto
vejo os dados faltantes": implementação seguiu com os campos sem
fonte como manuais, prontos pra virar auto-fill assim que uma fonte
aparecer.

**Layout novo, não reaproveitado dos outros termos.** Os termos
existentes usam prosa jurídica (`.rp-section-body` com parágrafos);
essa ficha é um formulário denso de campo único. Em vez de inventar
CSS novo, reaproveitei o componente `.rp-intro`/`.rp-intro-field`
que já existe (é o mesmo bloco cinza "Colaborador/Matrícula/Cargo/
Unidade" do cabeçalho de todos os outros termos) — só repetido várias
vezes, agrupado em seções (`.rp-section`) com o mesmo `.rp-section-
label` de sempre: Filiação, Documentos, Dados Pessoais, Endereço,
FGTS, PIS, Dados do Cargo, Dependentes (tabela `.rp-table`, mesmo
padrão dos outros termos). Zero CSS novo precisou ser escrito.

**Decisões de escopo, registradas aqui pra reversão fácil se o
usuário discordar:**
1. **Seção "Rescisão do contrato de trabalho" do formulário original
   foi omitida.** No modelo em papel, essa seção só é preenchida
   anos depois, na saída do colaborador — não faz sentido num PDF
   gerado (e assinado digitalmente) no momento da admissão.
2. **Bloco de assinatura física do colaborador também foi omitido**
   — mesmo padrão de todos os outros termos (assinatura só digital,
   rubrica+selfie no app).
3. **Foto do colaborador não foi incluída nessa primeira versão.** A
   ficha da Sara guarda uma selfie em storage (bucket
   `admissao-docs`) só pra quem passou pela ficha nova — a maioria
   dos colaboradores ativos hoje não tem. Perguntei ao usuário se
   valia a pena buscar quando existir; sem resposta ainda, fica pra
   uma iteração futura.
4. **Dependentes: lista editável (mesmo padrão de linhas do
   Salário-Família/Dependentes IR), não só leitura direta da ficha.**
   Auto-preenche a partir de `_admDependentesAgrupar` quando a ficha
   existe, mas o RH pode corrigir/adicionar/remover antes de gerar —
   evita que uma ficha desatualizada vire um registro formal errado.

**Vinculação:** `salário`/CTPS/RG/etc. usam CPF do colaborador
selecionado pra buscar `dp_rh.admissao_respostas` (mesma infra já
existente — `_admCarregarAdmissaoRespostas`). Unidade/CNPJ contratante
é um select manual (mesmo padrão do Contrato de Experiência/
Contribuição Sindical) — não dá pra inferir com segurança a partir do
campo livre `unidade` do colaborador. Novo `doc_tipo` "Registro de
Empregados" criado no catálogo (categoria "Contratos e Termos",
requer assinatura).

Testado com Playwright + mock completo (RPCs `colaboradores_listar`,
`admissao_respostas_por_cpf`, `cargos_salarios_listar`,
`doc_tipos_sandbox_listar`): todos os campos com fonte confirmados
auto-preenchidos corretamente (pai/mãe/RG/CTPS/reservista/nascimento/
estado civil/grau de instrução/endereço completo/telefone/PIS),
dependente da ficha auto-populado na lista editável, validação
bloqueando sem unidade selecionada, PDF final conferido (título,
CNPJ da unidade escolhida, todos os dados pessoais, CPF formatado,
dependente na tabela, cabeçalho com matrícula/nome, sem linha de
assinatura física). Conferência visual do PDF renderizado — achado e
corrigido um bug de layout real nessa primeira rodada: o campo
"Horário de Trabalho" (texto longo) dividindo a mesma linha com mais
6 campos ficava espremido numa coluna estreita, quebrando o texto
palavra por palavra verticalmente; corrigido movendo esse campo pra
sua própria linha inteira dentro da seção "Dados do Cargo".

**Feito (2026-09-28): 2 ajustes na Ficha de Registro, achados em teste
real — tabela de Dependentes compactada e foto do colaborador
adicionada.**

1. **Tabela de Dependentes destoava do resto da ficha.** O `.rp-table`
   padrão (mesmo usado em Salário-Família/Utensílios/Equipamento) tem
   texto sem negrito nas células — contrastando com as caixas
   `.rp-intro-value` do resto dessa ficha em particular, que são
   todas em negrito e mais compactas. Criada uma variante
   `.rp-table-compact` (mesma paleta/zebra, só com padding menor e
   texto em negrito/cor escura igual às caixas) e trocada só na
   tabela de Dependentes desse termo — as tabelas dos outros termos
   continuam com `.rp-table` original, sem mudança.

2. **Foto do colaborador.** Confirmado pelo usuário: buscar da selfie
   que a ficha da Sara já captura. Criada RPC nova
   `tata_plus.admissao_foto_por_cpf(p_cpf)` (mesmo padrão de
   segurança das outras — SECURITY DEFINER, grants só
   postgres+authenticated, REVOKE FROM PUBLIC aplicado e conferido)
   que resolve CPF → admissão mais recente → path do documento
   `observacao='foto'` em `dp_rh.admissao_documentos` (tabela
   normalizada — diferente do jsonb legado em `admissoes.documentos`
   que eu tinha visto antes; achei essa tabela nova investigando a
   RPC `admissao_ficha_get` já existente). Bucket `admissao-docs` é
   privado; confirmei que a policy de SELECT já libera qualquer
   sessão `authenticated` (sem precisar de mudança de RLS), então o
   front gera uma signed URL (`storage.from('admissao-docs').
   createSignedUrl(path, 3600)`) direto no client. Foto aparece como
   uma miniatura ao lado da caixa Matrícula/Nome; quando não existe
   (maioria dos colaboradores ativos hoje, que não passaram pela
   ficha nova), o espaço simplesmente não aparece — sem placeholder
   quebrado, mesmo padrão "sugestão, nunca trava".

Testado com Playwright + mock (incluindo mock de `storage.from(...).
createSignedUrl`): RPC chamada com o CPF certo, `createSignedUrl`
chamada com bucket/path corretos, URL assinada cai no campo oculto e
aparece na tag `<img>` do PDF gerado, tabela de Dependentes usando a
classe compacta nova (com 2 dependentes de teste), caso sem foto
confirmado não gerando `<img>` quebrada. Conferência visual do PDF
renderizado com foto de teste.

**Feito (2026-09-28): correção na tabela de Dependentes — peso da
fonte errado.** O ajuste anterior tinha ido na direção oposta ao
pedido: o usuário queria a fonte **mais fina** (mais leve), não mais
grossa — "Era pra pegar o padrão da fonte da segunda tabela... a mais
fina!". `.rp-table-compact td` estava com `font-weight:700` (igual às
caixas `.rp-intro-value`, que são propositalmente em negrito); trocado
pra `font-weight:400` (peso normal, sem negrito) com cor um pouco mais
suave (`#333`), mantendo o padding/margem compactos do ajuste
anterior — que esses sim estavam certos. Conferência visual da tabela
renderizada isolada confirmando o texto mais fino.

**Feito (2026-09-30): revisão de backlog — 3 pontas soltas fechadas.**

1. **CBO na Ficha de Registro (marcado como "sem fonte" por engano no
   levantamento original) — descartado, não será ligado.** Achei
   depois que `dp_rh.cargos_salarios.cbo` existe e já vem de graça na
   mesma RPC (`cargos_salarios_listar`) usada pro salário — seria um
   fix rápido. Perguntei ao usuário se valia a pena corrigir; resposta
   foi "dar como concluído e descartar". Campo continua manual no
   modal, decisão final, não é mais um backlog em aberto.
2. **Horário de Trabalho (`ADM_HORARIOS_OPCOES`) — lista aprovada
   como definitiva.** Vinha marcada como fictícia/provisória desde o
   Contrato de Experiência, esperando uma lista real do usuário;
   confirmado que os valores atuais ficam como estão. Comentário no
   código atualizado (removida a nota de "provisório").
3. **Botão "Ver" de documento assinado em `doc.html`** (pendência
   aberta desde a conversão sandbox→autenticação real de 22/08) —
   usuário testou e confirmou que funciona. Nota atualizada no topo
   deste documento.

**Feito (2026-10-01): "Enviar Documento em Lote" em `doc.html` — mesmo
mecanismo do "Enviar Cartão de Ponto" de `escalas.html`, generalizado
pra qualquer tipo de documento.**

**Contexto:** o usuário pediu pra "copiar" o modal de Cartão de Ponto
de `escalas.html`, mas com uma diferença central: lá o tipo é fixo
("Cartão de Ponto"); em `doc.html` o usuário escolhe o tipo no modal
(exemplo dado: Recibo de Férias). É o mesmo padrão de "documento
externo, já pronto" — ao contrário de todos os termos anteriores
(admissao.html/doc.html), aqui **não se gera PDF nenhum**: o arquivo
já vem pronto (da folha, de um sistema externo etc.), só é subido tal
como está e mandado pro mesmo pipeline de assinatura digital real.

**O que foi copiado de `escalas.html` (mesmo comportamento):**
- Casamento automático de cada arquivo com um colaborador pela
  **matrícula no início do nome do arquivo** (regex `^\d+`, tolera
  separador variável: `"7_NOME_id.pdf"` ou `"24416 – NOME.pdf"`).
- Lista de arquivos reconhecidos (✓ matrícula+nome) vs. não
  reconhecidos (✗ com motivo — matrícula não encontrada ou
  colaborador inativo), com resumo "X reconhecido(s) · Y não
  reconhecido(s)".
- Campo de **competência/período** (data início/fim, sugerido como
  mês fechado anterior, editável) — usado como chave de
  versionamento (reenviar o mesmo período vira v2, v3...).
- Envio sequencial em fila com progresso ("Enviando 2/15…"), falhas
  parciais não travam o lote (reporta quantos deram certo + lista de
  matrículas que falharam).
- Mesmo pipeline final: upload pro bucket `assinaturas` → `colaborador_
  documento_pendente_assinatura_sandbox_salvar` → `docs_enviar_para_
  assinatura` (exige rubrica + selfie) → `colaborador_documento_
  definir_atribuicao_sandbox`.

**O que mudou pra generalizar:**
- **Tipo de documento vira um `<select>`** no modal, populado a
  partir de `docTipos` (já carregado por `loadAllData()`, sem RPC
  extra) — filtrado pra só mostrar tipos com `requer_assinatura=true`
  (o pipeline sempre força rubrica+selfie, então não faz sentido
  listar tipos como "Holerite", que no catálogo estão marcados como
  não precisando de assinatura).
- Reaproveita `docColaboradores` (já carregado, cobre Ativo+Inativo)
  em vez de uma RPC nova (`hc_colaboradores_listar`, usada em
  escalas.html) — doc.html já tinha o que precisava.
- Drag-and-drop de verdade implementado (`ondragover`/`ondrop` na
  zona de arrastar) — a versão original em escalas.html tem o texto
  "clique ou arraste" e até o CSS `.dragover`, mas nunca ligou os
  eventos de arrastar; copiei o texto/CSS mas corrigi o comportamento
  nessa cópia nova.
- Novo doc_tipo "Recibo de Férias" criado no catálogo (categoria
  "Férias", `requer_assinatura=true`) — exemplo citado pelo usuário,
  não existia ainda.

Testado com Playwright + mock completo (incluindo `storage.from(...).
upload`): seletor de tipo mostra só os que exigem assinatura (Cartão
de Ponto, Recibo de Férias — Holerite corretamente de fora), 3
arquivos de teste (1 matrícula ativa reconhecida, 1 matrícula
inexistente, 1 colaborador inativo) classificados corretamente,
validação bloqueando sem tipo/período selecionado, upload confirmado
no bucket `assinaturas` com o path certo, só o arquivo válido gerou
as 2 chamadas de RPC do pipeline (pendente + definir atribuição).
Conferência visual do modal renderizado.

**Feito (2026-10-01): ajuste fino de densidade na Ficha de Registro
— fonte das caixas 1px menor e ~20% mais leve.** Pedido pontual ("diminui
1px da fonte e tira 20% do pesso") sobre as caixas `.rp-intro-value`
(o mesmo componente reaproveitado em todos os termos pro cabeçalho
Colaborador/Matrícula/Cargo/Unidade). Como essa ficha empilha muitas
mais caixas por página que qualquer outro termo, o ajuste foi
**escrito só pra essa página** — nova classe `.rp-freg-compact` no
`<div class="page">` do `_admFichaRegistroBuildPage`, com
`.rp-freg-compact .rp-intro-value{font-size:9.5px;font-weight:600;}`
sobrescrevendo só ali (10.5px/700 → 9.5px/600; 20% de 700 ≈ 560, mas
a DM Sans carregada aqui só tem os degraus 400/500/600/700, então 600
é o mais próximo). Os outros termos continuam com `.rp-intro-value`
original (10.5px/700), sem nenhuma mudança — mesmo cuidado de escopo
já usado antes pra não afetar `.rp-table` global ao compactar a
tabela de Dependentes.

Testado com Playwright: `getComputedStyle` confirmando 9.5px/600 nas
caixas da Ficha de Registro e 10.5px/700 inalterado num outro termo
renderizado ao lado (Contribuição Sindical). Conferência visual lado
a lado.

**Feito (2026-10-01): reorganização das linhas da Ficha de Registro
— 1ª rodada (usuário vai mandar o resto por partes).** O usuário
especificou a ordem exata das linhas por seção, numerada manualmente
(com `( )` sinalizando anotações, não nomes literais de campo).
Implementado exatamente o que foi pedido pra seção 1 e 2:

**Seção "Dados da Empresa e Colaborador"** — as 4 seções antigas que
cobriam esses dados (cabeçalho Empresa/CNPJ/Endereço/Matrícula/Nome,
"Documentos", "Dados Pessoais", "Endereço", "Dados do Cargo") foram
**unificadas numa seção só**, com 7 linhas na ordem pedida:
1. CNPJ / Empresa / Endereço
2. MT / Nome / Data de Admissão
3. Data de Nascimento / Nacionalidade / Local de Nascimento / Estado Civil
4. RG / CPF / Grau de Instrução / Título de Eleitor / PCD?
5. Endereço / Bairro / CEP / Cidade/UF / Telefone
6. CTPS (número/série/UF/categoria) / Carteira de Reservista
7. Departamento / Cargo / Horário / Salário Fixo / Pagamento

**Seção "Filiação"** — mantida como já estava (Pai/Mãe), só virou
seção independente logo depois da unificada (antes vinha antes de
"Documentos"; ordem não importa pro resultado, mas ficou mais perto
de como o usuário desenhou).

Pontos que precisaram de decisão/ajuste no meio do caminho:
- **CTPS sumiu da lista original do usuário** (só "Reservista"
  aparecia na linha 6, sozinho). Perguntei antes de mexer — resposta:
  "junto com Reservista na linha 6". Implementado como 5 caixas numa
  linha só (CTPS/Série/UF/Categoria/Reservista).
- **"País de Nascimento" virou "Nacionalidade"** — mesmo campo
  (`adm-freg-pais-nascimento`), só relabel + valor padrão trocado de
  "Brasil" pra "Brasileira" (gramaticalmente mais correto pro
  rótulo novo).
- **Local de Nascimento + UF (nascimento), antes 2 caixas
  separadas, viraram 1 caixa combinada** ("São Paulo/SP") — o
  usuário listou só "Local de Nascimento" na linha 3, sem mencionar
  UF separado; mantive os 2 campos manuais no modal (sem perder
  granularidade), só a exibição no PDF combina os dois.
- **CBO removido por completo** (campo do modal, leitura e exibição)
  — já tinha sido descartado no fechamento de backlog de 30/09 ("dar
  como concluído e descartar"), e a nova linha 7 do usuário não
  menciona CBO, confirmando a remoção definitiva. Campo órfão no
  modal (que não aparecia mais em lugar nenhum do PDF) foi limpo.

**O que ficou de fora dessa rodada, sem mudança:** seções de FGTS,
PIS e Dependentes continuam exatamente como estavam, na mesma ordem,
logo após Filiação — o usuário disse que vai passar a reorganização
delas "depois" (seção 3 em diante da numeração dele, ainda não
especificada).

Testado com Playwright: modal sem campo CBO, label/valor padrão
"Nacionalidade"/"Brasileira" confirmados, auto-preenchimento (ficha
via CPF) continuando a funcionar normalmente após a reestruturação,
PDF final com seção única "Dados da Empresa e Colaborador" (sem mais
"Dados do Cargo"/"Documentos" separados), CBO ausente do PDF, dados
batendo nas posições certas. Conferência visual da página completa
renderizada.

**Feito (2026-10-01): espaçamento entre linhas reduzido + foto
dobrada de tamanho, reposicionada à frente/esquerda das linhas 1 e
2.** Dois ajustes pontuais na Ficha de Registro:

1. **Espaçamento entre linhas.** `.rp-intro` (cada linha de caixas)
   tem `margin-bottom:18px` global — e como essa ficha empilha muito
   mais linhas que qualquer outro termo, reduzido pra `8px` **só
   nessa página** (`.rp-freg-compact .rp-intro`), mesmo escopo já
   usado nos ajustes anteriores de densidade.
2. **Foto 100% maior, posicionada à frente/esquerda das linhas 1 e 2**
   (CNPJ/Empresa/Endereço e MT/Nome/Data de Admissão) em vez de
   dentro da linha 2 como antes. 56px → 112px
   (`.rp-foto-box` → `.rp-foto-box-lg`, classe antiga removida por
   não ter mais uso). Estruturalmente, as linhas 1 e 2 agora ficam
   dentro de um `<div class="rp-freg-header-rows">` (coluna, sem
   espaçamento entre si) ao lado da foto, dentro de um
   `<div class="rp-freg-header-wrap">` (linha, `align-items:stretch`)
   — a foto estica pra cobrir a altura combinada das duas linhas.

Testado com `node -e` (sintaxe) e conferência visual da página
completa renderizada com foto de teste: espaçamento visivelmente mais
compacto entre todas as linhas da seção, foto grande e alinhada à
esquerda cobrindo as duas primeiras linhas, resto do layout
inalterado.

**Feito (2026-10-01): seção renomeada + Filiação incorporada como
linha, sem seção própria.** Dois ajustes:

1. **"Dados da Empresa e Colaborador" → "Informações Gerais"** (só o
   título da seção).
2. **Pai/Mãe saem da seção "Filiação" própria e viram uma linha a
   mais dentro de "Informações Gerais"**, logo depois da linha 3
   (Data de Nascimento/Nacionalidade/Local de Nascimento/Estado
   Civil) — sem nenhum divisor de seção entre elas. Labels das
   caixas trocadas de "Pai"/"Mãe" pra **"Filiação: Pai"/"Filiação:
   Mãe"**, já que o nome da seção que dava esse contexto deixou de
   existir ali.

Testado com `node -e` (sintaxe) + Playwright: lista de seções da
página confirmando que só sobrou "Informações Gerais" (sem
"Filiação" separada) seguida de FGTS/PIS/Dependentes, e os labels
"Filiação: Pai"/"Filiação: Mãe" presentes na posição certa (logo após
a linha de nascimento). Conferência visual da página completa.

**Feito (2026-10-01): CTPS/Série/UF combinados numa caixa só.**
Linha 6 da "Informações Gerais" tinha 5 caixas (CTPS/Série/UF/
Categoria/Carteira de Reservista); removidas "Série" e "UF" como
caixas separadas — o valor combinado (`número série UF`, ex.:
"4327254 3805 SP") passa a aparecer todo dentro da caixa "CTPS".
Mesmo padrão já usado em "Local de Nascimento" (campos do modal
continuam separados — `adm-freg-ctps`/`adm-freg-ctps-serie`/
`adm-freg-ctps-uf` —, só a exibição no PDF combina os três). Linha 6
fica com 3 caixas: CTPS / Categoria / Carteira de Reservista.

Testado com Playwright: confirmado que não sobra nenhuma caixa
rotulada "Série" ou "UF" na página, caixa "CTPS" com o valor
combinado "4327254 3805 SP". Conferência visual da página completa.

**Feito (2026-10-01): bug real — UF de nascimento parou de
auto-preencher porque um campo novo apareceu na ficha depois do
levantamento original.** Usuário reportou "local de nascimento não
está puxando (local_nascimento)". Conferi de novo `dp_rh.
admissao_respostas` e achei `grupo=pessoais campo=local_nascimento`
— **não existia na primeira investigação** (na época só tinha
nascimento/estado_civil/escolaridade etc.; esse campo foi adicionado
depois pela sessão que mantém a ficha da Sara, sem eu saber). Olhei o
valor real de alguns registros: são siglas de UF ("SP", "AL") ou
"Exterior" — ou seja, é a **UF de nascimento**, não a cidade, apesar
do nome do campo sugerir "local". Cidade continua sem fonte (nenhum
campo equivalente existe pra ela).

Corrigido: `_admFichaRegistroAutoFill()` agora também preenche
`adm-freg-uf-nascimento` a partir desse campo; placeholder do campo
no modal trocado de "sem fonte — preencher manualmente" pra
"preenchido automaticamente — confira" (campo de cidade continua com
o placeholder antigo, esse não mudou). A caixa combinada "Local de
Nascimento" do PDF (que já junta cidade+UF desde a reorganização
anterior) passa a mostrar a UF sozinha quando só ela vem preenchida
(ex.: "SP"), sem cidade.

Lição: campos "sem fonte" documentados aqui não são permanentes — a
ficha da Sara é mantida por outra sessão/repo e pode ganhar campos
novos a qualquer momento sem aviso. Reconferi `dp_rh.
admissao_respostas` por completo (`select distinct grupo, campo`) pra
ver se mais algum campo "sem fonte" tinha surgido — e tinha: **3 a
mais**, todos ligados agora na mesma rodada:

- `pessoais.ctps_uf` — UF da CTPS (antes manual).
- `pessoais.nacionalidade` — "Brasileira"/"Estrangeira" direto da
  ficha (antes só um valor padrão fixo "Brasileira", sem checar a
  ficha).
- `pessoais.titulo_numero` + `titulo_zona` + `titulo_secao` — Título
  de Eleitor completo (antes totalmente manual; combinados no mesmo
  campo "N° / Zona / Seção" do modal, juntados com " / ").

**Categoria (CTPS)** e **PIS banco/agência/endereço/data de
cadastro** seguem genuinamente sem fonte — não achei campo
equivalente pra nenhum deles na ficha. Esses continuam manuais.

Testado com Playwright: os 4 campos (UF de nascimento, UF da CTPS,
Nacionalidade, Título de Eleitor) confirmados auto-preenchendo a
partir de uma ficha mockada com todos os campos novos, valores
batendo exatamente com o formato esperado em cada um. Campo de
cidade (local de nascimento) e Categoria confirmados continuando
vazios/manuais.

_Última atualização: 2026-10-01._
