import {test} from 'node:test';import assert from 'node:assert/strict';
import {runCatalogBatch,catalogBatchRowKey} from '../src/lib/catalog-batch.ts';
const tenant='a0000000-0000-4000-8000-000000000001',key='batch-request-original-key';
const item={sku:'SKU-1',name:'Artikel',unit:'st',quantity_step:'1',barcode:null,package_quantity:'1',unit_price_minor:'1230',vat_bps:2500,active:true,self_scan:false};
const batch=(items=[item,{...item,sku:'SKU-2'}])=>({tenant_id:tenant,items});
test('catalog batch validates every row and parent key before any save',async()=>{
 let calls=0;const save=async()=>{calls++;return {data:{},error:null}};
 for(const body of [batch([]),batch(Array(11).fill(item)),batch([item,{...item,unit_price_minor:'1.25'}]),batch([item,{...item,tenant_id:tenant}]),batch([{...item,id:null}]),batch([{...item,version:0}]),{...batch(),actor_id:tenant}])await assert.rejects(runCatalogBatch(body,key,save));
 await assert.rejects(runCatalogBatch(batch(),'bad',save));assert.equal(calls,0);
});
test('catalog batch supplies same tenant and fixed new-row fields to save in order',async()=>{
 const calls=[];const result=await runCatalogBatch(batch(),key,async(body,rowKey)=>{calls.push({body,rowKey});return {data:{id:body.sku},error:null}});
 assert.equal(result.status,'completed');assert.equal(result.atomic,false);assert.deepEqual(result.saved.map(x=>x.index),[1,2]);assert.equal(result.remaining,0);
 for(const call of calls){assert.equal(call.body.tenant_id,tenant);assert.equal(call.body.id,null);assert.equal(call.body.version,0)}
 assert.notEqual(calls[0].rowKey,calls[1].rowKey);assert.equal(calls[0].rowKey,catalogBatchRowKey(key,1));assert.equal(calls[0].rowKey.length<129,true);
});
test('catalog batch stops on conflict or tenant permission failure and sanitizes errors',async()=>{
 for(const code of ['CATALOG_DUPLICATE','IDEMPOTENCY_CONFLICT','PERMISSION_DENIED','MFA_REQUIRED']){
  let calls=0;const result=await runCatalogBatch(batch([item,{...item,sku:'2'},{...item,sku:'3'}]),key,async()=>++calls===1?{data:{id:'saved'},error:null}:{data:null,error:{message:code,details:'private'}});
  assert.equal(calls,2);assert.equal(result.saved.length,1);assert.equal(result.failure.index,2);assert.equal(result.failure.code,code);assert.equal(result.failure.outcome,'rejected');assert.equal(result.remaining,1);assert.equal(JSON.stringify(result).includes('private'),false);
 }
});
test('unknown result stops immediately; retry unchanged whole batch replays commit after timeout',async()=>{
 const committed=new Map();let first=true,calls=0;
 const save=async(body,rowKey)=>{calls++;if(committed.has(rowKey))return {data:committed.get(rowKey),error:null};const result={id:body.sku};committed.set(rowKey,result);if(first){first=false;throw Error('network private response lost after commit')}return {data:result,error:null}};
 const failed=await runCatalogBatch(batch(),key,save);assert.equal(calls,1);assert.equal(failed.failure.outcome,'unknown');assert.equal(failed.remaining,1);assert.equal(failed.saved.length,0);assert.equal(JSON.stringify(failed).includes('private'),false);
 const retried=await runCatalogBatch(batch(),key,save);assert.equal(retried.status,'completed');assert.equal(committed.size,2);assert.equal(calls,3);
});
test('empty save response is unknown and does not advance',async()=>{
 let calls=0;const r=await runCatalogBatch(batch(),key,async()=>{calls++;return {data:null,error:null}});assert.equal(calls,1);assert.equal(r.failure.code,'UNKNOWN_OUTCOME');
});
