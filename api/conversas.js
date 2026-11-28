import { neon } from '@neondatabase/serverless';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    const sql = neon(process.env.DATABASE_URL);
    
    const conversas = await sql`
      SELECT 
        c.id, 
        c.nome as contato, 
        c.atualizado_em,
        (SELECT conteudo FROM socialmei.crm_mensagens_canal m WHERE m.conversa_id = c.id ORDER BY m.criado_em DESC LIMIT 1) as ultima_mensagem
      FROM socialmei.crm_conversas_canal c
      WHERE c.workspace_id = 1
      ORDER BY c.atualizado_em DESC
    `;
    return res.status(200).json(conversas);
  } catch (error) {
    console.error("Erro no DB:", error);
    return res.status(500).json({ error: error.message });
  }
}