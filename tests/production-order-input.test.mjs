import {test} from 'node:test';import assert from 'node:assert/strict';
import {productionCompleteInput,productionCancelInput} from '../src/lib/production-order-input.ts';
import {knownSqlErrorCode,failure} from '../src/lib/errors.ts';
test('physical completion requires explicit check, recipient and current version',()=>{
 assert.deepEqual(productionCompleteInput.parse({version:0,recipient_reference:'  Mottagare  ',checked:true}),{version:0,recipient_reference:'Mottagare',checked:true});
 for(const body of [{version:0,recipient_reference:'A',checked:false},{version:0,recipient_reference:' ',checked:true},{version:-1,recipient_reference:'A',checked:true},{version:0,recipient_reference:'A',checked:true,quantity:'2'},{version:0,recipient_reference:'A',checked:true,actor_id:'injected'}])assert.equal(productionCompleteInput.safeParse(body).success,false);
});
test('production cancellation accepts only version and explicit bounded reason',()=>{
 assert(productionCancelInput.safeParse({version:1,reason:'Kunden avbröt köpet'}).success);
 for(const body of [{version:0,reason:''},{version:'0',reason:'A'},{version:2147483647,reason:'A'},{version:0,reason:'x'.repeat(501)},{version:0,reason:'A',release_credit:true}])assert.equal(productionCancelInput.safeParse(body).success,false);
});
test('production SQL codes are matched exactly and unknown errors are sanitized',async()=>{
 for(const code of ['STOCK_UNAVAILABLE','INVENTORY_CONFLICT','FULFILLMENT_REQUIRED','FULFILLMENT_STATE_CONFLICT','IDEMPOTENCY_CONFLICT','MFA_REQUIRED']){
  assert.equal(knownSqlErrorCode({message:code}),code);
  const response=failure(code,'correlation',409);const body=await response.json();assert.equal(body.error.code,code);assert.notEqual(body.error.message,undefined);
 }
 for(const error of [{message:'private stack STOCK_UNAVAILABLE'},{message:'secret data'},null,'STOCK_UNAVAILABLE',{message:'__proto__'}])assert.equal(knownSqlErrorCode(error),null);
 const response=failure(knownSqlErrorCode({message:'private stack'})??'INTERNAL_ERROR','correlation',500);
 assert.equal((await response.text()).includes('private stack'),false);
});
