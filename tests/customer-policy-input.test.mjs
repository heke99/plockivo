import {test} from 'node:test';import assert from 'node:assert/strict';
import {customerPolicyInput} from '../src/lib/customer-policy-input.ts';
const id='a0000000-0000-4000-8000-000000000001';
const body={tenant_id:id,customer_account_id:id,version:0,status:'suspended',purchase_blocked:true,credit_limit_minor:'0',terms_version:null,review_status:'pending',reason:'Manuellt dokumenterat beslut',evidence_reference:'Kundakt 123'};
test('customer policies preserve exact limits and require explicit reviewed activation',()=>{
 assert.deepEqual(customerPolicyInput.parse(body),body);
 assert(customerPolicyInput.safeParse({...body,status:'active',review_status:'reviewed',terms_version:'v1',credit_limit_minor:'999999999999',purchase_blocked:false}).success);
 for(const extra of [{status:'active'},{status:'active',review_status:'reviewed'},{credit_limit_minor:'1'},{terms_version:''},{reason:'kort'},{evidence_reference:''},{version:-1},{version:1.5},{version:2147483647}])assert.equal(customerPolicyInput.safeParse({...body,...extra}).success,false);
});
test('customer policies reject approximate money and authority injection',()=>{
 for(const credit_limit_minor of [1,'1.5','01','1e3','-1','1000000000000'])assert.equal(customerPolicyInput.safeParse({...body,credit_limit_minor}).success,false);
 for(const extra of [{actor_id:id},{exposure_minor:'0'},{mode:'production'},{externally_verified:true},{review_status:'approved'}])assert.equal(customerPolicyInput.safeParse({...body,...extra}).success,false);
});
test('manual review does not silently activate or unblock account',()=>{
 const parsed=customerPolicyInput.parse({...body,review_status:'reviewed',credit_limit_minor:'100',terms_version:'v1'});
 assert.equal(parsed.status,'suspended');assert.equal(parsed.purchase_blocked,true);
 const zeroCredit=customerPolicyInput.parse({...body,status:'active',review_status:'reviewed',terms_version:'v1',purchase_blocked:true});
 assert.equal(zeroCredit.credit_limit_minor,'0');assert.equal(zeroCredit.purchase_blocked,true);
});
