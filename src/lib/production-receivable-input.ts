import {z} from 'zod';
const version=z.number().int().min(0).max(2147483646);
const evidence_reference=z.string().trim().min(1).max(200);
const reason=z.string().trim().min(10).max(500);
export const productionPaymentInput=z.object({version,amount_minor:z.string().regex(/^[0-9]{1,15}$/).refine(s=>/^[0-9]{1,15}$/.test(s)&&BigInt(s)>0n),payment_reference:z.string().trim().min(1).max(120),evidence_reference,reason}).strict();
export const productionPaymentReversalInput=z.object({version,receipt_id:z.uuid(),evidence_reference,reason}).strict();
