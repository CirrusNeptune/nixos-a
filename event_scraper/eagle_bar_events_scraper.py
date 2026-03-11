#!/usr/bin/env python3
"""
Web scraper for sf-eagle.com events.
Extracts upcoming events via the Tribe Events Calendar REST API
and returns them as JSON.

The site runs the "The Events Calendar" WordPress plugin, which exposes
a public JSON endpoint at /wp-json/tribe/events/v1/events.
"""

import logging
import re
import requests
from datetime import datetime
from dotenv import load_dotenv
import json
import os

load_dotenv()

logger = logging.getLogger("event_scraper.eagle_bar")

# Home Assistant configuration
HA_BASE_URL = os.environ.get("HA_URL", "http://homeassistant.local:8123")
HA_TOKEN = os.environ.get("HA_TOKEN", "")
HA_CALENDAR_ENTITY = os.environ.get("HA_CALENDAR_ENTITY", "calendar.local_calendar")

API_URL = "https://sf-eagle.com/wp-json/tribe/events/v1/events"
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                   '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
}


def scrape_events():
    """
    Fetch upcoming events from the SF Eagle Tribe Events REST API.
    Returns a list of event dicts.
    """
    events = []
    now = datetime.now()

    try:
        params = {
            'start_date': now.strftime('%Y-%m-%d'),
            'per_page': 50,
        }

        logger.debug("Fetching events from API: %s", API_URL)
        response = requests.get(API_URL, headers=HEADERS, params=params, timeout=15)
        logger.debug("Response status: %d", response.status_code)
        response.raise_for_status()

        data = response.json()
        raw_events = data.get('events', [])
        logger.debug("API returned %d events", len(raw_events))

        for raw in raw_events:
            event = parse_event(raw)
            if event:
                events.append(event)

        events.sort(key=lambda x: x.get('start_datetime') or '')
        logger.debug("Total future events: %d", len(events))

    except Exception as e:
        logger.error("Scrape failure: %s", e)

    return events


def parse_event(raw):
    """
    Parse a single Tribe Events API event object into our standard format.
    """
    title = raw.get('title', '')

    # Parse start/end datetimes (API returns "YYYY-MM-DD HH:MM:SS")
    start_date = raw.get('start_date')
    end_date = raw.get('end_date')
    start_datetime = start_date.replace(' ', 'T') if start_date else None
    end_datetime = end_date.replace(' ', 'T') if end_date else None

    # Build location string from venue data
    location = None
    venue = raw.get('venue', {}) or {}
    venue_name = venue.get('venue')
    address = venue.get('address')
    city = venue.get('city')
    state = venue.get('state')
    parts = [p for p in [venue_name, address, city, state] if p]
    if parts:
        location = ', '.join(parts)

    # Clean HTML from description
    description = None
    raw_desc = raw.get('description', '')
    if raw_desc:
        description = strip_html(raw_desc)[:500]

    url = raw.get('url')

    logger.debug("Parsed: %s on %s", title, start_datetime)

    return {
        "title": title or None,
        "description": description,
        "location": location,
        "start_datetime": start_datetime,
        "end_datetime": end_datetime,
        "url": url,
    }


def strip_html(html):
    """Remove HTML tags and collapse whitespace."""
    text = re.sub(r'<[^>]+>', ' ', html)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    events = scrape_events()
    logger.info(json.dumps(events, indent=2, ensure_ascii=False))
