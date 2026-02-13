#!/usr/bin/env python3
"""
Web scraper for frolicparty.com events
Extracts upcoming Frolic dance party dates and returns them as JSON.

All events share the same time and location; only the dates change.
The schedule is listed on the main page as:
  "2026 Saturday dates: February 14, April 11, June 13, ..."
"""

import logging
import requests
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
from dotenv import load_dotenv
import json
import os
import re

load_dotenv()

logger = logging.getLogger("event_scraper.frolic")

# Home Assistant configuration
HA_BASE_URL = os.environ.get("HA_URL", "http://homeassistant.local:8123")
HA_TOKEN = os.environ.get("HA_TOKEN", "")
HA_CALENDAR_ENTITY = os.environ.get("HA_CALENDAR_ENTITY", "calendar.local_calendar")

FROLIC_URL = "https://www.frolicparty.com/"


def scrape_events():
    """
    Scrape events from frolicparty.com and return as JSON array.
    """
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                       '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
    }

    events = []

    try:
        logger.debug("Fetching: %s", FROLIC_URL)
        response = requests.get(FROLIC_URL, headers=headers, timeout=10)
        logger.debug("Response status: %d", response.status_code)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')

        # Extract location from page title ("Frolic at the Folsom Foundry in San Francisco")
        location = None
        title_tag = soup.find('title')
        if title_tag:
            title_match = re.search(r'at the (.+)', title_tag.get_text())
            if title_match:
                location = title_match.group(1).strip()
                logger.debug("Location: %s", location)

        # Extract time from style8 span (e.g., "8pm - 2am (doors at 7)")
        start_time = "20:00:00"  # default 8pm
        end_time = "02:00:00"    # default 2am
        time_span = soup.find('span', class_='style8')
        if time_span:
            time_text = time_span.get_text(strip=True)
            logger.debug("Time text: '%s'", time_text)
            parsed_start, parsed_end = parse_time_range(time_text)
            if parsed_start:
                start_time = parsed_start
            if parsed_end:
                end_time = parsed_end

        # Extract description from the "Ultimate Furry Nightclub" section
        description = None
        style5_spans = soup.find_all('span', class_='style5')
        for span in style5_spans:
            text = span.get_text(strip=True)
            if 'crazy idea' in text or 'furry friends' in text:
                description = text[:500]
                logger.debug("Description (%d chars)", len(description))
                break

        # Extract the schedule line: "2026 Saturday dates: February 14, April 11, ..."
        schedule_year = None
        date_strings = []
        for span in style5_spans:
            text = span.get_text(strip=True)
            match = re.match(r'(\d{4})\s+Saturday dates?:\s*(.+)', text)
            if match:
                schedule_year = int(match.group(1))
                dates_part = match.group(2)
                logger.debug("Schedule line: year=%d, dates='%s'", schedule_year, dates_part)
                # Split on commas and "and"
                parts = re.split(r',\s*(?:and\s+)?|\s+and\s+', dates_part)
                date_strings = [p.strip() for p in parts if p.strip()]
                logger.debug("Parsed %d date strings: %s", len(date_strings), date_strings)
                break

        if not schedule_year or not date_strings:
            logger.warning("No schedule found on page")
            return events

        now = datetime.now()

        for date_str in date_strings:
            # Parse "February 14" with the schedule year
            event_date = parse_month_day(date_str, schedule_year)
            if not event_date:
                logger.warning("Failed to parse date: '%s'", date_str)
                continue

            start_dt = f"{event_date}T{start_time}"
            # Roll end date to next day if end time < start time (overnight event)
            end_date = event_date
            if end_time < start_time:
                next_day = datetime.strptime(event_date, '%Y-%m-%d') + timedelta(days=1)
                end_date = next_day.strftime('%Y-%m-%d')
            end_dt = f"{end_date}T{end_time}"

            # Only include future events
            event_dt = datetime.fromisoformat(start_dt)
            if event_dt < now:
                logger.debug("Skipping past event: %s", start_dt)
                continue

            event = {
                "title": "Frolic",
                "description": description,
                "location": location,
                "start_datetime": start_dt,
                "end_datetime": end_dt,
                "url": FROLIC_URL,
            }
            events.append(event)
            logger.debug("Added event: %s", start_dt)

        events.sort(key=lambda x: x.get('start_datetime') or '')
        logger.debug("Total future events: %d", len(events))

    except Exception as e:
        logger.error("Scrape failure: %s", e)

    return events


def parse_time_range(text):
    """
    Parse a time range like "8pm - 2am (doors at 7)" into 24h start/end strings.
    """
    # Strip parenthetical notes like "(doors at 7)"
    cleaned = re.sub(r'\(.*?\)', '', text).strip()

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

    parts = re.split(r'\s*[-–]\s*', cleaned, maxsplit=1)
    start = to_24h(parts[0]) if parts else None
    end = to_24h(parts[1]) if len(parts) > 1 else None
    logger.debug("parse_time_range: '%s' -> start=%s, end=%s", text, start, end)
    return start, end


def parse_month_day(text, year):
    """
    Parse "February 14" with a given year into "2026-02-14".
    """
    for fmt in ['%B %d', '%b %d']:
        try:
            dt = datetime.strptime(text.strip(), fmt).replace(year=year)
            return dt.strftime('%Y-%m-%d')
        except ValueError:
            continue
    return None


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
            "summary": event.get("title") or "Frolic Party",
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
