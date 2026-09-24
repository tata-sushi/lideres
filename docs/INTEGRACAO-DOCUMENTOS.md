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

_Última atualização: 2026-09-24._
