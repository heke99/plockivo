import {z} from 'zod';
export const customerPolicyInput=z.object({
 tenant_id:z.uuid(),customer_account_id:z.uuid(),version:z.number().int().min(0).max(2147483646),
 status:z.enum(['pending','active','suspended']),purchase_blocked:z.boolean(),
 credit_limit_minor:z.string().regex(/^(0|[1-9]\d{0,11})$/),
 terms_version:z.string().trim().min(1).max(100).nullable(),review_status:z.enum(['pending','reviewed']),
 reason:z.string().trim().min(10).max(1000),evidence_reference:z.string().trim().min(1).max(200),
}).strict().refine(v=>v.status!=='active'||(v.review_status==='reviewed'&&v.terms_version!==null),'Active customers require review and terms')
.refine(v=>v.credit_limit_minor==='0'||v.review_status==='reviewed','Credit requires explicit manual review');
