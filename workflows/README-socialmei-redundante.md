# SocialMEI Redundante — Agente IA WAHA-WhatsApp-Instagram

## Isolamento e segurança
- Este é um fluxo novo e independente; não modifica o workflow original nem a EC2.
- O workflow é importado com `active: false` e trabalha em modo shadow: recebe, normaliza e persiste mensagens; não responde ao cliente.
- Não há credenciais, tokens ou senhas no JSON.
- O backend usa `Authorization: Bearer` com segredo M2M próprio e workspace definido no servidor. Não aceita `workspace_id` enviado pelo n8n.

## Arquivos
- `api/integrations.js`: API M2M separada.
- `workflows/socialmei-redundante-shadow.json`: workflow importável com entradas WAHA, Meta Instagram e verificação GET do webhook Meta.
- `migrations/2026-11-26-socialmei-quotes.sql`: migração de cotações para validação/aplicação controlada.

## Variáveis necessárias no deploy da API
- `SOCIALMEI_M2M_TOKEN`: segredo aleatório com pelo menos 32 caracteres.
- `SOCIALMEI_M2M_WORKSPACE_ID`: ID numérico do workspace autorizado (o workspace Brilho&Limpeza identificado no diagnóstico é 1).
- `DATABASE_URL`: conexão PostgreSQL já usada pela API.

## Variáveis no n8n
- `SOCIALMEI_API_BASE_URL`: URL base do deploy da API, sem barra final.
- `SOCIALMEI_WAHA_ACCOUNT_REF`: identificador da conta WAHA no formato `waha:5511999999999@c.us` (substituir pelo número real).
- `SOCIALMEI_META_VERIFY_TOKEN`: token escolhido para verificação do webhook Meta.

Crie uma credencial n8n do tipo **Header Auth** chamada **SocialMEI Redundante API**, com:
- Header name: `Authorization`
- Header value: `Bearer <SOCIALMEI_M2M_TOKEN>`

## Endpoints M2M
- `POST /api/integrations/messages/ingest`: persiste mensagem externa, conversa, cliente quando identificável e cria job de sentimento pendente.
- `GET /api/integrations/catalog/services`: consulta somente serviços ativos do catálogo.
- `GET /api/integrations/quotes` e `POST /api/integrations/quotes`: consulta e registra cotações com preços obtidos diretamente do catálogo.
- `GET /api/integrations/agenda/resources`: lista recursos ativos da agenda.
- `GET /api/integrations/agenda/availability?resource_id=<uuid>&servico_id=<id>&scheduled_for=<ISO-8601>`: verifica conflito de horário.
- `POST /api/integrations/agenda/appointments`: registra agendamento somente com `customer_confirmed: true`, após validar serviço, cliente, recurso e conflito de horário.

## Limitações atuais — não considerar produção pronta
1. A nova entrada WAHA está pronta para teste, mas **não está conectada ao WAHA da EC2**. Fazer isso exigiria alterar a configuração de webhook na EC2 ou encaminhar pelo workflow original; ambos estão proibidos pela premissa atual. Use o webhook de teste/manual para validar sem tocar na infraestrutura existente.
2. Instagram tem webhook POST e verificação GET preparados, mas ainda exige configurar o app Meta, conta profissional, permissões e assinatura dos eventos.
3. O fluxo ainda não envia respostas. A etapa de IA/atendimento e o envio de saída por canal ficam bloqueados até concluir a validação shadow e configurar credenciais independentes.
4. O job de sentimento é enfileirado no banco; o consumidor/worker de análise ainda precisa ser ligado.
5. A migração de cotações foi validada somente na branch temporária Neon. Não foi aplicada à branch de produção.

## Ordem de ativação segura
1. Configurar as variáveis e credencial M2M no ambiente isolado.
2. Importar o JSON no n8n como workflow novo; manter inativo durante a revisão.
3. Testar manualmente os webhooks e conferir os registros no CRM.
4. Validar o app Meta e os eventos Instagram.
5. Implementar e validar o consumidor de sentimento e o agente Brilho Assistant.
6. Somente depois decidir como fornecer eventos ao novo fluxo sem alterar EC2/workflows originais.
