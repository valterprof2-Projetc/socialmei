# SocialMEI — API Financeira (Turso)

Esta entrega adiciona uma API serverless para leitura e gravação de `cash_transactions`, usando o banco Turso já existente. Não cria tabelas, não substitui `v_cash_balance` e não implementa abertura/fechamento físico de caixa.

## Configuração na Vercel

1. Importe/publica a raiz deste projeto na Vercel (a pasta `frontend/` continua contendo o site estático).
2. Configure as variáveis de ambiente a partir de `.env.example`:
   - `TURSO_DATABASE_URL`: URL libSQL do banco na região `aws-sa-east-1`.
   - `TURSO_AUTH_TOKEN`: token de autenticação do Turso.
   - `SOCIALMEI_INTERNAL_API_KEY`: segredo longo e aleatório, exclusivo do servidor.
3. Faça o deploy. Nunca coloque o token Turso nem a chave interna em `frontend/config.js`, HTML, JavaScript público ou repositório.
4. Execute `db/migrations/002_finance_indexes.sql` uma vez no SQL Console do Turso. O script usa `IF NOT EXISTS`.

## Autenticação nesta primeira entrega

As rotas exigem `Authorization: Bearer <SOCIALMEI_INTERNAL_API_KEY>`. É um mecanismo de integração servidor-a-servidor, adequado para n8n chamando a API por credencial guardada no servidor. Não exponha essa chave no navegador.

A autenticação de usuários do CRM ainda precisa ser integrada ao backend de contas/sessões do SocialMEI. Até isso estar pronto, não configure a chave interna no frontend e não habilite modo remoto do Financeiro no navegador.

## Rotas

### `GET /api/financeiro?business_id=<id>&from=AAAA-MM-DD&to=AAAA-MM-DD`

Filtros opcionais: `direction=income|expense`, `status=pending|confirmed|cancelled`, `payment_method=cash|pix|credit_card|debit_card|bank_transfer|other`, `limit` (máximo 100) e `offset`.

Retorna `{ items, count }`. Valores monetários são inteiros em centavos.

### `GET /api/financeiro/resumo?business_id=<id>&from=AAAA-MM-DD&to=AAAA-MM-DD`

Retorna receitas, despesas, resultado líquido estimado, movimentação líquida em dinheiro físico, quantidade de lançamentos, recebíveis pendentes e agrupamento por forma de pagamento. Os totais de receita/despesa consideram somente lançamentos `confirmed`.

### `GET /api/financeiro/pendentes?business_id=<id>&from=AAAA-MM-DD&to=AAAA-MM-DD`

Lista entradas com `direction='income'` e `status='pending'`. Na V2, `transaction_date` é a data do lançamento; ainda não existe campo separado de vencimento. Portanto, esta rota não deve ser apresentada como relatório completo de contas vencidas.

### `POST /api/financeiro?business_id=<id>`

Corpo JSON:

```json
{
  "direction": "income",
  "category": "Serviço de limpeza",
  "description": "Higienização de sofá",
  "amount_cents": 18500,
  "payment_method": "pix",
  "transaction_date": "2026-11-22",
  "status": "confirmed",
  "customer_id": null,
  "appointment_id": null,
  "notes": "Recebido após o atendimento"
}
```

`business_id` deve ser enviado na query string. `amount_cents` é inteiro positivo em centavos. `payment_method` aceita `cash`, `pix`, `credit_card`, `debit_card`, `bank_transfer` e `other`.

## Exemplo de chamada do n8n

Use uma credencial Header Auth ou credencial genérica Bearer:

- Header: `Authorization: Bearer <chave guardada como credencial no n8n>`
- Método: `GET`
- URL: `https://SEU-DOMINIO/api/financeiro/resumo?business_id=ID_DA_EMPRESA&from=2026-11-01&to=2026-11-30`

Não grave a chave em campos de texto fixos de workflows exportáveis.

## Regras e limites

- Cada consulta e gravação recebe explicitamente `business_id`; o backend nunca confia em um ID de empresa implícito.
- A chave interna autentica o serviço, mas não substitui autorização multiusuário por sessão. Para expor ao CRM no navegador, integrar autenticação e autorização por usuário/empresa primeiro.
- O resumo financeiro é gerencial e não substitui contabilidade, apuração tributária ou conciliação bancária.
- O saldo físico em dinheiro deve ser calculado somente com `payment_method='cash'`; PIX/cartões não compõem dinheiro em espécie.
- O endpoint de pendentes usa os registros atuais. Parcelas, vencimento real, baixa parcial e inadimplência com data de vencimento exigirão modelagem específica futura.
