#!/usr/bin/env python3
"""
MinIO + MLflow Demo Script
Demonstrates ML pipeline with MinIO as artifact storage
"""

import os
import mlflow
import mlflow.sklearn
from minio import Minio
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
from io import BytesIO

# =============================================================================
# 1. CONFIGURATION
# =============================================================================
print("=" * 60)
print("MinIO + MLflow ML Pipeline Demo")
print("=" * 60)

# MinIO client
minio_client = Minio(
    os.environ.get("MINIO_ENDPOINT", "localhost:9000"),
    access_key=os.environ.get("AWS_ACCESS_KEY_ID", "myminio"),
    secret_key=os.environ.get("AWS_SECRET_ACCESS_KEY", "minio123"),
    secure=False
)

# MLflow configuration
mlflow.set_tracking_uri(os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000"))
os.environ["MLFLOW_S3_ENDPOINT_URL"] = os.environ.get("MLFLOW_S3_ENDPOINT_URL", "http://localhost:9000")
os.environ["AWS_ACCESS_KEY_ID"] = "myminio"
os.environ["AWS_SECRET_ACCESS_KEY"] = "minio123"

print(f"\n[1] Connected to MinIO: localhost:9000")
print(f"[1] MLflow Tracking: {mlflow.get_tracking_uri()}")

# =============================================================================
# 2. CREATE AND UPLOAD DATASET TO MINIO
# =============================================================================
print("\n" + "-" * 60)
print("[2] Creating sample dataset and uploading to MinIO...")

np.random.seed(42)
n_samples = 500

# Simulate log data for classification
data = pd.DataFrame({
    'message_length': np.random.randint(10, 500, n_samples),
    'contains_error': np.random.randint(0, 2, n_samples),
    'response_time_ms': np.random.exponential(100, n_samples),
    'hour_of_day': np.random.randint(0, 24, n_samples),
    'request_count': np.random.poisson(10, n_samples),
})

# Target: predict if log is critical
data['is_critical'] = (
    (data['contains_error'] == 1) & (data['response_time_ms'] > 200)
).astype(int)

# Upload to MinIO
csv_buffer = BytesIO(data.to_csv(index=False).encode())
minio_client.put_object(
    "ml-datasets",
    "demo/training_data.csv",
    csv_buffer,
    len(csv_buffer.getvalue()),
    content_type="text/csv"
)

print(f"    Dataset uploaded: s3://ml-datasets/demo/training_data.csv")
print(f"    Samples: {len(data)} | Features: {len(data.columns)-1}")
print(f"    Critical logs: {data['is_critical'].sum()} ({data['is_critical'].mean()*100:.1f}%)")

# =============================================================================
# 3. LOAD DATA FROM MINIO AND TRAIN MODEL
# =============================================================================
print("\n" + "-" * 60)
print("[3] Loading data from MinIO and training model...")

# Load from MinIO
response = minio_client.get_object("ml-datasets", "demo/training_data.csv")
df = pd.read_csv(BytesIO(response.read()))

X = df.drop('is_critical', axis=1)
y = df['is_critical']
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train with MLflow tracking
mlflow.set_experiment("demo-log-classification")

with mlflow.start_run(run_name="demo-run") as run:
    # Log parameters
    params = {"n_estimators": 100, "max_depth": 10, "random_state": 42}
    mlflow.log_params(params)
    mlflow.log_param("data_source", "s3://ml-datasets/demo/training_data.csv")

    # Train model
    model = RandomForestClassifier(**params)
    model.fit(X_train, y_train)

    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    mlflow.log_metric("accuracy", accuracy)

    # Save model to MinIO via MLflow
    mlflow.sklearn.log_model(model, "model", registered_model_name="demo-classifier")

    print(f"    Model trained with accuracy: {accuracy:.2%}")
    print(f"    MLflow Run ID: {run.info.run_id}")
    print(f"    Model saved to: s3://mlflow-artifacts/")

# =============================================================================
# 4. LOAD MODEL AND PREDICT
# =============================================================================
print("\n" + "-" * 60)
print("[4] Loading model from MinIO and making predictions...")

# Load model
model_uri = f"runs:/{run.info.run_id}/model"
loaded_model = mlflow.sklearn.load_model(model_uri)

# Predict on new data
new_logs = pd.DataFrame({
    'message_length': [450, 50, 200],
    'contains_error': [1, 0, 1],
    'response_time_ms': [350, 80, 150],
    'hour_of_day': [3, 14, 10],
    'request_count': [25, 5, 12],
})

predictions = loaded_model.predict(new_logs)
probabilities = loaded_model.predict_proba(new_logs)

print("\n    New log predictions:")
for i, (pred, prob) in enumerate(zip(predictions, probabilities)):
    status = "CRITICAL" if pred == 1 else "NORMAL"
    confidence = max(prob) * 100
    print(f"    Log {i+1}: {status} (confidence: {confidence:.0f}%)")

# =============================================================================
# 5. SUMMARY
# =============================================================================
print("\n" + "=" * 60)
print("Demo Complete!")
print("=" * 60)
print(f"""
MinIO Buckets used:
  - ml-datasets: Training data storage
  - mlflow-artifacts: Model artifacts storage

MLflow UI: http://localhost:5000
  - View experiments, runs, and model versions
  - Compare model performance
  - Download model artifacts

Key Benefits:
  - Centralized data lake for ML datasets
  - Version-controlled model artifacts
  - Reproducible experiments
  - S3-compatible = works with any ML tool
""")
