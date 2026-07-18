import db from '../supabase/supabaseClient.js';
import { storyImage } from '../utils/renderUtils.js';

const HOME_TABLE = 'homepage_featured_content';

function normalizeStory(item) {
  if (!item) return null;

  const media = Array.isArray(item.media_library)
    ? item.media_library[0]
    : item.media_library;

  return {
    ...item,
    image_url: storyImage(item),
    image_alt: media?.alt_text || item.headline || item.title || '',
    image_caption: media?.caption || '',
    image_object_position: media?.object_position || '50% 50%'
  };
}

async function getContentByType(contentType, limit) {
  const { data, error } = await db
    .from(HOME_TABLE)
    .select('*, media_library(*)')
    .eq('content_type', contentType)
    .eq('is_active', true)
    .order('display_order', { ascending: true })
    .limit(limit);

  if (error) {
    console.error(`${contentType} content error:`, error);
    return [];
  }

  return (data || []).map(normalizeStory);
}

export async function getFeaturedStory() {
  const stories = await getContentByType('FEATURED', 1);
  return stories[0] || null;
}

export async function getStoryGrid() {
  return getContentByType('SECONDARY', 3);
}

export async function getNewsRail() {
  return getContentByType('NEWS', 4);
}
