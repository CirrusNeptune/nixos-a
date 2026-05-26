# SF K9 Unit Scraper — Blocked Context

## Task
Build a scraper for https://www.sfk9unit.org/calendar to extract upcoming events.

## Why It's Blocked
The site is built on **Wix Thunderbolt** which renders all page content client-side via JavaScript. Standard HTTP requests (requests + BeautifulSoup) return only the Wix framework shell — no event data, text, or calendar content is present in the initial HTML.

A browser engine (Selenium/Playwright + Chromium) is required to render the page, but no browser is installed in the current environment and installing one was not feasible at the time.

## What Was Investigated
- **Direct page fetch** (`/calendar`, `/about-us`, `/event-guidelines`, `/woofstock`, `/mosh-rules`): All return only Wix JS boilerplate, zero readable content.
- **Wix internal APIs** (`/_api/v2/dynamicmodel`, `/_api/v1/access-tokens`): Return auth tokens and app instance IDs but no page content or event data.
- **Wix Events API** (`/_api/events-server/api/v1/events`, `/_api/wix-one-events-server/...`): 404 — the site does not appear to use the Wix Events app.
- **Sitemap** (`/sitemap.xml` → `/pages-sitemap.xml`): Lists 21 pages, none with embedded event data accessible without JS rendering.
- **metaSiteId**: `e62f48aa-466a-44a2-ba65-1cfceec9eb89`

## To Unblock
1. **Install Chromium + Selenium** in the dev environment (and in the container image).
2. Use Selenium in headless mode to render `/calendar`, wait for Wix JS to hydrate, then extract the rendered DOM text.
3. Parse the recurring event details (names, cadences, times, locations) from the rendered page content.
4. Compute concrete dates for current month + next month.
5. Update `requirements.txt` and `Dockerfile` to include `selenium` and Chromium.
