# Event Scraper — Project Summary

## Overview
A Python application that scrapes upcoming events from multiple websites, merges them into a sorted master list, and dispatches unsent events to Home Assistant's calendar via its REST API. SQLite tracks which events have already been sent to avoid duplicates.

Designed to run weekly on Fridays in a Podman container, triggered by a systemd user timer.

## Architecture

```
event_manager.py              # Orchestrator: calls scrapers, dedupes, dispatches
├── sf_dog_events_scraper.py        # sf.dog/events — HTML scraping (requests + BS4)
├── frolic_events_scraper.py        # frolicparty.com — HTML scraping (requests + BS4)
├── transform1060_events_scraper.py # transform1060.org/calendar — JSON-LD + MEC AJAX
└── eagle_bar_events_scraper.py     # sf-eagle.com/events — Tribe Events REST API
```

### Data flow
1. Each scraper's `scrape_events()` returns a list of event dicts.
2. `event_manager.gather_all_events()` calls all scrapers, tags each event with its source, merges and sorts by `start_datetime`.
3. `event_manager.publish_events()` iterates the list. For each event, it hashes `(title, start_datetime, url)` with MD5 and checks SQLite. Unsent events go to `send_to_home_assistant()`, which POSTs to HA's `calendar.create_event` service.

### Standard event schema
Every scraper returns dicts with these keys:
```json
{
  "title": "string",
  "description": "string or null",
  "location": "string or null",
  "start_datetime": "2026-03-15T19:00:00",
  "end_datetime": "2026-03-15T21:00:00 or null",
  "url": "string or null"
}
```
`event_manager` adds a `"source"` key after collection.

## Scrapers

### sf_dog_events_scraper.py
- **Source**: https://www.sf.dog/events
- **Method**: Fetches the events listing page, collects all `/events/*/` links, visits each event page individually.
- **Parsing**: Extracts title from `<h1>`/`<h3>`, date/time/location from `<li>` elements with emoji prefixes (📅 Date:, 🕔 Time:, 📍 Location:). Handles multi-date strings and overnight events (end < start → next day).
- **Fallback**: If no date is found on the page, parses a date from the URL slug (e.g. `/events/slug/2026-02`).

### frolic_events_scraper.py
- **Source**: https://www.frolicparty.com/
- **Method**: Single page fetch. All events share the same time/location; only dates change.
- **Parsing**: Extracts location from `<title>` tag, time from `.style8` span, schedule from `.style5` span matching `"YYYY Saturday dates: ..."`. Splits on commas/and, parses `"Month Day"` with the schedule year. Rolls overnight end times.

### transform1060_events_scraper.py
- **Source**: https://www.transform1060.org/calendar/
- **Method**: Two-step: (1) extract JSON-LD `@type: Event` from the calendar page for current month, (2) POST to MEC AJAX endpoint (`mec_monthly_view_load_month`) for next month's events.
- **Parsing**: Merges JSON-LD and AJAX results keyed by `(url, date)` for dedup. Visits individual event pages (`/events/*`) for start/end times and descriptions. Handles midnight-crossing end times.

### eagle_bar_events_scraper.py
- **Source**: https://sf-eagle.com/events/
- **Method**: Calls the Tribe Events Calendar REST API at `/wp-json/tribe/events/v1/events?start_date=<today>&per_page=50`. Returns structured JSON directly — no HTML parsing needed.
- **Parsing**: Maps API fields (`title`, `start_date`, `end_date`, `venue`, `description`) to standard schema. Strips HTML tags from descriptions. Builds location string from venue name + address + city + state.

## Logging
All files use Python's `logging` module with a `"event_scraper"` logger hierarchy:
- `event_manager.py` configures the root `"event_scraper"` logger with two handlers:
  - **StreamHandler** → console (stdout)
  - **FileHandler** → `event_scraper.log` (configurable via `LOG_FILE` env var)
- Format: `%(asctime)s [%(levelname)s] %(name)s: %(message)s`
- Each scraper uses a child logger (e.g. `"event_scraper.sf_dog"`) that inherits the parent's handlers when called from `event_manager`.
- When scrapers run standalone (`__main__`), they call `logging.basicConfig()` to configure the root logger as a fallback.

## Containerization

### Dockerfile
- Base: `python:3.12-slim` (includes sqlite3)
- Copies `requirements.txt`, installs deps, copies `*.py` files
- No `.env` baked in — passed at runtime via `--env-file`

### requirements.txt
```
requests
beautifulsoup4
python-dotenv
```

### .dockerignore
Excludes `__pycache__/`, `*.pyc`, `.env`, `events.db`, `.claude/`

### Scheduling
- `event-scraper.service` — systemd oneshot unit that runs the container via Podman with `--env-file`, `-e DB_PATH=/data/events.db`, and `-v event-scraper-data:/data`
- `event-scraper.timer` — fires `OnCalendar=Fri *-*-* 09:00:00` with `Persistent=true`
- Installed to `~/.config/systemd/user/` (user-level, no root)

### Build & run
```bash
podman build -t event-scraper .
podman volume create event-scraper-data
podman run --rm --env-file .env -e DB_PATH=/data/events.db -v event-scraper-data:/data event-scraper
```

## Environment Variables
| Variable | Default | Purpose |
|---|---|---|
| `HA_URL` | `http://homeassistant.local:8123` | Home Assistant base URL |
| `HA_TOKEN` | (empty) | HA long-lived access token |
| `HA_CALENDAR_ENTITY` | `calendar.local_calendar` | Target calendar entity |
| `DB_PATH` | `<script_dir>/events.db` | SQLite database path |
| `LOG_FILE` | `<script_dir>/event_scraper.log` | Log file path |

## File Layout
```
event_scraper/
├── .dockerignore
├── .env                          # Not committed — HA_TOKEN, HA_URL, etc.
├── Dockerfile
├── requirements.txt
├── event-scraper.service         # systemd unit
├── event-scraper.timer           # systemd timer (Fridays 9 AM)
├── event_manager.py              # Orchestrator
├── sf_dog_events_scraper.py      # Scraper: sf.dog
├── frolic_events_scraper.py      # Scraper: frolicparty.com
├── transform1060_events_scraper.py # Scraper: transform1060.org
├── eagle_bar_events_scraper.py   # Scraper: sf-eagle.com
├── events.db                     # SQLite (sent_events tracking)
├── event_scraper.log             # Log output
├── prd/                          # Pending task specs
├── done/                         # Completed task specs
│   └── eagle_bar.txt
├── blocked/                      # Blocked task specs + context
│   ├── sf_k9_unit.txt
│   └── sf_k9_unit_context.md
└── contexts/                     # This file
    └── project_summary.md
```

## Blocked Work

### SF K9 Unit scraper (`blocked/sf_k9_unit.txt`)
- **Site**: https://www.sfk9unit.org/calendar
- **Blocker**: Wix Thunderbolt site — all content is JS-rendered. Standard HTTP returns only framework boilerplate. No usable Wix APIs were found (Events API returns 404). Selenium + Chromium required but not installed in the environment.
- **metaSiteId**: `e62f48aa-466a-44a2-ba65-1cfceec9eb89`
- **To unblock**: Install Chromium + Selenium, render the page headlessly, extract recurring event details from the DOM, compute dates for current + next month. Will also need Dockerfile changes.
- **Full context**: `blocked/sf_k9_unit_context.md`
