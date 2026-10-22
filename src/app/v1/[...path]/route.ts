import { randomUUID } from 'node:crypto';
import { userDatabase } from '@/lib/db';
import { failure } from '@/lib/errors';
import { prepareInput,confirmInput,approvalInput,cartInput,cartSubmitInput,keyInput,idInput } from '@/lib/input';
export const runtime='nodejs';
export const dynamic='force-dynamic';
async function handle(req:Request,ctx:{params:Promise<{path:string[]}>}) {
 const correlation=randomUUID();
 const {path}=await ctx.params;
 if(req.method==='GET'&&path.join('/')==='health')return Response.json({service:'plockivo-api',version:'0.2.0',contract:'0.2.0'},{headers:{'Cache-Control':'no-store'}});
 const token=req.headers.get('authorization')?.match(/^Bearer ([^\s]+)$/)?.[1];
 if(!token)return failure('AUTH_REQUIRED',correlation,401);
 try {
  const db=userDatabase(token);
  const [identity,limited]=await Promise.all([db.auth.getUser(token),db.rpc('consume_api_quota')]);
  if(identity.error||!identity.data.user)return failure('AUTH_REQUIRED',correlation,401);
  if(limited.error)throw limited.error;
  if(!limited.data)return failure('RATE_LIMITED',correlation,429);
  let result;
  if(req.method==='GET'&&path.join('/')==='carts/current'){
   const q=new URL(req.url).searchParams;result=await db.rpc('get_current_cart',{p_tenant:idInput.parse(q.get('tenant_id')),p_account:idInput.parse(q.get('customer_account_id')),p_store:idInput.parse(q.get('store_id')),p_project:idInput.parse(q.get('project_id'))});
  } else if(req.method==='GET'&&path.join('/')==='context')result=await db.rpc('get_context');
  else if(req.method==='GET'&&path.join('/')==='catalog') {
   const url=new URL(req.url); const tenant=idInput.parse(url.searchParams.get('tenant_id'));
   result=await db.rpc('lookup_products',{p_tenant:tenant,p_query:(url.searchParams.get('q')??'').slice(0,100)});
  } else if(req.method==='GET'&&path[0]==='purchase-intents'&&path.length===2)result=await db.rpc('get_purchase_intent',{p_id:idInput.parse(path[1])});
  else if(req.method==='GET'&&path.join('/')==='purchase-intents')result=await db.rpc('list_purchase_intents');
  else if(req.method==='POST') {
   if(!req.headers.get('content-type')?.startsWith('application/json'))return failure('VALIDATION_ERROR',correlation,415);
   const raw=await req.text();if(Buffer.byteLength(raw)>32768)return failure('VALIDATION_ERROR',correlation,413);
   const body=JSON.parse(raw);
   const key=keyInput.parse(req.headers.get('idempotency-key'));
   if(path.join('/')==='carts/save')result=await db.rpc('save_cart',{p_body:cartInput.parse(body),p_key:key,p_correlation:correlation});
   else if(path[0]==='carts'&&path.length===3&&path[2]==='submit')result=await db.rpc('submit_cart',{p_id:idInput.parse(path[1]),p_version:cartSubmitInput.parse(body).version,p_key:key,p_correlation:correlation});
   else if(path.join('/')==='purchase-intents')result=await db.rpc('prepare_purchase',{p_body:prepareInput.parse(body),p_key:key,p_correlation:correlation});
   else if(path[0]==='purchase-intents'&&path.length===3&&path[2]==='confirm')result=await db.rpc('confirm_purchase',{p_id:idInput.parse(path[1]),p_body:confirmInput.parse(body),p_key:key,p_correlation:correlation});
   else if(path[0]==='purchase-intents'&&path.length===3&&path[2]==='approval')result=await db.rpc('decide_approval',{p_id:idInput.parse(path[1]),p_body:approvalInput.parse(body),p_key:key,p_correlation:correlation});
  }
  if(!result)return failure('NOT_FOUND',correlation,404);
  if(result.error)throw result.error;
  return Response.json({data:result.data,contract_version:'0.2.0'}, {headers:{'Cache-Control':'no-store','X-Correlation-ID':correlation}});
 }catch(error) {
  if(error instanceof SyntaxError||(error&&typeof error==='object'&&'issues'in error))return failure('VALIDATION_ERROR',correlation,400);
  const msg=error&&typeof error==='object'&&'message'in error?String(error.message):'';
  const known=['PERMISSION_DENIED','NOT_FOUND','MEMBERSHIP_INACTIVE','VERSION_CONFLICT','IDEMPOTENCY_CONFLICT','CREDIT_UNAVAILABLE','APPROVAL_REQUIRED','PRICE_CHANGED','SALES_PAUSED','INTEGRATION_NOT_READY','BUDGET_EXCEEDED','VALIDATION_ERROR'];
  const code=known.find(x=>msg===x);
  return failure(code??'INTERNAL_ERROR',correlation,code==='NOT_FOUND'?404:code==='PERMISSION_DENIED'||code==='MEMBERSHIP_INACTIVE'?403:code?409:500);
 }
}
export const GET=handle;
export const POST=handle;
