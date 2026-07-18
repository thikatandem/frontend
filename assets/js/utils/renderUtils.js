export function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

export function safeUrl(value, fallback = '#') {
  if (!value) return fallback;

  try {
    const url = new URL(value, window.location.origin);
    const allowedProtocols = ['http:', 'https:'];

    if (url.origin === window.location.origin || allowedProtocols.includes(url.protocol)) {
      return url.href;
    }
  } catch (error) {
    console.warn('Invalid URL ignored:', value, error);
  }

  return fallback;
}

export function storyImage(record) {
  const media = record?.media_library;
  if (Array.isArray(media)) return media[0]?.file_url || '';
  return media?.file_url || record?.image_url || '';
}

export function formatStoryDate(value) {
  if (!value) return '';

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';

  return new Intl.DateTimeFormat('en-KE', {
    day: '2-digit',
    month: 'short',
    year: 'numeric'
  }).format(date);
}
