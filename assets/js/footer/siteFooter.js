import { getPublicSocialLinks, subscribeToNewsletter } from '../api/siteFooterApi.js';
import { escapeHtml, safeUrl } from '../utils/renderUtils.js';

const FALLBACK_SOCIALS = [];


function renderSocials(items) {
  const container = document.getElementById('footerSocialLinks');
  if (!container) return;
  const links = items.length ? items : FALLBACK_SOCIALS;
  container.innerHTML = links.map((item) => `
    <a href="${safeUrl(item.url || '#')}" aria-label="${escapeHtml(item.platform)}" target="_blank" rel="noopener noreferrer">
      <i class="${escapeHtml(item.icon_class || 'bi bi-link-45deg')}" aria-hidden="true"></i>
    </a>`).join('');
}

function bindNewsletter() {
  const form = document.getElementById('footerNewsletterForm');
  const message = document.getElementById('footerNewsletterMessage');
  if (!form || !message) return;

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    message.className = 'tt-footer-form-message';

    if (!form.reportValidity()) return;

    const button = form.querySelector('button[type="submit"]');
    button.disabled = true;
    message.textContent = 'Subscribing…';

    const result = await subscribeToNewsletter(new FormData(form).get('email'));
    button.disabled = false;

    if (!result.ok) {
      message.textContent = 'We could not complete your subscription. Please try again.';
      message.classList.add('is-error');
      return;
    }

    message.textContent = result.alreadySubscribed
      ? 'You are already subscribed to club updates.'
      : 'Thank you. You are now subscribed to club updates.';
    message.classList.add('is-success');
    form.reset();
  });
}

async function initializeSiteFooter() {
  const year = document.getElementById('footerYear');
  if (year) year.textContent = new Date().getFullYear();

  bindNewsletter();

  const socials = await getPublicSocialLinks();
  renderSocials(Array.isArray(socials) ? socials : []);
}

initializeSiteFooter().catch((error) => console.error('Footer initialization failed:', error));
