import { initializeNavigation } from './navigation/navigation.js';
import { initializeHome } from './home/home.js';

function onReady(callback) {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', callback, { once: true });
  } else {
    callback();
  }
}

function initializeOptionalLibraries() {
  if (typeof window.AOS !== 'undefined' && typeof window.AOS.init === 'function') {
    window.AOS.init({
      duration: 600,
      easing: 'ease-in-out',
      once: true,
      mirror: false
    });
  }

  if (typeof window.GLightbox === 'function') {
    window.GLightbox({ selector: '.glightbox' });
  }

  if (typeof window.Swiper === 'function') {
    document.querySelectorAll('.init-swiper').forEach((element) => {
      const configElement = element.querySelector('.swiper-config');
      if (!configElement) return;

      try {
        const config = JSON.parse(configElement.textContent.trim());
        new window.Swiper(element, config);
      } catch (error) {
        console.warn('Invalid Swiper configuration:', error);
      }
    });
  }

  if (
    typeof window.imagesLoaded === 'function' &&
    typeof window.Isotope === 'function'
  ) {
    document.querySelectorAll('.isotope-layout').forEach((layoutElement) => {
      const container = layoutElement.querySelector('.isotope-container');
      if (!container) return;

      window.imagesLoaded(container, () => {
        const isotope = new window.Isotope(container, {
          itemSelector: '.isotope-item',
          layoutMode: layoutElement.dataset.layout || 'masonry',
          filter: layoutElement.dataset.defaultFilter || '*',
          sortBy: layoutElement.dataset.sort || 'original-order'
        });

        layoutElement
          .querySelectorAll('.isotope-filters li')
          .forEach((filterElement) => {
            filterElement.addEventListener('click', () => {
              layoutElement
                .querySelector('.isotope-filters .filter-active')
                ?.classList.remove('filter-active');

              filterElement.classList.add('filter-active');
              isotope.arrange({
                filter: filterElement.dataset.filter || '*'
              });
            });
          });
      });
    });
  }
}

function initializePageChrome() {
  const body = document.body;
  const header = document.getElementById('header');

  const toggleScrolled = () => {
    if (!header) return;

    const sticky =
      header.classList.contains('scroll-up-sticky') ||
      header.classList.contains('sticky-top') ||
      header.classList.contains('fixed-top') ||
      header.classList.contains('tt-header');

    if (!sticky) return;
    body.classList.toggle('tt-scrolled', window.scrollY > 100);
    body.classList.toggle('scrolled', window.scrollY > 100);
  };

  const scrollTop = document.querySelector('.scroll-top');
  const updateScrollTop = () => {
    scrollTop?.classList.toggle('active', window.scrollY > 100);
  };

  scrollTop?.addEventListener('click', (event) => {
    event.preventDefault();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  document.addEventListener('scroll', toggleScrolled, { passive: true });
  document.addEventListener('scroll', updateScrollTop, { passive: true });
  toggleScrolled();
  updateScrollTop();

  document.getElementById('preloader')?.remove();

  document
    .querySelectorAll('.faq-item h3, .faq-item .faq-toggle')
    .forEach((item) => {
      item.addEventListener('click', () => {
        item.closest('.faq-item')?.classList.toggle('faq-active');
      });
    });

  if (window.location.hash) {
    const target = document.querySelector(window.location.hash);
    if (target) {
      window.requestAnimationFrame(() => {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    }
  }
}

async function initializeApplication() {
  // Always begin with a closed, synchronized drawer state.
  document.body.classList.remove('tt-mobile-nav-open', 'mobile-nav-active');

  initializePageChrome();
  initializeOptionalLibraries();

  try {
    await initializeNavigation();
  } catch (error) {
    console.error('Navigation initialization failed:', error);
  }

  const isHomePage =
    Boolean(document.getElementById('heroFeaturedStory')) ||
    Boolean(document.getElementById('heroStoryGrid')) ||
    document.body.dataset.pageCode === 'HOME';

  if (isHomePage) {
    try {
      await initializeHome();
    } catch (error) {
      console.error('Homepage initialization failed:', error);
    }
  }
}

onReady(initializeApplication);
