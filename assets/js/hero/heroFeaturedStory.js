import { getFeaturedStory } from '../api/homeApi.js';
import { escapeHtml, safeUrl } from '../utils/renderUtils.js';

export async function loadFeaturedStory() {
  const container = document.getElementById('heroFeaturedStory');
  if (!container) return;

  container.setAttribute('aria-busy', 'true');
  container.innerHTML = '<div class="tt-hero-skeleton" aria-hidden="true"></div>';

  const story = await getFeaturedStory();

  if (!story) {
    container.innerHTML = '';
    container.removeAttribute('aria-busy');
    return;
  }

  const title = story.headline || story.title || '';
  const href = safeUrl(story.button_url || story.url || '#');
  const image = safeUrl(story.image_url, '');

  container.innerHTML = `
    <article class="tt-featured-story">
      <a class="tt-featured-story__link" href="${href}" aria-label="${escapeHtml(title)}">
        ${image ? `<img class="tt-featured-story__image" src="${image}" alt="${escapeHtml(story.image_alt || title)}" style="object-position:${escapeHtml(story.image_object_position || '50% 50%')}">` : ''}
        <div class="tt-story-shade" aria-hidden="true"></div>
        <div class="tt-featured-story__content">
          ${story.category_name ? `<span class="tt-story-category">${escapeHtml(story.category_name)}</span>` : ''}
          <h1 class="tt-featured-story__title">${escapeHtml(title)}</h1>
          ${story.summary ? `<p class="tt-featured-story__summary">${escapeHtml(story.summary)}</p>` : ''}
          <span class="tt-story-action">
            ${escapeHtml(story.button_text || 'Read story')}
            <i class="bi bi-arrow-right" aria-hidden="true"></i>
          </span>
        </div>
      </a>
    </article>`;

  container.removeAttribute('aria-busy');
}
