import db from '../supabase/supabaseClient.js';

export async function getNavigationRegionItems(regionCode) {
  const { data, error } = await db
    .from('navigation_items')
    .select('*, navigation_regions!inner(region_code)')
    .eq('is_active', true)
    .eq('navigation_regions.region_code', regionCode)
    .order('display_order', { ascending: true });

  if (error) {
    console.error(`Navigation region ${regionCode} error:`, error);
    return [];
  }

  return data || [];
}

export async function getNavigationCampaigns() {
  const now = new Date().toISOString();

  const { data, error } = await db
    .from('navigation_campaigns')
    .select('*, media_library(*)')
    .eq('is_active', true)
    .or(`start_date.is.null,start_date.lte.${now}`)
    .or(`end_date.is.null,end_date.gte.${now}`)
    .order('display_order', { ascending: true })
    .limit(1);

  if (error) {
    console.error('Navigation campaign error:', error);
    return [];
  }

  return data || [];
}

export async function getNavigationCTAs() {
  const { data, error } = await db
    .from('navigation_cta_links')
    .select('*')
    .eq('is_active', true)
    .order('display_order', { ascending: true })
    .limit(1);

  if (error) {
    console.error('Navigation CTA error:', error);
    return [];
  }

  return data || [];
}
