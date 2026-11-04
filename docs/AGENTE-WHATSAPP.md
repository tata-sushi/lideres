# Agente RH no WhatsApp (Sam)

O Sam fica num **grupo de WhatsApp** e responde perguntas sobre a base do RH quando é chamado.
Ex.: "Sam, quantas entrevistas a Jéssica agendou?", "@Sam quem folga sábado no Itaim?".

Decisões do usuário (28/10):
- **Grupo** (todos do grupo perguntam) e, desde 02/11, **privado só para números cadastrados** (Victor, Tito e Binho).
- **Todos do grupo podem perguntar**: o controle é o grupo, e grupo novo nasce pendente.
- **Responde só quando chamado**: "Sam, …", @Sam ou reply a uma mensagem dele.
- **Instância uazapi do Sam** (`sam`, número 5511939311173). Ela só enviava (resumos, aniversários, pendências)
  e não tinha webhook. O agente tem **fluxo próprio no n8n** (porteiro). Os fluxos existentes não foram mexidos.
- **Claude via OpenRouter**, reaproveitando a `LLM_API_KEY`.
- **Consulta livre só-leitura**, sem colunas sensíveis.

> ⚠️ Adicionar alguém ao grupo = dar acesso aos dados que o Sam consulta (a resposta é vista por todos do grupo).

## Status (checklist vivo)

- [x] Banco: grupos autorizados, histórico/auditoria, log de ignorados (7 dias), senhas, estilo do prompt,
      papel `agente_leitor` + schema `agente` e o executor de consultas só-leitura.
- [x] Teste de segurança (28/10): 13 tentativas bloqueadas (tabela fora de `agente`, coluna sensível,
      função do portal via `public.`, `current_setting`, `query_to_xml`, `pg_proc`, `pg_sleep`, `;`);
      o papel não lê `dp_rh` direto e não grava nem chamando função que grava (read-only).
- [x] Edge `agente-whatsapp` v3 (modo grupo). Testes 28/10: pergunta em grupo novo → fica pendente;
      conversa normal → ignorada (nada gravado); modo teste → "Jéssica, são *9 exames* vencidos ou vencendo…".
      Entrevistas da Jéssica → 80 candidatos / 86 entrevistas (bate com a consulta manual). Modelo: `anthropic/claude-sonnet-5.5`.
- [x] Senha própria para o modo teste (a do webhook fica visível no n8n/uazapi e não abre o modo teste).
- [x] Token da instância `sam` validado na uazapi (conectada) e gravado no banco (`agente_config.uazapi_token`, fora do repo).
- [x] Grupo **Agentes** (`120363406109168905@g.us`, 3 participantes, o Sam já está dentro) liberado em `agente_grupos`.
      `bot_ids` = número + LID do Sam (`5511939311173,83499130314972`) — o grupo usa LID.
- [x] Fluxo próprio no n8n criado: **Agente RH — Sam (WhatsApp)** (`w45flILm6pftpj1V`, projeto pessoal Victor Carvalho),
      https://auto.tatasushi.tech/workflow/w45flILm6pftpj1V — **ainda desligado**.
- [x] **Ligado (28/10, ok do usuário)**: fluxo publicado no n8n; webhook da instância `sam` →
      `https://auto.tatasushi.tech/webhook/agente-rh-sam` (enabled, evento messages, excluir wasSentByApi).
      Teste de conexão (mensagem falsa de privado) → execução n8n com sucesso, parou no "não é grupo".
- [x] Primeiras perguntas reais no grupo Agentes (28/10, 23h56): "Sam," e **@Sam** reconhecidos (o grupo usa LID),
      resposta citando a pergunta, id da resposta gravado (reply ao Sam funciona). Sem erros.
- [x] **Mapa ampliado** a partir de `docs/mapas/dp_rh.md` + **nível por grupo** (28/10): básico = 38 visões
      (`agente`), completo = +14 restritas (`agente_restrito`: atas, avaliações, valores, reclamações). Grupo Agentes = completo.
      Teste: "últimas pautas da reunião de RH" → completo resumiu a reunião de 21/10; básico respondeu que não tem acesso.
- [x] **Grupo oficial (28/10)**: **DP/RH TATÁ SUSHI** (`120363040657807495@g.us`, 8 participantes) liberado, nível completo.
      **Agentes** continua ativo como grupo de teste (completo).
- [x] **Privado (02/11)**: Victor (5511934252017, matrícula 7) e Tito (5511976149080, matrícula 8, CEO) cadastrados
      em `dp_rh.agente_usuarios`, nível completo, com o LID de cada um. Edge v6 responde no privado só a cadastrados
      (sem precisar chamar "Sam"); fluxo n8n passa a repassar tudo que chega (descarta só o que o Sam enviou).
- [x] **Fotos (02/11)**: `agente.colaboradores.foto_url` (avatar do app). Edge v7 transforma linhas "Nome: <link do avatar>"
      da resposta em imagem no WhatsApp (uazapi `/send/media`, até 10); se a imagem falhar, manda o link como texto.
      Envio real confirmado em 02/11 (resposta do aviso #28 ao Tito, 1 foto, sem erro).
- [x] **Avisos de pergunta sem resposta (02/11)**: vão para o privado do responsável (`agente_config.responsavel_telefone`
      = Victor) com quem perguntou (nome pelo cadastro de colaboradores), onde, a pergunta, o motivo e o que o Sam respondeu.
      Casos: número não cadastrado, grupo não liberado, a IA chamou `sem_resposta` (dado inexistente / fora do alcance /
      depende de uma pessoa), erro. Limite 10 avisos/h por origem. O aviso entra no histórico do Victor (o Sam lembra dele).
- [x] **Comandos do responsável (02/11)**: cada aviso tem número (#id). No privado com o Sam o Victor escreve
      `responde 27` (a IA responde a pergunta original para a pessoa/grupo), `libera 27` (cadastra o número ou libera o grupo,
      nível básico, e responde), `27: texto` (manda o texto dele pelo Sam) ou `ignora 27`. Sem número = último aviso aberto
      (24h). O Sam confirma cada comando. Aviso manual: `?teste=<senha>&aviso=1` (usado p/ a pergunta do Tito de 01/11, #28).
      Se a pergunta veio de quem não estava liberado, a resposta começa explicando: "Seu número ainda não estava liberado…
      Reportei para o Victor e ele já liberou o acesso. Agora, sobre a sua pergunta:" (ou "…mas o Victor pediu para eu
      responder" quando continua sem cadastro).
- [x] **Identidade (02/11)**: nas instruções fixas (código): o Sam é o assistente virtual do RH, não uma pessoa, e se reporta
      ao responsável (`responsavel_nome`, Victor) — o que não resolver, alinha com ele. Não anuncia; só diz se perguntarem.
- [x] **Binho liberado (04/11)**: Fabio Yuzo Shiguematsu (Binho, sócio-chef executivo, matrícula 2, 5511999400971),
      privado, nível completo. Ele tinha escrito ao Sam antes de ser liberado (avisos #38 "Boa tarde" e #40 "término da
      experiência do Diogo"); o #40 foi respondido com `libera 40` (16:02) e desde então ele conversa direto com o Sam
      (sanções, banco de horas, foto de colaborador). Edge v13: no `responde N` o Sam olha o cadastro **atual** — quem foi liberado depois da pergunta
      recebe "Seu número ainda não estava liberado… Reportei para o Victor e ele já liberou o acesso" e a resposta sai no nível
      de hoje; a confirmação do `libera N` mostra o nível real (`agente_liberar` devolve o nível e mantém o que já existia).
- [x] **Estilo sucinto (02/11)**: entrou no código (instruções fixas, com prioridade sobre `prompt_estilo` do banco) — o
      `UPDATE` no banco pedia aprovação do Supabase que não chegava no celular. Responde em 1–3 linhas; só aprofunda quando pedem.
- [ ] **Prompt**: usuário vai passar o jeito de responder + mapa de tabelas → reescrever `prompt_estilo` (e visões, se faltar algo).
- [ ] Na 1ª mensagem real, conferir o payload em `agente_webhook_log` (formato da uazapi não confirmado na doc):
      @menção pelo contato (se o Sam usar ID anônimo/LID, cadastrar em `bot_ids`) e reply.
- [ ] Limpeza (precisa de ok p/ apagar): conversas de teste em `agente_mensagens`; grupo de teste
      `000000000000000000-teste@g.us` (inativo); sem uso: `tata_plus.agente_sql`, `tata_plus.agente_catalogo`,
      `tata_plus.agente_segredo()` (sem parâmetro).

## Fluxo

```
Pessoa no grupo Agentes: "Sam, quantas entrevistas a Jéssica agendou?"
        │
        ▼
uazapi (instância sam) ── webhook ──► n8n: "Agente RH — Sam (WhatsApp)"  (fluxo próprio)
                                        [Recebe WhatsApp]  POST /webhook/agente-rh-sam
                                              │
                                        [É mensagem de grupo?] ──não──► para (privado)
                                              │sim
                                        [Envia para o cérebro]  POST …/agente-whatsapp?k=<senha>
                                              │
                                              ▼
Supabase · Edge agente-whatsapp (o "cérebro")
  1. É grupo autorizado?          dp_rh.agente_grupos (novo → pendente, não responde)
  2. Chamaram o Sam?              "Sam, …" · @Sam · reply a mensagem dele (senão ignora, nada gravado)
  3. Histórico do grupo (3h)      dp_rh.agente_mensagens
  4. Claude (OpenRouter) ⇄ consultar_banco → tata_plus.agente_consultar (só-leitura; `agente` + `agente_restrito` se completo)
  5. Responde no grupo citando a pergunta  → uazapi /send/text (token da instância sam)
  6. Grava pergunta, quem perguntou, SQL rodado, modelo, tokens
```

O n8n só repassa; quem decide (grupo autorizado, chamado ou não) é o cérebro. O nó que chama o Supabase
tem `continuar em erro`, e a senha do webhook vai na URL dele.

## Prompt

Duas partes, montadas a cada pergunta:
- **Estilo** (persona, tom, formato da resposta): `dp_rh.agente_config`, chave `prompt_estilo`.
  Editar no banco vale em até 1 minuto, **sem publicar código**.
- **Técnico** (como consultar, o que não pode, data/hora, mapa das visões): fixo no código da edge.
  O mapa é lido do banco: o comentário de cada visão/coluna em `agente` vira explicação para a IA.

```sql
update dp_rh.agente_config set valor = $p$…novo estilo…$p$, atualizado_em = now() where chave = 'prompt_estilo';
```

## O que o agente enxerga

Fonte: `docs/mapas/dp_rh.md` (mapa do schema, com as regras de leitura). Cada grupo tem um **nível**:

- **básico** (padrão de grupo novo) — schema `agente`, 38 visões: colaboradores, recrutamento (candidaturas, entrevistas,
  testes, vagas, agenda dos líderes), escalas (dias, padrão, horários, controle), ausências, férias, banco de horas,
  feriados, exames, HC programado, cargos, admissões + documentos da admissão, pastinha de documentos + catálogo +
  exceções, demissões, sanções, solicitações, armários + histórico, estoque (sem custo), limpeza (sem fotos), agenda,
  score de líderes, líderes responsáveis, reconhecimentos, treinamentos, premiações (sem valor), chamados de manutenção.
- **completo** — + schema `agente_restrito`, 14 visões: atas das reuniões de DP/RH, avaliações (experiência, desempenho,
  liderança — só o consolidado) + legado, salários por cargo, pontos da loja, banco de horas com custo, diárias de teste
  e pretensão, salário das vagas, valores de rescisão, VT, custo de estoque, custo de manutenção, premiações com valor,
  reclamações trabalhistas.
- **Fora em qualquer nível**: ouvidoria, respostas de clima e de desligamento, CPF/telefone/e-mail, ficha da admissão.

```sql
update dp_rh.agente_grupos set nivel = 'completo' where chat_id = '…@g.us';   -- ou 'basico'
```

Para liberar mais: criar a visão em `agente` (básico) ou `agente_restrito` (completo) + `grant select` ao papel +
**comentário** na visão/colunas (vira explicação para a IA; o mapa é relido a cada 10 min, sem publicar).
Consultas passam por `tata_plus.agente_consultar` (filtro de texto + SET ROLE `agente_leitor`/`agente_leitor_total` +
transação read-only + timeout 8s + 200 linhas).

Arquivos: `supabase/migrations/20261028_agente_whatsapp.sql`, `supabase/functions/agente-whatsapp/index.ts`.

## Ligar

1. Token da instância `sam`: já no banco (`agente_config.uazapi_token`). Secret `SAM_UAZAPI_TOKEN` é opcional
   (sobrepõe). Outros opcionais: `SAM_UAZAPI_URL`, `AGENTE_LLM_MODEL` (padrão `anthropic/claude-sonnet-5.5`).
2. n8n: publicar **Agente RH — Sam (WhatsApp)**. Webhook da instância `sam` na uazapi → URL de produção do fluxo,
   evento **messages**, excluindo **wasSentByApi** e **sem** excluir grupos.
3. Grupo novo: adicionar o Sam e mandar **"Sam, oi"**. O grupo aparece pendente:
   ```sql
   select * from dp_rh.agente_grupos;
   update dp_rh.agente_grupos set ativo = true where chat_id = '…@g.us';
   ```

## Testar sem WhatsApp

`POST …/agente-whatsapp?teste=<teste_secret>` com `{"texto":"pergunta","nome":"Jéssica","grupo":"RH"}`
devolve a resposta e as consultas no corpo (não envia nem grava). Pelo banco:

```sql
select net.http_post(
  url := 'https://aoqsbusfrffapjglpqjk.supabase.co/functions/v1/agente-whatsapp?teste='
         || (select valor from dp_rh.agente_config where chave = 'teste_secret'),
  body := '{"texto":"quantos colaboradores ativos por unidade?"}'::jsonb,
  timeout_milliseconds := 120000);
-- depois: select status_code, content from net._http_response order by id desc limit 1;
```

## Acompanhar

```sql
-- conversas (pergunta, quem perguntou, resposta, SQL rodado, modelo, tokens, erros)
select telefone as conversa, papel, meta->>'autor_nome' as autor, texto, meta, criado_em
from dp_rh.agente_mensagens order by id desc limit 50;
-- grupos pendentes e falhas (guarda 7 dias)
select * from dp_rh.agente_webhook_log order by id desc limit 50;
```
