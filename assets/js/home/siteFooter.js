import { getPublicSiteSettings, getPublicSocialLinks, subscribeToNewsletter } from '../api/siteFooterApi.js';
import { escapeHtml, safeUrl } from '../utils/renderUtils.js';

const FALLBACK_SOCIALS = [];

function settingMap(items) {
  return Object.fromEntries(items.map((item) => [item.setting_code, item.setting_value]));
}

function renderContact(settings) {
  const container = document.getElementById('footerContactDetails');
  if (!container) return;

  const phone = settings.PHONE || '0704205815';
  const email = settings.EMAIL || 'info@thikatandemclub.com';
  const address = settings.ADDRESS || 'Section 9 Opposite Gatitu Total gas filling station';
  const mapQuery = encodeURIComponent(`${address}, Thika`);
  const phoneHref = phone.startsWith('+') ? phone : `+254${phone.replace(/\D/g, '').replace(/^0/, '')}`;

  container.innerHTML = `
    <a href="https://www.google.com/maps/search/?api=1&query=${mapQuery}" target="_blank" rel="noopener noreferrer">
      <i class="bi bi-geo-alt" aria-hidden="true"></i><span>${escapeHtml(address)}, Thika</span>
    </a>
    <a href="mailto:${escapeHtml(email)}"><i class="bi bi-envelope" aria-hidden="true"></i><span>${escapeHtml(email)}</span></a>
    <a href="tel:${escapeHtml(phoneHref)}"><i class="bi bi-telephone" aria-hidden="true"></i><span>${escapeHtml(phone)}</span></a>`;
}

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
  document.getElementById('footerYear').textContent = new Date().getFullYear();
  bindNewsletter();

  const [settingsResult, socialsResult] = await Promise.allSettled([
    getPublicSiteSettings(),
    getPublicSocialLinks()
  ]);

  renderContact(settingMap(settingsResult.status === 'fulfilled' ? settingsResult.value : []));
  renderSocials(socialsResult.status === 'fulfilled' ? socialsResult.value : []);
}

initializeSiteFooter().catch((error) => console.error('Footer initialization failed:', error));
