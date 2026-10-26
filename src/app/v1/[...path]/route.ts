import {runCatalogBatch} from '@/lib/catalog-batch';
import {customerCreateInput} from '@/lib/customer-input';
import {standaloneCatalogInput} from '@/lib/standalone-catalog-input';
import { randomUUID, randomBytes } from 'node:crypto';
import { userDatabase } from '@/lib/db';
import { failure } from '@/lib/errors';
import { prepareInput,confirmInput,approvalInput,cartInput,cartSubmitInput,keyInput,idInput } from '@/lib/input';
import {inspectionInput,claimInput,fulfillmentVersionInput} from '@/lib/fulfillment-input';
import {cancellationInput} from '@/lib/cancellation-input';
import {returnInput} from '@/lib/return-input';
import {memberRevokeInput} from '@/lib/member-input';
import {domainRequestInput,domainRemoveInput} from '@/lib/domain-input';
import {profileInput} from '@/lib/profile-input';
import {invitationInput,invitationTokenInput} from '@/lib/invitation-input';
export const runtime='nodejs';
export const maxDuration=300;
export const dynamic='force-dynamic';
async function handle(req:Request,ctx:{params:Promise<{path:string[]}>}) {
 const correlation=randomUUID();
 const {path}=await ctx.params;
 if(path[0]==='merchant-customers'&&process.env.STANDALONE_CUSTOMERS_ENABLED!=='true')return failure('INTEGRATION_NOT_READY',correlation,503);
 if(path[0]==='standalone-catalog'&&process.env.STANDALONE_CATALOG_ADMIN_ENABLED!=='true')return failure('INTEGRATION_NOT_READY',correlation,503);
 if(path[0]==='fulfillment'&&path[2]==='cancel'&&process.env.TEST_CANCELLATION_ENABLED!=='true')return failure('INTEGRATION_NOT_READY',correlation,503);
 if(path[0]==='fulfillment'&&process.env.TEST_FULFILLMENT_ENABLED!=='true')return Response.json({error:{code:'INTEGRATION_NOT_READY',message:'Testutlämning är inte aktiverad.'}},{status:503,headers:{'Cache-Control':'no-store'}});
 if(path[0]==='merchant-members'&&process.env.MERCHANT_MEMBER_ADMIN_ENABLED!=='true')return Response.json({error:{code:'INTEGRATION_NOT_READY',message:'Mandathanteringen är inte aktiverad ännu.'}},{status:503,headers:{'Cache-Control':'no-store'}});
 if(path[0]==='fulfillment'&&path[2]==='billing-underlay'&&process.env.TEST_BILLING_UNDERLAY_ENABLED!=='true')return failure('INTEGRATION_NOT_READY',correlation,503);
 if(req.method==='GET'&&path.join('/')==='health')return Response.json({service:'plockivo-api',version:'0.2.0',contract:'0.2.0'},{headers:{'Cache-Control':'no-store'}});
 const token=req.headers.get('authorization')?.match(/^Bearer ([^\s]+)$/)?.[1];
 if(!token)return failure('AUTH_REQUIRED',correlation,401);
 try {
  const db=userDatabase(token);
  const [identity,limited]=await Promise.all([db.auth.getUser(token),db.rpc('consume_api_quota')]);
  if(identity.error||!identity.data.user)return failure('AUTH_REQUIRED',correlation,401);
  if(limited.error)throw limited.error;
  if(!limited.data)return failure('RATE_LIMITED',correlation,429);
  let result;let invitationToken:string|undefined;
  if(req.method==='GET'&&path.join('/')==='merchant-customers'){result=await db.rpc('list_merchant_customers',{p_tenant:idInput.parse(new URL(req.url).searchParams.get('tenant_id'))});
  } else if(req.method==='GET'&&path.join('/')==='standalone-catalog'){result=await db.rpc('list_standalone_catalog',{p_tenant:idInput.parse(new URL(req.url).searchParams.get('tenant_id'))});
  } else if(req.method==='GET'&&path[0]==='fulfillment'&&path.length===3&&path[2]==='billing-underlay'){result=await db.rpc('get_test_billing_underlay',{p_order:idInput.parse(path[1])});
  } else if(req.method==='GET'&&path[0]==='fulfillment'&&path.length===2){result=await db.rpc('get_test_fulfillment',{p_order:idInput.parse(path[1])});
  } else if(req.method==='GET'&&path.join('/')==='merchant-jobs'){result=await db.rpc('list_merchant_jobs',{p_tenant:idInput.parse(new URL(req.url).searchParams.get('tenant_id'))});
  } else if(req.method==='GET'&&path.join('/')==='merchant-members'){result=await db.rpc('list_merchant_members',{p_tenant:idInput.parse(new URL(req.url).searchParams.get('tenant_id'))});
  } else if(req.method==='GET'&&path.join('/')==='merchant-domains'){result=await db.rpc('list_merchant_domains',{p_tenant:idInput.parse(new URL(req.url).searchParams.get('tenant_id'))});
  } else if(req.method==='GET'&&path.join('/')==='merchant-profile'){result=await db.rpc('get_merchant_profile',{p_tenant:idInput.parse(new URL(req.url).searchParams.get('tenant_id'))});
  } else if(req.method==='GET'&&path.join('/')==='invitations/options'){
   result=await db.rpc('invitation_options',{p_membership:idInput.parse(new URL(req.url).searchParams.get('membership_id'))});
  } else if(req.method==='GET'&&path.join('/')==='carts/current'){
   const q=new URL(req.url).searchParams;result=await db.rpc('get_current_cart',{p_tenant:idInput.parse(q.get('tenant_id')),p_account:idInput.parse(q.get('customer_account_id')),p_store:idInput.parse(q.get('store_id')),p_project:idInput.parse(q.get('project_id'))});
  } else if(req.method==='GET'&&path.join('/')==='context')result=await db.rpc('get_context');
  else if(req.method==='GET'&&path.join('/')==='catalog') {
   const url=new URL(req.url); const tenant=idInput.parse(url.searchParams.get('tenant_id'));
   result=await db.rpc('lookup_products',{p_tenant:tenant,p_query:(url.searchParams.get('q')??'').slice(0,100)});
  } else if(req.method==='GET'&&path[0]==='purchase-intents'&&path.length===3&&path[2]==='confirmation')result=await db.rpc('get_order_confirmation',{p_intent:idInput.parse(path[1])});
  else if(req.method==='GET'&&path[0]==='purchase-intents'&&path.length===2)result=await db.rpc('get_purchase_intent',{p_id:idInput.parse(path[1])});
  else if(req.method==='GET'&&path.join('/')==='purchase-intents')result=await db.rpc('list_purchase_intents');
  else if(req.method==='POST') {
   if(!req.headers.get('content-type')?.startsWith('application/json'))return failure('VALIDATION_ERROR',correlation,415);
   const raw=await req.text();if(Buffer.byteLength(raw)>32768)return failure('VALIDATION_ERROR',correlation,413);
   const body=JSON.parse(raw);
   const key=keyInput.parse(req.headers.get('idempotency-key'));
   if(path.join('/')==='standalone-catalog/import'){
    const batch=await runCatalogBatch(body,key,async (input,rowKey)=>{
     const quota=await db.rpc('consume_api_quota');if(quota.error)return {data:null,error:quota.error};if(!quota.data)return {data:null,error:{message:'RATE_LIMITED'}};
     return db.rpc('save_standalone_catalog',{p_body:input,p_key:rowKey,p_correlation:correlation});
    });
    return Response.json({data:batch,contract_version:'0.2.0'},{status:batch.status==='completed'?200:207,headers:{'Cache-Control':'no-store','X-Correlation-ID':correlation}});
   } else if(path.join('/')==='merchant-customers'){result=await db.rpc('create_merchant_customer',{p_body:customerCreateInput.parse(body),p_key:key,p_correlation:correlation});
   } else if(path.join('/')==='standalone-catalog'){result=await db.rpc('save_standalone_catalog',{p_body:standaloneCatalogInput.parse(body),p_key:key,p_correlation:correlation});
   } else if(path[0]==='fulfillment'&&path.length===3&&path[2]==='inspect'){result=await db.rpc('inspect_test_order',{p_order:idInput.parse(path[1]),p_body:inspectionInput.parse(body),p_key:key,p_correlation:correlation});
   } else if(path[0]==='fulfillment'&&path.length===3&&path[2]==='claim'){result=await db.rpc('claim_test_order',{p_order:idInput.parse(path[1]),p_body:claimInput.parse(body),p_key:key,p_correlation:correlation});
   } else if(path[0]==='fulfillment'&&path.length===5&&path[2]==='claims'&&path[4]==='confirm'){result=await db.rpc('confirm_test_claim',{p_order:idInput.parse(path[1]),p_claim:idInput.parse(path[3]),p_body:fulfillmentVersionInput.parse(body),p_key:key,p_correlation:correlation});
   } else if(path[0]==='fulfillment'&&path.length===3&&path[2]==='cancel'){result=await db.rpc('cancel_test_order_lines',{p_order:idInput.parse(path[1]),p_body:cancellationInput.parse(body),p_key:key,p_correlation:correlation});
   } else if(path[0]==='fulfillment'&&path.length===3&&path[2]==='returns'){result=await db.rpc('receive_test_return',{p_order:idInput.parse(path[1]),p_body:returnInput.parse(body),p_key:key,p_correlation:correlation});
   } else if(path[0]==='merchant-members'&&path.length===3&&path[2]==='revoke'){const d=memberRevokeInput.parse(body);result=await db.rpc('revoke_merchant_member',{p_tenant:d.tenant_id,p_member:idInput.parse(path[1]),p_version:d.version,p_key:key,p_correlation:correlation});
   } else if(path.join('/')==='merchant-domains'){const d=domainRequestInput.parse(body);result=await db.rpc('request_merchant_domain',{p_tenant:d.tenant_id,p_hostname:d.hostname,p_correlation:correlation});
   } else if(path[0]==='merchant-domains'&&path.length===3&&path[2]==='remove'){const d=domainRemoveInput.parse(body);result=await db.rpc('remove_merchant_domain',{p_tenant:d.tenant_id,p_id:idInput.parse(path[1]),p_version:d.version,p_correlation:correlation});
   } else if(path.join('/')==='merchant-profile'){result=await db.rpc('save_merchant_profile',{p_body:profileInput.parse(body),p_key:key,p_correlation:correlation});
   } else if(path.join('/')==='invitations'){
    invitationToken=randomBytes(32).toString('hex');
    result=await db.rpc('create_invitation',{p_body:invitationInput.parse(body),p_token:invitationToken,p_key:key,p_correlation:correlation});
   } else if(path.join('/')==='invitations/preview')result=await db.rpc('preview_invitation',{p_token:invitationTokenInput.parse(body).token});
   else if(path.join('/')==='invitations/accept')result=await db.rpc('accept_invitation',{p_token:invitationTokenInput.parse(body).token,p_correlation:correlation});
   else if(path[0]==='invitations'&&path.length===3&&path[2]==='revoke'){
    if(Object.keys(body).length) return failure('VALIDATION_ERROR',correlation,400);
    result=await db.rpc('revoke_invitation',{p_id:idInput.parse(path[1]),p_correlation:correlation});
   } else if(path.join('/')==='carts/save')result=await db.rpc('save_cart',{p_body:cartInput.parse(body),p_key:key,p_correlation:correlation});
   else if(path[0]==='carts'&&path.length===3&&path[2]==='submit')result=await db.rpc('submit_cart',{p_id:idInput.parse(path[1]),p_version:cartSubmitInput.parse(body).version,p_key:key,p_correlation:correlation});
   else if(path.join('/')==='purchase-intents')result=await db.rpc('prepare_purchase',{p_body:prepareInput.parse(body),p_key:key,p_correlation:correlation});
   else if(path[0]==='purchase-intents'&&path.length===3&&path[2]==='confirm')result=await db.rpc('confirm_purchase',{p_id:idInput.parse(path[1]),p_body:confirmInput.parse(body),p_key:key,p_correlation:correlation});
   else if(path[0]==='purchase-intents'&&path.length===3&&path[2]==='approval')result=await db.rpc('decide_approval',{p_id:idInput.parse(path[1]),p_body:approvalInput.parse(body),p_key:key,p_correlation:correlation});
  }
  if(!result)return failure('NOT_FOUND',correlation,404);
  if(result.error)throw result.error;
  return Response.json({data:invitationToken&&!result.data?.replayed?{...result.data,token:invitationToken}:result.data,contract_version:'0.2.0'}, {headers:{'Cache-Control':'no-store','X-Correlation-ID':correlation}});
 }catch(error) {
  if(error instanceof SyntaxError||(error&&typeof error==='object'&&'issues'in error))return failure('VALIDATION_ERROR',correlation,400);
  const msg=error&&typeof error==='object'&&'message'in error?String(error.message):'';
  const known=['CUSTOMER_EXISTS','CATALOG_DUPLICATE','INVITATION_INVALID','INVITATION_UNAVAILABLE','INVITATION_FINAL','RATE_LIMITED','MFA_REQUIRED','PERMISSION_DENIED','NOT_FOUND','MEMBERSHIP_INACTIVE','QUANTITY_CONFLICT','INSPECTION_REQUIRED','RETURN_QUANTITY_EXCEEDED','VERSION_CONFLICT','IDEMPOTENCY_CONFLICT','CREDIT_UNAVAILABLE','APPROVAL_REQUIRED','PRICE_CHANGED','SALES_PAUSED','INTEGRATION_NOT_READY','BUDGET_EXCEEDED','VALIDATION_ERROR'];
  const code=known.find(x=>msg===x);
  return failure(code??'INTERNAL_ERROR',correlation,code==='RATE_LIMITED'?429:code==='NOT_FOUND'?404:code==='MFA_REQUIRED'||code==='PERMISSION_DENIED'||code==='MEMBERSHIP_INACTIVE'?403:code?409:500);
 }
}
export const GET=handle;
export const POST=handle;

