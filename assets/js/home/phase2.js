import { getAllPhase2Sections } from '../api/phase2Api.js';
import { escapeHtml, safeUrl, formatStoryDate } from '../utils/renderUtils.js';

const fallback = {
  QUICK_ACTIONS: [
    { headline: 'Join the club', summary: 'Ride, train and grow with an inclusive cycling community.', button_url: 'join.html', accent: 'red' },
    { headline: 'Become a pilot', summary: 'Use your cycling skill to help another athlete move faster.', button_url: 'pilot.html', accent: 'black' },
    { headline: 'Find training', summary: 'Explore coached sessions for every stage of development.', button_url: 'training.html', accent: 'green' },
    { headline: 'Upcoming events', summary: 'See the next races, camps and community rides.', button_url: 'events.html', accent: 'image' }
  ],
  UPCOMING_EVENTS: [
    { headline: 'National para-cycling training camp', summary: 'A focused weekend for tandem teams, pilots and developing athletes.', button_url: 'events.html', metadata: { date: '2026-08-15', location: 'Thika, Kenya', status: 'Registration open' } },
    { headline: 'Community tandem skills day', button_url: 'events.html', metadata: { date: '2026-09-05', location: 'Kiambu County', status: 'Open' } },
    { headline: 'Road endurance assessment', button_url: 'events.html', metadata: { date: '2026-09-19', location: 'Thika', status: 'Team entry' } },
    { headline: 'Inclusive cycling showcase', button_url: 'events.html', metadata: { date: '2026-10-03', location: 'Nairobi', status: 'Coming soon' } }
  ],
  TANDEM_INTRO: [{ eyebrow: 'Discover tandem para-cycling', headline: 'Cycling together', summary: 'Tandem para-cycling pairs a sighted pilot at the front with a visually impaired stoker at the rear. Both riders train as one team—sharing rhythm, trust, power and ambition.', button_text: 'How tandem cycling works', button_url: 'about-tandem.html' }],
  LATEST_RESULTS: [
    { headline: 'Kenya Para-Cycling Road Series', summary: 'Thika Tandem A', metadata: { position: '1st', result: '01:18:42', label: 'Women’s tandem road race' } },
    { headline: 'National Time Trial', summary: 'Thika Tandem B', metadata: { position: '2nd', result: '34:16', label: 'Mixed tandem time trial' } },
    { headline: 'County Cycling Challenge', summary: 'Development Team', metadata: { position: '3rd', result: '42:08', label: 'Open tandem category' } }
  ],
  TEAM_STORY: [{ eyebrow: 'Athlete story', headline: 'Trust, timing and one shared finish line', summary: 'Meet the tandem pairs turning disciplined preparation into confidence, independence and competitive performance.', button_text: 'Read their story', button_url: 'team.html' }],
  JOIN_SUPPORT: [
    { headline: 'Ride with us', summary: 'Join training and discover where tandem cycling can take you.', button_text: 'Join the club', button_url: 'join.html' },
    { headline: 'Support the team', summary: 'Help athletes access equipment, coaching and competition.', button_text: 'Support us', button_url: 'support.html' },
    { headline: 'Become a partner', summary: 'Build meaningful impact through inclusive sport.', button_text: 'Partner with us', button_url: 'partners.html' }
  ],
  PARTNERS: [
    { headline: 'Partner one' }, { headline: 'Partner two' }, { headline: 'Partner three' }, { headline: 'Partner four' }
  ]
};

function itemsFor(sections, code) {
  return sections[code]?.length ? sections[code] : fallback[code];
}

function image(item, className = '') {
  return item.image_url
    ? `<img class="${className}" src="${safeUrl(item.image_url, '')}" alt="${escapeHtml(item.image_alt || item.headline || '')}" loading="lazy">`
    : '';
}

function meta(item) {
  return item.metadata && typeof item.metadata === 'object' ? item.metadata : {};
}

function renderQuickActions(items) {
  const container = document.getElementById('quickActionGrid');
  if (!container) return;
  container.innerHTML = items.slice(0, 4).map((item, index) => `
    <a class="tt-p2-action tt-p2-action--${escapeHtml(item.accent || (index === 0 ? 'red' : index === 2 ? 'green' : 'black'))} ${item.image_url ? 'has-image' : ''}" href="${safeUrl(item.button_url || '#')}">
      ${image(item, 'tt-p2-action__image')}
      <span class="tt-p2-action__shade" aria-hidden="true"></span>
      <span class="tt-p2-action__body">
        <strong>${escapeHtml(item.headline)}</strong>
        <small>${escapeHtml(item.summary || '')}</small>
        <i class="bi bi-arrow-up-right" aria-hidden="true"></i>
      </span>
    </a>`).join('');
}

function renderEvents(items) {
  const container = document.getElementById('upcomingEventsContent');
  if (!container) return;
  const [featured, ...rows] = items.slice(0, 4);
  const fm = meta(featured);
  container.innerHTML = `
    <div class="tt-p2-events-layout">
      <article class="tt-p2-event-feature ${featured.image_url ? 'has-image' : ''}">
        ${image(featured, 'tt-p2-event-feature__image')}
        <div class="tt-p2-event-feature__shade" aria-hidden="true"></div>
        <div class="tt-p2-event-date">
          <span>${escapeHtml(formatStoryDate(fm.date || featured.publish_date).split(' ')[0] || 'NEXT')}</span>
          <strong>${escapeHtml(formatStoryDate(fm.date || featured.publish_date).split(' ').slice(1).join(' ') || 'EVENT')}</strong>
        </div>
        <div class="tt-p2-event-feature__content">
          <span class="tt-p2-chip">${escapeHtml(fm.status || 'Upcoming')}</span>
          <h3>${escapeHtml(featured.headline)}</h3>
          <p>${escapeHtml(featured.summary || '')}</p>
          <div class="tt-p2-event-meta"><span><i class="bi bi-geo-alt"></i>${escapeHtml(fm.location || 'Kenya')}</span></div>
          <a href="${safeUrl(featured.button_url || 'events.html')}">View event <i class="bi bi-arrow-right"></i></a>
        </div>
      </article>
      <div class="tt-p2-event-list">
        ${rows.map((item) => {
          const m = meta(item);
          const d = formatStoryDate(m.date || item.publish_date);
          return `<a class="tt-p2-event-row ${item.image_url ? 'has-image' : ''}" href="${safeUrl(item.button_url || 'events.html')}">
            ${item.image_url ? `<span class="tt-p2-event-row__media">${image(item, 'tt-p2-event-row__image')}</span>` : ''}
            <time datetime="${escapeHtml(m.date || '')}"><strong>${escapeHtml(d.split(' ')[0] || '—')}</strong><span>${escapeHtml(d.split(' ').slice(1).join(' ') || 'Date TBC')}</span></time>
            <span class="tt-p2-event-row__main"><small>${escapeHtml(m.location || 'Kenya')}</small><b>${escapeHtml(item.headline)}</b></span>
            <span class="tt-p2-event-row__status">${escapeHtml(m.status || 'Upcoming')}</span>
            <i class="bi bi-arrow-right" aria-hidden="true"></i>
          </a>`;
        }).join('')}
      </div>
    </div>`;
}

function renderIntro(item) {
  const container = document.getElementById('tandemIntroContent');
  if (!container) return;
  container.innerHTML = `<div class="tt-p2-intro-card">
    <div class="tt-p2-intro-media">${image(item, 'tt-p2-intro-image')}<span class="tt-p2-intro-mark">01</span></div>
    <div class="tt-p2-intro-copy">
      <span class="tt-p2-eyebrow">${escapeHtml(item.eyebrow || 'Discover tandem para-cycling')}</span>
      <h2>${escapeHtml(item.headline)}</h2>
      <p>${escapeHtml(item.summary || '')}</p>
      <div class="tt-p2-role-pair"><span><b>Pilot</b><small>Steers, communicates and sets the line.</small></span><span><b>Stoker</b><small>Drives power, rhythm and shared performance.</small></span></div>
      <a class="tt-p2-button" href="${safeUrl(item.button_url || '#')}">${escapeHtml(item.button_text || 'Learn more')} <i class="bi bi-arrow-right"></i></a>
    </div>
  </div>`;
}

function renderResults(items) {
  const container = document.getElementById('latestResultsContent');
  if (!container) return;
  container.innerHTML = `<div class="tt-p2-result-grid">${items.slice(0, 3).map((item, index) => {
    const m = meta(item);
    return `<article class="tt-p2-result-card ${index === 0 ? 'is-featured' : ''} ${item.image_url ? 'has-image' : ''}">
      ${item.image_url ? `<div class="tt-p2-result-card__media">${image(item, 'tt-p2-result-card__image')}</div>` : ''}
      <div class="tt-p2-result-card__body">
        <span class="tt-p2-result-position">${escapeHtml(m.position || `${index + 1}`)}</span>
        <div><small>${escapeHtml(m.label || 'Recent result')}</small><h3>${escapeHtml(item.headline)}</h3><p>${escapeHtml(item.summary || '')}</p></div>
        <strong class="tt-p2-result-time">${escapeHtml(m.result || '—')}</strong>
      </div>
    </article>`;
  }).join('')}</div>`;
}

function renderTeamStory(item) {
  const container = document.getElementById('teamStoryContent');
  if (!container) return;
  container.innerHTML = `<article class="tt-p2-team-story">
    <div class="tt-p2-team-story__media">${image(item, 'tt-p2-team-story__image')}</div>
    <div class="tt-p2-team-story__copy"><span class="tt-p2-eyebrow">${escapeHtml(item.eyebrow || 'Athlete story')}</span><h3>${escapeHtml(item.headline)}</h3><p>${escapeHtml(item.summary || '')}</p><a class="tt-p2-button" href="${safeUrl(item.button_url || '#')}">${escapeHtml(item.button_text || 'Read profile')} <i class="bi bi-arrow-right"></i></a></div>
  </article>`;
}

function renderJoinSupport(items) {
  const container = document.getElementById('joinSupportContent');
  if (!container) return;
  const background = items.find((item) => item.image_url)?.image_url;
  container.innerHTML = `<div class="tt-p2-join-panel" ${background ? `style="--tt-p2-join-image:url('${safeUrl(background, '')}')"` : ''}>
    <div class="tt-section-shell"><div class="tt-p2-join-grid">${items.slice(0, 3).map((item) => `<a href="${safeUrl(item.button_url || '#')}" class="tt-p2-join-card"><span>${escapeHtml(item.headline)}</span><p>${escapeHtml(item.summary || '')}</p><strong>${escapeHtml(item.button_text || 'Find out more')} <i class="bi bi-arrow-right"></i></strong></a>`).join('')}</div></div>
  </div>`;
}

function renderPartners(items) {
  const container = document.getElementById('partnerLogoStrip');
  if (!container) return;
  container.innerHTML = items.slice(0, 8).map((item) => `<a class="tt-p2-partner" href="${safeUrl(item.button_url || '#')}" aria-label="${escapeHtml(item.headline)}">${item.image_url ? image(item, 'tt-p2-partner__logo') : `<span>${escapeHtml(item.headline)}</span>`}</a>`).join('');
}

export async function initializePhase2() {
  const sections = await getAllPhase2Sections();
  renderQuickActions(itemsFor(sections, 'QUICK_ACTIONS'));
  renderEvents(itemsFor(sections, 'UPCOMING_EVENTS'));
  renderIntro(itemsFor(sections, 'TANDEM_INTRO')[0]);
  renderResults(itemsFor(sections, 'LATEST_RESULTS'));
  renderTeamStory(itemsFor(sections, 'TEAM_STORY')[0]);
  renderJoinSupport(itemsFor(sections, 'JOIN_SUPPORT'));
  renderPartners(itemsFor(sections, 'PARTNERS'));
}
