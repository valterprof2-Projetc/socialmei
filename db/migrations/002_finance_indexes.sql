-- Índices adicionais do módulo financeiro. Seguro para execução repetida.
CREATE INDEX IF NOT EXISTS idx_cash_business_date
  ON cash_transactions(business_id, transaction_date);

CREATE INDEX IF NOT EXISTS idx_cash_business_status_direction_date
  ON cash_transactions(business_id, status, direction, transaction_date);

CREATE INDEX IF NOT EXISTS idx_cash_business_payment_date
  ON cash_transactions(business_id, payment_method, transaction_date);
