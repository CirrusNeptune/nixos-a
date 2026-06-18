#!/usr/bin/env python3
"""
Send a WAV file to a Wyoming Faster Whisper server and print the transcript.

Usage:
    python wyoming_whisper_ping.py audio.wav
    python wyoming_whisper_ping.py audio.wav --host 192.168.1.100 --port 10300
"""

import argparse
import asyncio
import wave
import sys
from pathlib import Path

from wyoming.asr import Transcribe, Transcript
from wyoming.audio import AudioChunk, AudioStart, AudioStop
from wyoming.event import async_read_event, async_write_event
from wyoming.info import Describe, Info

SAMPLES_PER_CHUNK = 1024


async def transcribe(host: str, port: int, wav_path: Path) -> str:
    reader, writer = await asyncio.open_connection(host, port)

    try:
        # 1. Ask the server to describe itself (optional handshake, but polite)
        await async_write_event(Describe().event(), writer)
        while True:
            event = await async_read_event(reader)
            if event is None:
                raise ConnectionError("Server closed connection during handshake")
            if Info.is_type(event.type):
                print(f"[info] Connected to: {Info.from_event(event).asr[0].name if Info.from_event(event).asr else 'unknown'}")
                break

        # 2. Tell the server we want a transcription
        await async_write_event(Transcribe(language="en").event(), writer)

        # 3. Stream the WAV file as PCM chunks
        with wave.open(str(wav_path), "rb") as wav_file:
            sample_rate = wav_file.getframerate()
            sample_width = wav_file.getsampwidth()
            channels = wav_file.getnchannels()

            await async_write_event(
                AudioStart(
                    rate=sample_rate,
                    width=sample_width,
                    channels=channels,
                ).event(),
                writer,
            )

            while chunk := wav_file.readframes(SAMPLES_PER_CHUNK):
                await async_write_event(
                    AudioChunk(
                        rate=sample_rate,
                        width=sample_width,
                        channels=channels,
                        audio=chunk,
                    ).event(),
                    writer,
                )

            await async_write_event(AudioStop().event(), writer)

        # 4. Wait for the transcript
        while True:
            event = await async_read_event(reader)
            if event is None:
                raise ConnectionError("Server closed connection before returning transcript")
            if Transcript.is_type(event.type):
                return Transcript.from_event(event).text

    finally:
        writer.close()
        await writer.wait_closed()


def main():
    parser = argparse.ArgumentParser(description="Ping a Wyoming Faster Whisper server with a WAV file")
    parser.add_argument("wav", type=Path, help="Path to a WAV file")
    parser.add_argument("--host", default="localhost", help="Whisper server host (default: localhost)")
    parser.add_argument("--port", type=int, default=10300, help="Whisper server port (default: 10300)")
    args = parser.parse_args()

    if not args.wav.is_file():
        print(f"Error: file not found: {args.wav}", file=sys.stderr)
        sys.exit(1)

    if args.wav.suffix.lower() != ".wav":
        print("Warning: file doesn't have a .wav extension — it must be a PCM WAV file", file=sys.stderr)

    print(f"[info] Sending {args.wav.name} to {args.host}:{args.port} ...")
    transcript = asyncio.run(transcribe(args.host, args.port, args.wav))
    print(f"\nTranscript: {transcript}")


if __name__ == "__main__":
    main()