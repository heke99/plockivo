import {z} from 'zod';
const logo=z.string().max(22000).regex(/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/]+={0,2}$/).refine(s=>Buffer.from(s.split(',')[1],'base64').byteLength<=16384).nullable();
export const profileInput=z.object({tenant_id:z.uuid(),version:z.number().int().min(0).max(2147483646),profile:z.object({display_name:z.string().trim().min(1).max(80),primary_color:z.string().regex(/^#[0-9a-fA-F]{6}$/),logo_data_url:logo}).strict()}).strict();
