import { createClient } from '@supabase/supabase-js';
import { config } from './config';
export function userDatabase(token: string) {
  const env = config();
  return createClient(env.SUPABASE_URL, env.SUPABASE_PUBLISHABLE_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` }, fetch: (url, options) => fetch(url, { ...options, signal: AbortSignal.timeout(15000) }) },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}
