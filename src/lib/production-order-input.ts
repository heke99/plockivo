import {z} from 'zod';
const version=z.number().int().min(0).max(2147483646);
export const productionCompleteInput=z.object({version,recipient_reference:z.string().trim().min(1).max(100),checked:z.literal(true)}).strict();
export const productionCancelInput=z.object({version,reason:z.string().trim().min(1).max(500)}).strict();
