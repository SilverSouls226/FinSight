from fastapi import FastAPI
from .api import endpoints
from .database import models
from .database.database import engine

# Automatically create all tables on startup
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="FinSentinel - Financial State Engine API")

app.include_router(endpoints.router)

@app.get("/")
def read_root():
    return {"message": "Financial State Engine is running!"}
