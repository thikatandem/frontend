import { loadFeaturedStory } from '../hero/heroFeaturedStory.js';
import { loadStoryGrid } from '../hero/heroStoryGrid.js';
import { loadNewsRail } from './newsRail.js';
import { initializePhase2 } from './phase2.js';

export async function initializeHome() {
  const results = await Promise.allSettled([
    loadFeaturedStory(),
    loadStoryGrid(),
    loadNewsRail(),
    initializePhase2()
  ]);

  results.forEach((result) => {
    if (result.status === 'rejected') {
      console.error('Homepage component failed:', result.reason);
    }
  });
}
