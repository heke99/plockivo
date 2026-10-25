import {z} from 'zod';
export const memberRevokeInput=z.object({tenant_id:z.uuid(),version:z.number().int().nonnegative().max(2147483646)}).strict();
