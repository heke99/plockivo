import {timingSafeEqual} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';
import {start} from 'workflow/api';
import {processOutbox} from '@/workflows/outbox';
export const runtime='nodejs';
export const dynamic='force-dynamic';
export async function GET(req:Request){
 const expected=process.env.CRON_SECRET,actual=req.headers.get('authorization');
 if(!expected||!actual||Buffer.byteLength(actual)!==Buffer.byteLength('Bearer '+expected)||!timingSafeEqual(Buffer.from(actual),Buffer.from('Bearer '+expected)))return new Response(null,{status:401});
 if(!process.env.SUPABASE_URL||!process.env.SUPABASE_SECRET_KEY)return Response.json({error:'WORKER_NOT_CONFIGURED'},{status:503});
 const db=createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await db.rpc('pending_test_jobs');
 if(error)return new Response(null,{status:503});
 const results=await Promise.allSettled((data as string[]).slice(0,20).map(id=>start(processOutbox,[id])));
 return Response.json({started:results.filter(x=>x.status==='fulfilled').length,failed:results.filter(x=>x.status==='rejected').length},{headers:{'Cache-Control':'no-store'}});
}
