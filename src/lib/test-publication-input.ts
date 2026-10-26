import {z} from 'zod';
export const testPublicationInput=z.object({
 tenant_id:z.uuid(),version:z.number().int().positive().max(2147483646),customer_account_id:z.uuid(),
}).strict();
