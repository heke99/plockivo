const fs=require('node:fs');
const assert=require('node:assert/strict');
(async()=>{
 const access=JSON.parse(fs.readFileSync(process.env.WORKER_TEST_ACCESS_FILE??'/tmp/plockivo-worker-access.json','utf8'));
 const base=process.env.WORKER_TEST_API_URL??'https://plockivo-api.vercel.app';
 const mode=process.argv[2]??'auth';
 async function call(authorization){
  const r=await fetch(base+'/internal/outbox',{headers:{'x-vercel-protection-bypass':access.bypass,...(authorization?{Authorization:authorization}:{})},signal:AbortSignal.timeout(60000)});
  const body=await r.text();return {status:r.status,body:body?JSON.parse(body):null};
 }
 if(mode==='auth'){
  for(const auth of [undefined,'Bearer wrong']){const r=await call(auth);assert.equal(r.status,401);}
  console.log('PASS: missing/wrong Cron authorization rejected');
 }else if(mode==='parallel'){
  const results=await Promise.all([call('Bearer '+access.cron),call('Bearer '+access.cron)]);
  for(const r of results)assert.equal(r.status,200,JSON.stringify(r));
  console.log(JSON.stringify({mode,results}));
 }else{
  const r=await call('Bearer '+access.cron);assert.equal(r.status,200,JSON.stringify(r));
  if(mode==='empty')assert.equal(r.body.started,0);
  console.log(JSON.stringify({mode,...r}));
 }
})().catch(e=>{console.error(e.message);process.exit(1)});
