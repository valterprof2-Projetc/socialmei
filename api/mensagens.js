// api/mensagens.js (Roda no servidor da Vercel)
import { neon } from '@neondatabase/serverless';

export default async function handler(req, res) {
  // Libera o CORS para o seu frontend acessar
  res.setHeader('Access-Control-Allow-Origin', '*');

  try {
    const sql = neon(process.env.DATABASE_URL);
    
    // Busca os rascunhos gerados pela IA no Neon
    const rascunhos = await sql`
      SELECT id, conversa_id, conteudo, criado_em 
      FROM socialmei.crm_mensagens_canal 
      WHERE status = 'rascunho' 
      ORDER BY criado_em DESC
    `;

    return res.status(200).json(rascunhos);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}