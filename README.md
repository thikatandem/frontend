# Thika Tandem linked pages package

Generated pages: 23

## Included
- 23 complete HTML pages matching the existing Thika Tandem visual language
- one complete idempotent SQL migration per page
- one combined SQL migration: `sql/00_ALL_PAGES.sql`
- appended `assets/css/phase1.css`
- shared database-driven renderer: `assets/js/pages/pageContent.js`

## Installation
1. Copy all HTML files to the website root.
2. Replace your current `assets/css/phase1.css` with the supplied appended version.
3. Copy `assets/js/pages/pageContent.js` into the matching project folder.
4. Run each SQL file separately, or run `sql/00_ALL_PAGES.sql`.
5. Ensure `assets/js/supabase/supabaseClient.js` exports a named `supabase` client.
6. Rename physical image files that still contain `_001` so they match the clean manifest URLs.

## Pages
- news.html
- events.html
- campaigning.html
- learning.html
- insight-zone.html
- team.html
- shop.html
- start.html
- mtb.html
- volunteer.html
- membership.html
- results.html
- rankings.html
- benefits.html
- clubs.html
- officials.html
- cyclocross.html
- rides.html
- coaches.html
- championships.html
- renew.html
- partners.html
- teams.html

## Important
The supplied SQL uses your existing `profiles` and `user_role_master` tables for administrator authorization.
Recognised role codes: ADMIN, SUPER_ADMIN, CONTENT_ADMIN, EDITOR.
