# Agente RH no WhatsApp (Sam)

O Sam fica num **grupo de WhatsApp** e responde perguntas sobre a base do RH quando é chamado.
Ex.: "Sam, quantas entrevistas a Jéssica agendou?", "@Sam quem folga sábado no Itaim?".

Decisões do usuário (28/10):
- **Só em grupo**: mensagem no privado é ignorada.
- **Todos do grupo podem perguntar**: o controle é o grupo, e grupo novo nasce pendente.
- **Responde só quando chamado**: "Sam, …", @Sam ou reply a uma mensagem dele.
- **Instância uazapi do Sam** (`sam`, número 5511939311173). Ela só enviava (resumos, aniversários, pendências)
  e não tinha webhook. O agente tem **fluxo próprio no n8n** (porteiro). Os fluxos existentes não foram mexidos.
- **Claude via OpenRouter**, reaproveitando a `LLM_API_KEY`.
- **Consulta livre só-leitura**, sem colunas sensíveis.

> ⚠️ Adicionar alguém ao grupo = dar acesso aos dados que o Sam consulta (a resposta é vista por todos do grupo).

## Status (checklist vivo)

- [x] Banco: grupos autorizados, histórico/auditoria, log de ignorados (7 dias), senhas, estilo do prompt,
      papel `agente_leitor` + schema `agente` (26 visões limpas) e `tata_plus.agente_sql`.
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
- [ ] Primeira pergunta real no grupo Agentes.
- [ ] **Prompt**: usuário vai passar o jeito de responder + mapa de tabelas → reescrever `prompt_estilo` (e visões, se faltar algo).
- [ ] Na 1ª mensagem real, conferir o payload em `agente_webhook_log` (formato da uazapi não confirmado na doc):
      @menção pelo contato (se o Sam usar ID anônimo/LID, cadastrar em `bot_ids`) e reply.
- [ ] Limpeza: grupo de teste `000000000000000000-teste@g.us` em `dp_rh.agente_grupos` (inativo, pode apagar);
      `dp_rh.agente_usuarios` e `tata_plus.agente_usuario` ficaram sem uso (eram do modo privado).

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
  4. Claude (OpenRouter) ⇄ consultar_banco → tata_plus.agente_sql (só-leitura, visões `agente`)
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

Só as visões do schema `agente` (26): colaboradores, recrutamento (candidaturas, entrevistas, testes, vagas,
agenda dos líderes), escalas (dias, padrão, controle), ausências, férias, banco de horas, feriados, exames,
HC programado, cargos, admissões, demissões, sanções, solicitações, armários, agenda, score de líderes,
reconhecimentos, treinamentos, chamados de manutenção.
Fora: CPF, telefone, e-mail, salários/valores, respostas de clima/desligamento/ouvidoria.
Para liberar mais: criar/alterar a visão em `agente` + `grant select … to agente_leitor` + comentário.

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
