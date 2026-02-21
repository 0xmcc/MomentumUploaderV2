from fastapi import FastAPI

from config import settings
from routers.health import router as health_router
from routers.transcribe import router as transcribe_router

app = FastAPI(title=settings.app_name)

app.include_router(health_router)
app.include_router(transcribe_router)
