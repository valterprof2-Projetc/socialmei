import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import argon2 from "argon2";
import { getPostgresPool, query } from "../../lib/postgres.js";

const COOKIE = "socialmei_session";
const SESSION_DAYS = 30;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const COMMON_PASSWORDS = new Set([
  "12345678", "123456789", "1234567890", "01234567", "87654321",
  "password", "password1", "password123", "qwertyui", "qwerty123",
  "senha123", "senha1234", "admin123", "admin1234", "iloveyou", "abc12345",
]);

function fail(status, message, code = "invalid_request") {
  const error = new Error(message);
  error.statusCode = status;
  error.code = code;
  throw error;
}
function send(res, status, body) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Pragma", "no-cache");
  res.setHeader("Vary", "Cookie");
  return res.status(status).json(body);
}
function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}
function sessionSecret() {
  const value = process.env.SOCIALMEI_SESSION_SECRET;
  if (!value || value.length < 32) fail(503, "Autenticação temporariamente indisponível.", "configuration_error");
  return value;
}
function csrfFor(token, userId, workspaceId) {
  return createHmac("sha256", sessionSecret())
    .update(`${token}:${userId}:${workspaceId}`)
    .digest("hex");
}
function cookieValue(req, name) {
  const header = String(req.headers.cookie || "");
  for (const part of header.split(";")) {
    const index = part.indexOf("=");
    if (index < 0) continue;
    if (part.slice(0, index).trim() === name) return decodeURIComponent(part.slice(index + 1).trim());
  }
  return "";
}
function setSessionCookie(req, res, token) {
  const forwarded = String(req.headers["x-forwarded-proto"] || "");
  const secure = forwarded === "https" || process.env.VERCEL === "1";
  const maxAge = SESSION_DAYS * 24 * 60 * 60;
  res.setHeader("Set-Cookie", `${COOKIE}=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${maxAge}${secure ? "; Secure" : ""}`);
}
function clearSessionCookie(req, res) {
  const secure = String(req.headers["x-forwarded-proto"] || "") === "https" || process.env.VERCEL === "1";
  res.setHeader("Set-Cookie", `${COOKIE}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0${secure ? "; Secure" : ""}`);
}
function sameOrigin(req) {
  const origin = req.headers.origin;
  if (!origin) return;
  let parsed;
  try { parsed = new URL(origin); } catch { fail(403, "Origem da solicitação inválida.", "origin_rejected"); }
  const host = String(req.headers.host || "").toLowerCase();
  if (!host || parsed.host.toLowerCase() !== host) fail(403, "Origem da solicitação não autorizada.", "origin_rejected");
}
function bodyOf(req) {
  if (!req.body || typeof req.body !== "object" || Array.isArray(req.body)) return {};
  return req.body;
}
function routeOf(req) {
  const raw = req.query?.path;
  const parts = Array.isArray(raw) ? raw : raw ? [raw] : [];
  return "/" + parts.map((part) => String(part)).join("/").replace(/^\/+|\/+$/g, "");
}
function safeId(value, label = "Identificador") {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 1) fail(422, `${label} inválido.`);
  return n;
}
function publicIdentity(session, token) {
  return {
    usuario: {
      id: Number(session.user_id),
      nome: session.user_name,
      email: session.email,
      telefone: session.telefone || "",
    },
    negocio: {
      id: Number(session.workspace_id),
      slug: session.slug,
      nome: session.workspace_name,
      configuracao: session.configuracao || {},
      papel: session.role,
    },
    csrf_token: csrfFor(token, session.user_id, session.workspace_id),
  };
}
async function resolveSession(req) {
  const token = cookieValue(req, COOKIE);
  if (!/^[A-Za-z0-9_-]{40,100}$/.test(token)) return null;
  const tokenHash = sha256(token);
  const result = await query(
    `SELECT s.token_hash, s.user_id, s.workspace_id,
            u.email, u.nome AS user_name, u.telefone,
            w.slug, w.nome AS workspace_name, w.configuracao,
            m.role, c.administrador_plataforma
       FROM socialmei.auth_sessoes s
       JOIN socialmei.users u ON u.id = s.user_id
       JOIN socialmei.workspaces w ON w.id = s.workspace_id
       JOIN socialmei.workspace_members m
         ON m.user_id = s.user_id AND m.workspace_id = s.workspace_id
       JOIN socialmei.auth_credenciais c ON c.user_id = s.user_id AND c.ativo = true
      WHERE s.token_hash = $1 AND s.revogada_em IS NULL AND s.expira_em > now()
      LIMIT 1`,
    [tokenHash],
  );
  if (!result.rows.length) return null;
  return { ...result.rows[0], token, tokenHash };
}
function requireCsrf(req, session) {
  const identity = String(req.headers["x-socialmei-identity"] || "");
  if (identity !== `${session.user_id}:${session.workspace_id}`)
    fail(403, "A identidade da sessão não confere. Atualize a página.", "identity_mismatch");
  const supplied = String(req.headers["x-socialmei-csrf"] || "");
  const expected = csrfFor(session.token, session.user_id, session.workspace_id);
  const a = Buffer.from(supplied);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b))
    fail(403, "A proteção da sessão expirou. Atualize a página.", "csrf_rejected");
}
async function createSession(client, userId, workspaceId) {
  const token = randomBytes(32).toString("base64url");
  const expires = new Date(Date.now() + SESSION_DAYS * 86400000);
  await client.query(
    `INSERT INTO socialmei.auth_sessoes (token_hash, user_id, workspace_id, expira_em)
     VALUES ($1, $2, $3, $4)`,
    [sha256(token), userId, workspaceId, expires],
  );
  return token;
}
async function withTransaction(work) {
  const client = await getPostgresPool().connect();
  try {
    await client.query("BEGIN");
    const value = await work(client);
    await client.query("COMMIT");
    return value;
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}
function validatePassword(password) {
  if (typeof password !== "string") fail(422, "Informe uma senha.");
  const length = Array.from(password).length;
  if (length < 8 || length > 128) fail(422, "Use uma senha de 8 a 128 caracteres.");
  if (COMMON_PASSWORDS.has(password.toLowerCase()) || new Set(password).size === 1)
    fail(422, "Esta senha é muito comum. Escolha uma senha menos previsível.");
}
function slugFrom(name) {
  const base = String(name).normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 48) || "negocio";
  return `${base}-${randomBytes(4).toString("hex")}`;
}
async function loadSessionIdentity(tokenHash) {
  const r = await query(
    `SELECT s.user_id, s.workspace_id, u.email, u.nome AS user_name, u.telefone,
            w.slug, w.nome AS workspace_name, w.configuracao, m.role
       FROM socialmei.auth_sessoes s
       JOIN socialmei.users u ON u.id=s.user_id
       JOIN socialmei.workspaces w ON w.id=s.workspace_id
       JOIN socialmei.workspace_members m ON m.user_id=s.user_id AND m.workspace_id=s.workspace_id
      WHERE s.token_hash=$1 AND s.revogada_em IS NULL AND s.expira_em>now() LIMIT 1`,
    [tokenHash],
  );
  return r.rows[0] || null;
}
async function registration(req, res) {
  const mode = process.env.SOCIALMEI_REGISTRATION_MODE === "open" ? "open" : "invite";
  return send(res, 200, { mode });
}
async function register(req, res) {
  sessionSecret();
  const input = bodyOf(req);
  const name = String(input.nome || "").trim();
  const email = String(input.email || "").trim().toLowerCase();
  const phone = String(input.telefone || "").trim();
  const password = input.senha;
  if (name.length < 2 || name.length > 160) fail(422, "Informe seu nome completo.");
  if (!EMAIL_RE.test(email) || email.length > 255) fail(422, "Informe um e-mail válido.");
  if (phone.length > 40) fail(422, "Telefone inválido.");
  validatePassword(password);
  const mode = process.env.SOCIALMEI_REGISTRATION_MODE === "open" ? "open" : "invite";
  const invitation = String(input.convite || "").trim();
  if (mode !== "open" && !/^[a-f0-9]{64}$/i.test(invitation))
    fail(403, "O cadastro deste ambiente exige convite. Peça o código ao administrador.", "invite_required");
  const passwordHash = await argon2.hash(password, { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 });
  const result = await withTransaction(async (client) => {
    if (mode !== "open") {
      const invite = await client.query(
        `SELECT token_hash, email FROM socialmei.auth_convites
          WHERE token_hash=$1 AND lower(email)=lower($2) AND usado_em IS NULL
            AND revogado_em IS NULL AND expira_em>now() FOR UPDATE`,
        [sha256(invitation), email],
      );
      if (!invite.rows.length) fail(403, "Convite inválido, expirado ou destinado a outro e-mail.", "invite_invalid");
    }
    const existing = await client.query("SELECT id FROM socialmei.users WHERE lower(btrim(email))=$1 LIMIT 1", [email]);
    if (existing.rows.length) fail(409, "Já existe uma conta com este e-mail.", "email_exists");
    const user = await client.query(
      "INSERT INTO socialmei.users (email, nome, telefone) VALUES ($1,$2,$3) RETURNING id",
      [email, name, phone || null],
    );
    const userId = Number(user.rows[0].id);
    const workspaceName = `Negócio de ${name.split(/\\s+/)[0]}`.slice(0, 160);
    const workspace = await client.query(
      "INSERT INTO socialmei.workspaces (slug,nome,configuracao) VALUES ($1,$2,'{}'::jsonb) RETURNING id,slug,nome,configuracao",
      [slugFrom(name), workspaceName],
    );
    const workspaceId = Number(workspace.rows[0].id);
    await client.query(
      "INSERT INTO socialmei.workspace_members (workspace_id,user_id,role) VALUES ($1,$2,'owner')",
      [workspaceId, userId],
    );
    await client.query(
      "INSERT INTO socialmei.auth_credenciais (user_id,senha_hash,ativo) VALUES ($1,$2,true)",
      [userId, passwordHash],
    );
    await client.query(
      "INSERT INTO socialmei.auth_preferences (workspace_id,user_id,schema_version,revision,preferences) VALUES ($1,$2,1,1,'{\"theme\":\"auto\"}'::jsonb)",
      [workspaceId, userId],
    );
    const defaultProfile = {
      version: 1, businessName: workspaceName, segment: "other", activity: "",
      offers: [], services: [], productCategories: [],
      capabilities: {}, modules: [], ignoredSuggestions: [], completed: false,
    };
    await client.query(
      "INSERT INTO socialmei.workspace_profiles (workspace_id,schema_version,revision,profile) VALUES ($1,1,1,$2::jsonb)",
      [workspaceId, JSON.stringify(defaultProfile)],
    );
    if (mode !== "open") {
      await client.query(
        "UPDATE socialmei.auth_convites SET usado_em=now(), user_id=$2 WHERE token_hash=$1",
        [sha256(invitation), userId],
      );
    }
    const token = await createSession(client, userId, workspaceId);
    return { token, userId, workspaceId };
  });
  setSessionCookie(req, res, result.token);
  const identity = await loadSessionIdentity(sha256(result.token));
  return send(res, 201, publicIdentity(identity, result.token));
}
async function consumeLoginAttempt(email, req) {
  const forwarded = String(req.headers["x-forwarded-for"] || "").split(",")[0].trim();
  const ip = forwarded || String(req.headers["x-real-ip"] || "unknown");
  const key = sha256(`login:${email}:${ip}`);
  const result = await query(
    `INSERT INTO socialmei.auth_limites AS limite (chave,inicio,tentativas)
     VALUES ($1,now(),1)
     ON CONFLICT (chave) DO UPDATE SET
       inicio=CASE WHEN limite.inicio < now()-interval '15 minutes'
                   THEN now() ELSE limite.inicio END,
       tentativas=CASE WHEN limite.inicio < now()-interval '15 minutes'
                       THEN 1 ELSE limite.tentativas+1 END
     RETURNING tentativas`,
    [key],
  );
  if (Number(result.rows[0]?.tentativas || 0) > 10)
    fail(429, "Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.", "rate_limited");
  return key;
}
async function login(req, res) {
  sessionSecret();
  const input = bodyOf(req);
  const email = String(input.email || "").trim().toLowerCase();
  const password = input.senha;
  if (!EMAIL_RE.test(email) || typeof password !== "string" || password.length > 128)
    fail(401, "E-mail ou senha inválidos.", "invalid_credentials");
  const attemptKey = await consumeLoginAttempt(email, req);
  const result = await query(
    `SELECT u.id, c.senha_hash, c.ativo
       FROM socialmei.users u
       JOIN socialmei.auth_credenciais c ON c.user_id=u.id
      WHERE lower(btrim(u.email))=$1 LIMIT 1`,
    [email],
  );
  if (!result.rows.length || !result.rows[0].ativo)
    fail(401, "E-mail ou senha inválidos.", "invalid_credentials");
  const valid = await argon2.verify(result.rows[0].senha_hash, password).catch(() => false);
  if (!valid) fail(401, "E-mail ou senha inválidos.", "invalid_credentials");
  await query("DELETE FROM socialmei.auth_limites WHERE chave=$1", [attemptKey]);
  const userId = Number(result.rows[0].id);
  const memberships = await query(
    `SELECT workspace_id FROM socialmei.workspace_members
      WHERE user_id=$1 ORDER BY criado_em ASC, workspace_id ASC LIMIT 1`,
    [userId],
  );
  if (!memberships.rows.length) fail(403, "Esta conta não possui um negócio ativo.", "workspace_missing");
  const workspaceId = Number(memberships.rows[0].workspace_id);
  const token = await withTransaction((client) => createSession(client, userId, workspaceId));
  setSessionCookie(req, res, token);
  const identity = await loadSessionIdentity(sha256(token));
  return send(res, 200, publicIdentity(identity, token));
}
async function getWorkspaceProfile(session) {
  const r = await query(
    "SELECT schema_version,revision,profile FROM socialmei.workspace_profiles WHERE workspace_id=$1",
    [session.workspace_id],
  );
  if (!r.rows.length) return sendProfileMissing();
  return { schema_version: r.rows[0].schema_version, revision: Number(r.rows[0].revision), profile: r.rows[0].profile };
}
function sendProfileMissing() {
  fail(404, "Perfil do negócio ainda não foi criado.", "profile_missing");
}
function validDate(value, label) {
  if (value == null || value === "") return null;
  if (typeof value !== "string" || !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(value))
    fail(422, `${label} deve estar no formato AAAA-MM-DD.`);
  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0,10) !== value)
    fail(422, `${label} inválida.`);
  return value;
}
function numeric(value, label, { min = 0, nullable = false } = {}) {
  if (value == null && nullable) return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < min) fail(422, `${label} inválido.`);
  return n;
}
function version(value) {
  if (!Number.isSafeInteger(value) || value < 1) fail(422, "expected_version inválida.");
  return value;
}
function customerRow(row) {
  return {
    ...row,
    id: Number(row.id),
    versao: Number(row.versao),
    total: Number(row.total || 0),
    pendente: Number(row.pendente || 0),
  };
}
function productRow(row) {
  return {
    ...row,
    id: Number(row.id),
    versao: Number(row.versao),
    preco: Number(row.preco),
    custo: Number(row.custo || 0),
    estoque: row.estoque == null ? null : Number(row.estoque),
    minimo: row.minimo == null ? null : Number(row.minimo),
    duracao_minutos: row.duracao_minutos == null ? null : Number(row.duracao_minutos),
  };
}
const CUSTOMER_COLUMNS = "id,nome,telefone,email,status,observacao,tags,total,pendente,versao,criado_em,atualizado_em";
const PRODUCT_COLUMNS = "id,nome,tipo,preco,custo,estoque,minimo,status,versao,criado_em,atualizado_em,duracao_minutos,categoria,descricao";

async function customers(req, res, session, route, method) {
  if (route === "/clientes" && method === "GET") {
    const r = await query(
      `SELECT ${CUSTOMER_COLUMNS} FROM socialmei.crm_clientes
        WHERE workspace_id=$1 ORDER BY lower(nome),id LIMIT 500`,
      [session.workspace_id],
    );
    return send(res, 200, r.rows.map(customerRow));
  }
  if (route === "/clientes" && method === "POST") {
    const input = bodyOf(req);
    const nome = String(input.nome || "").trim();
    const email = input.email == null ? null : String(input.email).trim().toLowerCase();
    const telefone = input.telefone == null ? null : String(input.telefone).trim();
    const observacao = input.observacao == null ? "" : String(input.observacao).trim();
    if (nome.length < 2 || nome.length > 160) fail(422, "Informe o nome do cliente.");
    if (email && (email.length > 255 || !EMAIL_RE.test(email))) fail(422, "E-mail do cliente inválido.");
    if (telefone && telefone.length > 40) fail(422, "Telefone do cliente inválido.");
    if (observacao.length > 10000) fail(422, "Observação muito longa.");
    const r = await query(
      `INSERT INTO socialmei.crm_clientes
        (workspace_id,nome,email,telefone,observacao)
       VALUES ($1,$2,$3,$4,$5) RETURNING ${CUSTOMER_COLUMNS}`,
      [session.workspace_id,nome,email || null,telefone || null,observacao],
    );
    return send(res, 201, customerRow(r.rows[0]));
  }
  const match = route.startsWith("/clientes/") ? [null, route.slice("/clientes/".length)] : null;
  if (match && /^[1-9][0-9]*$/.test(match[1]) && method === "PATCH") {
    const id = safeId(match[1], "Cliente");
    const input = bodyOf(req);
    const expected = version(input.expected_version);
    const fields = [];
    const values = [id,session.workspace_id,expected];
    const add = (column, value) => { values.push(value); fields.push(`${column}=$${values.length}`); };
    if (input.nome !== undefined) {
      const value = String(input.nome).trim();
      if (value.length < 2 || value.length > 160) fail(422, "Informe o nome do cliente.");
      add("nome",value);
    }
    if (input.email !== undefined) {
      const value = input.email == null ? null : String(input.email).trim().toLowerCase();
      if (value && (value.length > 255 || !EMAIL_RE.test(value))) fail(422, "E-mail do cliente inválido.");
      add("email",value || null);
    }
    if (input.telefone !== undefined) {
      const value = input.telefone == null ? null : String(input.telefone).trim();
      if (value && value.length > 40) fail(422, "Telefone do cliente inválido.");
      add("telefone",value || null);
    }
    if (input.observacao !== undefined) {
      const value = input.observacao == null ? "" : String(input.observacao);
      if (value.length > 10000) fail(422, "Observação muito longa.");
      add("observacao",value);
    }
    if (!fields.length) fail(422, "Nenhum campo para atualizar.");
    const r = await query(
      `UPDATE socialmei.crm_clientes SET ${fields.join(",")},versao=versao+1,atualizado_em=now()
        WHERE id=$1 AND workspace_id=$2 AND versao=$3
        RETURNING ${CUSTOMER_COLUMNS}`,
      values,
    );
    if (!r.rows.length) fail(409, "O cliente foi alterado ou não existe neste negócio. Atualize a lista.", "revision_conflict");
    return send(res, 200, customerRow(r.rows[0]));
  }
  return null;
}

async function products(req, res, session, route, method) {
  if (route === "/produtos" && method === "GET") {
    const r = await query(
      `SELECT ${PRODUCT_COLUMNS} FROM socialmei.crm_produtos
        WHERE workspace_id=$1 ORDER BY lower(nome),id LIMIT 500`,
      [session.workspace_id],
    );
    return send(res, 200, r.rows.map(productRow));
  }
  if (route === "/produtos" && method === "POST") {
    const input = bodyOf(req);
    const nome = String(input.nome || "").trim();
    const tipo = input.tipo;
    if (nome.length < 2 || nome.length > 160) fail(422, "Informe o nome do produto ou serviço.");
    if (!["Produto","Serviço"].includes(tipo)) fail(422, "Tipo de cadastro inválido.");
    const preco = numeric(input.preco,"Preço");
    const custo = numeric(input.custo ?? 0,"Custo");
    const status = input.status || "Ativo";
    if (!["Ativo","Inativo"].includes(status)) fail(422, "Status inválido.");
    const categoria = String(input.categoria || "").trim();
    const descricao = String(input.descricao || "").trim();
    if (categoria.length > 80 || descricao.length > 2000) fail(422, "Categoria ou descrição muito longa.");
    let estoque = null, minimo = null, duracao = null;
    if (tipo === "Produto") {
      estoque = numeric(input.estoque,"Estoque");
      minimo = numeric(input.minimo,"Estoque mínimo");
      if (!Number.isSafeInteger(estoque) || !Number.isSafeInteger(minimo)) fail(422, "Estoque e estoque mínimo devem ser inteiros.");
    } else if (input.duracao_minutos != null) {
      duracao = numeric(input.duracao_minutos,"Duração");
      if (!Number.isInteger(duracao) || duracao < 1 || duracao > 1440) fail(422, "Duração deve ser de 1 a 1440 minutos.");
    }
    const r = await query(
      `INSERT INTO socialmei.crm_produtos
        (workspace_id,nome,tipo,preco,custo,estoque,minimo,status,duracao_minutos,categoria,descricao)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING ${PRODUCT_COLUMNS}`,
      [session.workspace_id,nome,tipo,preco,custo,estoque,minimo,status,duracao,categoria,descricao],
    );
    return send(res, 201, productRow(r.rows[0]));
  }
  const match = route.startsWith("/produtos/") ? [null, route.slice("/produtos/".length)] : null;
  if (match && /^[1-9][0-9]*$/.test(match[1]) && method === "PATCH") {
    const id = safeId(match[1],"Produto");
    const input = bodyOf(req);
    const expected = version(input.expected_version);
    const current = await query(
      `SELECT ${PRODUCT_COLUMNS} FROM socialmei.crm_produtos
        WHERE id=$1 AND workspace_id=$2 LIMIT 1`,
      [id,session.workspace_id],
    );
    if (!current.rows.length) fail(404, "Produto não encontrado neste negócio.");
    if (Number(current.rows[0].versao) !== expected) fail(409, "O produto foi alterado. Atualize antes de salvar.", "revision_conflict");
    const old = current.rows[0];
    const next = {
      nome: input.nome === undefined ? old.nome : String(input.nome).trim(),
      tipo: input.tipo === undefined ? old.tipo : input.tipo,
      preco: input.preco === undefined ? Number(old.preco) : numeric(input.preco,"Preço"),
      custo: input.custo === undefined ? Number(old.custo) : numeric(input.custo,"Custo"),
      status: input.status === undefined ? old.status : input.status,
      categoria: input.categoria === undefined ? old.categoria : String(input.categoria).trim(),
      descricao: input.descricao === undefined ? old.descricao : String(input.descricao).trim(),
      estoque: input.estoque === undefined ? old.estoque : input.estoque,
      minimo: input.minimo === undefined ? old.minimo : input.minimo,
      duracao_minutos: input.duracao_minutos === undefined ? old.duracao_minutos : input.duracao_minutos,
    };
    if (next.nome.length < 2 || next.nome.length > 160) fail(422, "Nome inválido.");
    if (!["Produto","Serviço"].includes(next.tipo)) fail(422, "Tipo inválido.");
    if (!["Ativo","Inativo"].includes(next.status)) fail(422, "Status inválido.");
    if (next.categoria.length > 80 || next.descricao.length > 2000) fail(422, "Categoria ou descrição muito longa.");
    if (next.tipo === "Produto") {
      next.estoque = numeric(next.estoque,"Estoque");
      next.minimo = numeric(next.minimo,"Estoque mínimo");
      if (!Number.isSafeInteger(next.estoque) || !Number.isSafeInteger(next.minimo)) fail(422, "Estoque e estoque mínimo devem ser inteiros.");
      next.duracao_minutos = null;
    } else {
      next.estoque = null;
      next.minimo = null;
      next.duracao_minutos = next.duracao_minutos == null ? null : numeric(next.duracao_minutos,"Duração");
      if (next.duracao_minutos != null && (!Number.isInteger(next.duracao_minutos) || next.duracao_minutos < 1 || next.duracao_minutos > 1440)) fail(422, "Duração deve ser de 1 a 1440 minutos.");
    }
    const r = await query(
      `UPDATE socialmei.crm_produtos
          SET nome=$4,tipo=$5,preco=$6,custo=$7,estoque=$8,minimo=$9,status=$10,
              duracao_minutos=$11,categoria=$12,descricao=$13,versao=versao+1,atualizado_em=now()
        WHERE id=$1 AND workspace_id=$2 AND versao=$3
        RETURNING ${PRODUCT_COLUMNS}`,
      [id,session.workspace_id,expected,next.nome,next.tipo,next.preco,next.custo,next.estoque,next.minimo,next.status,next.duracao_minutos,next.categoria,next.descricao],
    );
    if (!r.rows.length) fail(409, "O produto foi alterado. Atualize antes de salvar.", "revision_conflict");
    return send(res, 200, productRow(r.rows[0]));
  }
  return null;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function operationId(value) {
  if (typeof value !== "string" || !UUID_RE.test(value)) fail(422, "operation_id deve ser um UUID válido.");
  return value.toLowerCase();
}
async function idempotent(client, table, workspaceId, opId, fingerprint, work) {
  if (!["crm_venda_operacoes","crm_financeiro_operacoes"].includes(table)) throw new Error("Invalid operation table.");
  await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1,0))", [`${workspaceId}:${opId}`]);
  const previous = await client.query(
    `SELECT fingerprint,resposta FROM socialmei.${table} WHERE workspace_id=$1 AND operation_id=$2`,
    [workspaceId,opId],
  );
  if (previous.rows.length) {
    if (previous.rows[0].fingerprint !== fingerprint)
      fail(409, "Este identificador de operação já foi usado com outros dados.", "operation_conflict");
    return previous.rows[0].resposta;
  }
  const response = await work();
  await client.query(
    `INSERT INTO socialmei.${table} (workspace_id,operation_id,fingerprint,resposta)
     VALUES ($1,$2,$3,$4::jsonb)`,
    [workspaceId,opId,fingerprint,JSON.stringify(response)],
  );
  return response;
}
function saleRow(row) {
  return {
    ...row,
    id: Number(row.id),
    cliente_id: row.cliente_id == null ? null : Number(row.cliente_id),
    produto_id: row.produto_id == null ? null : Number(row.produto_id),
    quantidade: Number(row.quantidade),
    preco: row.preco == null ? null : Number(row.preco),
    desconto: Number(row.desconto || 0),
    valor: Number(row.valor),
    versao: Number(row.versao),
  };
}
function financeRow(row) {
  return {
    ...row,
    id: Number(row.id),
    cliente_id: row.cliente_id == null ? null : Number(row.cliente_id),
    valor: Number(row.valor),
    versao: Number(row.versao),
  };
}
const SALE_COLUMNS = "id,workspace_id,cliente_id,produto_id,cliente,item,tipo_item,data,quantidade,preco,desconto,valor,pagamento,observacao,status,estoque_aplicado,importada,excluida,versao,criado_em,atualizado_em";
const FINANCE_COLUMNS = "id,workspace_id,cliente_id,descricao,pessoa,tipo,valor,vencimento,status,data_pagamento,importada,excluida,versao,criado_em,atualizado_em";

async function sales(req, res, session, route, method) {
  if (route === "/vendas" && method === "GET") {
    const r = await query(
      `SELECT ${SALE_COLUMNS} FROM socialmei.crm_vendas
        WHERE workspace_id=$1 AND excluida=false ORDER BY data DESC,id DESC LIMIT 500`,
      [session.workspace_id],
    );
    return send(res, 200, r.rows.map(saleRow));
  }
  if (route === "/vendas" && method === "POST") {
    const input = bodyOf(req);
    const opId = operationId(input.operation_id);
    const clienteId = input.cliente_id == null || input.cliente_id === "" ? null : safeId(input.cliente_id,"Cliente");
    const produtoId = safeId(input.produto_id,"Produto ou serviço");
    const quantidade = numeric(input.quantidade,"Quantidade");
    if (!Number.isSafeInteger(quantidade) || quantidade < 1) fail(422, "Quantidade deve ser um inteiro positivo.");
    const date = validDate(input.data,"Data da venda");
    if (!date) fail(422, "Data da venda é obrigatória.");
    const payment = String(input.pagamento || "Não informado").trim().slice(0,40);
    if (!payment) fail(422, "Informe a forma de pagamento.");
    const desconto = numeric(input.desconto ?? 0,"Desconto");
    const fingerprint = sha256(JSON.stringify({
      cliente_id:clienteId,produto_id:produtoId,quantidade,preco:input.preco ?? null,
      desconto,data:date,pagamento:payment,status:input.status || "Pendente",
    }));
    const result = await withTransaction(async (client) => idempotent(
      client,"crm_venda_operacoes",session.workspace_id,opId,fingerprint,async () => {
        const product = await client.query(
          "SELECT id,nome,tipo,preco,estoque,status FROM socialmei.crm_produtos WHERE id=$1 AND workspace_id=$2 FOR UPDATE",
          [produtoId,session.workspace_id],
        );
        if (!product.rows.length || product.rows[0].status !== "Ativo") fail(404,"Produto ou serviço indisponível neste negócio.");
        const p = product.rows[0];
        const unitPrice = input.preco == null ? Number(p.preco) : numeric(input.preco,"Preço");
        const value = Math.max(0, Number((unitPrice * quantidade - desconto).toFixed(2)));
        if (desconto > unitPrice * quantidade) fail(422,"O desconto não pode superar o valor da venda.");
        let customerName = "Consumidor final";
        if (clienteId != null) {
          const customer = await client.query(
            "SELECT nome FROM socialmei.crm_clientes WHERE id=$1 AND workspace_id=$2",
            [clienteId,session.workspace_id],
          );
          if (!customer.rows.length) fail(404,"Cliente não encontrado neste negócio.");
          customerName = customer.rows[0].nome;
        }
        const status = input.status || "Pendente";
        if (!["Pendente","Rascunho"].includes(status)) fail(422,"Status inicial de venda inválido.");
        const created = await client.query(
          `INSERT INTO socialmei.crm_vendas
            (workspace_id,cliente_id,produto_id,cliente,item,tipo_item,data,quantidade,preco,desconto,valor,pagamento,observacao,status)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
           RETURNING ${SALE_COLUMNS}`,
          [session.workspace_id,clienteId,produtoId,customerName,p.nome,p.tipo,date,quantidade,unitPrice,desconto,value,payment,String(input.observacao || "").slice(0,5000),status],
        );
        return saleRow(created.rows[0]);
      },
    ));
    return send(res, 201, result);
  }
  const match = /^\/vendas\/([1-9][0-9]*)\/pagar$/.exec(route);
  if (match && method === "POST") {
    const input = bodyOf(req);
    const opId = operationId(input.operation_id);
    const id = safeId(match[1],"Venda");
    const expected = version(input.expected_version);
    const fingerprint = sha256(JSON.stringify({id,expected,action:"pay"}));
    const result = await withTransaction(async (client) => idempotent(
      client,"crm_venda_operacoes",session.workspace_id,opId,fingerprint,async () => {
        const sale = await client.query(
          `SELECT ${SALE_COLUMNS} FROM socialmei.crm_vendas
            WHERE id=$1 AND workspace_id=$2 FOR UPDATE`,
          [id,session.workspace_id],
        );
        if (!sale.rows.length || sale.rows[0].excluida) fail(404,"Venda não encontrada neste negócio.");
        const row = sale.rows[0];
        if (Number(row.versao) !== expected) fail(409,"A venda foi alterada. Atualize antes de confirmar o pagamento.","revision_conflict");
        if (row.status === "Pago") return saleRow(row);
        if (row.status !== "Pendente") fail(409,"Somente vendas pendentes podem ser pagas.");
        if (row.tipo_item === "Produto" && !row.estoque_aplicado) {
          const product = await client.query(
            "SELECT estoque FROM socialmei.crm_produtos WHERE id=$1 AND workspace_id=$2 FOR UPDATE",
            [row.produto_id,session.workspace_id],
          );
          if (!product.rows.length) fail(409,"O produto associado não está disponível.");
          if (Number(product.rows[0].estoque) < Number(row.quantidade)) fail(409,"Estoque insuficiente para confirmar esta venda.");
          await client.query(
            "UPDATE socialmei.crm_produtos SET estoque=estoque-$3,versao=versao+1,atualizado_em=now() WHERE id=$1 AND workspace_id=$2",
            [row.produto_id,session.workspace_id,row.quantidade],
          );
        }
        const updated = await client.query(
          `UPDATE socialmei.crm_vendas
              SET status='Pago',estoque_aplicado=($4::boolean),versao=versao+1,atualizado_em=now()
            WHERE id=$1 AND workspace_id=$2 AND versao=$3
            RETURNING ${SALE_COLUMNS}`,
          [id,session.workspace_id,expected,row.tipo_item === "Produto"],
        );
        if (!updated.rows.length) fail(409,"A venda mudou durante a confirmação.","revision_conflict");
        return saleRow(updated.rows[0]);
      },
    ));
    return send(res, 200, result);
  }
  return null;
}

async function finance(req, res, session, route, method) {
  if (route === "/financeiro" && method === "GET") {
    const r = await query(
      `SELECT ${FINANCE_COLUMNS} FROM socialmei.crm_financeiro
        WHERE workspace_id=$1 AND excluida=false ORDER BY vencimento DESC,id DESC LIMIT 500`,
      [session.workspace_id],
    );
    return send(res, 200, r.rows.map(financeRow));
  }
  if (route === "/financeiro" && method === "POST") {
    const input = bodyOf(req);
    const opId = operationId(input.operation_id);
    const descricao = String(input.descricao || "").trim();
    const tipo = input.tipo;
    const valor = numeric(input.valor,"Valor");
    const vencimento = validDate(input.vencimento,"Vencimento");
    const status = input.status || "aberto";
    if (descricao.length < 2 || descricao.length > 240) fail(422,"Informe uma descrição.");
    if (!["receita","despesa"].includes(tipo)) fail(422,"Tipo financeiro inválido.");
    if (!vencimento) fail(422,"Vencimento é obrigatório.");
    if (!["aberto","atrasado","pago"].includes(status)) fail(422,"Status financeiro inválido.");
    const dataPagamento = status === "pago" ? validDate(input.data_pagamento || vencimento,"Data do pagamento") : null;
    const clienteId = input.cliente_id == null || input.cliente_id === "" ? null : safeId(input.cliente_id,"Cliente");
    const pessoa = String(input.pessoa || "").trim().slice(0,160);
    const fingerprint = sha256(JSON.stringify({descricao,tipo,valor,vencimento,status,dataPagamento,clienteId,pessoa}));
    const result = await withTransaction(async (client) => idempotent(
      client,"crm_financeiro_operacoes",session.workspace_id,opId,fingerprint,async () => {
        if (clienteId != null) {
          const customer = await client.query("SELECT nome FROM socialmei.crm_clientes WHERE id=$1 AND workspace_id=$2",[clienteId,session.workspace_id]);
          if (!customer.rows.length) fail(404,"Cliente não encontrado neste negócio.");
        }
        const r = await client.query(
          `INSERT INTO socialmei.crm_financeiro
            (workspace_id,cliente_id,descricao,pessoa,tipo,valor,vencimento,status,data_pagamento)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING ${FINANCE_COLUMNS}`,
          [session.workspace_id,clienteId,descricao,pessoa,tipo,valor,vencimento,status,dataPagamento],
        );
        return financeRow(r.rows[0]);
      },
    ));
    return send(res, 201, result);
  }
  const match = /^\/financeiro\/([1-9][0-9]*)\/excluir$/.exec(route);
  if (match && method === "POST") {
    const input = bodyOf(req);
    const opId = operationId(input.operation_id);
    const id = safeId(match[1],"Lançamento financeiro");
    const expected = version(input.expected_version);
    const fingerprint = sha256(JSON.stringify({id,expected,action:"exclude"}));
    const result = await withTransaction(async (client) => idempotent(
      client,"crm_financeiro_operacoes",session.workspace_id,opId,fingerprint,async () => {
        const r = await client.query(
          `UPDATE socialmei.crm_financeiro
              SET excluida=true,versao=versao+1,atualizado_em=now()
            WHERE id=$1 AND workspace_id=$2 AND versao=$3 AND excluida=false
            RETURNING ${FINANCE_COLUMNS}`,
          [id,session.workspace_id,expected],
        );
        if (!r.rows.length) fail(409,"O lançamento foi alterado ou já foi excluído. Atualize antes de continuar.","revision_conflict");
        return financeRow(r.rows[0]);
      },
    ));
    return send(res, 200, result);
  }
  return null;
}


const AGENDA_UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const APPOINTMENT_COLUMNS = "workspace_id,id,cliente_id,servico_id,resource_id,client_name,service_name,duration_minutes,price,scheduled_for,ends_at,notes,status,revision,creation_fingerprint,created_at,updated_at";
const REMINDER_COLUMNS = "workspace_id,id,title,scheduled_for,notes,cliente_id,status,revision,creation_fingerprint,created_at,updated_at";
function agendaUuid(value, label = "Identificador") {
  if (typeof value !== "string" || !AGENDA_UUID_RE.test(value)) fail(422, label + " deve ser um UUID válido.");
  return value.toLowerCase();
}
function agendaInstant(value, label = "Data e horário") {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,3})?)?(?:Z|[+-]\d{2}:\d{2})$/i.test(value))
    fail(422, label + " deve conter data, horário e fuso (ISO 8601).");
  const d = new Date(value);
  if (!Number.isFinite(d.getTime())) fail(422, label + " inválido.");
  return d.toISOString();
}
function agendaDateQuery(value, label) {
  if (value == null || value === "") return null;
  return validDate(String(value), label);
}
function appointmentRow(row) {
  return {
    ...row,
    id: String(row.id),
    cliente_id: row.cliente_id == null ? null : Number(row.cliente_id),
    servico_id: row.servico_id == null ? null : Number(row.servico_id),
    duration_minutes: Number(row.duration_minutes),
    price: Number(row.price),
    revision: Number(row.revision),
  };
}
function reminderRow(row) {
  return {
    ...row,
    id: String(row.id),
    cliente_id: row.cliente_id == null ? null : Number(row.cliente_id),
    revision: Number(row.revision),
  };
}
function resourceRow(row) {
  return { ...row, id: String(row.id), revision: Number(row.revision), ativo: Boolean(row.ativo) };
}
async function lockAgendaResource(client, workspaceId, resourceId) {
  await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1,0))", ["agenda:" + workspaceId + ":" + resourceId]);
}
async function hasAppointmentConflict(client, workspaceId, resourceId, start, end, excludeId = null) {
  const result = await client.query(
    \`SELECT 1 FROM socialmei.agenda_appointments
      WHERE workspace_id=$1 AND resource_id=$2 AND status='pending'
        AND scheduled_for < $4::timestamptz AND ends_at > $3::timestamptz
        AND ($5::uuid IS NULL OR id <> $5::uuid)
      LIMIT 1\`,
    [workspaceId, resourceId, start, end, excludeId],
  );
  return result.rows.length > 0;
}
async function agendaResources(req, res, session, route, method) {
  if (route === "/agenda/resources" && method === "GET") {
    const result = await query(
      "SELECT workspace_id,id,nome,ativo,revision,created_at,updated_at FROM socialmei.agenda_resources WHERE workspace_id=$1 ORDER BY lower(nome),id",
      [session.workspace_id],
    );
    return send(res, 200, { items: result.rows.map(resourceRow) });
  }
  if (route === "/agenda/resources" && method === "POST") {
    const input = bodyOf(req);
    const id = agendaUuid(input.operation_id, "operation_id");
    const nome = String(input.nome || "").trim();
    if (!nome || nome.length > 160) fail(422, "Informe um nome de até 160 caracteres.");
    const fingerprint = sha256(JSON.stringify({ nome }));
    const result = await withTransaction(async (client) => {
      await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1,0))", ["agenda-resource-create:" + session.workspace_id + ":" + id]);
      const previous = await client.query(
        "SELECT * FROM socialmei.agenda_resources WHERE workspace_id=$1 AND id=$2",
        [session.workspace_id,id],
      );
      if (previous.rows.length) {
        if (previous.rows[0].creation_fingerprint.trim() !== fingerprint)
          fail(409, "Este identificador já foi usado para outro recurso.", "operation_conflict");
        return resourceRow(previous.rows[0]);
      }
      const created = await client.query(
        "INSERT INTO socialmei.agenda_resources (workspace_id,id,nome,creation_fingerprint) VALUES ($1,$2,$3,$4) RETURNING *",
        [session.workspace_id,id,nome,fingerprint],
      );
      return resourceRow(created.rows[0]);
    });
    return send(res, 201, result);
  }
  const prefix = "/agenda/resources/";
  if (route.startsWith(prefix) && method === "PATCH") {
    const id = agendaUuid(route.slice(prefix.length), "Recurso");
    const input = bodyOf(req);
    const expected = version(input.expected_revision);
    const nome = input.nome == null ? null : String(input.nome).trim();
    if (nome !== null && (!nome || nome.length > 160)) fail(422, "Informe um nome de até 160 caracteres.");
    if (input.ativo !== undefined && typeof input.ativo !== "boolean") fail(422, "Status do recurso inválido.");
    const result = await query(
      \`UPDATE socialmei.agenda_resources
          SET nome=COALESCE($4,nome),ativo=COALESCE($5,ativo),revision=revision+1,updated_at=now()
        WHERE workspace_id=$1 AND id=$2 AND revision=$3
        RETURNING workspace_id,id,nome,ativo,revision,created_at,updated_at\`,
      [session.workspace_id,id,expected,nome,input.ativo === undefined ? null : input.ativo],
    );
    if (!result.rows.length) fail(409, "O recurso foi alterado ou não existe. Atualize a lista.", "revision_conflict");
    return send(res, 200, resourceRow(result.rows[0]));
  }
  return null;
}
async function agendaAvailability(req, res, session, route, method) {
  if (route !== "/agenda/availability" || method !== "GET") return null;
  const resourceId = agendaUuid(req.query?.resource_id, "Recurso");
  const serviceId = safeId(req.query?.servico_id, "Serviço");
  const start = agendaInstant(req.query?.scheduled_for);
  const service = await query(
    "SELECT duracao_minutos FROM socialmei.crm_produtos WHERE workspace_id=$1 AND id=$2 AND tipo='Serviço' AND status='Ativo'",
    [session.workspace_id,serviceId],
  );
  if (!service.rows.length || !service.rows[0].duracao_minutos)
    fail(404, "Serviço ativo com duração não encontrado neste negócio.");
  const resource = await query(
    "SELECT 1 FROM socialmei.agenda_resources WHERE workspace_id=$1 AND id=$2 AND ativo=true",
    [session.workspace_id,resourceId],
  );
  if (!resource.rows.length) fail(404, "Recurso ativo não encontrado neste negócio.");
  const end = new Date(new Date(start).getTime() + Number(service.rows[0].duracao_minutos) * 60000).toISOString();
  const conflict = await query(
    \`SELECT 1 FROM socialmei.agenda_appointments
      WHERE workspace_id=$1 AND resource_id=$2 AND status='pending'
        AND scheduled_for < $4::timestamptz AND ends_at > $3::timestamptz LIMIT 1\`,
    [session.workspace_id,resourceId,start,end],
  );
  return send(res, 200, { available: conflict.rows.length === 0, ends_at: end });
}
async function agendaAppointments(req, res, session, route, method) {
  if (route === "/agenda/appointments" && method === "GET") {
    const from = agendaDateQuery(req.query?.from_date, "Data inicial");
    const to = agendaDateQuery(req.query?.to_date, "Data final");
    if (from && to && from > to) fail(422, "O período da agenda está invertido.");
    const includeCancelled = String(req.query?.include_cancelled || "") === "true";
    const result = await query(
      \`SELECT \${APPOINTMENT_COLUMNS} FROM socialmei.agenda_appointments
        WHERE workspace_id=$1
          AND ($2::date IS NULL OR scheduled_for >= $2::date::timestamptz)
          AND ($3::date IS NULL OR scheduled_for < ($3::date + 1)::timestamptz)
          AND ($4::boolean OR status <> 'cancelled')
        ORDER BY scheduled_for,id LIMIT 501\`,
      [session.workspace_id,from,to,includeCancelled],
    );
    return send(res, 200, { items: result.rows.slice(0,500).map(appointmentRow), truncated: result.rows.length > 500 });
  }
  if (route === "/agenda/appointments" && method === "POST") {
    const input = bodyOf(req);
    const id = agendaUuid(input.operation_id, "operation_id");
    const clienteId = safeId(input.cliente_id, "Cliente");
    const serviceId = safeId(input.servico_id, "Serviço");
    const resourceId = agendaUuid(input.resource_id, "Recurso");
    const start = agendaInstant(input.scheduled_for);
    const notes = String(input.notes || "").trim();
    if (notes.length > 1000) fail(422, "As observações devem ter até 1000 caracteres.");
    const fingerprint = sha256(JSON.stringify({ clienteId,serviceId,resourceId,start,notes }));
    const created = await withTransaction(async (client) => {
      await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1,0))", ["agenda-appointment-create:" + session.workspace_id + ":" + id]);
      await lockAgendaResource(client,session.workspace_id,resourceId);
      const previous = await client.query(
        "SELECT * FROM socialmei.agenda_appointments WHERE workspace_id=$1 AND id=$2",
        [session.workspace_id,id],
      );
      if (previous.rows.length) {
        if (previous.rows[0].creation_fingerprint.trim() !== fingerprint)
          fail(409, "Este identificador já foi usado para outro agendamento.", "operation_conflict");
        return appointmentRow(previous.rows[0]);
      }
      const resource = await client.query(
        "SELECT id FROM socialmei.agenda_resources WHERE workspace_id=$1 AND id=$2 AND ativo=true FOR SHARE",
        [session.workspace_id,resourceId],
      );
      if (!resource.rows.length) fail(404, "Recurso ativo não encontrado neste negócio.");
      const service = await client.query(
        "SELECT id,nome,preco,duracao_minutos FROM socialmei.crm_produtos WHERE workspace_id=$1 AND id=$2 AND tipo='Serviço' AND status='Ativo' FOR SHARE",
        [session.workspace_id,serviceId],
      );
      if (!service.rows.length || !service.rows[0].duracao_minutos)
        fail(404, "Serviço ativo com duração não encontrado neste negócio.");
      const customer = await client.query(
        "SELECT nome FROM socialmei.crm_clientes WHERE workspace_id=$1 AND id=$2",
        [session.workspace_id,clienteId],
      );
      if (!customer.rows.length) fail(404, "Cliente não encontrado neste negócio.");
      const duration = Number(service.rows[0].duracao_minutos);
      const end = new Date(new Date(start).getTime() + duration * 60000).toISOString();
      if (await hasAppointmentConflict(client,session.workspace_id,resourceId,start,end))
        fail(409, "Horário ocupado para este recurso. Escolha outro horário.", "schedule_conflict");
      const result = await client.query(
        \`INSERT INTO socialmei.agenda_appointments
          (workspace_id,id,cliente_id,servico_id,resource_id,client_name,service_name,duration_minutes,price,scheduled_for,ends_at,notes,creation_fingerprint)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING \${APPOINTMENT_COLUMNS}\`,
        [session.workspace_id,id,clienteId,serviceId,resourceId,customer.rows[0].nome,service.rows[0].nome,duration,Number(service.rows[0].preco),start,end,notes,fingerprint],
      );
      const row = result.rows[0];
      await client.query(
        \`INSERT INTO socialmei.agenda_appointment_history
          (workspace_id,appointment_id,revision,scheduled_for,ends_at,status)
         VALUES ($1,$2,$3,$4,$5,$6)\`,
        [session.workspace_id,id,row.revision,row.scheduled_for,row.ends_at,row.status],
      );
      return appointmentRow(row);
    });
    return send(res, 201, created);
  }
  const historyPrefix = "/agenda/appointments/";
  if (route.startsWith(historyPrefix) && route.endsWith("/history") && method === "GET") {
    const id = agendaUuid(route.slice(historyPrefix.length,-"/history".length), "Agendamento");
    const result = await query(
      \`SELECT revision,scheduled_for,ends_at,status,recorded_at
         FROM socialmei.agenda_appointment_history
        WHERE workspace_id=$1 AND appointment_id=$2 ORDER BY revision\`,
      [session.workspace_id,id],
    );
    return send(res, 200, { items: result.rows.map((row) => ({ ...row, revision: Number(row.revision) })) });
  }
  const prefix = "/agenda/appointments/";
  if (route.startsWith(prefix) && method === "PATCH") {
    const id = agendaUuid(route.slice(prefix.length), "Agendamento");
    const input = bodyOf(req);
    const expected = version(input.expected_revision);
    const status = input.status;
    const newStart = input.scheduled_for == null ? null : agendaInstant(input.scheduled_for);
    if (status !== undefined && !["done","cancelled"].includes(status))
      fail(422, "Situação de agendamento inválida.");
    if ((status === undefined) === (newStart === null))
      fail(422, "Informe uma nova data e horário ou uma situação.");
    const result = await withTransaction(async (client) => {
      const current = await client.query(
        \`SELECT * FROM socialmei.agenda_appointments
          WHERE workspace_id=$1 AND id=$2 FOR UPDATE\`,
        [session.workspace_id,id],
      );
      if (!current.rows.length) fail(404, "Agendamento não encontrado neste negócio.");
      const row = current.rows[0];
      if (Number(row.revision) !== expected) fail(409, "O agendamento foi alterado. Atualize a agenda.", "revision_conflict");
      if (row.status !== "pending") fail(409, "Somente agendamentos pendentes podem ser alterados.");
      let start = row.scheduled_for, end = row.ends_at, nextStatus = status || row.status;
      if (newStart) {
        await lockAgendaResource(client,session.workspace_id,String(row.resource_id));
        start = newStart;
        end = new Date(new Date(start).getTime() + Number(row.duration_minutes) * 60000).toISOString();
        if (await hasAppointmentConflict(client,session.workspace_id,String(row.resource_id),start,end,id))
          fail(409, "Horário ocupado para este recurso. Escolha outro horário.", "schedule_conflict");
      }
      const updated = await client.query(
        \`UPDATE socialmei.agenda_appointments
            SET scheduled_for=$4,ends_at=$5,status=$6,revision=revision+1,updated_at=now()
          WHERE workspace_id=$1 AND id=$2 AND revision=$3
          RETURNING \${APPOINTMENT_COLUMNS}\`,
        [session.workspace_id,id,expected,start,end,nextStatus],
      );
      if (!updated.rows.length) fail(409, "O agendamento foi alterado. Atualize a agenda.", "revision_conflict");
      const saved = updated.rows[0];
      await client.query(
        \`INSERT INTO socialmei.agenda_appointment_history
          (workspace_id,appointment_id,revision,scheduled_for,ends_at,status)
         VALUES ($1,$2,$3,$4,$5,$6)\`,
        [session.workspace_id,id,saved.revision,saved.scheduled_for,saved.ends_at,saved.status],
      );
      return appointmentRow(saved);
    });
    return send(res, 200, result);
  }
  return null;
}
async function agendaReminders(req, res, session, route, method) {
  if (route === "/agenda" && method === "GET") {
    const from = agendaDateQuery(req.query?.from_date, "Data inicial");
    const to = agendaDateQuery(req.query?.to_date, "Data final");
    if (from && to && from > to) fail(422, "O período da agenda está invertido.");
    const result = await query(
      \`SELECT \${REMINDER_COLUMNS} FROM socialmei.agenda_reminders
        WHERE workspace_id=$1
          AND ($2::date IS NULL OR scheduled_for >= $2::date::timestamptz)
          AND ($3::date IS NULL OR scheduled_for < ($3::date + 1)::timestamptz)
        ORDER BY scheduled_for,id LIMIT 501\`,
      [session.workspace_id,from,to],
    );
    return send(res, 200, { items: result.rows.slice(0,500).map(reminderRow), truncated: result.rows.length > 500 });
  }
  if (route === "/agenda" && method === "POST") {
    const input = bodyOf(req);
    const id = agendaUuid(input.operation_id, "operation_id");
    const title = String(input.title || "").trim();
    const start = agendaInstant(input.scheduled_for);
    const notes = String(input.notes || "").trim();
    const clienteId = input.cliente_id == null || input.cliente_id === "" ? null : safeId(input.cliente_id,"Cliente");
    if (!title || title.length > 160 || notes.length > 1000) fail(422, "Confira título e observações do lembrete.");
    const fingerprint = sha256(JSON.stringify({ title,start,notes,clienteId }));
    const result = await withTransaction(async (client) => {
      await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1,0))", ["agenda-reminder:" + session.workspace_id + ":" + id]);
      const previous = await client.query(
        "SELECT * FROM socialmei.agenda_reminders WHERE workspace_id=$1 AND id=$2",
        [session.workspace_id,id],
      );
      if (previous.rows.length) {
        if (previous.rows[0].creation_fingerprint.trim() !== fingerprint)
          fail(409, "Este identificador já foi usado para outro lembrete.", "operation_conflict");
        return reminderRow(previous.rows[0]);
      }
      if (clienteId !== null) {
        const customer = await client.query("SELECT 1 FROM socialmei.crm_clientes WHERE workspace_id=$1 AND id=$2",[session.workspace_id,clienteId]);
        if (!customer.rows.length) fail(404,"Cliente não encontrado neste negócio.");
      }
      const created = await client.query(
        \`INSERT INTO socialmei.agenda_reminders
          (workspace_id,id,title,scheduled_for,notes,cliente_id,creation_fingerprint)
         VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING \${REMINDER_COLUMNS}\`,
        [session.workspace_id,id,title,start,notes,clienteId,fingerprint],
      );
      const row = created.rows[0];
      await client.query(
        `INSERT INTO socialmei.agenda_reminder_history
          (workspace_id,reminder_id,revision,scheduled_for,status)
         VALUES ($1,$2,$3,$4,$5)`,
        [session.workspace_id,id,row.revision,row.scheduled_for,row.status],
      );
      return reminderRow(row);
    });
    return send(res, 201, result);
  }
  const prefix = "/agenda/";
  if (route.startsWith(prefix) && method === "PATCH") {
    const id = agendaUuid(route.slice(prefix.length), "Lembrete");
    const input = bodyOf(req);
    const expected = version(input.expected_revision);
    const status = input.status;
    if (!["done","cancelled"].includes(status)) fail(422, "Situação do lembrete inválida.");
    const saved = await withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE socialmei.agenda_reminders
            SET status=$4,revision=revision+1,updated_at=now()
          WHERE workspace_id=$1 AND id=$2 AND revision=$3 AND status='pending'
          RETURNING ${REMINDER_COLUMNS}`,
        [session.workspace_id,id,expected,status],
      );
      if (!result.rows.length) fail(409, "O lembrete foi alterado ou não existe. Atualize a agenda.", "revision_conflict");
      const row = result.rows[0];
      await client.query(
        `INSERT INTO socialmei.agenda_reminder_history
          (workspace_id,reminder_id,revision,scheduled_for,status)
         VALUES ($1,$2,$3,$4,$5)`,
        [session.workspace_id,id,row.revision,row.scheduled_for,row.status],
      );
      return reminderRow(row);
    });
    return send(res, 200, saved);
  }
  return null;
}

async function handle(req, res) {
  const method = String(req.method || "GET").toUpperCase();
  if (method === "OPTIONS") return res.status(204).end();
  sameOrigin(req);
  const route = routeOf(req);
  const input = bodyOf(req);

  if (route === "/auth/registration" && method === "GET") return registration(req, res);
  if (route === "/auth/session" && method === "GET") {
    const session = await resolveSession(req);
    return send(res, 200, session ? publicIdentity(session, session.token) : null);
  }
  if (route === "/auth/register" && method === "POST") return register(req, res);
  if (route === "/auth/login" && method === "POST") return login(req, res);

  const session = await resolveSession(req);
  if (!session) {
    clearSessionCookie(req, res);
    return send(res, 401, { error: "unauthorized", detail: "Sua sessão expirou. Entre novamente." });
  }
  if (!["GET", "HEAD"].includes(method)) requireCsrf(req, session);

  const customerResponse = await customers(req, res, session, route, method);
  if (customerResponse !== null) return customerResponse;
  const productResponse = await products(req, res, session, route, method);
  if (productResponse !== null) return productResponse;

  const salesResponse = await sales(req, res, session, route, method);
  if (salesResponse !== null) return salesResponse;
  const financeResponse = await finance(req, res, session, route, method);
  if (financeResponse !== null) return financeResponse;

  const resourcesResponse = await agendaResources(req, res, session, route, method);
  if (resourcesResponse !== null) return resourcesResponse;
  const availabilityResponse = await agendaAvailability(req, res, session, route, method);
  if (availabilityResponse !== null) return availabilityResponse;
  const appointmentsResponse = await agendaAppointments(req, res, session, route, method);
  if (appointmentsResponse !== null) return appointmentsResponse;
  const remindersResponse = await agendaReminders(req, res, session, route, method);
  if (remindersResponse !== null) return remindersResponse;

  if (route === "/auth/logout" && method === "POST") {
    await query("UPDATE socialmei.auth_sessoes SET revogada_em=now() WHERE token_hash=$1 AND revogada_em IS NULL", [session.tokenHash]);
    clearSessionCookie(req, res);
    return res.status(204).end();
  }
  if (route === "/auth/workspaces/switch" && method === "POST") {
    const workspaceId = safeId(input.workspace_id, "Negócio");
    const membership = await query(
      "SELECT 1 FROM socialmei.workspace_members WHERE user_id=$1 AND workspace_id=$2",
      [session.user_id, workspaceId],
    );
    if (!membership.rows.length) fail(403, "Você não tem acesso a este negócio.", "workspace_forbidden");
    const token = await withTransaction(async (client) => {
      await client.query("UPDATE socialmei.auth_sessoes SET revogada_em=now() WHERE token_hash=$1 AND revogada_em IS NULL", [session.tokenHash]);
      return createSession(client, session.user_id, workspaceId);
    });
    setSessionCookie(req, res, token);
    const identity = await loadSessionIdentity(sha256(token));
    return send(res, 200, publicIdentity(identity, token));
  }
  if (route === "/auth/profile" && method === "PATCH") {
    const nome = input.nome == null ? null : String(input.nome).trim();
    const nomeNegocio = input.nome_negocio == null ? null : String(input.nome_negocio).trim();
    if (nome !== null && (nome.length < 2 || nome.length > 160)) fail(422, "Nome inválido.");
    if (nomeNegocio !== null && (nomeNegocio.length < 2 || nomeNegocio.length > 160)) fail(422, "Nome do negócio inválido.");
    const config = input.configuracao_negocio;
    if (config != null && (typeof config !== "object" || Array.isArray(config))) fail(422, "Configuração do negócio inválida.");
    await withTransaction(async (client) => {
      if (nome !== null) await client.query("UPDATE socialmei.users SET nome=$2, atualizado_em=now() WHERE id=$1", [session.user_id, nome]);
      if (nomeNegocio !== null || config != null) {
        await client.query(
          `UPDATE socialmei.workspaces
              SET nome=COALESCE($2,nome),
                  configuracao=CASE WHEN $3::jsonb IS NULL THEN configuracao ELSE configuracao || $3::jsonb END,
                  atualizado_em=now()
            WHERE id=$1`,
          [session.workspace_id, nomeNegocio, config == null ? null : JSON.stringify(config)],
        );
      }
    });
    const identity = await loadSessionIdentity(session.tokenHash);
    return send(res, 200, publicIdentity(identity, session.token));
  }
  if (route === "/auth/preferences" && method === "GET") {
    const r = await query(
      "SELECT schema_version,revision,preferences FROM socialmei.auth_preferences WHERE workspace_id=$1 AND user_id=$2",
      [session.workspace_id, session.user_id],
    );
    return send(res, 200, r.rows[0]
      ? { schema_version: r.rows[0].schema_version, revision: Number(r.rows[0].revision), preferences: r.rows[0].preferences }
      : { schema_version: 1, revision: 1, preferences: { theme: "auto" } });
  }
  if (route === "/auth/preferences" && method === "PATCH") {
    if (input.schema_version !== 1 || !Number.isSafeInteger(input.expected_revision) || !input.preferences || typeof input.preferences !== "object" || Array.isArray(input.preferences))
      fail(422, "Preferências inválidas.");
    const allowed = { theme: ["light", "dark", "auto"] };
    const next = {};
    for (const [key, value] of Object.entries(input.preferences)) {
      if (key === "theme" && allowed.theme.includes(value)) next.theme = value;
    }
    const r = await query(
      `UPDATE socialmei.auth_preferences
          SET preferences=$3::jsonb, revision=revision+1, atualizado_em=now()
        WHERE workspace_id=$1 AND user_id=$2 AND revision=$4
        RETURNING schema_version,revision,preferences`,
      [session.workspace_id, session.user_id, JSON.stringify(next), input.expected_revision],
    );
    if (!r.rows.length) fail(409, "As preferências mudaram. Atualize antes de salvar.", "revision_conflict");
    return send(res, 200, { schema_version: r.rows[0].schema_version, revision: Number(r.rows[0].revision), preferences: r.rows[0].preferences });
  }
  if (route === "/workspace-profile" && method === "GET") {
    const profile = await getWorkspaceProfile(session);
    return send(res, 200, profile);
  }
  if (route === "/workspace-profile" && method === "PATCH") {
    if (input.schema_version !== 1 || !Number.isSafeInteger(input.expected_revision) || !input.profile || typeof input.profile !== "object" || Array.isArray(input.profile) || input.profile.version !== 1)
      fail(422, "Perfil do negócio inválido.");
    const raw = JSON.stringify(input.profile);
    if (Buffer.byteLength(raw, "utf8") > 65536) fail(422, "O perfil excede o tamanho permitido.");
    const r = await query(
      `UPDATE socialmei.workspace_profiles
          SET profile=$2::jsonb, revision=revision+1, atualizado_em=now()
        WHERE workspace_id=$1 AND revision=$3
        RETURNING schema_version,revision,profile`,
      [session.workspace_id, raw, input.expected_revision],
    );
    if (!r.rows.length) fail(409, "O perfil mudou. Atualize antes de salvar.", "revision_conflict");
    return send(res, 200, { schema_version: r.rows[0].schema_version, revision: Number(r.rows[0].revision), profile: r.rows[0].profile });
  }
  if (route === "/auth/sessions/revoke-others" && method === "POST") {
    const password = input.atual;
    const r = await query(
      `SELECT c.senha_hash FROM socialmei.auth_credenciais c
        WHERE c.user_id=$1 AND c.ativo=true`,
      [session.user_id],
    );
    const valid = r.rows.length && typeof password === "string"
      ? await argon2.verify(r.rows[0].senha_hash, password).catch(() => false)
      : false;
    if (!valid) fail(401, "Senha atual incorreta.", "invalid_credentials");
    await query(
      "UPDATE socialmei.auth_sessoes SET revogada_em=now() WHERE user_id=$1 AND token_hash<>$2 AND revogada_em IS NULL",
      [session.user_id, session.tokenHash],
    );
    return send(res, 200, { ok: true });
  }

  return send(res, 404, { error: "not_found", detail: "Recurso ainda não implementado nesta etapa." });
}

export default async function handler(req, res) {
  try {
    return await handle(req, res);
  } catch (error) {
    const status = Number.isInteger(error.statusCode) ? error.statusCode : error.code === "23505" ? 409 : 500;
    if (status >= 500) console.error("SocialMEI API v1:", error.message);
    return send(res, status, {
      error: status === 409 && error.code === "23505" ? "conflict" : error.code || (status >= 500 ? "internal_error" : "invalid_request"),
      detail: status >= 500 ? "Não foi possível processar a solicitação." : status === 409 && error.code === "23505" ? "Já existe um registro com esses dados." : error.message,
    });
  }
}
