import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !anonKey) {
  throw new Error(
    'Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY. Copy .env.example to .env.local and fill them in.',
  )
}
if (!/^https?:\/\//.test(url)) {
  throw new Error('VITE_SUPABASE_URL must be your project URL, e.g. https://<ref>.supabase.co (not a key).')
}
if (anonKey.startsWith('sb_secret_')) {
  throw new Error(
    'VITE_SUPABASE_ANON_KEY is a SECRET key. It would be shipped to the browser and bypass RLS. Use the publishable key.',
  )
}

export const supabase = createClient(url, anonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})
