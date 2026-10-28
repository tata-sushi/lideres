# Agente RH no WhatsApp (Sam)

Pergunta em linguagem natural pelo WhatsApp → resposta com dados do Supabase.
Ex.: "quantas entrevistas a Jéssica agendou?", "quem folga sábado no Itaim?",
"quantos atestados em outubro por unidade?".

Decisões do usuário (28/10): **lista fixa** de números · **instância uazapi do Sam** ·
**Claude via OpenRouter** (reaproveita `LLM_API_KEY`) · **consulta livre só-leitura**, sem colunas sensíveis.

## Status (checklist vivo)

- [x] Migração aplicada: lista de números, histórico/auditoria, log de ignorados (7 dias), senha do webhook,
      papel `agente_leitor` + schema `agente` (26 visões limpas) e `tata_plus.agente_sql`.
- [x] Teste de segurança (28/10): 13 tentativas bloqueadas (tabela fora de `agente`, coluna sensível,
      função do portal via `public.`, `current_setting`, `query_to_xml`, `pg_proc`, `pg_sleep`, `;`);
      o papel não lê `dp_rh` direto e não grava nem chamando função que grava (read-only).
- [x] Edge `agente-whatsapp` publicada (v1). Teste ponta a ponta em modo teste: "quantas entrevistas a
      Jéssica agendou" → 80 candidatos / 86 entrevistas (6 remarcadas) — bate com a consulta manual.
      Modelo em uso: `anthropic/claude-sonnet-5.5`.
- [ ] Senha própria para o modo teste (hoje usa a mesma do webhook, que fica visível no painel da uazapi).
- [ ] **[USUÁRIO]** secret `SAM_UAZAPI_TOKEN`.
- [ ] **[USUÁRIO]** números autorizados (nome + WhatsApp).
- [ ] **[USUÁRIO]** webhook na instância do Sam (ver "Ligar" abaixo).
- [ ] Primeira mensagem real: conferir `agente_webhook_log` / `agente_mensagens` — o formato do payload
      da uazapi não pôde ser confirmado na documentação (a leitura é tolerante a variações).

## Como funciona

```
WhatsApp → uazapi (instância do Sam) → webhook
  → Edge `agente-whatsapp`
      1. número está em dp_rh.agente_usuarios? senão ignora (sem responder)
      2. histórico das últimas 3h da conversa
      3. Claude (OpenRouter) + ferramenta consultar_banco
         → tata_plus.agente_sql: só SELECT, como o papel agente_leitor,
           transação read-only, timeout 8s, até 200 linhas
      4. responde pela uazapi e grava tudo em dp_rh.agente_mensagens
```

O agente **só lê**, e só as visões do schema `agente` (26 visões: colaboradores,
recrutamento, escalas, ausências, férias, banco de horas, exames, HC, cargos,
admissões, demissões, sanções, solicitações, armários, agenda, score de líderes,
reconhecimentos, treinamentos, chamados de manutenção). Fora das visões:
CPF, telefone, e-mail, salários/valores, respostas de clima/desligamento/ouvidoria.
Para liberar mais coisa: criar/alterar a visão em `agente` + `grant select … to agente_leitor`
(o catálogo do prompt é lido do banco — comentário da visão/coluna vira explicação pra IA).

Arquivos: `supabase/migrations/20261028_agente_whatsapp.sql`, `supabase/functions/agente-whatsapp/index.ts`.

## Ligar

1. **Secret** `SAM_UAZAPI_TOKEN` (Supabase → Edge Functions → Secrets) = token da instância do Sam.
   Opcionais: `SAM_UAZAPI_URL` (padrão `https://tatasushi.uazapi.com`), `AGENTE_LLM_MODEL`
   (padrão `anthropic/claude-sonnet-5.5`). A IA usa `LLM_API_URL`/`LLM_API_KEY` (os mesmos do gerar-cardapio).
2. **Webhook** na instância do Sam (painel uazapi): URL
   `https://aoqsbusfrffapjglpqjk.supabase.co/functions/v1/agente-whatsapp?k=<senha>`,
   evento **messages**, excluir **wasSentByApi** e **isGroupYes**.
   Senha: `select valor from dp_rh.agente_config where chave = 'webhook_secret';`
   Se a instância já tiver webhook (n8n), **adicionar** um segundo — não trocar.
3. **Números autorizados:**
   ```sql
   insert into dp_rh.agente_usuarios (telefone, nome, matricula) values ('5511999999999', 'Nome', '12345');
   -- desligar: update dp_rh.agente_usuarios set ativo = false where telefone = '…';
   ```

## Testar sem WhatsApp

`POST …/agente-whatsapp?k=<senha>&teste=1` com `{"texto":"pergunta"}` devolve a resposta
e as consultas no corpo (não envia nem grava). Pelo banco:

```sql
select net.http_post(
  url := 'https://aoqsbusfrffapjglpqjk.supabase.co/functions/v1/agente-whatsapp?teste=1&k='
         || (select valor from dp_rh.agente_config where chave = 'webhook_secret'),
  body := '{"texto":"quantos colaboradores ativos por unidade?"}'::jsonb,
  timeout_milliseconds := 120000);
-- depois: select status_code, content from net._http_response order by id desc limit 1;
```

## Acompanhar

```sql
-- conversas (pergunta, resposta, SQL rodado, modelo, tokens, erros)
select telefone, papel, texto, meta, criado_em from dp_rh.agente_mensagens order by id desc limit 50;
-- o que foi ignorado (número fora da lista, áudio, payload estranho) — guarda 7 dias
select * from dp_rh.agente_webhook_log order by id desc limit 50;
```
