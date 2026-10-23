import {createClient} from '@supabase/supabase-js';
import {start} from 'workflow/api';
import {processOutbox} from '@/workflows/outbox';
import {validCronAuthorization} from '@/lib/cron';
export const runtime='nodejs';
export const dynamic='force-dynamic';
export async function GET(req:Request){
 if(!validCronAuthorization(process.env.CRON_SECRET,req.headers.get('authorization')))return new Response(null,{status:401,headers:{'Cache-Control':'no-store'}});
 if(!process.env.SUPABASE_URL||!process.env.SUPABASE_SECRET_KEY)return Response.json({error:'WORKER_NOT_CONFIGURED'},{status:503,headers:{'Cache-Control':'no-store'}});
 const db=createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SECRET_KEY,{global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000)})},auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await db.rpc('pending_test_jobs');
 if(error){console.error({event:'test_outbox_scan_failed',code:error.code});return Response.json({error:'WORKER_SCAN_FAILED'},{status:503,headers:{'Cache-Control':'no-store'}});}
 if(!Array.isArray(data)||!data.every(id=>typeof id==='string'&&/^[a-f0-9-]{36}$/.test(id)))return Response.json({error:'WORKER_SCAN_INVALID'},{status:503,headers:{'Cache-Control':'no-store'}});
 const results=await Promise.allSettled((data as string[]).slice(0,20).map(async jobId=>{
  const run=await start(processOutbox,[jobId],{region:'arn1'});
  return {jobId,runId:run.runId};
 }));
 const runs=results.flatMap(x=>x.status==='fulfilled'?[x.value]:[]),failed=results.filter(x=>x.status==='rejected').length;
 console.info({event:'test_outbox_dispatched',started:runs.length,failed,runs});
 return Response.json({started:runs.length,failed,runs},{status:failed?503:200,headers:{'Cache-Control':'no-store'}});
}
