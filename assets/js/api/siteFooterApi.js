import db from '../supabase/supabaseClient.js';

export async function getPublicSiteSettings() {
  const { data, error } = await db
    .from('site_settings')
    .select('setting_code, setting_value, display_label, display_order')
    .eq('is_public', true)
    .order('display_order', { ascending: true });

  if (error) {
    console.error('Public site settings error:', error);
    return [];
  }

  return data || [];
}

export async function getPublicSocialLinks() {
  const { data, error } = await db
    .from('navigation_social_links')
    .select('platform, icon_class, url, display_order')
    .eq('is_active', true)
    .order('display_order', { ascending: true });

  if (error) {
    console.error('Footer social links error:', error);
    return [];
  }

  return data || [];
}

export async function subscribeToNewsletter(email, source = 'FOOTER') {
  const normalizedEmail = String(email || '').trim().toLowerCase();
  const { error } = await db.from('newsletter_subscribers').insert({
    email: normalizedEmail,
    source,
    consent_given: true,
    status: 'ACTIVE'
  });

  if (!error) return { ok: true };

  if (error.code === '23505') {
    return { ok: true, alreadySubscribed: true };
  }

  console.error('Newsletter signup error:', error);
  return { ok: false };
}
