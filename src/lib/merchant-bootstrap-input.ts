import {z} from 'zod';
import {validOrganizationNumber} from './customer-input.ts';
const reserved=new Set(['app','api','admin','auth','www','support','status','mail']);
export const merchantBootstrapInput=z.object({
 slug:z.string().trim().toLowerCase().regex(/^[a-z][a-z0-9-]{2,40}$/).refine(s=>!reserved.has(s)),
 name:z.string().trim().min(1).max(160),
 legal_name:z.string().trim().min(1).max(200),
 organization_number:z.string().regex(/^[0-9]{6}-?[0-9]{4}$/).transform(s=>s.replace('-','')).refine(validOrganizationNumber),
 reason:z.string().trim().min(5).max(500),
}).strict();
