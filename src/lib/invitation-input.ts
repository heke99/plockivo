import {z} from 'zod';
const minor=z.string().regex(/^[0-9]{1,15}$/);
export const invitationInput=z.object({membership_id:z.uuid(),recipient_email:z.email().max(254).transform(s=>s.trim().toLowerCase()),role:z.enum(['buyer','approver']),store_id:z.uuid().nullable(),project_id:z.uuid().nullable(),per_purchase_minor:minor,approval_threshold_minor:minor,valid_to:z.iso.datetime({offset:true})}).strict().refine(v=>/^[0-9]{1,15}$/.test(v.per_purchase_minor)&&/^[0-9]{1,15}$/.test(v.approval_threshold_minor)&&BigInt(v.per_purchase_minor)>0n&&BigInt(v.approval_threshold_minor)<=BigInt(v.per_purchase_minor));
export const invitationTokenInput=z.object({token:z.string().regex(/^[a-f0-9]{64}$/)}).strict();
