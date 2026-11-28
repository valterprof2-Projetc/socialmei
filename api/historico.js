import { neon } from '@neondatabase/serverless';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const { conversa_id } = req.query;
  if (!conversa_id) {
    return res.status(400).json({ error: "Parâmetro conversa_id é obrigatório" });
  }

  try {
    const sql = neon(process.env.DATABASE_URL);
    
    const mensagens = await sql`
      SELECT id, direcao, conteudo, status, criado_em
      FROM socialmei.crm_mensagens_canal
      WHERE conversa_id = ${conversa_id} AND status != 'rascunho'
      ORDER BY criado_em ASC
    `;

    const rascunhos = await sql`
      SELECT id, conteudo, criado_em
      FROM socialmei.crm_mensagens_canal
      WHERE conversa_id = ${conversa_id} AND status = 'rascunho'
      ORDER BY criado_em DESC LIMIT 1
    `;

    return res.status(200).json({
      mensagens,
      rascunho_ia: rascunhos.length > 0 ? rascunhos[0] : null
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}