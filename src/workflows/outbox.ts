import { createClient } from '@supabase/supabase-js';
import { FatalError } from 'workflow';
export async function processOutbox(id:string){
 'use workflow';
 return await processJob(id);
}
async function processJob(id:string){
 'use step';
 const key=process.env.SUPABASE_SECRET_KEY;
 if(!key||!process.env.SUPABASE_URL)throw new FatalError('Worker connection is not configured');
 const db=createClient(process.env.SUPABASE_URL,key,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await db.rpc('process_test_job',{p_id:id});
 if(error)throw new FatalError('Job requires review; inspect durable outbox state');
 return data;
}
