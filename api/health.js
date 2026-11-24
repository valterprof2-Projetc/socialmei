import { query } from "../lib/postgres.js";

export default async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Content-Type-Options", "nosniff");

  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({ ok: false, error: "method_not_allowed" });
  }

  try {
    const result = await query(
      "SELECT current_database() AS database_name, to_regnamespace('socialmei') IS NOT NULL AS schema_ready",
    );
    return res.status(200).json({
      ok: true,
      service: "socialmei-api",
      database: "connected",
      schema_ready: result.rows[0]?.schema_ready === true,
    });
  } catch (error) {
    console.error("SocialMEI health check failed:", error.message);
    return res.status(error.statusCode || 503).json({
      ok: false,
      service: "socialmei-api",
      database: "unavailable",
    });
  }
}
