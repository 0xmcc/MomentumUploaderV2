import asyncio
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache
from uuid import uuid4

from supabase import Client, create_client

from config import settings


@dataclass
class SavedTranscript:
    memo_id: str
    full_transcript: str


class SupabaseWriter:
    def __init__(self) -> None:
        self._client: Client = create_client(settings.supabase_url, settings.supabase_service_key)

    async def save_transcript(self, session_id: str, full_transcript: str, duration: float = 0.0) -> SavedTranscript:
        memo_id = str(uuid4())
        created_at = datetime.now(timezone.utc).isoformat()
        title = f"Live Session - {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%SZ')}"

        payload = {
            "id": memo_id,
            "created_at": created_at,
            "title": title,
            "audio_url": "",
            "transcript": full_transcript,
            "duration": str(duration),
            "stream_session_id": session_id,
        }

        await asyncio.to_thread(self._insert_row, payload)
        return SavedTranscript(memo_id=memo_id, full_transcript=full_transcript)

    def _insert_row(self, payload: dict) -> None:
        self._client.table(settings.supabase_table).insert(payload).execute()


@lru_cache(maxsize=1)
def get_supabase_writer() -> SupabaseWriter:
    return SupabaseWriter()
