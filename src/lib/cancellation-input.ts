import {z} from 'zod';
const quantity=z.string().regex(/^(?:0|[1-9]\d{0,5})(?:\.\d{1,6})?$/).refine(q=>/[1-9]/.test(q),'Quantity must be positive');
export const cancellationInput=z.object({version:z.number().int().min(0).max(2147483646),reason:z.string().trim().min(1).max(500),lines:z.array(z.object({product_id:z.uuid(),quantity}).strict()).min(1).max(100)}).strict().refine(v=>new Set(v.lines.map(l=>l.product_id.toLowerCase())).size===v.lines.length,'Duplicate order lines');
