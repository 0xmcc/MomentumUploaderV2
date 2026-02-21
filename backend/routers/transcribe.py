import asyncio
import json
from contextlib import suppress

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import ValidationError

from config import settings
from models.ws_messages import (
    ErrorMessage,
    SessionEndMessage,
    SessionSavedMessage,
    SessionStartMessage,
    TranscriptMessage,
)
from services.riva_client import RivaStreamingSession, get_riva_client
from services.supabase_writer import get_supabase_writer

router = APIRouter()


def _parse_control_message(text: str) -> SessionStartMessage | SessionEndMessage:
    payload = json.loads(text)
    message_type = payload.get("type")

    if message_type == "session.start":
        return SessionStartMessage.model_validate(payload)
    if message_type == "session.end":
        return SessionEndMessage.model_validate(payload)

    raise ValueError(f"Unsupported control type: {message_type}")


async def _send_error(websocket: WebSocket, code: str, message: str) -> None:
    await websocket.send_text(ErrorMessage(code=code, message=message).model_dump_json())


async def _forward_riva_events(
    websocket: WebSocket,
    riva_session: RivaStreamingSession,
    final_segments: list[str],
) -> None:
    async for event in riva_session.events():
        if event.is_final:
            final_segments.append(event.text)
            message_type = "transcript.final"
        else:
            message_type = "transcript.partial"

        payload = TranscriptMessage(
            type=message_type,
            text=event.text,
            is_final=event.is_final,
            sequence=event.sequence,
        )
        await websocket.send_text(payload.model_dump_json())


@router.websocket("/ws/transcribe")
async def transcribe_websocket(websocket: WebSocket) -> None:
    await websocket.accept()

    riva_session: RivaStreamingSession | None = None
    result_forward_task: asyncio.Task[None] | None = None
    active_session_id: str | None = None
    final_segments: list[str] = []

    try:
        while True:
            message = await websocket.receive()

            if message["type"] == "websocket.disconnect":
                break

            text_frame = message.get("text")
            if text_frame is not None:
                try:
                    control = _parse_control_message(text_frame)
                except (json.JSONDecodeError, ValidationError, ValueError) as exc:
                    await _send_error(websocket, "INVALID_MESSAGE", f"Invalid control frame: {exc}")
                    continue

                if isinstance(control, SessionStartMessage):
                    if riva_session is not None:
                        await _send_error(websocket, "SESSION_ALREADY_STARTED", "session.start already received.")
                        continue

                    if control.config.sample_rate != settings.sample_rate_hz:
                        await _send_error(
                            websocket,
                            "INVALID_AUDIO_CONFIG",
                            f"sample_rate must be {settings.sample_rate_hz}.",
                        )
                        continue

                    if control.config.channels != 1 or control.config.bit_depth != 16:
                        await _send_error(
                            websocket,
                            "INVALID_AUDIO_CONFIG",
                            "Only mono 16-bit PCM streaming is supported.",
                        )
                        continue

                    active_session_id = control.session_id
                    riva_session = get_riva_client().create_session()
                    await riva_session.start()

                    result_forward_task = asyncio.create_task(
                        _forward_riva_events(websocket, riva_session, final_segments)
                    )
                    continue

                if isinstance(control, SessionEndMessage):
                    if riva_session is None or active_session_id is None:
                        await _send_error(websocket, "SESSION_NOT_STARTED", "Send session.start before session.end.")
                        continue

                    if control.session_id != active_session_id:
                        await _send_error(websocket, "SESSION_MISMATCH", "session_id does not match active stream.")
                        continue

                    await riva_session.finish_input()

                    if result_forward_task is not None:
                        try:
                            await result_forward_task
                        except Exception as exc:  # noqa: BLE001
                            await _send_error(websocket, "RIVA_ERROR", str(exc))
                            await websocket.close(code=1011)
                            return

                    transcript = " ".join(segment for segment in final_segments if segment).strip()
                    try:
                        saved = await get_supabase_writer().save_transcript(
                            session_id=active_session_id,
                            full_transcript=transcript,
                        )
                    except Exception as exc:  # noqa: BLE001
                        await _send_error(websocket, "SUPABASE_ERROR", f"Failed to save transcript: {exc}")
                        await websocket.close(code=1011)
                        return

                    await websocket.send_text(
                        SessionSavedMessage(memo_id=saved.memo_id, full_transcript=saved.full_transcript).model_dump_json()
                    )
                    await websocket.close(code=1000)
                    return

            audio_bytes = message.get("bytes")
            if audio_bytes is not None:
                if riva_session is None:
                    await _send_error(websocket, "SESSION_NOT_STARTED", "Send session.start before audio data.")
                    continue

                await riva_session.send_audio(audio_bytes)

    except WebSocketDisconnect:
        pass
    finally:
        if riva_session is not None:
            await riva_session.close()

        if result_forward_task is not None and not result_forward_task.done():
            result_forward_task.cancel()
            with suppress(asyncio.CancelledError):
                await result_forward_task
