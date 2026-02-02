import { createClient } from '@supabase/supabase-js'

/**
 * Creates a server-side Supabase client with service role key.
 * Use this for operations that require elevated permissions like
 * generating signed URLs for private storage buckets.
 *
 * WARNING: Never expose this client or the service key in client-side code.
 */
export function createServerClient() {
  const supabaseUrl = process.env.SUPABASE_URL
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error('Missing Supabase environment variables: SUPABASE_URL and SUPABASE_SERVICE_KEY are required')
  }

  return createClient(supabaseUrl, supabaseServiceKey)
}
