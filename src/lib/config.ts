import { z } from 'zod';
const schema = z.object({ SUPABASE_URL: z.url(), SUPABASE_PUBLISHABLE_KEY: z.string().min(20) });
export function config() { return schema.parse(process.env); }
