from typing import Literal

from pydantic import BaseModel, ConfigDict


class AudioConfig(BaseModel):
    model_config = ConfigDict(extra="ignore")

    sample_rate: int = 16000
    channels: int = 1
    bit_depth: int = 16
    encoding: Literal["LINEAR_PCM"] = "LINEAR_PCM"


class SessionStartMessage(BaseModel):
    type: Literal["session.start"]
    session_id: str
    config: AudioConfig


class SessionEndMessage(BaseModel):
    type: Literal["session.end"]
    session_id: str


class TranscriptMessage(BaseModel):
    type: Literal["transcript.partial", "transcript.final"]
    text: str
    is_final: bool
    sequence: int


class SessionSavedMessage(BaseModel):
    type: Literal["session.saved"] = "session.saved"
    memo_id: str
    full_transcript: str


class ErrorMessage(BaseModel):
    type: Literal["error"] = "error"
    code: str
    message: str
