/* global supabaseClient */


const SUPABASE_URL =
    'https://ingbnzsiabtttijddenn.supabase.co'

const SUPABASE_ANON_KEY =
    'sb_publishable_jaruEYItuMtUUgyQ_xfFMg_VH_ZWUsW'

const supabaseClient =
    window.supabase.createClient(
        SUPABASE_URL,
        SUPABASE_ANON_KEY
    )

window.supabaseClient =
    supabaseClient

export default supabaseClient