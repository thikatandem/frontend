import supabase from '../supabase/supabaseClient.js';

const escapeHtml = (value = '') => String(value).replace(/[&<>"']/g, (character) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'
}[character]));

const safeUrl = (value = '#') => {
  const url = String(value || '#').trim();
  if (/^(javascript|data):/i.test(url)) return '#';
  return url;
};

async function loadPageContent() {
  const pageCode = document.body.dataset.pageCode;
  if (!pageCode) return;

  const table = `site_${pageCode.toLowerCase()}_items`;
  const { data, error } = await supabase
    .from(table)
    .select('item_id, section_code, eyebrow, title, summary, button_text, button_url, image_url, image_alt, metadata, display_order')
    .eq('is_active', true)
    .lte('publish_at', new Date().toISOString())
    .order('display_order');

  if (error) {
    console.warn(`Could not load ${table}:`, error.message);
    return;
  }

  const listing = document.getElementById('pageListingGrid');
  if (listing && data?.length) {
    listing.innerHTML = data.map((item) => `
      <article class="tt-listing-card">
        ${item.image_url ? `<div class="tt-listing-card__media"><img src="${safeUrl(item.image_url)}" alt="${escapeHtml(item.image_alt || item.title)}"></div>` : ''}
        <div class="tt-listing-card__body">
          <span>${escapeHtml(item.eyebrow || item.section_code || '')}</span>
          <h3>${escapeHtml(item.title)}</h3>
          <p>${escapeHtml(item.summary || '')}</p>
          ${item.button_url ? `<a href="${safeUrl(item.button_url)}">${escapeHtml(item.button_text || 'Read more')} <i class="bi bi-arrow-right"></i></a>` : ''}
        </div>
      </article>`).join('');
  }

  const rows = document.getElementById('pageDataRows');
  if (rows && data?.length) {
    rows.innerHTML = data.map((item, index) => {
      const metadata = item.metadata || {};
      return `<tr><td>${escapeHtml(metadata.position || index + 1)}</td><td><strong>${escapeHtml(item.title)}</strong><small>${escapeHtml(item.summary || '')}</small></td><td>${escapeHtml(metadata.category || item.section_code || '—')}</td><td>${escapeHtml(metadata.points || metadata.time || '—')}</td></tr>`;
    }).join('');
  }
}

async function initializePage() {
  const results = await Promise.allSettled([
    loadPageContent()
  ]);

  results.forEach((result) => {
    if (result.status === 'rejected') {
      console.error('Page component failed:', result.reason);
    }
  });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializePage, { once: true });
} else {
  initializePage();
}
