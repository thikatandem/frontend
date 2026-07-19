THIKA TANDEM REVISED PACKAGE

WHAT THIS PACKAGE DOES
1. Keeps phase1.css as the only supplied site stylesheet.
2. Removes references to assets/css/main.css from every HTML file through APPLY_FIX.ps1.
3. Initializes the database navigation on every page from main.js.
4. Renders Home only from public.navigation_items. No Home entry is hard-coded.
5. Renders the header CTA only from public.navigation_cta_links.
6. Uses one drawer controller: assets/js/navigation/navigation.js.
7. Keeps optional AOS, GLightbox, Swiper and Isotope guarded so missing libraries cannot stop navigation.
8. Stops querying the nonexistent public.site_settings table.
9. Keeps Supabase data tables unchanged.

INSTALL
A. Extract this ZIP into a temporary folder.
B. Open PowerShell inside the extracted folder.
C. Run:
   powershell -ExecutionPolicy Bypass -File .\_install\APPLY_FIX.ps1 -SiteRoot "E:\Tandem"

Change E:\Tandem only if your website root is elsewhere.

The installer:
- backs up the existing assets folder and changed HTML files;
- copies the revised assets folder into your site;
- removes only <link> tags that reference assets/css/main.css.

DATABASE REQUIREMENT
Home must exist as an active root row in public.navigation_items linked to the MAIN navigation region.
This package does not insert or hard-code Home.

EXPECTED HTML IDS
The existing header must retain:
- mainNavigationList
- navmenu
- mobileNavToggle
- utilityNavigationList
- mobileUtilityNavigationList
- headerCtaContainer
- navigationCampaignBar
- a .tt-mobile-backdrop element

No database schema changes are included.
