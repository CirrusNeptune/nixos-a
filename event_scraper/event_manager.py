#!/usr/bin/env python3
"""
Central event orchestrator with SQLite pub/sub.

Calls all event scrapers, merges results into a sorted master list,
and dispatches unsent events to each registered subscriber (e.g. Home Assistant).
Uses SQLite to track which events have already been sent to which subscriber.
"""

import hashlib
import json
import logging
import os
import sqlite3
from datetime import datetime, timedelta

import requests
from dotenv import load_dotenv

import sf_dog_events_scraper
import frolic_events_scraper
import transform1060_events_scraper
import eagle_bar_events_scraper

load_dotenv()

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------

LOG_FILE = os.environ.get(
    "LOG_FILE",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "event_scraper.log"),
)

logger = logging.getLogger("event_scraper")
logger.setLevel(logging.DEBUG)

_formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")

_console_handler = logging.StreamHandler()
_console_handler.setLevel(logging.DEBUG)
_console_handler.setFormatter(_formatter)
logger.addHandler(_console_handler)

_file_handler = logging.FileHandler(LOG_FILE)
_file_handler.setLevel(logging.DEBUG)
_file_handler.setFormatter(_formatter)
logger.addHandler(_file_handler)

# Home Assistant configuration
HA_BASE_URL = os.environ.get("HA_URL", "http://homeassistant.local:8123")
HA_TOKEN = os.environ.get("HA_TOKEN", "")
HA_CALENDAR_ENTITY = os.environ.get("HA_CALENDAR_ENTITY", "calendar.local_calendar")

# SQLite database in the same directory as this script
DB_PATH = os.environ.get("DB_PATH", os.path.join(os.path.dirname(os.path.abspath(__file__)), "events.db"))


# ---------------------------------------------------------------------------
# SQLite setup
# ---------------------------------------------------------------------------

def init_db():
    """Create the sent_events table if it doesn't exist."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS sent_events (
            event_hash  TEXT NOT NULL,
            subscriber  TEXT NOT NULL,
            sent_at     TEXT NOT NULL,
            PRIMARY KEY (event_hash, subscriber)
        )
    """)
    conn.commit()
    conn.close()


# ---------------------------------------------------------------------------
# Event hashing
# ---------------------------------------------------------------------------

def hash_event(event):
    """Return an MD5 hex digest that uniquely identifies an event instance."""
    key = f"{event.get('title', '')}|{event.get('start_datetime', '')}|{event.get('url', '')}"
    return hashlib.md5(key.encode()).hexdigest()


# ---------------------------------------------------------------------------
# Master list assembly
# ---------------------------------------------------------------------------

SCRAPERS = [
    ("sf_dog",        sf_dog_events_scraper.scrape_events),
    ("frolic",        frolic_events_scraper.scrape_events),
    ("transform1060", transform1060_events_scraper.scrape_events),
    ("eagle_bar",     eagle_bar_events_scraper.scrape_events),
]


def gather_all_events():
    """Call every scraper, tag events with source, merge and sort."""
    master = []

    for source_name, scrape_fn in SCRAPERS:
        try:
            logger.info("Scraping: %s", source_name)
            events = scrape_fn()
            for e in events:
                e["source"] = source_name
            master.extend(events)
            logger.info("[%s] %d events collected", source_name, len(events))
        except Exception as exc:
            logger.error("[%s] Scraper failed: %s", source_name, exc)

    master.sort(key=lambda e: e.get("start_datetime") or "")
    logger.info("Master list: %d total events", len(master))
    return master


# ---------------------------------------------------------------------------
# Pub/Sub dispatch
# ---------------------------------------------------------------------------

def already_sent(event_hash, subscriber_name):
    """Check whether this event has already been sent to a subscriber."""
    conn = sqlite3.connect(DB_PATH)
    row = conn.execute(
        "SELECT 1 FROM sent_events WHERE event_hash = ? AND subscriber = ?",
        (event_hash, subscriber_name),
    ).fetchone()
    conn.close()
    return row is not None


def record_sent(event_hash, subscriber_name):
    """Record that an event was successfully sent to a subscriber."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "INSERT OR IGNORE INTO sent_events (event_hash, subscriber, sent_at) VALUES (?, ?, ?)",
        (event_hash, subscriber_name, datetime.now().isoformat()),
    )
    conn.commit()
    conn.close()


def publish_events(events):
    """Iterate events and send unsent ones to each subscriber."""
    subscribers = {
        "home_assistant": send_to_home_assistant,
    }

    summary = {name: {"sent": 0, "skipped": 0, "failed": 0} for name in subscribers}

    for name, send_fn in subscribers.items():
        logger.info("Publishing to: %s", name)
        for event in events:
            ehash = hash_event(event)
            if already_sent(ehash, name):
                summary[name]["skipped"] += 1
                continue

            success = send_fn(event)
            if success:
                record_sent(ehash, name)
                summary[name]["sent"] += 1
            else:
                summary[name]["failed"] += 1

    # Log summary
    logger.info("Dispatch summary")
    for name, counts in summary.items():
        logger.info("  %s: %d sent, %d already sent, %d failed",
                     name, counts['sent'], counts['skipped'], counts['failed'])


# ---------------------------------------------------------------------------
# Subscriber: Home Assistant
# ---------------------------------------------------------------------------

def send_to_home_assistant(event):
    """
    Send a single event to the Home Assistant calendar.
    Returns True on success, False on failure.
    """
    if not HA_TOKEN:
        logger.error("HA_TOKEN environment variable is not set.")
        return False

    api_url = f"{HA_BASE_URL}/api/services/calendar/create_event"
    ha_headers = {
        "Authorization": f"Bearer {HA_TOKEN}",
        "Content-Type": "application/json",
    }

    payload = {
        "entity_id": HA_CALENDAR_ENTITY,
        "summary": event.get("title") or "Event",
    }

    start = event.get("start_datetime")
    if not start:
        logger.warning("Skipping event with no start datetime: %s", event.get('title'))
        return False
    payload["start_date_time"] = start.replace("T", " ")

    end = event.get("end_datetime")
    if end:
        payload["end_date_time"] = end.replace("T", " ")
    else:
        fallback_end = datetime.fromisoformat(start) + timedelta(hours=2)
        payload["end_date_time"] = fallback_end.strftime("%Y-%m-%d %H:%M:%S")

    if event.get("description"):
        payload["description"] = event["description"]
    if event.get("location"):
        payload["location"] = event["location"]

    logger.info("Creating: %s (%s)", payload['summary'], payload['start_date_time'])

    try:
        response = requests.post(api_url, headers=ha_headers, json=payload, timeout=10)
        if response.ok:
            logger.info("  -> Success (HTTP %d)", response.status_code)
            return True
        else:
            logger.error("  -> Failed (HTTP %d): %s", response.status_code, response.text)
            return False
    except Exception as exc:
        logger.error("  -> Error: %s", exc)
        return False


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    init_db()

    events = gather_all_events()

    logger.info("Master event list")
    logger.info(json.dumps(events, indent=2, ensure_ascii=False))

    publish_events(events)
