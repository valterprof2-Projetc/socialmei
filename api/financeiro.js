import { timingSafeEqual } from "node:crypto";
import { getDb } from "../lib/db.js";

const METHODS = new Set(["cash", "pix", "credit_card", "debit_card", "bank_transfer", "other"]);
const DIRECTIONS = new Set(["income", "expense"]);
const STATUSES = new Set(["pending", "confirmed", "cancelled"]);
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function send(res, status, body) {
  res.status(status).setHeader("Cache-Control", "no-store");
  return res.json(body);
}

function authorized(req) {
  const expected = process.env.SOCIALMEI_INTERNAL_API_KEY || "";
  const supplied = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (!expected || !supplied) return false;
  const a = Buffer.from(expected);
  const b = Buffer.from(supplied);
  return a.length === b.length && timingSafeEqual(a, b);
}

function validDate(value, name) {
  if (value == null || value === "") return null;
  if (typeof value !== "string" || !DATE_RE.test(value)) {
    const error = new Error(`${name} deve estar no formato AAAA-MM-DD.`);
    error.statusCode = 422;
    throw error;
  }
  return value;
}

function businessId(req) {
  const value = String(req.query.business_id || req.body?.business_id || "").trim();
  if (!/^[a-zA-Z0-9_-]{1,128}$/.test(value)) {
    const error = new Error("Informe um business_id válido.");
    error.statusCode = 422;
    throw error;
  }
  return value;
}

function queryFilters(req) {
  const from = validDate(req.query.from, "from");
  const to = validDate(req.query.to, "to");
  if (from && to && from > to) {
    const error = new Error("A data inicial não pode ser posterior à data final.");
    error.statusCode = 422;
    throw error;
  }
  return { from, to };
}

async function listTransactions(db, id, filters) {
  const clauses = ["business_id = ?"];
  const args = [id];
  if (filters.from) { clauses.push("transaction_date >= ?"); args.push(filters.from); }
  if (filters.to) { clauses.push("transaction_date < date(?, '+1 day')"); args.push(filters.to); }
  if (filters.direction && DIRECTIONS.has(filters.direction)) { clauses.push("direction = ?"); args.push(filters.direction); }
  if (filters.status && STATUSES.has(filters.status)) { clauses.push("status = ?"); args.push(filters.status); }
  if (filters.payment_method && METHODS.has(filters.payment_method)) { clauses.push("payment_method = ?"); args.push(filters.payment_method); }
  const limit = Math.min(Math.max(Number.parseInt(filters.limit || "50", 10) || 50, 1), 100);
  const offset = Math.max(Number.parseInt(filters.offset || "0", 10) || 0, 0);
  const result = await db.execute({
    sql: `SELECT id, business_id, appointment_id, customer_id, direction, category, description,
                 amount_cents, payment_method, transaction_date, status, notes, created_at
          FROM cash_transactions WHERE ${clauses.join(" AND ")}
          ORDER BY transaction_date DESC, created_at DESC LIMIT ? OFFSET ?`,
    args: [...args, limit, offset],
  });
  return result.rows;
}

async function summary(db, id, from, to) {
  const clauses = ["business_id = ?", "status = 'confirmed'"];
  const args = [id];
  if (from) { clauses.push("transaction_date >= ?"); args.push(from); }
  if (to) { clauses.push("transaction_date < date(?, '+1 day')"); args.push(to); }
  const where = clauses.join(" AND ");
  const totals = await db.execute({
    sql: `SELECT
      COALESCE(SUM(CASE WHEN direction='income' THEN amount_cents ELSE 0 END),0) AS income_cents,
      COALESCE(SUM(CASE WHEN direction='expense' THEN amount_cents ELSE 0 END),0) AS expense_cents,
      COALESCE(SUM(CASE WHEN direction='income' THEN amount_cents ELSE -amount_cents END),0) AS net_cents,
      COALESCE(SUM(CASE WHEN payment_method='cash' AND direction='income' THEN amount_cents
                        WHEN payment_method='cash' AND direction='expense' THEN -amount_cents ELSE 0 END),0) AS cash_movement_net_cents,
      COUNT(*) AS transactions_count
      FROM cash_transactions WHERE ${where}`,
    args,
  });
  const payments = await db.execute({
    sql: `SELECT payment_method, direction, COALESCE(SUM(amount_cents),0) AS amount_cents, COUNT(*) AS count
          FROM cash_transactions WHERE ${where}
          GROUP BY payment_method, direction ORDER BY payment_method, direction`,
    args,
  });
  const pending = await db.execute({
    sql: `SELECT COALESCE(SUM(amount_cents),0) AS pending_receivables_cents, COUNT(*) AS pending_receivables_count
          FROM cash_transactions WHERE business_id = ? AND direction='income' AND status='pending'
          ${from ? "AND transaction_date >= ?" : ""} ${to ? "AND transaction_date < date(?, '+1 day')" : ""}`,
    args: [id, ...(from ? [from] : []), ...(to ? [to] : [])],
  });
  const row = totals.rows[0] || {};
  const pend = pending.rows[0] || {};
  return {
    period: { from, to },
    income_cents: Number(row.income_cents || 0),
    expense_cents: Number(row.expense_cents || 0),
    net_cents: Number(row.net_cents || 0),
    cash_movement_net_cents: Number(row.cash_movement_net_cents || 0),
    transactions_count: Number(row.transactions_count || 0),
    pending_receivables_cents: Number(pend.pending_receivables_cents || 0),
    pending_receivables_count: Number(pend.pending_receivables_count || 0),
    payment_breakdown: payments.rows.map((r) => ({
      payment_method: r.payment_method,
      direction: r.direction,
      amount_cents: Number(r.amount_cents || 0),
      count: Number(r.count || 0),
    })),
    currency: "BRL",
    note: "Resultado operacional estimado com base nos lançamentos confirmados; não equivale à apuração contábil ou tributária.",
  };
}

async function createTransaction(db, id, body) {
  const direction = body.direction;
  const status = body.status || "confirmed";
  const amount = body.amount_cents;
  if (!DIRECTIONS.has(direction)) throw Object.assign(new Error("direction deve ser income ou expense."), { statusCode: 422 });
  if (!STATUSES.has(status)) throw Object.assign(new Error("status inválido."), { statusCode: 422 });
  if (!Number.isSafeInteger(amount) || amount <= 0) throw Object.assign(new Error("amount_cents deve ser inteiro positivo em centavos."), { statusCode: 422 });
  if (body.payment_method != null && !METHODS.has(body.payment_method)) throw Object.assign(new Error("payment_method inválido."), { statusCode: 422 });
  const transactionDate = validDate(body.transaction_date, "transaction_date");
  if (!transactionDate) throw Object.assign(new Error("transaction_date é obrigatório."), { statusCode: 422 });
  const category = String(body.category || "").trim().slice(0, 80);
  const description = String(body.description || "").trim().slice(0, 240);
  if (!category || !description) throw Object.assign(new Error("category e description são obrigatórios."), { statusCode: 422 });
  const result = await db.execute({
    sql: `INSERT INTO cash_transactions
      (business_id, appointment_id, customer_id, direction, category, description, amount_cents,
       payment_method, transaction_date, status, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      RETURNING id, business_id, appointment_id, customer_id, direction, category, description,
                amount_cents, payment_method, transaction_date, status, notes, created_at`,
    args: [id, body.appointment_id || null, body.customer_id || null, direction, category, description,
      amount, body.payment_method || null, transactionDate, status,
      body.notes == null ? null : String(body.notes).slice(0, 1000)],
  });
  return result.rows[0];
}

export default async function handler(req, res) {
  if (req.method === "OPTIONS") return res.status(204).end();
  if (!authorized(req)) return send(res, 401, { error: "unauthorized", detail: "Credencial de integração inválida ou ausente." });
  try {
    const db = getDb();
    const id = businessId(req);
    const pathname = new URL(req.url, "https://socialmei.invalid").pathname.replace(/\/+$/, "");
    const route = String(req.query.route || "").replace(/^\/+|\/+$/g, "");

    if (req.method === "GET" && (route === "resumo" || pathname.endsWith("/resumo"))) {
      const { from, to } = queryFilters(req);
      return send(res, 200, await summary(db, id, from, to));
    }

    if (req.method === "GET" && (route === "pendentes" || pathname.endsWith("/pendentes"))) {
      const { from, to } = queryFilters(req);
      const result = await db.execute({
        sql: `SELECT id, customer_id, appointment_id, category, description, amount_cents,
                     payment_method, transaction_date, notes
              FROM cash_transactions WHERE business_id = ? AND direction='income' AND status='pending'
              ${from ? "AND transaction_date >= ?" : ""} ${to ? "AND transaction_date < date(?, '+1 day')" : ""}
              ORDER BY transaction_date ASC LIMIT 100`,
        args: [id, ...(from ? [from] : []), ...(to ? [to] : [])],
      });
      return send(res, 200, { items: result.rows, count: result.rows.length });
    }

    if (req.method === "GET" && (pathname === "/api/financeiro" || pathname.endsWith("/financeiro"))) {
      const items = await listTransactions(db, id, {
        ...queryFilters(req), direction: req.query.direction, status: req.query.status,
        payment_method: req.query.payment_method, limit: req.query.limit, offset: req.query.offset,
      });
      return send(res, 200, { items, count: items.length });
    }

    if (req.method === "POST" && (pathname === "/api/financeiro" || pathname.endsWith("/financeiro"))) {
      const item = await createTransaction(db, id, req.body || {});
      return send(res, 201, { item });
    }

    return send(res, 404, { error: "not_found", detail: "Rota financeira não encontrada." });
  } catch (error) {
    const status = Number.isInteger(error.statusCode) ? error.statusCode : 500;
    if (status >= 500) console.error("SocialMEI finance API:", error);
    return send(res, status, { error: status >= 500 ? "internal_error" : "invalid_request", detail: status >= 500 ? "Não foi possível processar a operação financeira." : error.message });
  }
}
