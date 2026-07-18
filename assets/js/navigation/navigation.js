import {
  getNavigationRegionItems,
  getNavigationCampaigns,
  getNavigationCTAs
} from '../api/navigationService.js';
import { escapeHtml, safeUrl } from '../utils/renderUtils.js';

let navigationEventsBound = false;

function isPublicNavigationItem(item) {
  const label = String(item?.title || item?.label || '').toLowerCase();
  const url = String(item?.url || '').toLowerCase();
  return !/(member\s*login|login|log in|sign in)/i.test(label)
    && !/(^|\/)(login|signin|sign-in)(\/|$|\?)/i.test(url);
}

export async function initializeNavigation() {
  const [mainItems, utilityItems, campaigns, ctas] = await Promise.all([
    getNavigationRegionItems('MAIN'),
    getNavigationRegionItems('UTILITY'),
    getNavigationCampaigns(),
    getNavigationCTAs()
  ]);

  renderUtilityNavigation(utilityItems);
  renderMainNavigation(mainItems);
  renderCampaignBar(campaigns[0]);
  renderHeaderCTA(ctas[0]);
  bindNavigationEvents();
}

function renderUtilityNavigation(items) {
  const desktop = document.getElementById('utilityNavigationList');
  const mobile = document.getElementById('mobileUtilityNavigationList');
  const rootItems = items.filter((item) => !item.parent_item_id && isPublicNavigationItem(item));

  const markup = rootItems.map((item) => `
    <li><a href="${safeUrl(item.url || '#')}">${escapeHtml(item.title)}</a></li>`).join('');

  if (desktop) desktop.innerHTML = markup;
  if (mobile) mobile.innerHTML = markup;
}

function renderMainNavigation(items) {
  const container = document.getElementById('mainNavigationList');
  if (!container) return;

  const roots = items
    .filter((item) => !item.parent_item_id && isPublicNavigationItem(item))
    .sort((a, b) => a.display_order - b.display_order);

  container.innerHTML = roots.map((item) => buildNavigationItem(item, items)).join('');
}

function buildNavigationItem(item, allItems) {
  const children = allItems
    .filter((child) => child.parent_item_id === item.item_id && isPublicNavigationItem(child))
    .sort((a, b) => a.display_order - b.display_order);

  if (!children.length) {
    return `<li class="tt-nav-item"><a class="tt-nav-link" href="${safeUrl(item.url || '#')}">${escapeHtml(item.title)}</a></li>`;
  }

  const description = item.description || `Explore ${item.title} at Thika Tandem.`;

  return `
    <li class="tt-nav-item tt-nav-item--dropdown">
      <button class="tt-nav-link tt-dropdown-toggle" type="button" aria-expanded="false">
        <span>${escapeHtml(item.title)}</span>
        <i class="bi bi-chevron-down" aria-hidden="true"></i>
      </button>
      <div class="tt-mega-menu">
        <div class="tt-mega-menu__intro">
          <span class="tt-mega-menu__eyebrow">Explore</span>
          <h2>${escapeHtml(item.title)}</h2>
          <p>${escapeHtml(description)}</p>
        </div>
        <ul class="tt-mega-menu__links">
          ${children.map((child) => `
            <li><a href="${safeUrl(child.url || '#')}"><span>${escapeHtml(child.title)}</span><i class="bi bi-arrow-right" aria-hidden="true"></i></a></li>`).join('')}
        </ul>
        <a class="tt-mega-menu__feature" href="${safeUrl(item.url || children[0]?.url || '#')}">
          <span>Thika Tandem</span>
          <strong>Ride together. Go further.</strong>
          <i class="bi bi-arrow-up-right" aria-hidden="true"></i>
        </a>
      </div>
    </li>`;
}

function renderHeaderCTA() {
  const container = document.getElementById('headerCtaContainer');
  if (!container) return;

  container.innerHTML = `
    <a
      class="tt-header-contact"
      href="/contact.html"
      aria-label="Contact Thika Tandem"
    >
      <i class="bi bi-chat-dots" aria-hidden="true"></i>
      <span>Contact Us</span>
    </a>

    <a class="tt-header-cta" href="#join">
      Join the club
    </a>
  `;
}

function renderCampaignBar(campaign) {
  const container = document.getElementById('navigationCampaignBar');
  if (!container) return;

  if (!campaign || sessionStorage.getItem(`campaign-dismissed-${campaign.campaign_id || campaign.id || 'active'}`)) {
    container.hidden = true;
    container.innerHTML = '';
    return;
  }

  const campaignId = campaign.campaign_id || campaign.id || 'active';
  const href = safeUrl(campaign.button_url || campaign.url || '#');

  container.hidden = false;
  container.dataset.campaignId = campaignId;
  container.innerHTML = `
    <div class="tt-campaign-inner">
      <a class="tt-campaign-message" href="${href}">
        <strong>${escapeHtml(campaign.headline || '')}</strong>
        ${campaign.subheadline ? `<span>${escapeHtml(campaign.subheadline)}</span>` : ''}
        <span class="tt-campaign-action">${escapeHtml(campaign.button_text || 'View details')} <i class="bi bi-arrow-right" aria-hidden="true"></i></span>
      </a>
      <button class="tt-campaign-close" type="button" aria-label="Dismiss announcement"><i class="bi bi-x-lg" aria-hidden="true"></i></button>
    </div>`;
}

function bindNavigationEvents() {
  if (navigationEventsBound) return;
  navigationEventsBound = true;

  const body = document.body;
  const nav = document.getElementById('navmenu');
  const mobileToggle = document.getElementById('mobileNavToggle');
  const searchOpen = document.getElementById('headerSearchButton');
  const searchClose = document.getElementById('headerSearchClose');
  const searchPanel = document.getElementById('headerSearchPanel');

  function closeAllDropdowns(except = null) {
    document.querySelectorAll('.tt-nav-item--dropdown.is-open').forEach((item) => {
      if (item === except) return;
      item.classList.remove('is-open');
      item.querySelector('.tt-dropdown-toggle')?.setAttribute('aria-expanded', 'false');
    });
  }

  function closeMobileNavigation() {
    body.classList.remove('tt-mobile-nav-open');
    mobileToggle?.setAttribute('aria-expanded', 'false');
    mobileToggle?.querySelector('i')?.classList.replace('bi-x-lg', 'bi-list');
    closeAllDropdowns();
  }

  mobileToggle?.addEventListener('click', () => {
    const open = body.classList.toggle('tt-mobile-nav-open');
    mobileToggle.setAttribute('aria-expanded', String(open));
    const icon = mobileToggle.querySelector('i');
    icon?.classList.toggle('bi-list', !open);
    icon?.classList.toggle('bi-x-lg', open);
  });

  nav?.addEventListener('click', (event) => {
    const toggle = event.target.closest('.tt-dropdown-toggle');
    if (toggle) {
      const item = toggle.closest('.tt-nav-item--dropdown');
      const opening = !item.classList.contains('is-open');
      closeAllDropdowns(item);
      item.classList.toggle('is-open', opening);
      toggle.setAttribute('aria-expanded', String(opening));
      return;
    }

    if (event.target.closest('a') && window.matchMedia('(max-width: 1199px)').matches) {
      closeMobileNavigation();
    }
  });

  document.addEventListener('click', (event) => {
    if (!event.target.closest('#navmenu')) closeAllDropdowns();
  });

  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    closeAllDropdowns();
    closeMobileNavigation();
    closeSearch();
  });

  document.querySelector('.tt-mobile-backdrop')?.addEventListener('click', closeMobileNavigation);

  function openSearch() {
    if (!searchPanel) return;
    searchPanel.hidden = false;
    body.classList.add('tt-search-open');
    searchOpen?.setAttribute('aria-expanded', 'true');
    searchPanel.querySelector('input')?.focus();
  }

  function closeSearch() {
    if (!searchPanel) return;
    searchPanel.hidden = true;
    body.classList.remove('tt-search-open');
    searchOpen?.setAttribute('aria-expanded', 'false');
  }

  searchOpen?.addEventListener('click', openSearch);
  searchClose?.addEventListener('click', closeSearch);

  document.querySelector('.tt-search-backdrop')?.addEventListener('click', closeSearch);

  document.querySelector('.tt-campaign-close')?.addEventListener('click', () => {
    const campaign = document.getElementById('navigationCampaignBar');
    const campaignId = campaign?.dataset.campaignId || 'active';
    sessionStorage.setItem(`campaign-dismissed-${campaignId}`, 'true');
    campaign.hidden = true;
  });
}
