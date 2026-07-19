/* global supabase */

const SUPABASE_URL = 'https://ingbnzsiabtttijddenn.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_jaruEYItuMtUUgyQ_xfFMg_VH_ZWUsW';

if (!window.supabase || typeof window.supabase.createClient !== 'function') {
  throw new Error(
    'Supabase library is missing. Load @supabase/supabase-js before supabaseClient.js.'
  );
}

const supabaseClient = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_ANON_KEY
);

window.supabaseClient = supabaseClient;

export { supabaseClient, supabaseClient as supabase };
export default supabaseClient;
