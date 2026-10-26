import {z} from 'zod';
const minor=z.string().regex(/^[0-9]{1,15}$/);
export const customerInvitationSetupInput=z.object({tenant_id:z.uuid(),customer_account_id:z.uuid(),per_purchase_minor:minor,approval_threshold_minor:minor,valid_to:z.iso.datetime({offset:true}),reason:z.string().trim().min(5).max(500)}).strict().refine(v=>/^[0-9]{1,15}$/.test(v.per_purchase_minor)&&/^[0-9]{1,15}$/.test(v.approval_threshold_minor)&&BigInt(v.per_purchase_minor)>0n&&BigInt(v.approval_threshold_minor)<=BigInt(v.per_purchase_minor));
