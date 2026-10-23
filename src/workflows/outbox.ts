import { createClient } from '@supabase/supabase-js';
import { FatalError, RetryableError } from 'workflow';
import {workerErrorKind} from '@/lib/worker-errors';
export async function processOutbox(id:string){
 'use workflow';
 return await processJob(id);
}
async function processJob(id:string){
 'use step';
 console.info({event:'test_outbox_step_started',jobId:id});
 const key=process.env.SUPABASE_SECRET_KEY;
 if(!key||!process.env.SUPABASE_URL)throw new FatalError('Worker connection is not configured');
 const db=createClient(process.env.SUPABASE_URL,key,{global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000)})},auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error,status}=await db.rpc('process_test_job',{p_id:id});
 if(error){
  const kind=workerErrorKind(error,status);console.warn({event:'test_outbox_step_failed',jobId:id,kind,code:error.code});
  if(kind==='fatal')throw new FatalError('Test job requires operational review');
  throw new RetryableError('Temporary worker connection failure',{retryAfter:'5s'});
 }
 console.info({event:'test_outbox_step_finished',jobId:id,status:data?.status});
 return data;
}
processJob.maxRetries=3;
