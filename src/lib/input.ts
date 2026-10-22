import { z } from 'zod';
const uuid=z.uuid();
export const prepareInput=z.object({tenant_id:uuid,customer_account_id:uuid,store_id:uuid,project_id:uuid,reference:z.string().trim().min(1).max(100),lines:z.array(z.object({product_id:uuid,quantity:z.string().regex(/^(?:0|[1-9]\d{0,5})(?:\.\d{1,6})?$/)}).strict()).min(1).max(100)}).strict();
export const confirmInput=z.object({version:z.number().int().positive(),quote_hash:z.string().regex(/^[a-f0-9]{32}$/)}).strict();
export const approvalInput=z.object({version:z.number().int().positive(),decision:z.enum(['approved','rejected'])}).strict();
export const keyInput=z.string().min(16).max(128).regex(/^[a-zA-Z0-9:_-]+$/);
export const idInput=uuid;
