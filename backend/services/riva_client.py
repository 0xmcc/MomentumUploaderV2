import asyncio
import threading
from collections.abc import AsyncIterator, Iterable
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

from config import settings


@dataclass
class RivaTranscriptEvent:
    text: str
    is_final: bool
    sequence: int


class RivaStreamingSession:
    def __init__(
        self,
        *,
        asr_service: Any,
        streaming_config: Any,
        model_name: str,
    ) -> None:
        self._asr_service = asr_service
        self._streaming_config = streaming_config
        self._model_name = model_name

        self._audio_queue: asyncio.Queue[bytes | None] = asyncio.Queue(maxsize=64)
        self._result_queue: asyncio.Queue[RivaTranscriptEvent | Exception | None] = asyncio.Queue()

        self._loop: asyncio.AbstractEventLoop | None = None
        self._thread: threading.Thread | None = None
        self._input_closed = False

    async def start(self) -> None:
        if self._thread is not None:
            return

        self._loop = asyncio.get_running_loop()
        self._thread = threading.Thread(target=self._run_streaming_loop, daemon=True, name="riva-stream")
        self._thread.start()

    async def send_audio(self, chunk: bytes) -> None:
        if self._input_closed:
            return
        await self._audio_queue.put(chunk)

    async def finish_input(self) -> None:
        if self._input_closed:
            return

        self._input_closed = True
        await self._audio_queue.put(None)

    async def close(self) -> None:
        await self.finish_input()
        if self._thread is not None and self._thread.is_alive():
            await asyncio.to_thread(self._thread.join, 2.0)

    async def events(self) -> AsyncIterator[RivaTranscriptEvent]:
        while True:
            item = await self._result_queue.get()
            if item is None:
                break
            if isinstance(item, Exception):
                raise item
            yield item

    def _run_streaming_loop(self) -> None:
        assert self._loop is not None

        sequence = 0
        try:
            responses = self._response_generator(self._audio_chunks())
            for response in responses:
                for text, is_final in self._extract_transcripts(response):
                    sequence += 1
                    event = RivaTranscriptEvent(text=text, is_final=is_final, sequence=sequence)
                    asyncio.run_coroutine_threadsafe(self._result_queue.put(event), self._loop).result()
        except Exception as exc:  # noqa: BLE001
            asyncio.run_coroutine_threadsafe(self._result_queue.put(exc), self._loop).result()
        finally:
            asyncio.run_coroutine_threadsafe(self._result_queue.put(None), self._loop).result()

    def _audio_chunks(self) -> Iterable[bytes]:
        assert self._loop is not None

        while True:
            chunk_future = asyncio.run_coroutine_threadsafe(self._audio_queue.get(), self._loop)
            chunk = chunk_future.result()
            if chunk is None:
                break
            if chunk:
                yield chunk

    def _response_generator(self, chunks: Iterable[bytes]) -> Iterable[Any]:
        try:
            return self._asr_service.streaming_response_generator(
                audio_chunks=chunks,
                streaming_config=self._streaming_config,
                model_name=self._model_name,
            )
        except TypeError:
            return self._asr_service.streaming_response_generator(chunks, self._streaming_config)

    @staticmethod
    def _extract_transcripts(response: Any) -> list[tuple[str, bool]]:
        events: list[tuple[str, bool]] = []
        results = getattr(response, "results", None) or []
        for result in results:
            alternatives = getattr(result, "alternatives", None) or []
            if not alternatives:
                continue

            transcript = (getattr(alternatives[0], "transcript", "") or "").strip()
            if not transcript:
                continue

            is_final = bool(getattr(result, "is_final", False))
            events.append((transcript, is_final))

        return events


class RivaClient:
    def __init__(self) -> None:
        try:
            import riva.client  # type: ignore
        except ImportError as exc:  # pragma: no cover - import is environment dependent
            raise RuntimeError("nvidia-riva-client is not installed.") from exc

        metadata_args: list[tuple[str, str]] = []
        if settings.riva_api_key:
            metadata_args.append(("authorization", f"Bearer {settings.riva_api_key}"))

        auth = riva.client.Auth(
            uri=settings.riva_uri,
            use_ssl=settings.riva_use_ssl,
            metadata_args=metadata_args,
        )

        self._asr_service = riva.client.ASRService(auth)

        recognition_config = riva.client.RecognitionConfig(
            encoding=riva.client.AudioEncoding.LINEAR_PCM,
            language_code=settings.riva_language_code,
            sample_rate_hertz=settings.sample_rate_hz,
            audio_channel_count=1,
            max_alternatives=1,
            enable_automatic_punctuation=True,
        )

        self._streaming_config = riva.client.StreamingRecognitionConfig(
            config=recognition_config,
            interim_results=True,
        )

    def create_session(self) -> RivaStreamingSession:
        return RivaStreamingSession(
            asr_service=self._asr_service,
            streaming_config=self._streaming_config,
            model_name=settings.riva_asr_model,
        )


@lru_cache(maxsize=1)
def get_riva_client() -> RivaClient:
    return RivaClient()
