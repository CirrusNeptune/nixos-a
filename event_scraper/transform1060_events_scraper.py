#!/usr/bin/env python3
"""
Web scraper for transform1060.org events
Extracts upcoming events from the calendar page (current + next month)
by parsing embedded JSON-LD data and visiting individual event pages for times.

The site uses the Modern Events Calendar (MEC) WordPress plugin.
"""

import logging
import requests
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
from dotenv import load_dotenv
from html import unescape
import json
import os
import re

load_dotenv()

logger = logging.getLogger("event_scraper.transform1060")

# Home Assistant configuration
HA_BASE_URL = os.environ.get("HA_URL", "http://homeassistant.local:8123")
HA_TOKEN = os.environ.get("HA_TOKEN", "")
HA_CALENDAR_ENTITY = os.environ.get("HA_CALENDAR_ENTITY", "calendar.local_calendar")

CALENDAR_URL = "https://www.transform1060.org/calendar/"
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                   '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
}


def scrape_events():
    """
    Scrape events from transform1060.org/calendar/ and return as JSON array.
    Covers the current month and next month.
    """
    events = []
    now = datetime.now()

    try:
        # --- Step 1: Fetch the calendar page ---
        logger.debug("Fetching calendar page: %s", CALENDAR_URL)
        response = requests.get(CALENDAR_URL, headers=HEADERS, timeout=15)
        logger.debug("Response status: %d", response.status_code)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')

        # --- Step 2: Extract JSON-LD events (current month + partial next) ---
        jsonld_events = extract_jsonld_events(soup)
        logger.debug("Found %d JSON-LD events on calendar page", len(jsonld_events))

        # --- Step 3: Load next month via MEC AJAX ---
        ajax_events = load_next_month_events(soup)
        logger.debug("Found %d events from next month AJAX", len(ajax_events))

        # --- Step 4: Merge into unified event list, de-duplicate ---
        # Build a dict keyed by (url, date) to de-duplicate
        merged = {}

        # Add JSON-LD events
        for e in jsonld_events:
            event_url = e.get('url') or e.get('offers', {}).get('url', '')
            start_date = e.get('startDate', '')
            key = (event_url, start_date)
            if key not in merged:
                name = unescape(e.get('name', '') or '')
                loc_data = e.get('location', {})
                loc_name = 'Transform 1060'
                loc_addr = loc_data.get('address', '')
                location = None
                if loc_name and loc_addr:
                    location = f"{loc_name}, {loc_addr}"
                elif loc_addr:
                    location = loc_addr
                elif loc_name:
                    location = loc_name
                merged[key] = {
                    '_source': 'jsonld',
                    'date': start_date,
                    'end_date': e.get('endDate', start_date),
                    'title': name or None,
                    'url': event_url or None,
                    'location': location,
                    'start_time': None,
                    'end_time': None,
                }

        # Add AJAX events (these already have times)
        for e in ajax_events:
            key = (e.get('url', ''), e.get('date', ''))
            if key not in merged:
                merged[key] = e

        logger.debug("%d unique events after de-duplication", len(merged))

        # --- Step 5: Filter future events and fetch details ---
        for key, event_data in merged.items():
            start_date = event_data.get('date', '')

            # Skip past events
            try:
                event_dt = datetime.strptime(start_date, '%Y-%m-%d')
                if event_dt.date() < now.date():
                    logger.debug("Skipping past event: %s %s", start_date, event_data.get('title', ''))
                    continue
            except ValueError:
                pass

            event_url = event_data.get('url', '')
            start_time = event_data.get('start_time')
            end_time = event_data.get('end_time')

            event = {
                "title": event_data.get('title'),
                "description": None,
                "location": event_data.get('location'),
                "start_datetime": f"{start_date}T{start_time or '00:00:00'}",
                "end_datetime": None,
                "url": event_url or None,
            }

            # Fetch event page for times (if missing) and description
            if event_url and 'transform1060.org/events/' in event_url:
                page_details = fetch_event_page(event_url)
                if page_details:
                    if not start_time and page_details.get('start_time'):
                        start_time = page_details['start_time']
                        event['start_datetime'] = f"{start_date}T{start_time}"
                    if not end_time and page_details.get('end_time'):
                        end_time = page_details['end_time']
                    if page_details.get('description'):
                        event['description'] = page_details['description']
                    if page_details.get('location') and not event['location']:
                        event['location'] = page_details['location']

            # Compute end datetime with midnight-crossing fix
            if end_time:
                end_date_str = event_data.get('end_date', start_date)
                if start_time and end_time <= start_time:
                    next_day = datetime.strptime(start_date, '%Y-%m-%d') + timedelta(days=1)
                    end_date_str = next_day.strftime('%Y-%m-%d')
                    logger.debug("  End time crosses midnight, using end date %s", end_date_str)
                event['end_datetime'] = f"{end_date_str}T{end_time}"

            events.append(event)
            logger.debug("Added: %s on %s", event['title'], event['start_datetime'])

        events.sort(key=lambda x: x.get('start_datetime') or '')
        logger.debug("Total future events: %d", len(events))

    except Exception as e:
        logger.error("Scrape failure: %s", e, exc_info=True)

    return events


def extract_jsonld_events(soup):
    """Extract Event objects from JSON-LD script tags."""
    events = []
    for script in soup.find_all('script', type='application/ld+json'):
        try:
            data = json.loads(script.string)
            if isinstance(data, dict) and data.get('@type') == 'Event':
                events.append(data)
            elif isinstance(data, list):
                events.extend(d for d in data if isinstance(d, dict) and d.get('@type') == 'Event')
        except (json.JSONDecodeError, TypeError):
            pass
    return events


def load_next_month_events(soup):
    """
    Load the next month's events via MEC AJAX.
    Parses the mecMonthlyView config from inline scripts to build the AJAX request.
    Returns a list of event dicts parsed from the AJAX HTML (events_side).
    """
    page_text = str(soup)

    # Extract the MEC monthly view config
    match = re.search(
        r'mecMonthlyView\(\s*\{(.*?)\}\s*\)',
        page_text,
        re.DOTALL
    )
    if not match:
        logger.warning("Could not find mecMonthlyView config")
        return []

    config_text = match.group(1)

    # Extract widget ID
    id_match = re.search(r'id:\s*"(\d+)"', config_text)
    widget_id = id_match.group(1) if id_match else None

    # Extract next month info
    next_match = re.search(r'next_month:\s*\{year:\s*"(\d+)",\s*month:\s*"(\d+)"\}', config_text)
    if not next_match or not widget_id:
        logger.warning("Could not parse next month from config")
        return []

    next_year = next_match.group(1)
    next_month = next_match.group(2)
    logger.debug("Loading next month: %s-%s", next_year, next_month)

    # Extract atts parameter
    atts_match = re.search(r'atts:\s*"([^"]*)"', config_text)
    atts = atts_match.group(1) if atts_match else ''

    # Make the AJAX request
    ajax_url = "https://www.transform1060.org/wp-admin/admin-ajax.php"
    payload = {
        'action': 'mec_monthly_view_load_month',
        'mec_year': next_year,
        'mec_month': next_month,
        'id': widget_id,
        'atts': atts,
        'apply_sf': '0',
    }

    try:
        resp = requests.post(ajax_url, data=payload, headers=HEADERS, timeout=15)
        logger.debug("AJAX response status: %d, length: %d", resp.status_code, len(resp.text))
        if not resp.ok:
            return []

        data = resp.json()
        events_html = data.get('events_side', '')
        return parse_mec_events_html(events_html)

    except Exception as e:
        logger.error("AJAX request failed: %s", e)
        return []


def parse_mec_events_html(html):
    """
    Parse event data from MEC calendar events_side HTML.
    Each day section has data-mec-cell="YYYYMMDD" and contains articles
    with .mec-event-time, .mec-event-title a[href], and .mec-event-loc-place.
    Returns list of dicts with keys matching our event format.
    """
    events_soup = BeautifulSoup(html, 'html.parser')
    events = []
    seen = set()

    for section in events_soup.find_all('div', class_='mec-calendar-events-sec'):
        cell_date = section.get('data-mec-cell', '')
        if not cell_date or len(cell_date) != 8:
            continue
        date_str = f"{cell_date[:4]}-{cell_date[4:6]}-{cell_date[6:8]}"

        for article in section.find_all('article', class_='mec-event-article'):
            # Skip "No Events" placeholders
            detail = article.find('div', class_='mec-event-detail')
            if detail and detail.get_text(strip=True) == 'No Events':
                continue

            link = article.find('a', href=True)
            if not link:
                continue

            url = link['href']
            title = link.get_text(strip=True)

            # De-duplicate by URL + date
            key = (url, date_str)
            if key in seen:
                continue
            seen.add(key)

            # Extract inline time
            time_el = article.find(class_='mec-event-time')
            start_time = None
            end_time = None
            if time_el:
                time_text = time_el.get_text(strip=True)
                start_time, end_time = parse_time_range(time_text)

            # Extract location
            loc_el = article.find(class_='mec-event-loc-place')
            location = loc_el.get_text(strip=True) if loc_el else None

            events.append({
                '_source': 'ajax',
                'date': date_str,
                'title': unescape(title) if title else None,
                'url': url,
                'start_time': start_time,
                'end_time': end_time,
                'location': location,
            })

    return events


def fetch_event_page(url):
    """
    Fetch an individual event page and extract time, description, and location.
    MEC event pages have:
      .mec-single-event-time: "Time8:00 PM - 12:00 AM"
      .mec-single-event-description: description text
      .mec-single-event-location: location text
    """
    try:
        logger.debug("  Fetching event page: %s", url)
        resp = requests.get(url, headers=HEADERS, timeout=15)
        if not resp.ok:
            logger.warning("  Event page returned %d", resp.status_code)
            return None
        soup = BeautifulSoup(resp.content, 'html.parser')

        details = {}

        # Extract time
        time_el = soup.find(class_='mec-single-event-time')
        if time_el:
            time_text = time_el.get_text(strip=True)
            # Strip leading "Time" label
            time_text = re.sub(r'^Time\s*', '', time_text)
            logger.debug("  Time: '%s'", time_text)
            start_time, end_time = parse_time_range(time_text)
            details['start_time'] = start_time
            details['end_time'] = end_time

        # Extract description
        desc_el = soup.find(class_='mec-single-event-description')
        if desc_el:
            text = desc_el.get_text(separator=' ', strip=True)
            if text:
                details['description'] = text[:500]

        # Extract location
        loc_el = soup.find(class_='mec-single-event-location')
        if loc_el:
            text = loc_el.get_text(strip=True)
            text = re.sub(r'^Location\s*', '', text)
            if text:
                details['location'] = text

        return details

    except Exception as e:
        logger.error("  Error fetching event page: %s", e)
        return None


def parse_time_range(text):
    """
    Parse a time range like "8:00 PM - 12:00 AM" into 24h start/end strings.
    Returns (start, end) as "HH:MM:SS" or (None, None).
    """
    def to_24h(t):
        t = t.strip().lower()
        match = re.match(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', t)
        if not match:
            return None
        hour, minute, period = match.groups()
        hour = int(hour)
        minute = int(minute) if minute else 0
        if period == 'pm' and hour != 12:
            hour += 12
        elif period == 'am' and hour == 12:
            hour = 0
        return f"{hour:02d}:{minute:02d}:00"

    parts = re.split(r'\s*[-–]\s*', text.strip(), maxsplit=1)
    start = to_24h(parts[0]) if parts else None
    end = to_24h(parts[1]) if len(parts) > 1 else None
    return start, end


def add_events_to_home_assistant(events):
    """
    Add events to a Home Assistant calendar via the REST API.
    Uses the calendar.create_event service.
    """
    if not HA_TOKEN:
        logger.error("HA_TOKEN environment variable is not set. "
                      "Create a long-lived access token in Home Assistant "
                      "(Profile -> Security -> Long-Lived Access Tokens) "
                      "and set it in your .env file.")
        return []

    api_url = f"{HA_BASE_URL}/api/services/calendar/create_event"
    ha_headers = {
        "Authorization": f"Bearer {HA_TOKEN}",
        "Content-Type": "application/json",
    }

    results = []
    for event in events:
        payload = {
            "entity_id": HA_CALENDAR_ENTITY,
            "summary": event.get("title") or "Transform1060 Event",
        }

        start = event.get("start_datetime")
        if start:
            payload["start_date_time"] = start.replace("T", " ")
        else:
            logger.warning("Skipping event with no start datetime: %s", event.get('title'))
            continue

        end = event.get("end_datetime")
        if end:
            payload["end_date_time"] = end.replace("T", " ")
        else:
            fallback_end = datetime.fromisoformat(start) + timedelta(hours=2)
            payload["end_date_time"] = fallback_end.strftime("%Y-%m-%d %H:%M:%S")
            logger.debug("No end time, using fallback: %s", payload['end_date_time'])

        if event.get("description"):
            payload["description"] = event["description"]
        if event.get("location"):
            payload["location"] = event["location"]

        logger.info("Creating HA calendar event: %s", payload['summary'])
        logger.debug("  Start: %s", payload['start_date_time'])
        logger.debug("  End:   %s", payload['end_date_time'])

        try:
            response = requests.post(api_url, headers=ha_headers, json=payload, timeout=10)
            if response.ok:
                logger.info("  -> Success (HTTP %d)", response.status_code)
                results.append({"event": event["title"], "status": "created"})
            else:
                logger.error("  -> Failed (HTTP %d): %s", response.status_code, response.text)
                results.append({"event": event["title"], "status": "failed",
                                "error": response.text})
        except Exception as e:
            logger.error("  -> Error: %s", e)
            results.append({"event": event["title"], "status": "error", "error": str(e)})

    return results


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    events = scrape_events()
    logger.info(json.dumps(events, indent=2, ensure_ascii=False))

    if events:
        logger.info("Adding %d event(s) to Home Assistant calendar '%s'...",
                     len(events), HA_CALENDAR_ENTITY)
        results = add_events_to_home_assistant(events)
        logger.info("Home Assistant results:")
        for r in results:
            logger.info("  %s: %s", r['event'], r['status'])
    else:
        logger.info("No future events to add to Home Assistant.")
