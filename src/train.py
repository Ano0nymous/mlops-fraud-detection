import os
import sys
import mlflow
import mlflow.sklearn
import numpy as np
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from mlflow.tracking import MlflowClient


MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI")
AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
EXPERIMENT_NAME = "Fraud_Detection_Production"
# FIX: was missing entirely - train.py always promoted the latest run to
# Production regardless of how it scored. A bad training run (bad data,
# a bug, an unlucky random_state) went straight to serving real traffic.
MIN_F1_THRESHOLD = float(os.getenv("MIN_F1_THRESHOLD", "0.85"))

if not MLFLOW_TRACKING_URI:
    raise ValueError("MLFLOW_TRACKING_URI environment variable is not set!")

# 1. Generate Data
X, y = make_classification(n_samples=5000, n_features=12, n_informative=10,
                           n_redundant=2, weights=[0.95], random_state=42)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# 2. Connect to MLflow
mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
mlflow.set_experiment(EXPERIMENT_NAME)

with mlflow.start_run(run_name="Cloud_Champion_v1") as run:
    mlflow.log_param("aws_region", AWS_REGION)
    mlflow.log_param("random_seed", 42)
    mlflow.log_param("min_f1_threshold", MIN_F1_THRESHOLD)

    # 3. Build and train pipeline
    pipeline = Pipeline([
        ('scaler', StandardScaler()),
        ('classifier', RandomForestClassifier(n_estimators=100, max_depth=8, random_state=42))
    ])
    pipeline.fit(X_train, y_train)

    # 4. Evaluate
    y_pred = pipeline.predict(X_test)
    test_f1 = f1_score(y_test, y_pred)
    mlflow.log_metric("test_accuracy", accuracy_score(y_test, y_pred))
    mlflow.log_metric("test_precision", precision_score(y_test, y_pred))
    mlflow.log_metric("test_recall", recall_score(y_test, y_pred))
    mlflow.log_metric("test_f1", test_f1)

    # 5. Log model with signature and input example (logged regardless of
    # the gate below, so failed runs are still inspectable in MLflow)
    input_example = X_test[:1]
    mlflow.sklearn.log_model(
        sk_model=pipeline,
        artifact_path="model",
        registered_model_name="FraudDetector",
        input_example=input_example,
        signature=mlflow.models.infer_signature(X_test, y_pred)
    )

    # 6. Evaluation gate — do not promote a model that regressed.
    # This is what makes the CI training job "fail" (k8s Job condition
    # goes to Failed), which is what stops the pipeline before it restarts
    # the serving deployment onto a worse model.
    if test_f1 < MIN_F1_THRESHOLD:
        print(f"F1 {test_f1:.4f} is below the {MIN_F1_THRESHOLD} threshold — "
              f"not promoting. Run ID: {run.info.run_id}")
        sys.exit(1)

    # 7. Promote to Production (only reached if the gate above passed)
    client = MlflowClient()
    latest_version = client.get_latest_versions("FraudDetector", stages=["None"])[0].version
    client.transition_model_version_stage(
        name="FraudDetector",
        version=latest_version,
        stage="Production"
    )

print(f"Model registered and promoted to Production! F1={test_f1:.4f}, Run ID: {run.info.run_id}")
