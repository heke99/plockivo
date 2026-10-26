import {z} from 'zod';
export const returnInput=z.object({version:z.number().int().min(0).max(2147483646),claim_id:z.uuid(),order_line_id:z.uuid(),quantity:z.string().regex(/^(?:0|[1-9][0-9]{0,13})(?:\.[0-9]{1,6})?$/).refine(v=>Number(v)>0),condition:z.enum(['unopened','opened','damaged','unknown']),reason:z.string().trim().min(1).max(500)}).strict();
