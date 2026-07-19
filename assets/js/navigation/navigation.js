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
let navigationInitializationPromise = null;

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

function sortByDisplayOrder(items) {
  return [...items].sort((a, b) => {
    return (
      Number(a?.display_order || 0) -
      Number(b?.display_order || 0)
    );
  });
}

export function initializeNavigation() {
  document.body?.classList.remove('tt-mobile-nav-open', 'mobile-nav-active');

  if (navigationInitializationPromise) {
    return navigationInitializationPromise;
  }

  navigationInitializationPromise = (async () => {
  try {
    const [
      mainItems,
      utilityItems,
      campaigns,
      ctas
    ] = await Promise.all([
      getNavigationRegionItems('MAIN'),
      getNavigationRegionItems('UTILITY'),
      getNavigationCampaigns(),
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

    renderHeaderCTAs(Array.isArray(ctas) ? ctas : []);
    bindNavigationEvents();
  } catch (error) {
    console.error(
      'Unable to initialise navigation:',
      error
    );

    renderUtilityNavigation([]);
    renderMainNavigation([]);
    renderHeaderCTAs([]);
    bindNavigationEvents();
  }
  })().catch((error) => {
    navigationInitializationPromise = null;
    throw error;
  });

  return navigationInitializationPromise;
}

/**
 * Utility navigation is rendered only from database records.
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
        isPublicNavigationItem(item)
      );
    })
  );

  const markup = rootItems
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

  if (desktop) {
    desktop.innerHTML = markup;
  }

  if (mobile) {
    mobile.innerHTML = markup;
  }
}

/**
 * Main navigation, including Home, is rendered only from database records.
 */
function renderMainNavigation(items) {
  const container = document.getElementById('mainNavigationList');
  if (!container) return;

  const publicItems = items.filter(isPublicNavigationItem);
  const roots = sortByDisplayOrder(
    publicItems.filter((item) => !item?.parent_item_id)
  );

  container.innerHTML = roots
    .map((item) => buildNavigationItem(item, publicItems))
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
function renderHeaderCTAs(items) {
  const container = document.getElementById('headerCtaContainer');
  if (!container) return;

  const publicItems = sortByDisplayOrder(
    (Array.isArray(items) ? items : []).filter((item) => {
      const title = String(item?.title || '').trim();
      const url = String(item?.url || '').trim();

      return (
        title &&
        url &&
        isPublicNavigationItem(item)
      );
    })
  ).slice(0, 2);

  container.innerHTML = publicItems
    .map((item, index) => {
      const title = item?.title || '';
      const href = safeUrl(item?.url || '#');
      const style = String(item?.button_style || '').trim().toLowerCase();

      const className =
        style === 'contact' || /contact/i.test(title)
          ? 'tt-header-contact'
          : index === 0
            ? 'tt-header-contact'
            : 'tt-header-cta';

      return `
        <a class="${className}" href="${href}">
          ${escapeHtml(title)}
        </a>
      `;
    })
    .join('');
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
  const body = document.body;
  const nav = document.getElementById('navmenu');
  const mobileToggle = document.getElementById('mobileNavToggle');
  const mobileBackdrop = document.querySelector('.tt-mobile-backdrop');
  const searchOpen = document.getElementById('headerSearchButton');
  const searchClose = document.getElementById('headerSearchClose');
  const searchPanel = document.getElementById('headerSearchPanel');
  const searchBackdrop = document.querySelector('.tt-search-backdrop');
  const desktopMediaQuery = window.matchMedia('(min-width: 1200px)');

  if (!body || !nav || !mobileToggle) {
    console.error('Navigation elements missing:', {
      body: Boolean(body),
      nav: Boolean(nav),
      mobileToggle: Boolean(mobileToggle)
    });

    navigationEventsBound = false;
    return;
  }

  if (navigationEventsBound) {
    return;
  }

  navigationEventsBound = true;

  let previouslyFocusedElement = null;

  function getDropdownItems() {
    return nav.querySelectorAll(
      '.tt-nav-item--dropdown'
    );
  }

  function getDirectChild(item, selector) {
    return Array.from(item.children).find((child) => {
      return child.matches(selector);
    }) || null;
  }

  function closeDropdown(item) {
    if (!item) {
      return;
    }

    item.classList.remove('is-open');

    const toggle = getDirectChild(
      item,
      '.tt-dropdown-toggle'
    );

    toggle?.setAttribute(
      'aria-expanded',
      'false'
    );

    const menu = getDirectChild(
      item,
      '.tt-mega-menu'
    );

    if (menu) {
      menu.setAttribute(
        'aria-hidden',
        'true'
      );
    }
  }

  function openDropdown(item) {
    if (!item) {
      return;
    }

    item.classList.add('is-open');

    const toggle = getDirectChild(
      item,
      '.tt-dropdown-toggle'
    );

    toggle?.setAttribute(
      'aria-expanded',
      'true'
    );

    const menu = getDirectChild(
      item,
      '.tt-mega-menu'
    );

    if (menu) {
      menu.setAttribute(
        'aria-hidden',
        'false'
      );
    }
  }

  function closeAllDropdowns(except = null) {
    getDropdownItems().forEach((item) => {
      if (item !== except) {
        closeDropdown(item);
      }
    });
  }

  function setMobileToggleState(open) {
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
    previouslyFocusedElement =
      document.activeElement;

    body.classList.add(
      'tt-mobile-nav-open'
    );

    nav.setAttribute(
      'aria-hidden',
      'false'
    );

    setMobileToggleState(true);

    window.requestAnimationFrame(() => {
      const firstControl = nav.querySelector(
        '.tt-nav-link, .tt-mobile-utility a'
      );

      firstControl?.focus();
    });
  }

  function closeMobileNavigation({
    restoreFocus = false
  } = {}) {
    const wasOpen = body.classList.contains(
      'tt-mobile-nav-open'
    );

    body.classList.remove(
      'tt-mobile-nav-open'
    );

    nav.setAttribute(
      'aria-hidden',
      desktopMediaQuery.matches
        ? 'false'
        : 'true'
    );

    setMobileToggleState(false);
    closeAllDropdowns();

    if (
      wasOpen &&
      restoreFocus &&
      previouslyFocusedElement instanceof HTMLElement
    ) {
      previouslyFocusedElement.focus();
    }
  }

  function toggleMobileNavigation() {
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
          'input, button, a[href]'
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

  mobileToggle.setAttribute(
    'aria-controls',
    nav.id || 'navmenu'
  );

  setMobileToggleState(false);

  getDropdownItems().forEach((item) => {
    closeDropdown(item);
  });

  if (!desktopMediaQuery.matches) {
    nav.setAttribute(
      'aria-hidden',
      'true'
    );
  } else {
    nav.setAttribute(
      'aria-hidden',
      'false'
    );
  }

  mobileToggle.addEventListener(
    'click',
    (event) => {
      event.preventDefault();
      event.stopPropagation();
      toggleMobileNavigation();
    }
  );

  nav.addEventListener(
    'click',
    (event) => {
      const target =
        event.target instanceof Element
          ? event.target
          : event.target?.parentElement;

      if (!target) {
        return;
      }

      const dropdownToggle = target.closest(
        '.tt-dropdown-toggle'
      );

      if (
        dropdownToggle &&
        nav.contains(dropdownToggle)
      ) {
        event.preventDefault();
        event.stopPropagation();

        const item = dropdownToggle.closest(
          '.tt-nav-item--dropdown'
        );

        if (!item) {
          return;
        }

        const shouldOpen =
          !item.classList.contains('is-open');

        closeAllDropdowns(item);

        if (shouldOpen) {
          openDropdown(item);
        } else {
          closeDropdown(item);
        }

        return;
      }

      const link = target.closest('a[href]');

      if (!link || !nav.contains(link)) {
        return;
      }

      const href = link.getAttribute('href');

      if (
        !href ||
        href === '#' ||
        href.trim().toLowerCase().startsWith('javascript:')
      ) {
        event.preventDefault();
        return;
      }

      if (!desktopMediaQuery.matches) {
        closeMobileNavigation();
      }
    }
  );

  mobileBackdrop?.addEventListener(
    'click',
    (event) => {
      event.preventDefault();

      closeMobileNavigation({
        restoreFocus: true
      });
    }
  );

  document.addEventListener(
    'click',
    (event) => {
      const target =
        event.target instanceof Element
          ? event.target
          : event.target?.parentElement;

      if (!target) {
        return;
      }

      if (
        nav.contains(target) ||
        mobileToggle.contains(target)
      ) {
        return;
      }

      if (desktopMediaQuery.matches) {
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

      if (
        body.classList.contains(
          'tt-search-open'
        )
      ) {
        closeSearch();
        searchOpen?.focus();
        return;
      }

      if (
        body.classList.contains(
          'tt-mobile-nav-open'
        )
      ) {
        closeMobileNavigation({
          restoreFocus: true
        });

        return;
      }

      closeAllDropdowns();
    }
  );

  searchOpen?.addEventListener(
    'click',
    (event) => {
      event.preventDefault();
      openSearch();
    }
  );

  searchClose?.addEventListener(
    'click',
    (event) => {
      event.preventDefault();
      closeSearch();
      searchOpen?.focus();
    }
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

  function handleDesktopChange(event) {
    if (event.matches) {
      body.classList.remove(
        'tt-mobile-nav-open'
      );

      nav.setAttribute(
        'aria-hidden',
        'false'
      );

      setMobileToggleState(false);
      closeAllDropdowns();
    } else {
      nav.setAttribute(
        'aria-hidden',
        body.classList.contains(
          'tt-mobile-nav-open'
        )
          ? 'false'
          : 'true'
      );
    }
  }

  if (
    typeof desktopMediaQuery.addEventListener ===
    'function'
  ) {
    desktopMediaQuery.addEventListener(
      'change',
      handleDesktopChange
    );
  } else {
    desktopMediaQuery.addListener(
      handleDesktopChange
    );
  }
}