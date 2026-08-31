import numpy as np
import os
import time
import mlflow              
import mlflow.pyfunc
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel, Field
from typing import List
from contextlib import asynccontextmanager
from prometheus_client import Counter, Histogram, make_asgi_app

MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
MODEL_URI = os.getenv("MODEL_URI", "models:/MyModel/Production")

model = None

REQUESTS = Counter('predictions_total', 'Total predictions', ['status', 'client_id'])
LATENCY = Histogram('prediction_latency_seconds', 'Prediction latency in seconds', ['client_id'])
POSITIVE_RATIO = Counter('predictions_positive_total', 'Positive predictions (e.g., fraud)', ['client_id'])

@asynccontextmanager
async def lifespan(app: FastAPI):
    global model
    print(f"🔗 Connecting to MLflow at: {MLFLOW_TRACKING_URI}")
    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
    print(f"⬇️  Loading model from URI: {MODEL_URI}")
    model = mlflow.pyfunc.load_model(MODEL_URI)
    print("✅ Model loaded successfully.")
    yield

app = FastAPI(title="Model Serving API",
              description="Serves predictions from an MLflow model with monitoring.",
              version="1.0.0",
              lifespan=lifespan)

app.mount("/metrics", make_asgi_app())

class PredictRequest(BaseModel):
    features: List[float] = Field(..., min_length=12, max_length=12)

@app.get("/health")
def health():
    return {"status": "alive", "service": "model-serving"}

@app.get("/ready")
def ready():
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")
    return {"status": "ready", "model_uri": MODEL_URI}

@app.post("/predict")
def predict(request: PredictRequest, x_client_id: str = Header(default="unknown")):
    start = time.time()
    try:
        features_array = np.array([request.features])   # <-- this line
        result = model.predict(features_array)
        prediction = int(result[0])
        latency = time.time() - start
        REQUESTS.labels(status="success", client_id=x_client_id).inc()
        LATENCY.labels(client_id=x_client_id).observe(latency)
        if prediction == 1:
            POSITIVE_RATIO.labels(client_id=x_client_id).inc()
        return {"prediction": prediction, "latency_ms": round(latency * 1000, 2)}
    except Exception as e:
        REQUESTS.labels(status="error", client_id=x_client_id).inc()
        raise HTTPException(status_code=500, detail=str(e))