import {z} from 'zod';
const limit=z.union([z.number().int(),z.string().regex(/^[1-9]\d{0,2}$/).transform(Number)]).pipe(z.number().int().min(1).max(100));
export const catalogPageInput=z.object({
 tenant_id:z.uuid(),query:z.string().max(100).default(''),
 after_sku:z.string().min(1).max(80).nullable().default(null),
 after_id:z.uuid().nullable().default(null),limit:limit.default(50),
}).strict().refine(v=>(v.after_sku===null)===(v.after_id===null),'Cursor must include both SKU and ID');
