import {createHash} from 'node:crypto';
import {z} from 'zod';
import {standaloneCatalogInput} from './standalone-catalog-input.ts';
// Reuse every field validator. The single-row id/version refinement is enforced
// by constructing new rows with id:null and version:0 below.
const newItemInput=z.object({...standaloneCatalogInput.shape}).omit({tenant_id:true,id:true,version:true}).strict();
export const catalogBatchInput=z.object({tenant_id:z.uuid(),items:z.array(newItemInput).min(1).max(10)}).strict();
const parentKeyInput=z.string().min(16).max(128).regex(/^[a-zA-Z0-9:_-]+$/);
export type CatalogNewRow=z.infer<typeof standaloneCatalogInput>;
const knownErrors:Record<string,string>={
 CATALOG_DUPLICATE:'Artikelnummer eller streckkod används redan hos handlaren.',
 VERSION_CONFLICT:'Artikeln har ändrats. Kontrollera aktuell version.',
 IDEMPOTENCY_CONFLICT:'Samma begäran har redan använts med ett annat innehåll.',
 PERMISSION_DENIED:'Du saknar behörighet att hantera handlarens artiklar.',
 MFA_REQUIRED:'Bekräfta din inloggning med en engångskod.',
 AUTH_REQUIRED:'Logga in för att fortsätta.',
 MEMBERSHIP_INACTIVE:'Ditt mandat är inte aktivt.',
 VALIDATION_ERROR:'Kontrollera artikeluppgifterna.',
 RATE_LIMITED:'För många anrop. Vänta innan du försöker igen.',
};
export type CatalogBatchFailure={index:number;code:string;message:string;outcome:'rejected'|'unknown'};
export type CatalogBatchResult<T>={status:'completed'|'stopped';atomic:false;saved:Array<{index:number;data:T}>;failure:CatalogBatchFailure|null;remaining:number};
/** Stable across retries. The parent key and complete row order must be retained. */
export function catalogBatchRowKey(parentKey:string,index:number){
 parentKeyInput.parse(parentKey);
 if(!Number.isInteger(index)||index<1||index>10)throw Error('Invalid batch row index');
 return 'catalog-batch:'+createHash('sha256').update(parentKey+':'+index).digest('hex');
}
/** Validate the entire request before effects. Sequential independent row commits;
 * stop at the first rejection or uncertain outcome. Retry the WHOLE unchanged
 * batch with its ORIGINAL parent key so committed rows replay safely in SQL. */
export async function runCatalogBatch<T>(raw:unknown,parentKey:string,save:(input:CatalogNewRow,key:string)=>Promise<{data:T|null;error:unknown}>):Promise<CatalogBatchResult<T>>{
 const batch=catalogBatchInput.parse(raw);parentKeyInput.parse(parentKey);
 const rows=batch.items.map(item=>standaloneCatalogInput.parse({...item,tenant_id:batch.tenant_id,id:null,version:0}));
 const saved:Array<{index:number;data:T}>=[];
 for(let i=0;i<rows.length;i++){
  try{
   const result=await save(rows[i],catalogBatchRowKey(parentKey,i+1));
   if(result.error)throw result.error;
   if(result.data===null||result.data===undefined)throw Error('Unknown save outcome');
   saved.push({index:i+1,data:result.data});
  }catch(error){
   const candidate=error&&typeof error==='object'&&'message'in error&&typeof error.message==='string'?error.message:'';
   const known=Object.prototype.hasOwnProperty.call(knownErrors,candidate);
   return {status:'stopped',atomic:false,saved,failure:{index:i+1,code:known?candidate:'UNKNOWN_OUTCOME',message:known?knownErrors[candidate]:'Utfallet för raden kunde inte bekräftas. Kontrollera artikellistan och försök med samma oförändrade import och begäran.',outcome:known?'rejected':'unknown'},remaining:rows.length-i-1};
  }
 }
 return {status:'completed',atomic:false,saved,failure:null,remaining:0};
}
