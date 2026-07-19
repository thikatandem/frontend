import {
  getNavigationRegionItems,
  getNavigationCampaigns,
  getNavigationCTAs
} from '../api/navigationService.js';

import {
  escapeHtml,
  safeUrl
} from '../utils/renderUtils.js';

let navigationEventsBound = false;

/**
 * Prevent private account links from appearing in public navigation.
 */
function isPublicNavigationItem(item) {
  const label = String(
    item?.title || item?.label || ''
  )
    .trim()
    .toLowerCase();

  const url = String(item?.url || '')
    .trim()
    .toLowerCase();

  const isLoginLabel =
    /member\s*login|member\s*sign[\s-]*in|login|log\s*in|sign[\s-]*in/i
      .test(label);

  const isLoginUrl =
    /(^|\/)(login|log-in|signin|sign-in|member-login)(\/|$|\?|#)/i
      .test(url);

  return !isLoginLabel && !isLoginUrl;
}

/**
 * Recognise every possible Home entry so database Home links can be
 * removed before the single permanent Home link is inserted.
 */
function isHomeNavigationItem(item) {
  const label = String(
    item?.title || item?.label || ''
  )
    .trim()
    .toLowerCase();

  const rawUrl = String(item?.url || '')
    .trim()
    .toLowerCase();

  const normalizedUrl = rawUrl
    .replace(/^https?:\/\/[^/]+/i, '')
    .replace(/[?#].*$/, '')
    .replace(/\/+$/, '') || '/';

  return (
    label === 'home' ||
    normalizedUrl === '/' ||
    normalizedUrl === '/index' ||
    normalizedUrl === '/index.html'
  );
}

function sortByDisplayOrder(items) {
  return [...items].sort((a, b) => {
    return (
      Number(a?.display_order || 0) -
      Number(b?.display_order || 0)
    );
  });
}

export async function initializeNavigation() {
  try {
    const [
      mainItems,
      utilityItems,
      campaigns
    ] = await Promise.all([
      getNavigationRegionItems('MAIN'),
      getNavigationRegionItems('UTILITY'),
      getNavigationCampaigns(),

      /*
       * Keep the service request available to the application,
       * but do not use a database CTA to replace Join the club.
       */
      getNavigationCTAs()
    ]);

    renderUtilityNavigation(
      Array.isArray(utilityItems)
        ? utilityItems
        : []
    );

    renderMainNavigation(
      Array.isArray(mainItems)
        ? mainItems
        : []
    );

    renderCampaignBar(
      Array.isArray(campaigns)
        ? campaigns[0]
        : null
    );

    /*
     * Join the club is intentionally fixed and cannot become Login.
     */
    renderHeaderCTA();

    bindNavigationEvents();
  } catch (error) {
    console.error(
      'Unable to initialise navigation:',
      error
    );

    /*
     * Still render the permanent buttons when database navigation
     * is temporarily unavailable.
     */
    renderUtilityNavigation([]);
    renderMainNavigation([]);
    renderHeaderCTA();
    bindNavigationEvents();
  }
}

/**
 * Utility navigation:
 * - Home is always first.
 * - Database Home duplicates are removed.
 * - Login entries are removed.
 */
function renderUtilityNavigation(items) {
  const desktop = document.getElementById(
    'utilityNavigationList'
  );

  const mobile = document.getElementById(
    'mobileUtilityNavigationList'
  );

  const rootItems = sortByDisplayOrder(
    items.filter((item) => {
      return (
        !item?.parent_item_id &&
        isPublicNavigationItem(item) &&
        !isHomeNavigationItem(item)
      );
    })
  );

  const homeItem = `
    <li>
      <a href="/" aria-label="Home">
        Home
      </a>
    </li>
  `;

  const databaseItems = rootItems
    .map((item) => {
      const title =
        item?.title ||
        item?.label ||
        '';

      return `
        <li>
          <a href="${safeUrl(item?.url || '#')}">
            ${escapeHtml(title)}
          </a>
        </li>
      `;
    })
    .join('');

  const markup = homeItem + databaseItems;

  if (desktop) {
    desktop.innerHTML = markup;
  }

  if (mobile) {
    mobile.innerHTML = markup;
  }
}

function renderMainNavigation(items) {
  const container = document.getElementById(
    'mainNavigationList'
  );

  if (!container) {
    return;
  }

  const publicItems = items.filter(
    isPublicNavigationItem
  );

  const roots = sortByDisplayOrder(
    publicItems.filter((item) => {
      return !item?.parent_item_id;
    })
  );

  container.innerHTML = roots
    .map((item) => {
      return buildNavigationItem(
        item,
        publicItems
      );
    })
    .join('');
}

function buildNavigationItem(item, allItems) {
  const title =
    item?.title ||
    item?.label ||
    '';

  const children = sortByDisplayOrder(
    allItems.filter((child) => {
      return (
        child?.parent_item_id === item?.item_id &&
        isPublicNavigationItem(child)
      );
    })
  );

  if (!children.length) {
    return `
      <li class="tt-nav-item">
        <a
          class="tt-nav-link"
          href="${safeUrl(item?.url || '#')}"
        >
          ${escapeHtml(title)}
        </a>
      </li>
    `;
  }

  const description =
    item?.description ||
    `Explore ${title} at Thika Tandem.`;

  const childMarkup = children
    .map((child) => {
      const childTitle =
        child?.title ||
        child?.label ||
        '';

      return `
        <li>
          <a href="${safeUrl(child?.url || '#')}">
            <span>
              ${escapeHtml(childTitle)}
            </span>

            <i
              class="bi bi-arrow-right"
              aria-hidden="true"
            ></i>
          </a>
        </li>
      `;
    })
    .join('');

  const featureUrl = safeUrl(
    item?.url ||
    children[0]?.url ||
    '#'
  );

  return `
    <li class="tt-nav-item tt-nav-item--dropdown">
      <button
        class="tt-nav-link tt-dropdown-toggle"
        type="button"
        aria-expanded="false"
      >
        <span>
          ${escapeHtml(title)}
        </span>

        <i
          class="bi bi-chevron-down"
          aria-hidden="true"
        ></i>
      </button>

      <div class="tt-mega-menu">
        <div class="tt-mega-menu__intro">
          <span class="tt-mega-menu__eyebrow">
            Explore
          </span>

          <h2>
            ${escapeHtml(title)}
          </h2>

          <p>
            ${escapeHtml(description)}
          </p>
        </div>

        <ul class="tt-mega-menu__links">
          ${childMarkup}
        </ul>

        <a
          class="tt-mega-menu__feature"
          href="${featureUrl}"
        >
          <span>
            Thika Tandem
          </span>

          <strong>
            Ride together. Go further.
          </strong>

          <i
            class="bi bi-arrow-up-right"
            aria-hidden="true"
          ></i>
        </a>
      </div>
    </li>
  `;
}

/**
 * These two public buttons are deliberately fixed.
 * Database CTA content cannot replace Join the club with Login.
 */
function renderHeaderCTA() {
  const container = document.getElementById(
    'headerCtaContainer'
  );

  if (!container) {
    return;
  }

  container.innerHTML = `
    <a
      class="tt-header-contact"
      href="/contact"
      aria-label="Contact Thika Tandem"
    >
      <i
        class="bi bi-chat-dots"
        aria-hidden="true"
      ></i>

      <span>
        Contact Us
      </span>
    </a>

    <a
      class="tt-header-cta"
      href="#join"
      aria-label="Join Thika Tandem ParaCycling Club"
    >
      Join the club
    </a>
  `;
}

function renderCampaignBar(campaign) {
  const container = document.getElementById(
    'navigationCampaignBar'
  );

  if (!container) {
    return;
  }

  if (!campaign) {
    container.hidden = true;
    container.innerHTML = '';
    return;
  }

  const campaignId =
    campaign?.campaign_id ||
    campaign?.id ||
    'active';

  const storageKey =
    `campaign-dismissed-${campaignId}`;

  if (sessionStorage.getItem(storageKey)) {
    container.hidden = true;
    container.innerHTML = '';
    return;
  }

  const href = safeUrl(
    campaign?.button_url ||
    campaign?.url ||
    '#'
  );

  const headline = escapeHtml(
    campaign?.headline || ''
  );

  const subheadline = campaign?.subheadline
    ? `
      <span>
        ${escapeHtml(campaign.subheadline)}
      </span>
    `
    : '';

  const buttonText = escapeHtml(
    campaign?.button_text ||
    'View details'
  );

  container.hidden = false;
  container.dataset.campaignId =
    String(campaignId);

  container.innerHTML = `
    <div class="tt-campaign-inner">
      <a
        class="tt-campaign-message"
        href="${href}"
      >
        <strong>
          ${headline}
        </strong>

        ${subheadline}

        <span class="tt-campaign-action">
          ${buttonText}

          <i
            class="bi bi-arrow-right"
            aria-hidden="true"
          ></i>
        </span>
      </a>

      <button
        class="tt-campaign-close"
        type="button"
        aria-label="Dismiss announcement"
      >
        <i
          class="bi bi-x-lg"
          aria-hidden="true"
        ></i>
      </button>
    </div>
  `;
}

function bindNavigationEvents() {
  if (navigationEventsBound) {
    return;
  }

  navigationEventsBound = true;

  const body = document.body;

  const nav = document.getElementById(
    'navmenu'
  );

  const mobileToggle = document.getElementById(
    'mobileNavToggle'
  );

  const searchOpen = document.getElementById(
    'headerSearchButton'
  );

  const searchClose = document.getElementById(
    'headerSearchClose'
  );

  const searchPanel = document.getElementById(
    'headerSearchPanel'
  );

  const mobileBackdrop = document.querySelector(
    '.tt-mobile-backdrop'
  );

  const searchBackdrop = document.querySelector(
    '.tt-search-backdrop'
  );

  const desktopMediaQuery = window.matchMedia(
    '(min-width: 1200px)'
  );

  let previouslyFocusedElement = null;

  function closeAllDropdowns(except = null) {
    document
      .querySelectorAll(
        '.tt-nav-item--dropdown.is-open'
      )
      .forEach((item) => {
        if (item === except) {
          return;
        }

        item.classList.remove('is-open');

        item
          .querySelector('.tt-dropdown-toggle')
          ?.setAttribute(
            'aria-expanded',
            'false'
          );
      });
  }

  function setMobileToggleState(open) {
    if (!mobileToggle) {
      return;
    }

    mobileToggle.setAttribute(
      'aria-expanded',
      String(open)
    );

    mobileToggle.setAttribute(
      'aria-label',
      open
        ? 'Close navigation menu'
        : 'Open navigation menu'
    );

    const icon = mobileToggle.querySelector('i');

    if (!icon) {
      return;
    }

    icon.classList.toggle(
      'bi-list',
      !open
    );

    icon.classList.toggle(
      'bi-x-lg',
      open
    );
  }

  function openMobileNavigation() {
    if (!nav || !mobileToggle) {
      return;
    }

    previouslyFocusedElement =
      document.activeElement;

    body.classList.add(
      'tt-mobile-nav-open'
    );

    setMobileToggleState(true);

    window.requestAnimationFrame(() => {
      nav
        .querySelector(
          'a[href], button:not([disabled])'
        )
        ?.focus();
    });
  }

  function closeMobileNavigation(options = {}) {
    const {
      restoreFocus = false
    } = options;

    const wasOpen = body.classList.contains(
      'tt-mobile-nav-open'
    );

    body.classList.remove(
      'tt-mobile-nav-open'
    );

    setMobileToggleState(false);
    closeAllDropdowns();

    if (wasOpen && restoreFocus) {
      const focusTarget =
        previouslyFocusedElement instanceof HTMLElement
          ? previouslyFocusedElement
          : mobileToggle;

      focusTarget?.focus();
    }
  }

  function openSearch() {
    if (!searchPanel) {
      return;
    }

    closeMobileNavigation();

    searchPanel.hidden = false;

    body.classList.add(
      'tt-search-open'
    );

    searchOpen?.setAttribute(
      'aria-expanded',
      'true'
    );

    window.requestAnimationFrame(() => {
      searchPanel
        .querySelector(
          'input, button, [href]'
        )
        ?.focus();
    });
  }

  function closeSearch() {
    if (!searchPanel) {
      return;
    }

    searchPanel.hidden = true;

    body.classList.remove(
      'tt-search-open'
    );

    searchOpen?.setAttribute(
      'aria-expanded',
      'false'
    );
  }

  if (mobileToggle) {
    mobileToggle.setAttribute(
      'aria-controls',
      nav?.id || 'navmenu'
    );

    setMobileToggleState(false);

    mobileToggle.addEventListener(
      'click',
      () => {
        const isOpen = body.classList.contains(
          'tt-mobile-nav-open'
        );

        if (isOpen) {
          closeMobileNavigation({
            restoreFocus: true
          });
        } else {
          openMobileNavigation();
        }
      }
    );
  }

  nav?.addEventListener(
    'click',
    (event) => {
      const toggle = event.target.closest(
        '.tt-dropdown-toggle'
      );

      if (toggle) {
        const item = toggle.closest(
          '.tt-nav-item--dropdown'
        );

        if (!item) {
          return;
        }

        const opening =
          !item.classList.contains('is-open');

        closeAllDropdowns(item);

        item.classList.toggle(
          'is-open',
          opening
        );

        toggle.setAttribute(
          'aria-expanded',
          String(opening)
        );

        return;
      }

      const clickedLink =
        event.target.closest('a[href]');

      if (
        clickedLink &&
        !desktopMediaQuery.matches
      ) {
        closeMobileNavigation();
      }
    }
  );

  document.addEventListener(
    'click',
    (event) => {
      if (
        !event.target.closest('#navmenu') &&
        !event.target.closest('#mobileNavToggle')
      ) {
        closeAllDropdowns();
      }
    }
  );

  document.addEventListener(
    'keydown',
    (event) => {
      if (event.key !== 'Escape') {
        return;
      }

      closeAllDropdowns();

      closeMobileNavigation({
        restoreFocus: true
      });

      closeSearch();
    }
  );

  mobileBackdrop?.addEventListener(
    'click',
    () => {
      closeMobileNavigation({
        restoreFocus: true
      });
    }
  );

  searchOpen?.addEventListener(
    'click',
    openSearch
  );

  searchClose?.addEventListener(
    'click',
    closeSearch
  );

  searchBackdrop?.addEventListener(
    'click',
    closeSearch
  );

  document
    .querySelector('.tt-campaign-close')
    ?.addEventListener(
      'click',
      () => {
        const campaign =
          document.getElementById(
            'navigationCampaignBar'
          );

        const campaignId =
          campaign?.dataset?.campaignId ||
          'active';

        sessionStorage.setItem(
          `campaign-dismissed-${campaignId}`,
          'true'
        );

        if (campaign) {
          campaign.hidden = true;
        }
      }
    );

  const handleDesktopChange = (event) => {
    if (event.matches) {
      closeMobileNavigation();
    }
  };

  if (
    typeof desktopMediaQuery.addEventListener ===
    'function'
  ) {
    desktopMediaQuery.addEventListener(
      'change',
      handleDesktopChange
    );
  } else if (
    typeof desktopMediaQuery.addListener ===
    'function'
  ) {
    desktopMediaQuery.addListener(
      handleDesktopChange
    );
  }
}