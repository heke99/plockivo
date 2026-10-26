import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawn,spawnSync} from 'node:child_process';
import {randomBytes,randomUUID,createHmac} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';

// LOCAL CI ONLY: signup confirmation is disabled in the disposable local Auth config.
// This exercises actual Auth/TOTP sessions, HTTP API and PostgREST; it does not prove Strato delivery.
const origin='http://127.0.0.1:3581';let server;
function requireLocal(url){const u=new URL(url);if(u.protocol!=='http:'||!['127.0.0.1','localhost'].includes(u.hostname)||u.username||u.password||u.pathname!=='/'||u.search||u.hash)throw Error('Refusing a non-loopback Supabase target.');return u.origin}
function uuid(value){assert.match(value,/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i);return value}
function totp(secret,time=Date.now()){
 const alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';let bits=0,value=0;const bytes=[];
 for(const char of secret.toUpperCase().replace(/=+$/,'')){const index=alphabet.indexOf(char);if(index<0)throw Error('Invalid local test TOTP secret.');value=(value<<5)|index;bits+=5;if(bits>=8){bits-=8;bytes.push((value>>bits)&255);value&=(1<<bits)-1}}
 const counter=Buffer.alloc(8);counter.writeBigUInt64BE(BigInt(Math.floor(time/30000)));const digest=createHmac('sha1',Buffer.from(bytes)).update(counter).digest();const offset=digest[19]&15;
 return String((digest.readUInt32BE(offset)&0x7fffffff)%1000000).padStart(6,'0');
}
function org(prefix){for(let digit=0;digit<10;digit++){const candidate=prefix+digit;const sum=[...candidate].reduce((n,c,i)=>{const v=Number(c)*(i%2===0?2:1);return n+Math.floor(v/10)+v%10},0);if(sum%10===0)return candidate}throw Error('Cannot build local fixture checksum.')}
function key(){return 'http058:'+randomUUID()}
async function call(token,path,body,requestKey=key(),expected=200,errorCode){
 const response=await fetch(origin+'/v1/'+path,{method:body===undefined?'GET':'POST',headers:{...(token?{Authorization:'Bearer '+token}:{}),...(body===undefined?{}:{'Content-Type':'application/json','Idempotency-Key':requestKey})},body:body===undefined?undefined:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(20000)});
 const result=await response.json();assert.equal(response.status,expected,'HTTP status for '+path);if(errorCode)assert.equal(result.error?.code,errorCode,'Business error for '+path);return expected===200?result.data:result.error;
}
async function main(){
 if(process.env.PLOCKIVO_LOCAL_HTTP_TEST!=='1')throw Error('Refusing HTTP test: set PLOCKIVO_LOCAL_HTTP_TEST=1 only for a disposable local Supabase stack.');
 const config=readFileSync('supabase/config.toml','utf8'),project=config.match(/^project_id\s*=\s*"([a-zA-Z0-9_-]+)"/m)?.[1];
 if(!project)throw Error('Missing local project ID.');
 const emailConfig=config.match(/^\[auth\.email\]\s*([\s\S]*?)(?=^\[|$(?![\s\S]))/m)?.[1]??'';
 if(!/^enable_confirmations\s*=\s*false\s*$/m.test(emailConfig))throw Error('This test requires local-only disabled signup confirmation; hosted policy must never be changed.');
 // Capture status privately. Never print stdout/stderr or any local API/Auth keys.
 const status=spawnSync('node_modules/.bin/supabase',['status','-o','json'],{encoding:'utf8',timeout:30000});
 if(status.error||status.status!==0)throw Error('Local Supabase status is unavailable.');
 let settings;try{settings=JSON.parse(status.stdout)}catch{throw Error('Invalid local Supabase status output.')}
 const supabaseUrl=requireLocal(settings.API_URL),publishable=settings.PUBLISHABLE_KEY??settings.ANON_KEY;
 if(typeof publishable!=='string'||publishable.length<20)throw Error('Local publishable API key is unavailable.');
 const sql=query=>{const result=spawnSync('docker',['exec','-i','supabase_db_'+project,'psql','-X','-q','-A','-t','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:query,encoding:'utf8',timeout:20000});if(result.error||result.status!==0)throw Error('Local fixture SQL/readback failed.');return result.stdout.trim()};
 assert.equal(totp('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',59000),'287082','RFC6238 six-digit vector');
 const clients=[];
 for(const role of ['admin','buyer']){
  const client=createClient(supabaseUrl,publishable,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
  const signup=await client.auth.signUp({email:`http058-${role}-${randomUUID()}@example.test`,password:randomBytes(32).toString('base64url')});
  if(signup.error||!signup.data.session||!signup.data.user)throw Error('Local Auth signup did not create a verified personal session.');
  clients.push({client,userId:uuid(signup.data.user.id),token:signup.data.session.access_token});
 }
 const [admin,buyer]=clients;
 const enrollment=await admin.client.auth.mfa.enroll({factorType:'totp',friendlyName:'Disposable HTTP integration factor'});
 if(enrollment.error||!enrollment.data?.totp?.secret)throw Error('Local Auth TOTP enrollment failed.');
 const challenge=await admin.client.auth.mfa.challengeAndVerify({factorId:enrollment.data.id,code:totp(enrollment.data.totp.secret)});
 if(challenge.error)throw Error('Local Auth TOTP challenge failed.');
 const session=await admin.client.auth.getSession();if(!session.data.session)throw Error('Local MFA session missing.');admin.token=session.data.session.access_token;
 const identity=await admin.client.auth.getUser(admin.token);if(identity.error||identity.data.user?.id!==admin.userId)throw Error('Local MFA identity not verified.');
 const claims=JSON.parse(Buffer.from(admin.token.split('.')[1],'base64url').toString('utf8'));assert.equal(claims.aal,'aal2','Real Auth challenge must issue aal2');
 server=spawn(process.execPath,['node_modules/next/dist/bin/next','start','--hostname','127.0.0.1','--port','3581'],{stdio:'ignore',env:{PATH:process.env.PATH,HOME:process.env.HOME,NODE_ENV:'production',NEXT_TELEMETRY_DISABLED:'1',SUPABASE_URL:supabaseUrl,SUPABASE_PUBLISHABLE_KEY:publishable,STANDALONE_CUSTOMERS_ENABLED:'true',STANDALONE_CATALOG_ADMIN_ENABLED:'true',MERCHANT_MEMBER_ADMIN_ENABLED:'true'}});
 let ready=false;for(let attempt=0;attempt<100;attempt++){if(server.exitCode!==null)throw Error('Local API server exited before readiness.');try{const response=await fetch(origin+'/v1/health',{signal:AbortSignal.timeout(1000)});if(response.ok){ready=true;break}}catch{}await new Promise(resolve=>setTimeout(resolve,200))}
 if(!ready)throw Error('Built local API did not become ready. Run npm run build before this test.');
 await call(null,'production/setup?tenant_id='+randomUUID(),undefined,key(),401,'AUTH_REQUIRED');
 const merchant=await call(admin.token,'merchant-bootstrap',{slug:'http058-'+randomBytes(8).toString('hex'),name:'HTTP058 disposable merchant',legal_name:'HTTP058 synthetic business',organization_number:org('999999001'),reason:'Disposable local HTTP integration fixture'});
 const tenant=uuid(merchant.tenant_id);assert.equal(merchant.mode,'production');assert.equal(merchant.sales_paused,true);
 const account=await call(admin.token,'merchant-customers',{tenant_id:tenant,name:'HTTP058 disposable buyer',organization_number:org('999999002')});const accountId=uuid(account.id);
 await call(admin.token,'merchant-customers/'+accountId+'/policy',{tenant_id:tenant,customer_account_id:accountId,version:0,status:'active',purchase_blocked:false,credit_limit_minor:'1000000',terms_version:'http058-v1',review_status:'reviewed',reason:'Reviewed disposable local customer policy',evidence_reference:'HTTP058-LOCAL-POLICY'});
 await call(admin.token,'production/setup',{tenant_id:tenant,version:0,price_authority:'plockivo',credit_authority:'merchant-manual',inventory_authority:'plockivo',billing_authority:'manual-export',activate_production:true,sales_enabled:true,reason:'Explicit disposable standalone production configuration',evidence_reference:'HTTP058-LOCAL-SETUP'});
 const store=await call(admin.token,'production/stores',{tenant_id:tenant,id:null,version:0,name:'HTTP058 local store',code:'HTTP058',sales_paused:false});const storeId=uuid(store.id);
 const projectRow=await call(admin.token,'production/projects',{tenant_id:tenant,id:null,version:0,customer_account_id:accountId,name:'HTTP058 local project',budget_minor:'1000000',active:true});const projectId=uuid(projectRow.id);
 const source=await call(admin.token,'standalone-catalog',{tenant_id:tenant,id:null,version:0,sku:'HTTP058-001',name:'HTTP058 exact-price item',unit:'st',quantity_step:'1',barcode:'HTTP05800001',package_quantity:'1',unit_price_minor:'12345',vat_bps:2500,active:true,self_scan:true});
 const published=await call(admin.token,'production/catalog',{tenant_id:tenant,item_id:uuid(source.id),source_version:source.version,customer_account_id:accountId,version:0});const productId=uuid(published.product_id);
 await call(admin.token,'production/stock',{tenant_id:tenant,store_id:storeId,product_id:productId,version:0,on_hand:'10',reason:'Counted disposable local opening stock',evidence_reference:'HTTP058-LOCAL-STOCK'});
 // Only the scoped business mandate is seeded. Auth users/sessions/tokens above are real Auth API results.
 sql(`insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor,approval_threshold_minor) values('${buyer.userId}','${tenant}','${accountId}','${storeId}','${projectId}','buyer',1000000,1000000);`);
 await call(buyer.token,'production/setup?tenant_id='+tenant,undefined,key(),403,'PERMISSION_DENIED');
 const catalog=await call(buyer.token,'catalog?tenant_id='+tenant+'&q=HTTP05800001');assert(catalog.some(item=>item.id===productId),'Published barcode lookup');
 const cartBody={tenant_id:tenant,customer_account_id:accountId,store_id:storeId,project_id:projectId,id:null,version:0,reference:'HTTP058-ORDER',lines:[{product_id:productId,quantity:'2'}]},cartKey=key();
 const cart=await call(buyer.token,'carts/save',cartBody,cartKey);assert.deepEqual(await call(buyer.token,'carts/save',cartBody,cartKey),cart,'Actual HTTP cart replay');
 const prepared=await call(buyer.token,'carts/'+uuid(cart.id)+'/submit',{version:cart.version});assert.equal(prepared.mode,'production');assert.equal(prepared.quote.total_minor,'30863');assert.equal(prepared.status,'ready_for_confirmation');
 const confirmBody={version:prepared.version,quote_hash:prepared.quote_hash},confirmKey=key();const order=await call(buyer.token,'purchase-intents/'+uuid(prepared.id)+'/confirm',confirmBody,confirmKey);const orderId=uuid(order.id);
 assert.equal(order.total_minor,'30863');assert.deepEqual(await call(buyer.token,'purchase-intents/'+prepared.id+'/confirm',confirmBody,confirmKey),order,'Actual HTTP confirm replay');
 const document=await call(buyer.token,'purchase-intents/'+prepared.id+'/confirmation');assert.equal(document.status,'ready');assert.equal(document.document.content.total_minor,'30863');
 const orderPath='production/orders/'+orderId;
 await call(buyer.token,orderPath+'/complete',{version:0,recipient_reference:'Unauthorized buyer receipt',checked:true},key(),403,'MFA_REQUIRED');
 await call(buyer.token,orderPath+'/billing',undefined,key(),403,'MFA_REQUIRED');
 await call(admin.token,orderPath+'/complete',{version:0,recipient_reference:'HTTP058 checked recipient',checked:true});
 const billing=await call(admin.token,orderPath+'/billing');assert.equal(billing.status,'ready_for_manual_export');
 const ledger=await call(admin.token,orderPath+'/receivables');assert.equal(ledger.balance_minor,'30863');
 const partBody={version:ledger.version,amount_minor:'10000',payment_reference:'HTTP058-PARTIAL',evidence_reference:'HTTP058-LOCAL-BANK-1',reason:'Checked disposable local bank fixture'},partKey=key();
 const [partial,twinPartial]=await Promise.all([call(admin.token,orderPath+'/payments',partBody,partKey),call(admin.token,orderPath+'/payments',partBody,partKey)]);assert.deepEqual(twinPartial,partial,'Concurrent same-key payment replay');assert.equal(partial.paid_minor,'10000');assert.equal(partial.balance_minor,'20863');assert.equal(sql(`select exposure_minor::text from public.customer_accounts where id='${accountId}';`),'20863','Partial payment reduces exposure once');
 assert.deepEqual(await call(admin.token,orderPath+'/payments',partBody,partKey),partial,'Payment command replay');
 await call(admin.token,orderPath+'/payments',{...partBody,amount_minor:'1',payment_reference:'HTTP058-STALE'},key(),409,'VERSION_CONFLICT');
 await call(admin.token,orderPath+'/payments',{...partBody,version:partial.version,amount_minor:'1'},key(),409,'PAYMENT_REFERENCE_CONFLICT');
 const competing=await Promise.all(['HTTP058-FULL-A','HTTP058-FULL-B'].map(async payment_reference=>{const response=await fetch(origin+'/v1/'+orderPath+'/payments',{method:'POST',headers:{Authorization:'Bearer '+admin.token,'Content-Type':'application/json','Idempotency-Key':key()},body:JSON.stringify({...partBody,version:partial.version,amount_minor:'20863',payment_reference,evidence_reference:'HTTP058-LOCAL-BANK-2'}),redirect:'error',signal:AbortSignal.timeout(20000)});return {status:response.status,result:await response.json()}}));
 assert.equal(competing.filter(x=>x.status===200).length,1,'Exactly one competing payment wins');assert.equal(competing.filter(x=>x.status===409&&x.result.error?.code==='VERSION_CONFLICT').length,1,'Other concurrent payment is stale');
 const paid=competing.find(x=>x.status===200).result.data;assert.equal(paid.balance_minor,'0');assert.equal(sql(`select exposure_minor::text from public.customer_accounts where id='${accountId}';`),'0','Full payment clears exposure');
 await call(admin.token,orderPath+'/payments',{...partBody,version:paid.version,amount_minor:'1',payment_reference:'HTTP058-OVERPAY'},key(),409,'PAYMENT_EXCEEDS_BALANCE');
 const receiptId=uuid(partial.receipts.find(receipt=>receipt.payment_reference==='HTTP058-PARTIAL').id),reverseBody={version:paid.version,receipt_id:receiptId,evidence_reference:'HTTP058-LOCAL-CORRECTION',reason:'Corrected disposable local payment registration'},reverseKey=key();
 const reversed=await call(admin.token,orderPath+'/payments/reverse',reverseBody,reverseKey);assert.equal(reversed.balance_minor,'10000');assert.equal(reversed.paid_minor,'20863');
 assert.deepEqual(await call(admin.token,orderPath+'/payments/reverse',reverseBody,reverseKey),reversed,'Reversal command replay');
 await call(admin.token,orderPath+'/payments/reverse',{...reverseBody,version:reversed.version},key(),409,'PAYMENT_ALREADY_REVERSED');
 const readback=JSON.parse(sql(`select jsonb_build_object('exposure',(select exposure_minor::text from public.customer_accounts where id='${accountId}'),'committed',(select committed_minor::text from public.projects where id='${projectId}'),'on_hand',(select on_hand::text from private.production_stock where tenant_id='${tenant}' and store_id='${storeId}' and product_id='${productId}'),'reserved',(select reserved::text from private.production_stock where tenant_id='${tenant}' and store_id='${storeId}' and product_id='${productId}'),'orders',(select count(*) from public.orders where tenant_id='${tenant}'),'reservation_rows',(select count(*) from private.credit_reservations where tenant_id='${tenant}'));`));
 assert.equal(readback.exposure,'10000');assert.equal(readback.committed,'30863');assert.equal(Number(readback.on_hand),8);assert.equal(Number(readback.reserved),0);assert.equal(readback.orders,1);assert.equal(readback.reservation_rows,1);
 const logout=await buyer.client.auth.signOut({scope:'local'});if(logout.error)throw Error('Local test logout failed.');
 const staleClient=createClient(supabaseUrl,publishable,{global:{headers:{Authorization:'Bearer '+buyer.token}},auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});const stale=await staleClient.rpc('get_production_order',{p_order:orderId});assert(stale.error&&['PERMISSION_DENIED','MFA_REQUIRED'].includes(stale.error.message),'Signed JWT from closed Auth session must fail direct RPC');
 console.log('HTTP-PRODUCTION-058 PASS: real Auth signup/TOTP, HTTP API, PostgREST, scoped buyer checkout, exact totals, receipt, manual billing, payments/reversal, permission denials, concurrent payments/replay, closed-session RPC denial and DB aggregates.');
}
try{await main()}catch(error){console.error(error instanceof Error?error.message:'Local HTTP integration failed.');process.exitCode=1}finally{server?.kill('SIGTERM')}
