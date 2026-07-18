import db from '../supabase/supabaseClient.js';

function normalizeItem(item) {
  const media = item?.media_library;
  const mediaRecord = Array.isArray(media) ? media[0] : media;
  return {
    ...item,
    image_url: mediaRecord?.file_url || '',
    image_alt: mediaRecord?.alt_text || item?.headline || ''
  };
}

export async function getPhase2Section(sectionCode) {
  const { data, error } = await db
    .from('homepage_section_items')
    .select('*, homepage_sections!inner(section_code), media_library(*)')
    .eq('homepage_sections.section_code', sectionCode)
    .eq('is_active', true)
    .order('display_order', { ascending: true });

  if (error) {
    console.error(`Phase 2 section ${sectionCode} error:`, error);
    return [];
  }

  return (data || []).map(normalizeItem);
}

export async function getAllPhase2Sections() {
  const sectionCodes = [
    'QUICK_ACTIONS',
    'UPCOMING_EVENTS',
    'TANDEM_INTRO',
    'LATEST_RESULTS',
    'TEAM_STORY',
    'JOIN_SUPPORT',
    'PARTNERS'
  ];

  const results = await Promise.all(
    sectionCodes.map(async (code) => [code, await getPhase2Section(code)])
  );

  return Object.fromEntries(results);
}
