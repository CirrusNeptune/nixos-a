#!/usr/bin/env python3
"""
Web scraper for sf.dog events
Extracts upcoming events and returns them as JSON
"""

import logging
import requests
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
from dotenv import load_dotenv
import json
import os
import re
from urllib.parse import urljoin

load_dotenv()

logger = logging.getLogger("event_scraper.sf_dog")

# Home Assistant configuration
HA_BASE_URL = os.environ.get("HA_URL", "http://homeassistant.local:8123")
HA_TOKEN = os.environ.get("HA_TOKEN", "")
HA_CALENDAR_ENTITY = os.environ.get("HA_CALENDAR_ENTITY", "calendar.local_calendar")


def scrape_events():
    """
    Scrape events from sf.dog/events and return as JSON array
    """
    base_url = "https://www.sf.dog"
    events_url = f"{base_url}/events"

    # Headers to mimic a browser request
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    events = []

    try:
        # Get the main events page
        logger.debug("Fetching events page: %s", events_url)
        response = requests.get(events_url, headers=headers, timeout=10)
        logger.debug("Response status: %d", response.status_code)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')
        logger.debug("Page content length: %d bytes", len(response.content))

        # Find all event links
        event_links = set()
        all_links = soup.find_all('a', href=True)
        logger.debug("Total links found on page: %d", len(all_links))
        for link in all_links:
            href = link['href']
            # Look for event links (pattern: /events/[event-name]/[date])
            if '/events/' in href and href.count('/') >= 3:
                full_url = urljoin(base_url, href)
                event_links.add(full_url)

        logger.debug("Unique event links found: %d", len(event_links))
        for link in event_links:
            logger.debug("  -> %s", link)

        # Scrape each event page
        for event_url in event_links:
            try:
                logger.debug("Scraping event page: %s", event_url)
                event_data = scrape_event_page(event_url, headers)
                if event_data:
                    logger.debug("  Title: %s", event_data.get('title'))
                    logger.debug("  Start: %s", event_data.get('start_datetime'))
                    logger.debug("  Location: %s", event_data.get('location'))
                    if is_future_event(event_data.get('start_datetime')):
                        logger.debug("  -> Included (future event)")
                        events.append(event_data)
                    else:
                        logger.debug("  -> Skipped (past event)")
                else:
                    logger.debug("  -> No event data returned")
            except Exception as e:
                logger.error("  -> Error scraping event: %s", e)
                continue

        # Sort events by start datetime
        events.sort(key=lambda x: x.get('start_datetime') or '')
        logger.debug("Total future events found: %d", len(events))

    except Exception as e:
        logger.error("Main page failure: %s", e)
        pass

    return events


def scrape_event_page(url, headers):
    """
    Scrape individual event page and extract event details.

    sf.dog event pages use <li> elements with emoji prefixes for structured data:
      📅 Date: Friday, February 20, 2026
      🕔 Time: 8pm - 2am
      📍 Location: Lone Star Saloon, 1354 Harrison Street, San Francisco
    """
    try:
        response = requests.get(url, headers=headers, timeout=10)
        logger.debug("  Event page status: %d", response.status_code)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')

        # Initialize event object
        event = {
            "title": None,
            "description": None,
            "location": None,
            "start_datetime": None,
            "end_datetime": None,
            "url": url
        }

        # Extract title from <h1>, with optional subtitle from <h3>
        # Only treat <h3> as a subtitle if it doesn't end with ":" (section headers do)
        h1 = soup.find('h1')
        h3 = soup.find('h3')
        if h1:
            title = h1.get_text(strip=True)
            if h3:
                subtitle = h3.get_text(strip=True)
                if not subtitle.endswith(':'):
                    title = f"{title}: {subtitle}"
                    logger.debug("  Appended <h3> subtitle: '%s'", subtitle)
                else:
                    logger.debug("  Skipped <h3> (section header): '%s'", subtitle)
            event['title'] = title
            logger.debug("  Title: %s", event['title'])
        else:
            logger.debug("  No <h1> title found")

        # Extract details from <li> elements (emoji-prefixed structured data)
        list_items = soup.find_all('li')
        logger.debug("  Found %d <li> elements", len(list_items))
        date_text = None
        time_text = None
        for li in list_items:
            li_text = li.get_text(strip=True)
            # Strip leading emoji characters and whitespace
            cleaned = li_text.lstrip('\U0001f4c5\U0001f554\U0001f4cd\U0001f4b0\U0001f39f\ufe0f ')

            if re.match(r'Date:', cleaned, re.I):
                date_text = re.sub(r'^Date:\s*', '', cleaned, flags=re.I)
                logger.debug("  Raw date text: '%s'", date_text)
            elif re.match(r'Time:', cleaned, re.I):
                time_text = re.sub(r'^Time:\s*', '', cleaned, flags=re.I)
                logger.debug("  Raw time text: '%s'", time_text)
            elif re.match(r'Location:', cleaned, re.I):
                event['location'] = re.sub(r'^Location:\s*', '', cleaned, flags=re.I)
                logger.debug("  Location: %s", event['location'])

        # Parse date and time into ISO datetimes
        if date_text:
            event_date = parse_event_date(date_text)
            if event_date:
                start_time, end_time = parse_event_time(time_text)
                if start_time:
                    event['start_datetime'] = f"{event_date}T{start_time}"
                else:
                    event['start_datetime'] = f"{event_date}T00:00:00"
                if end_time:
                    # If end time is earlier than start (e.g. 8pm-2am), roll to next day
                    end_date = event_date
                    if start_time and end_time < start_time:
                        next_day = datetime.strptime(event_date, '%Y-%m-%d') + timedelta(days=1)
                        end_date = next_day.strftime('%Y-%m-%d')
                        logger.debug("  End time crosses midnight, rolling to %s", end_date)
                    event['end_datetime'] = f"{end_date}T{end_time}"
                logger.debug("  Parsed start: %s", event['start_datetime'])
                logger.debug("  Parsed end:   %s", event['end_datetime'])

        # Fallback: parse date from URL (e.g., /events/slut-puppy/2026-02)
        if not event['start_datetime']:
            logger.debug("  No date from page, falling back to URL parsing")
            date_match = re.search(r'/(\d{4})-(\d{2})(?:-(\d{2}))?', url)
            if date_match:
                year, month, day = date_match.groups()
                day = day or '01'
                event['start_datetime'] = f"{year}-{month}-{day}T00:00:00"
                logger.debug("  Parsed date from URL: %s", event['start_datetime'])

        if not event['start_datetime']:
            logger.warning("  No datetime found for event at %s", url)

        # Extract description from <p> tags (skip generic meta description)
        paragraphs = soup.find_all('p')
        desc_parts = []
        for p in paragraphs:
            text = p.get_text(strip=True)
            if text and len(text) > 20:
                desc_parts.append(text)
        if desc_parts:
            event['description'] = ' '.join(desc_parts)[:500]
            logger.debug("  Description (%d chars): %s...", len(event['description']), event['description'][:80])
        else:
            logger.debug("  No description paragraphs found")

        return event

    except Exception as e:
        logger.error("  Exception scraping event page %s: %s", url, e)
        return None


def parse_event_date(date_text):
    """
    Parse date text like "Friday, February 20, 2026" into "2026-02-20".
    Handles multi-date strings like "Saturday, April 19, 2025, Saturday, April 26, 2025"
    by extracting individual dates and returning the first one.
    """
    # Try formats with and without day-of-week
    formats = [
        '%A, %B %d, %Y',   # "Friday, February 20, 2026"
        '%B %d, %Y',       # "February 20, 2026"
        '%A, %b %d, %Y',   # "Friday, Feb 20, 2026"
        '%b %d, %Y',       # "Feb 20, 2026"
    ]

    # First try parsing the full string directly
    for fmt in formats:
        try:
            dt = datetime.strptime(date_text.strip(), fmt)
            result = dt.strftime('%Y-%m-%d')
            logger.debug("  parse_event_date: '%s' -> %s (fmt=%s)", date_text, result, fmt)
            return result
        except ValueError:
            continue

    # If that fails, try to extract individual dates (multi-date events)
    # Match patterns like "Saturday, April 19, 2025"
    date_pattern = r'(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s+\w+\s+\d{1,2},\s+\d{4}'
    matches = re.findall(date_pattern, date_text)
    if matches:
        logger.debug("  parse_event_date: found %d dates in multi-date string", len(matches))
        for fmt in formats:
            try:
                dt = datetime.strptime(matches[0].strip(), fmt)
                result = dt.strftime('%Y-%m-%d')
                logger.debug("  parse_event_date: '%s' -> %s (first of %d dates)", matches[0], result, len(matches))
                return result
            except ValueError:
                continue

    logger.warning("  parse_event_date: failed to parse '%s'", date_text)
    return None


def parse_event_time(time_text):
    """
    Parse time text like "8pm - 2am" into ("20:00:00", "02:00:00").
    Returns (start_time, end_time) as 24h strings, or (None, None).
    """
    if not time_text:
        return None, None

    def to_24h(t):
        """Convert '8pm', '5PM', '12am' etc. to 'HH:MM:SS'"""
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

    # Split on common separators: " - ", " – ", " to "
    parts = re.split(r'\s*[-–to]+\s*', time_text, maxsplit=1)
    start = to_24h(parts[0]) if parts else None
    end = to_24h(parts[1]) if len(parts) > 1 else None
    logger.debug("  parse_event_time: '%s' -> start=%s, end=%s", time_text, start, end)
    return start, end


def is_future_event(start_datetime):
    """
    Check if event is in the future
    """
    if not start_datetime:
        logger.debug("  is_future_event: no datetime, defaulting to True")
        return True  # Include events with unknown dates

    try:
        event_dt = datetime.fromisoformat(start_datetime)
        is_future = event_dt >= datetime.now()
        logger.debug("  is_future_event: %s -> %s", start_datetime, is_future)
        return is_future
    except Exception as e:
        logger.warning("  is_future_event: parse error for '%s': %s, defaulting to True", start_datetime, e)
        return True  # Include if we can't parse the date


def add_events_to_home_assistant(events):
    """
    Add events to a Home Assistant calendar via the REST API.
    Uses the calendar.create_event service.

    Requires HA_TOKEN environment variable set to a long-lived access token.
    Optionally set HA_URL (default: http://homeassistant.local:8123)
    and HA_CALENDAR_ENTITY (default: calendar.local_calendar).
    """
    if not HA_TOKEN:
        logger.error("HA_TOKEN environment variable is not set. "
                      "Create a long-lived access token in Home Assistant "
                      "(Profile -> Security -> Long-Lived Access Tokens) "
                      "and set it: export HA_TOKEN='your_token_here'")
        return []

    api_url = f"{HA_BASE_URL}/api/services/calendar/create_event"
    ha_headers = {
        "Authorization": f"Bearer {HA_TOKEN}",
        "Content-Type": "application/json",
    }

    results = []
    for event in events:
        # Build the service call payload
        payload = {
            "entity_id": HA_CALENDAR_ENTITY,
            "summary": event.get("title") or "SF.dog Event",
        }

        # Add start datetime (required)
        start = event.get("start_datetime")
        if start:
            # HA expects "YYYY-MM-DD HH:MM:SS" format for start_date_time
            payload["start_date_time"] = start.replace("T", " ")
        else:
            logger.warning("Skipping event with no start datetime: %s", event.get('title'))
            continue

        # Add end datetime (required by HA; fall back to start + 2 hours)
        end = event.get("end_datetime")
        if end:
            payload["end_date_time"] = end.replace("T", " ")
        else:
            fallback_end = datetime.fromisoformat(start) + timedelta(hours=2)
            payload["end_date_time"] = fallback_end.strftime("%Y-%m-%d %H:%M:%S")
            logger.debug("No end time, using fallback: %s", payload['end_date_time'])

        # Add optional fields
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
