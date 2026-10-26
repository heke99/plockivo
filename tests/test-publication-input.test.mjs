import {test} from 'node:test';import assert from 'node:assert/strict';
import {testPublicationInput} from '../src/lib/test-publication-input.ts';
const id='a0000000-0000-4000-8000-000000000001';
const body={tenant_id:id,version:1,customer_account_id:id};
test('test publication accepts only explicit versioned source and account',()=>{
 assert.deepEqual(testPublicationInput.parse(body),body);
 for(const patch of [{version:0},{version:-1},{version:'1'},{version:1.1},{version:2147483647},{customer_account_id:null},{tenant_id:'bad'}])assert.equal(testPublicationInput.safeParse({...body,...patch}).success,false);
});
test('test publication rejects client supplied authority or copied pricing',()=>{
 for(const patch of [{mode:'production'},{actor_id:id},{unit_price_minor:'1'},{vat_bps:0},{product_id:id},{source_item_id:id},{active:true},{self_scan:true},{force:true}])assert.equal(testPublicationInput.safeParse({...body,...patch}).success,false);
 for(const key of Object.keys(body)){const partial={...body};delete partial[key];assert.equal(testPublicationInput.safeParse(partial).success,false)}
});
