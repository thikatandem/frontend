import { getNewsRail } from '../api/homeApi.js';
import { escapeHtml, safeUrl, formatStoryDate } from '../utils/renderUtils.js';

export async function loadNewsRail() {
  const container = document.getElementById('homeNewsRail');
  if (!container) return;

  container.setAttribute('aria-busy', 'true');
  container.innerHTML = '<div class="tt-news-grid-skeleton" aria-hidden="true"></div>';

  const news = await getNewsRail();

  if (!news.length) {
    container.innerHTML = '';
    container.removeAttribute('aria-busy');
    return;
  }

  container.innerHTML = news.map((item) => {
    const title = item.headline || item.title || '';
    const href = safeUrl(item.button_url || item.url || '#');
    const image = safeUrl(item.image_url, '');
    const rawDate = item.published_at || item.publication_date || item.created_at;
    const date = formatStoryDate(rawDate);

    return `
      <article class="tt-news-card">
        <a class="tt-news-card__link" href="${href}">
          <div class="tt-news-card__media">
            ${image ? `<img src="${image}" alt="${escapeHtml(item.image_alt || title)}" style="object-position:${escapeHtml(item.image_object_position || '50% 50%')}">` : ''}
          </div>
          <div class="tt-news-card__body">
            <div class="tt-news-card__meta">
              <span>${escapeHtml(item.category_name || 'News')}</span>
              ${date ? `<time datetime="${escapeHtml(rawDate)}">${escapeHtml(date)}</time>` : ''}
            </div>
            <h3>${escapeHtml(title)}</h3>
            ${item.summary ? `<p>${escapeHtml(item.summary)}</p>` : ''}
            <span class="tt-news-card__action">Read more <i class="bi bi-arrow-right" aria-hidden="true"></i></span>
          </div>
        </a>
      </article>`;
  }).join('');

  container.removeAttribute('aria-busy');
}
