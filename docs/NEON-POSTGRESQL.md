# SocialMEI — Neon PostgreSQL

## Limite operacional obrigatória

O desenvolvimento desta branch é restrito ao GitHub, Neon e Vercel. A infraestrutura AWS/EC2 usada pelos alunos é intocável. Não reiniciar containers, alterar Docker, portas, redes, volumes, variáveis, n8n, WAHA ou workflows. A integração futura será somente consumidora dos endpoints/webhooks que já estiverem disponibilizados, após validação dos responsáveis.

## Estado desta etapa

- O frontend V22 continua em HTML/CSS/JavaScript vanilla.
- O PostgreSQL do Neon é acessado exclusivamente no servidor pela variável `DATABASE_URL`.
- `lib/postgres.js` fornece um pool reutilizável para funções serverless da Vercel.
- `GET /api/health` verifica conectividade e presença do schema `socialmei` sem expor dados de conexão.
- `api/v1/[...path].js` inicia a API versionada compatível com o caminho-base esperado pela V22 (`/api/v1`).
- A primeira camada implementa sessão por cookie HttpOnly, login/cadastro, troca de workspace, logout, perfil do usuário/negócio, preferências, perfil do workspace e revogação de outras sessões.
- As senhas novas são armazenadas com Argon2id. O servidor valida identidade e CSRF em operações autenticadas e limita tentativas repetidas de login usando `auth_limites`.
- O cadastro fica fechado por convite por padrão. Para ambiente Preview isolado, `SOCIALMEI_REGISTRATION_MODE=open` permite cadastro aberto; não habilite isso em produção sem política de entrada definida.
- `frontend/config.js` permanece sem `auth.mode = "remote"`. Não ativar o frontend remoto até concluir e validar todos os endpoints que ele consome.
- A API Turso existente (`api/financeiro.js` e `lib/db.js`) foi preservada nesta etapa para evitar interromper o fluxo anterior.
- A migração `003_cash_ledger_and_register.sql` adiciona o livro-caixa e as sessões operacionais de abertura/fechamento diário. Ela não substitui `crm_financeiro`, que continua sendo o módulo de contas a pagar/receber. A migração ainda precisa ser aplicada e validada no Neon antes de qualquer uso desses recursos.

## Variáveis na Vercel

Configure no projeto, somente no ambiente Preview inicialmente:

- `DATABASE_URL`: string de conexão pooled do Neon para execução serverless.
- `DATABASE_URL_UNPOOLED`: conexão direta, reservada a migrações e tarefas administrativas.
- `SOCIALMEI_SESSION_SECRET`: segredo aleatório com pelo menos 32 caracteres, usado para derivar a proteção CSRF. Gere um segredo novo e guarde-o somente nas variáveis protegidas da Vercel.
- `SOCIALMEI_REGISTRATION_MODE`: use `invite` (padrão seguro) ou `open` somente em Preview controlado.

Não coloque nenhuma dessas variáveis em arquivos do frontend, no Git ou em mensagens. Não use `DATABASE_URL_UNPOOLED` na execução normal das funções. Não reutilize tokens ou senhas que tenham sido expostos anteriormente.

## Rotas de autenticação implementadas nesta etapa

- `GET /api/v1/auth/registration`
- `GET /api/v1/auth/session`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/workspaces/switch`
- `PATCH /api/v1/auth/profile`
- `GET /api/v1/auth/preferences`
- `PATCH /api/v1/auth/preferences`
- `POST /api/v1/auth/sessions/revoke-others`
- `GET /api/v1/workspace-profile`
- `PATCH /api/v1/workspace-profile`

A recuperação de senha, verificação de e-mail e os módulos de dados (clientes, produtos, vendas, financeiro e agenda) ainda não estão concluídos nesta camada. Portanto, esta entrega é uma base técnica para Preview e não deve ser considerada pronta para produção ou para abertura pública de contas.

## Teste de conectividade

Após configurar `DATABASE_URL` e publicar esta branch em um ambiente Preview:

- Acesse `/api/health`.
- Resultado esperado: HTTP 200, `ok: true`, `database: "connected"` e `schema_ready: true`.

A rota responde sem devolver host, usuário, senha ou mensagem interna do PostgreSQL.

## Próximas etapas de implementação

1. Testes automatizados da autenticação, cookie, CSRF, limites de tentativas e isolamento entre workspaces.
2. Clientes e catálogo, incluindo controle otimista de versão.
3. Vendas e movimentação de estoque transacional.
4. Contas a pagar/receber e livro-caixa, mantendo os dois conceitos separados.
5. Agenda, disponibilidade, recursos e operações idempotentes.
6. Adaptadores de consumo para os serviços AWS/n8n/WAHA já existentes, sem modificá-los.
7. Somente depois dos testes, ativar o modo remoto da V22 no ambiente Preview.

## Regra de integração AWS

O backend Vercel será cliente dos serviços já existentes na EC2. Endpoints, autenticação e payloads serão documentados a partir das configurações que o responsável disponibilizar. Nenhuma ação administrativa será executada na AWS como parte deste trabalho.
