import { getStoryGrid } from '../api/homeApi.js';
import { escapeHtml, safeUrl, formatStoryDate } from '../utils/renderUtils.js';

export async function loadStoryGrid() {
  const container = document.getElementById('heroStoryGrid');
  if (!container) return;

  container.setAttribute('aria-busy', 'true');
  container.innerHTML = '<div class="tt-story-grid-skeleton" aria-hidden="true"></div>';

  const stories = await getStoryGrid();

  if (!stories.length) {
    container.innerHTML = '';
    container.removeAttribute('aria-busy');
    return;
  }

  container.innerHTML = stories.map((story, index) => {
    const title = story.headline || story.title || '';
    const href = safeUrl(story.button_url || story.url || '#');
    const image = safeUrl(story.image_url, '');
    const date = formatStoryDate(story.published_at || story.publication_date || story.created_at);

    return `
      <article class="tt-story-card tt-story-card--${index + 1}">
        <a class="tt-story-card__link" href="${href}" aria-label="${escapeHtml(title)}">
          ${image ? `<img class="tt-story-card__image" src="${image}" alt="${escapeHtml(story.image_alt || title)}" style="object-position:${escapeHtml(story.image_object_position || '50% 50%')}">` : ''}
          <div class="tt-story-shade" aria-hidden="true"></div>
          <div class="tt-story-card__content">
            <div class="tt-story-card__meta">
              ${story.category_name ? `<span class="tt-story-category">${escapeHtml(story.category_name)}</span>` : ''}
              ${date ? `<time datetime="${escapeHtml(story.published_at || story.publication_date || story.created_at)}">${escapeHtml(date)}</time>` : ''}
            </div>
            <h2 class="tt-story-card__title">${escapeHtml(title)}</h2>
          </div>
        </a>
      </article>`;
  }).join('');

  container.removeAttribute('aria-busy');
}
