import {timingSafeEqual} from 'node:crypto';

export function validCronAuthorization(expected:string|undefined,actual:string|null):boolean {
 if(!expected||expected.length<32||!actual)return false;
 const wanted=Buffer.from('Bearer '+expected),received=Buffer.from(actual);
 return wanted.length===received.length&&timingSafeEqual(wanted,received);
}
