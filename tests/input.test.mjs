import {test} from 'node:test';
import assert from 'node:assert/strict';
import {prepareInput,confirmInput,keyInput,cartInput,cartSubmitInput} from '../src/lib/input.ts';
const id='00000000-0000-4000-8000-000000000001';
const body={tenant_id:id,customer_account_id:id,store_id:id,project_id:id,reference:'TEST',lines:[{product_id:id,quantity:'2.500000'}]};
test('business amounts and actor cannot be injected',()=>{assert(prepareInput.safeParse(body).success);for(const extra of [{actor_id:id},{price:0},{role:'admin'}])assert(!prepareInput.safeParse({...body,...extra}).success)});
test('exact decimal representation and bounded payload',()=>{for(const quantity of ['1e9','-1','NaN','1.0000001','9999999','1,5'])assert(!prepareInput.safeParse({...body,lines:[{product_id:id,quantity}]}).success);assert(!prepareInput.safeParse({...body,lines:Array(101).fill(body.lines[0])}).success)});
test('confirmation requires immutable hash, version and valid idempotency key',()=>{assert(!confirmInput.safeParse({version:1}).success);assert(!confirmInput.safeParse({version:0,quote_hash:'a'.repeat(32)}).success);assert(!keyInput.safeParse('short').success);assert(!keyInput.safeParse('unsafe\nheader-value').success)});

test('draft cart permits empty lines/reference but requires explicit revision and excludes actor',()=>{const draft={...body,id:null,version:0,reference:'',lines:[]};assert(cartInput.safeParse(draft).success);for(const extra of [{actor_id:id},{version:-1},{lines:Array(101).fill(body.lines[0])}])assert(!cartInput.safeParse({...draft,...extra}).success);assert(!cartSubmitInput.safeParse({version:0}).success)});
