import {z} from 'zod';
const quantity=z.string().regex(/^[0-9]{1,12}(\.[0-9]{1,6})?$/).refine(s=>Number(s)>0);
const lines=z.array(z.object({product_id:z.uuid(),quantity}).strict()).min(1).max(100).refine(a=>new Set(a.map(x=>x.product_id)).size===a.length);
export const fulfillmentVersionInput=z.object({version:z.number().int().nonnegative().max(2147483646)}).strict();
export const inspectionInput=z.object({version:z.number().int().nonnegative().max(2147483646),result:z.enum(['passed','blocked']),reason:z.string().trim().min(1).max(500),recipient_reference:z.string().trim().min(1).max(100),lines}).strict();
export const claimInput=z.object({version:z.number().int().nonnegative().max(2147483646),recipient_reference:z.string().trim().min(1).max(100),lines}).strict();
