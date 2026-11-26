import { createHash, timingSafeEqual, randomUUID } from "node:crypto";
import { getPostgresPool, query } from "../lib/postgres.js";
function fail(status,message,code="invalid_request"){const e=new Error(message);e.statusCode=status;e.code=code;throw e;}
function send(res,status,body){res.setHeader("Cache-Control","no-store");res.setHeader("Pragma","no-cache");return res.status(status).json(body);}
function bodyOf(req){return req.body&&typeof req.body==="object"&&!Array.isArray(req.body)?req.body:{};}
function hash(v){return createHash("sha256").update(v).digest("hex");}
function auth(req){
 const expected=process.env.SOCIALMEI_M2M_TOKEN||"", supplied=String(req.headers.authorization||"").replace(/^Bearer\s+/i,"");
 if(expected.length<32||supplied.length!==expected.length||!timingSafeEqual(Buffer.from(supplied),Buffer.from(expected)))fail(401,"Integração não autorizada.","unauthorized");
 const workspaceId=Number(process.env.SOCIALMEI_M2M_WORKSPACE_ID);if(!Number.isSafeInteger(workspaceId)||workspaceId<1)fail(503,"Workspace da integração não configurado.","configuration_error");return workspaceId;
}
async function tx(work){const c=await getPostgresPool().connect();try{await c.query("BEGIN");const v=await work(c);await c.query("COMMIT");return v;}catch(e){await c.query("ROLLBACK").catch(()=>{});throw e;}finally{c.release();}}
function channelRefs(input){
 const channel=input.channel,account=String(input.account_ref||""),contact=String(input.contact_ref||"");
 if(!["whatsapp","instagram"].includes(channel))fail(422,"Canal inválido.");
 if(channel==="whatsapp"&&(!/^waha:[0-9]{1,40}@c\.us$/.test(account)||!/^waha:([0-9]{1,40}@c\.us|[A-Za-z0-9][A-Za-z0-9_.:-]{0,79}@lid)$/.test(contact)))fail(422,"Referências WAHA inválidas.");
 if(channel==="instagram"&&(!/^instagram:[0-9]{1,40}$/.test(account)||!/^instagram:[0-9]{1,40}$/.test(contact)))fail(422,"Referências Instagram inválidas.");
 return {channel,account,contact,origin:channel==="whatsapp"?"waha":"instagram"};
}
async function ingest(req,res,wid){
 if(req.method!=="POST")fail(405,"Método não permitido.");
 const input=bodyOf(req),refs=channelRefs(input),externalId=String(input.external_message_id||""),text=String(input.text||"");
 const contactName=String(input.contact_name||"Cliente").trim().slice(0,160)||"Cliente";
 if(!/^[!-~]{1,1024}$/.test(externalId))fail(422,"external_message_id inválido.");
 if(!text.trim()||Buffer.byteLength(text,"utf8")>8192)fail(422,"Mensagem vazia ou acima de 8 KB.");
 const occurredAt=input.occurred_at?new Date(input.occurred_at):new Date();if(!Number.isFinite(occurredAt.getTime()))fail(422,"occurred_at inválido.");
 const customer=input.customer&&typeof input.customer==="object"?input.customer:{},customerName=String(customer.name||contactName).trim().slice(0,160)||contactName;
 const phone=customer.phone?String(customer.phone).replace(/[^0-9+]/g,"").slice(0,40):null,instagram=refs.channel==="instagram"?refs.contact.replace("instagram:",""):null;
 const fingerprint=hash(JSON.stringify({...refs,externalId,text,occurredAt:occurredAt.toISOString()}));
 const result=await tx(async c=>{
  let customerId=null;
  if(phone||instagram){
   const found=await c.query(`SELECT id FROM socialmei.crm_clientes WHERE workspace_id=$1 AND
    (($2::text IS NOT NULL AND regexp_replace(coalesce(telefone,''),'[^0-9]','','g')=regexp_replace($2,'[^0-9]','','g')) OR ($3::text IS NOT NULL AND instagram=$3))
    ORDER BY id LIMIT 1 FOR UPDATE`,[wid,phone,instagram]);
   if(found.rows.length)customerId=Number(found.rows[0].id);
   else {const created=await c.query("INSERT INTO socialmei.crm_clientes(workspace_id,nome,telefone,instagram) VALUES($1,$2,$3,$4) RETURNING id",[wid,customerName,phone,instagram]);customerId=Number(created.rows[0].id);}
  }
  const conv=await c.query(`INSERT INTO socialmei.me_conversations(workspace_id,channel,account_ref,contact_ref,contact_name,revision,origin,cliente_id)
   VALUES($1,$2,$3,$4,$5,1,$6,$7) ON CONFLICT(workspace_id,channel,account_ref,contact_ref)
   DO UPDATE SET contact_name=EXCLUDED.contact_name,cliente_id=COALESCE(socialmei.me_conversations.cliente_id,EXCLUDED.cliente_id),
   revision=socialmei.me_conversations.revision+1 RETURNING id,revision`,
   [wid,refs.channel,refs.account,refs.contact,contactName,refs.origin,customerId]);
  const conversationId=Number(conv.rows[0].id);
  const old=await c.query(`SELECT m.id,m.fingerprint FROM socialmei.me_external_messages x JOIN socialmei.me_messages m
   ON m.workspace_id=x.workspace_id AND m.id=x.message_id WHERE x.workspace_id=$1 AND x.channel=$2 AND x.account_ref=$3 AND x.external_message_id=$4`,
   [wid,refs.channel,refs.account,externalId]);
  if(old.rows.length){if(old.rows[0].fingerprint!==fingerprint)fail(409,"ID externo reutilizado com conteúdo diferente.","message_conflict");
   return {accepted:true,duplicate:true,conversation_id:conversationId,message_id:Number(old.rows[0].id),customer_id:customerId};}
  const msg=await c.query(`INSERT INTO socialmei.me_messages(workspace_id,conversation_id,external_message_id,fingerprint,conversation_revision,text,occurred_at,origin)
   VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
   [wid,conversationId,externalId,fingerprint,Number(conv.rows[0].revision),text,occurredAt.toISOString(),refs.origin]);
  const messageId=Number(msg.rows[0].id);
  await c.query("INSERT INTO socialmei.me_external_messages(workspace_id,channel,account_ref,external_message_id,message_id,origin) VALUES($1,$2,$3,$4,$5,$6)",
   [wid,refs.channel,refs.account,externalId,messageId,refs.origin]);
  await c.query("INSERT INTO socialmei.me_provider_sentiment_jobs(workspace_id,message_id,claim_id,status,lease_until) VALUES($1,$2,$3,'processing',now()+interval '3 minutes') ON CONFLICT(workspace_id,message_id) DO NOTHING",
   [wid,messageId,randomUUID()]);
  return {accepted:true,duplicate:false,conversation_id:conversationId,message_id:messageId,customer_id:customerId,sentiment_pending:true};
 });
 return send(res,result.duplicate?200:202,result);
}
async function catalog(req,res,wid){
 if(req.method!=="GET")fail(405,"Método não permitido.");
 const r=await query("SELECT id,nome,categoria,descricao,preco,duracao_minutos FROM socialmei.crm_produtos WHERE workspace_id=$1 AND tipo='Serviço' AND status='Ativo' ORDER BY lower(nome),id LIMIT 300",[wid]);
 return send(res,200,{items:r.rows.map(x=>({...x,id:Number(x.id),preco:Number(x.preco),duracao_minutos:x.duracao_minutos==null?null:Number(x.duracao_minutos)}))});
}
async function quotes(req,res,wid){
 if(req.method==="GET"){
  const r=await query(`SELECT q.id,q.cliente_id,q.conversation_id,q.status,q.subtotal,q.desconto,q.total,q.validade_ate,q.observacoes,q.created_at,
   COALESCE(jsonb_agg(jsonb_build_object('id',i.id,'produto_id',i.produto_id,'descricao',i.descricao_snapshot,'quantidade',i.quantidade,'preco_unitario',i.preco_unitario,'total',i.total)) FILTER(WHERE i.id IS NOT NULL),'[]'::jsonb) itens
   FROM socialmei.crm_cotacoes q LEFT JOIN socialmei.crm_cotacao_itens i ON i.workspace_id=q.workspace_id AND i.cotacao_id=q.id
   WHERE q.workspace_id=$1 GROUP BY q.workspace_id,q.id ORDER BY q.created_at DESC LIMIT 200`,[wid]);
  return send(res,200,{items:r.rows});
 }
 if(req.method!=="POST")fail(405,"Método não permitido.");
 const input=bodyOf(req),clientId=Number(input.cliente_id),opId=String(input.operation_id||""),items=Array.isArray(input.items)?input.items:[];
 if(!Number.isSafeInteger(clientId)||clientId<1||!/^[0-9a-f-]{36}$/i.test(opId))fail(422,"cliente_id ou operation_id inválido.");
 if(!items.length||items.length>30)fail(422,"A cotação deve conter de 1 a 30 itens.");
 const desconto=Number(input.desconto||0);if(!Number.isFinite(desconto)||desconto<0)fail(422,"Desconto inválido.");
 const result=await tx(async c=>{
  const old=await c.query("SELECT id FROM socialmei.crm_cotacoes WHERE workspace_id=$1 AND operation_id=$2",[wid,opId]);if(old.rows.length)return {id:old.rows[0].id,duplicate:true};
  const customer=await c.query("SELECT id FROM socialmei.crm_clientes WHERE workspace_id=$1 AND id=$2",[wid,clientId]);if(!customer.rows.length)fail(404,"Cliente não encontrado.");
  const convId=input.conversation_id==null?null:Number(input.conversation_id);
  if(convId!==null){const cr=await c.query("SELECT id FROM socialmei.me_conversations WHERE workspace_id=$1 AND id=$2",[wid,convId]);if(!cr.rows.length)fail(404,"Conversa não encontrada.");}
  const ids=[...new Set(items.map(x=>Number(x.produto_id)))];if(ids.some(x=>!Number.isSafeInteger(x)||x<1))fail(422,"produto_id inválido.");
  const products=await c.query("SELECT id,nome,preco,status FROM socialmei.crm_produtos WHERE workspace_id=$1 AND id=ANY($2::bigint[]) AND tipo='Serviço'",[wid,ids]);
  if(products.rows.length!==ids.length||products.rows.some(p=>p.status!=="Ativo"))fail(422,"Um ou mais serviços não estão ativos no catálogo.");
  const byId=new Map(products.rows.map(p=>[Number(p.id),p]));let subtotal=0;const normalized=[];
  for(const item of items){const p=byId.get(Number(item.produto_id)),qty=Number(item.quantidade);if(!Number.isFinite(qty)||qty<=0||qty>1000)fail(422,"Quantidade inválida.");
   const price=Number(p.preco),total=Number((price*qty).toFixed(2));subtotal+=total;normalized.push({id:randomUUID(),produto_id:Number(p.id),descricao:p.nome,quantidade:qty,preco_unitario:price,total});}
  subtotal=Number(subtotal.toFixed(2));if(desconto>subtotal)fail(422,"Desconto não pode superar o subtotal.");
  const total=Number((subtotal-desconto).toFixed(2)),id=randomUUID();
  await c.query("INSERT INTO socialmei.crm_cotacoes(workspace_id,id,cliente_id,conversation_id,status,subtotal,desconto,total,validade_ate,observacoes,operation_id) VALUES($1,$2,$3,$4,'draft',$5,$6,$7,$8,$9,$10)",
   [wid,id,clientId,convId,subtotal,desconto,total,input.validade_ate||null,String(input.observacoes||"").slice(0,5000),opId]);
  for(const item of normalized)await c.query("INSERT INTO socialmei.crm_cotacao_itens(workspace_id,cotacao_id,id,produto_id,descricao_snapshot,quantidade,preco_unitario,total) VALUES($1,$2,$3,$4,$5,$6,$7,$8)",
   [wid,id,item.id,item.produto_id,item.descricao,item.quantidade,item.preco_unitario,item.total]);
  return {id,duplicate:false,subtotal,desconto,total,status:"draft",items:normalized};
 });
 return send(res,result.duplicate?200:201,result);
}
export default async function handler(req,res){
 try{if(req.method==="OPTIONS")return res.status(204).end();const wid=auth(req),route=String(req.query?.route||"").replace(/^\/+|\/+$/g,"");
  if(route==="messages/ingest")return await ingest(req,res,wid);
  if(route==="catalog/services")return await catalog(req,res,wid);
  if(route==="quotes")return await quotes(req,res,wid);
  return send(res,404,{error:"not_found",detail:"Endpoint de integração não implementado."});
 }catch(e){const status=Number.isInteger(e.statusCode)?e.statusCode:e.code==="23505"?409:500;if(status>=500)console.error("SocialMEI integration API:",e.message);
  return send(res,status,{error:e.code||(status>=500?"internal_error":"invalid_request"),detail:status>=500?"Não foi possível processar a integração.":e.message});}
}
