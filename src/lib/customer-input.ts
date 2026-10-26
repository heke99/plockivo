import {z} from 'zod';
export function validOrganizationNumber(value:string){
 if(!/^[0-9]{10}$/.test(value)||Number(value[2])<2)return false;
 const sum=[...value].reduce((n,c,i)=>{const d=Number(c)*(i%2===0?2:1);return n+Math.floor(d/10)+d%10},0);
 return sum%10===0;
}
// Format/checksum only: does not verify existence, company form or creditworthiness.
export const customerCreateInput=z.object({tenant_id:z.uuid(),name:z.string().trim().min(1).max(160),organization_number:z.string().regex(/^[0-9]{6}-?[0-9]{4}$/).transform(s=>s.replace('-','')).refine(validOrganizationNumber)}).strict();
