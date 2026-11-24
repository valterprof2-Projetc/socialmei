# SocialMEI — Neon PostgreSQL

## Estado desta etapa

- O frontend V22 continua em HTML/CSS/JavaScript vanilla.
- O PostgreSQL do Neon é acessado exclusivamente no servidor pela variável `DATABASE_URL`.
- `lib/postgres.js` fornece um pool reutilizável para funções serverless da Vercel.
- `GET /api/health` verifica conectividade e presença do schema `socialmei` sem expor dados de conexão.
- A API Turso existente (`api/financeiro.js` e `lib/db.js`) foi preservada nesta etapa para evitar interromper o fluxo anterior.
- A migração `003_cash_ledger_and_register.sql` adiciona o livro-caixa e as sessões operacionais de abertura/fechamento diário. Ela não substitui `crm_financeiro`, que continua sendo o módulo de contas a pagar/receber.

## Variáveis na Vercel

Configure no projeto:

- `DATABASE_URL`: string de conexão pooled do Neon para execução serverless.
- `DATABASE_URL_UNPOOLED`: conexão direta, reservada a migrações e tarefas administrativas.

Não coloque nenhuma dessas variáveis em arquivos do frontend, no Git ou em mensagens. Não use `DATABASE_URL_UNPOOLED` na execução normal das funções.

## Teste

Após configurar `DATABASE_URL` e publicar esta branch em um ambiente Preview:

- Acesse `/api/health`.
- Resultado esperado: HTTP 200, `ok: true`, `database: "connected"` e `schema_ready: true`.

Se a variável estiver ausente ou a conexão falhar, a rota responde com estado indisponível sem devolver host, usuário, senha ou mensagem interna do PostgreSQL.

## Próxima etapa de implementação

A API completa `/api/v1` ainda precisa ser implementada antes de ativar `SOCIALMEI_CONFIG.auth` e os módulos remotos no navegador. A ordem segura é:

1. sessão, login, cadastro, CSRF e autorização por workspace;
2. clientes e catálogo, incluindo importações idempotentes e controle de versão;
3. vendas e movimentação de estoque transacional;
4. contas a pagar/receber e livro-caixa, mantendo os dois conceitos separados;
5. agenda, disponibilidade e operações idempotentes;
6. testes automatizados e validação no Preview da Vercel.

Os fluxos n8n e WAHA existentes na EC2 permanecem externos e não são recriados por esta camada.
