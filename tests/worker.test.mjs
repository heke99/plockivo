import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validCronAuthorization} from '../src/lib/cron.ts';
import {workerErrorKind} from '../src/lib/worker-errors.ts';

test('cron rejects absent, weak, malformed and multibyte credentials',()=>{
 const key='test-only-'.repeat(5);
 assert(validCronAuthorization(key,'Bearer '+key));
 for(const actual of [null,'','bearer '+key,'Bearer '+key+'x','Bearer '+'å'.repeat(key.length)])assert(!validCronAuthorization(key,actual));
 assert(!validCronAuthorization(undefined,'Bearer '+key));
 assert(!validCronAuthorization('short','Bearer short'));
});
test('temporary connection and database contention are retryable',()=>{
 for(const error of [{code:'40001'},{code:'40P01'},{message:'TypeError: fetch failed'},{code:'57014'}])assert.equal(workerErrorKind(error,503),'retryable');
});
test('business and credential failures stop the workflow instead of automatic step replay',()=>{
 for(const message of ['NOT_FOUND','PERMISSION_DENIED','INTEGRATION_NOT_READY'])assert.equal(workerErrorKind({message}),'fatal');
 for(const code of ['42501','PGRST202','PGRST301'])assert.equal(workerErrorKind({code}),'fatal');
 assert.equal(workerErrorKind({},401),'fatal');assert.equal(workerErrorKind({},403),'fatal');
});
