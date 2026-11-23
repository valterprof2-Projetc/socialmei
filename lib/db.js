import { createClient } from "@libsql/client";

let client;

export function getDb() {
  if (client) return client;
  const url = process.env.TURSO_DATABASE_URL;
  const authToken = process.env.TURSO_AUTH_TOKEN;
  if (!url || !authToken) {
    const error = new Error("Banco Turso não configurado. Defina TURSO_DATABASE_URL e TURSO_AUTH_TOKEN.");
    error.statusCode = 503;
    throw error;
  }
  client = createClient({ url, authToken });
  return client;
}
