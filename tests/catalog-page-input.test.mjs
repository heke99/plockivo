import {test} from 'node:test';import assert from 'node:assert/strict';
import {catalogPageInput} from '../src/lib/catalog-page-input.ts';
const tenant_id='a0000000-0000-4000-8000-000000000001';
test('catalog page defaults bounded page with no cursor',()=>{
 assert.deepEqual(catalogPageInput.parse({tenant_id}),{tenant_id,query:'',after_sku:null,after_id:null,limit:50});
 for(const value of [1,100,'1','100'])assert.equal(catalogPageInput.parse({tenant_id,limit:value}).limit,Number(value));
});
test('catalog page accepts cursor pairs and preserves literal query characters',()=>{
 const parsed=catalogPageInput.parse({tenant_id,query:' %_\\ ',after_sku:'SKU-%_',after_id:tenant_id});
 assert.equal(parsed.query,' %_\\ ');assert.equal(parsed.after_sku,'SKU-%_');
});
test('catalog page rejects oversized search, unpaired cursors, injected authority and bad limits',()=>{
 for(const extra of [{query:'x'.repeat(101)},{after_sku:'SKU'},{after_id:tenant_id},{after_sku:'',after_id:tenant_id},{after_sku:'x'.repeat(81),after_id:tenant_id},{after_sku:'SKU',after_id:'bad'},{mode:'production'},...[-1,0,101,1.5,'','1e2','0x10','01',true,null].map(limit=>({limit}))])assert.equal(catalogPageInput.safeParse({tenant_id,...extra}).success,false,JSON.stringify(extra));
});
