# Agente RH no WhatsApp (Sam)

Pergunta em linguagem natural pelo WhatsApp → resposta com dados do Supabase.
Ex.: "quantas entrevistas a Jéssica agendou?", "quem folga sábado no Itaim?",
"quantos atestados em outubro por unidade?".

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
