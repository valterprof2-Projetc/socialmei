-- SocialMEI Redundante: cotações independentes de vendas e oportunidades.
CREATE TABLE socialmei.crm_cotacoes (
 workspace_id bigint NOT NULL REFERENCES socialmei.workspaces(id) ON DELETE CASCADE,
 id uuid NOT NULL, cliente_id bigint NOT NULL, conversation_id bigint NULL,
 status text NOT NULL DEFAULT 'draft', subtotal numeric(14,2) NOT NULL DEFAULT 0,
 desconto numeric(14,2) NOT NULL DEFAULT 0, total numeric(14,2) NOT NULL DEFAULT 0,
 validade_ate date NULL, observacoes text NOT NULL DEFAULT '', operation_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT crm_cotacoes_pk PRIMARY KEY(workspace_id,id),
 CONSTRAINT crm_cotacoes_cliente_fk FOREIGN KEY(workspace_id,cliente_id) REFERENCES socialmei.crm_clientes(workspace_id,id),
 CONSTRAINT crm_cotacoes_conversation_fk FOREIGN KEY(workspace_id,conversation_id) REFERENCES socialmei.me_conversations(workspace_id,id),
 CONSTRAINT crm_cotacoes_status_ck CHECK(status IN ('draft','sent','accepted','rejected','expired','cancelled')),
 CONSTRAINT crm_cotacoes_amounts_ck CHECK(subtotal>=0 AND desconto>=0 AND total>=0 AND desconto<=subtotal),
 CONSTRAINT crm_cotacoes_observacoes_ck CHECK(octet_length(observacoes)<=5000),
 CONSTRAINT crm_cotacoes_operation_uq UNIQUE(workspace_id,operation_id)
);
CREATE INDEX crm_cotacoes_cliente_idx ON socialmei.crm_cotacoes(workspace_id,cliente_id,created_at DESC);
CREATE INDEX crm_cotacoes_conversation_idx ON socialmei.crm_cotacoes(workspace_id,conversation_id,created_at DESC);
CREATE TABLE socialmei.crm_cotacao_itens (
 workspace_id bigint NOT NULL, cotacao_id uuid NOT NULL, id uuid NOT NULL, produto_id bigint NOT NULL,
 descricao_snapshot text NOT NULL, quantidade numeric(12,2) NOT NULL, preco_unitario numeric(14,2) NOT NULL,
 total numeric(14,2) NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT crm_cotacao_itens_pk PRIMARY KEY(workspace_id,cotacao_id,id),
 CONSTRAINT crm_cotacao_itens_quote_fk FOREIGN KEY(workspace_id,cotacao_id) REFERENCES socialmei.crm_cotacoes(workspace_id,id) ON DELETE CASCADE,
 CONSTRAINT crm_cotacao_itens_product_fk FOREIGN KEY(workspace_id,produto_id) REFERENCES socialmei.crm_produtos(workspace_id,id),
 CONSTRAINT crm_cotacao_itens_qty_ck CHECK(quantidade>0),
 CONSTRAINT crm_cotacao_itens_price_ck CHECK(preco_unitario>=0 AND total>=0),
 CONSTRAINT crm_cotacao_itens_desc_ck CHECK(char_length(btrim(descricao_snapshot))>0 AND octet_length(descricao_snapshot)<=500)
);
CREATE INDEX crm_cotacao_itens_product_idx ON socialmei.crm_cotacao_itens(workspace_id,produto_id);
