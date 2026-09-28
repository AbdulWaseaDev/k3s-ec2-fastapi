import os
import socket

from fastapi import FastAPI

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/")
def root():
    return {
        "message": os.environ.get("APP_MESSAGE", "no message set"),
        "environment": os.environ.get("APP_ENV", "unset"),
        "hostname": socket.gethostname(),
    }
