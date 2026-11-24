import pg from "pg";

const { Pool } = pg;

let pool;

export function getPostgresPool() {
  if (pool) return pool;

  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    const error = new Error("DATABASE_URL não configurada.");
    error.statusCode = 503;
    throw error;
  }

  pool = new Pool({
    connectionString,
    max: Number.parseInt(process.env.PG_POOL_MAX || "5", 10),
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 10_000,
    allowExitOnIdle: true,
    application_name: "socialmei-vercel-api",
  });

  pool.on("error", (error) => {
    console.error("SocialMEI PostgreSQL pool error:", error.message);
  });

  return pool;
}

export async function query(text, values = []) {
  return getPostgresPool().query(text, values);
}
