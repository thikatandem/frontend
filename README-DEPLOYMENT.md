# Thika Tandem SEO + Netlify package

Only each HTML document head was enhanced. Existing body content was preserved byte-for-byte.

## Included
- 20 SEO-enhanced HTML files
- robots.txt
- sitemap.xml
- manifest.webmanifest and site.webmanifest
- _redirects
- netlify.toml
- SEO-AUDIT.json

## Pretty URLs
- /news.html permanently redirects to /news
- /news internally serves /news.html
- /index.html permanently redirects to /
- HTTP and www redirect to https://thikatandemclub.com

Copy these files into the website publish root. Keep your existing assets folder in the same root. Do not add a catch-all SPA rewrite. After deployment, submit /sitemap.xml in Google Search Console.

The social image and logo paths must exist exactly as referenced in the HTML metadata.
