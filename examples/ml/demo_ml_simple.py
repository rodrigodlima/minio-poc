#!/usr/bin/env python3
"""
MinIO ML Demo - Simple Version
Demonstrates ML pipeline using MinIO as data lake (no MLflow required)
Run: pip install minio pandas numpy scikit-learn && python demo_ml_simple.py
"""

from minio import Minio
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
from io import BytesIO
import pickle
from datetime import datetime

# =============================================================================
# 1. CONNECT TO MINIO
# =============================================================================
print("=" * 60)
print("MinIO ML Pipeline Demo (Simple)")
print("=" * 60)

client = Minio(
    "localhost:9000",
    access_key="myminio",
    secret_key="minio123",
    secure=False
)

# Create ML bucket if needed
for bucket in ["ml-datasets", "ml-models"]:
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)
        print(f"[+] Created bucket: {bucket}")

print("\n[1] Connected to MinIO at localhost:9000")

# =============================================================================
# 2. CREATE AND UPLOAD TRAINING DATA
# =============================================================================
print("\n" + "-" * 60)
print("[2] Generating and uploading training data...")

np.random.seed(42)
n_samples = 500

# Simulate log data
data = pd.DataFrame({
    'message_length': np.random.randint(10, 500, n_samples),
    'contains_error': np.random.randint(0, 2, n_samples),
    'response_time_ms': np.random.exponential(100, n_samples),
    'hour_of_day': np.random.randint(0, 24, n_samples),
    'request_count': np.random.poisson(10, n_samples),
})

# Target: critical if error + slow response
data['is_critical'] = (
    (data['contains_error'] == 1) & (data['response_time_ms'] > 200)
).astype(int)

# Upload to MinIO
csv_bytes = data.to_csv(index=False).encode()
client.put_object(
    "ml-datasets",
    "logs/training_data.csv",
    BytesIO(csv_bytes),
    len(csv_bytes),
    content_type="text/csv"
)

print(f"    Uploaded: s3://ml-datasets/logs/training_data.csv")
print(f"    Samples: {len(data)} | Critical: {data['is_critical'].sum()}")

# =============================================================================
# 3. LOAD DATA FROM MINIO AND TRAIN MODEL
# =============================================================================
print("\n" + "-" * 60)
print("[3] Loading data from MinIO and training model...")

# Load from MinIO
response = client.get_object("ml-datasets", "logs/training_data.csv")
df = pd.read_csv(BytesIO(response.read()))
response.close()

# Prepare features
X = df.drop('is_critical', axis=1)
y = df['is_critical']
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train model
model = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
model.fit(X_train, y_train)

# Evaluate
accuracy = accuracy_score(y_test, model.predict(X_test))
print(f"    Model trained! Accuracy: {accuracy:.1%}")

# =============================================================================
# 4. SAVE MODEL TO MINIO
# =============================================================================
print("\n" + "-" * 60)
print("[4] Saving model to MinIO...")

# Serialize model
model_bytes = pickle.dumps(model)
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
model_path = f"log-classifier/v_{timestamp}/model.pkl"

# Save model
client.put_object(
    "ml-models",
    model_path,
    BytesIO(model_bytes),
    len(model_bytes),
    content_type="application/octet-stream"
)

# Save metadata
metadata = {
    "accuracy": accuracy,
    "features": list(X.columns),
    "n_estimators": 100,
    "max_depth": 10,
    "created_at": timestamp
}
meta_bytes = str(metadata).encode()
client.put_object(
    "ml-models",
    f"log-classifier/v_{timestamp}/metadata.json",
    BytesIO(meta_bytes),
    len(meta_bytes),
    content_type="application/json"
)

print(f"    Saved: s3://ml-models/{model_path}")

# =============================================================================
# 5. LOAD MODEL AND PREDICT
# =============================================================================
print("\n" + "-" * 60)
print("[5] Loading model from MinIO and predicting...")

# Load model from MinIO
response = client.get_object("ml-models", model_path)
loaded_model = pickle.loads(response.read())
response.close()

# Predict on new logs
new_logs = pd.DataFrame({
    'message_length': [450, 50, 200],
    'contains_error': [1, 0, 1],
    'response_time_ms': [350, 80, 150],
    'hour_of_day': [3, 14, 10],
    'request_count': [25, 5, 12],
})

predictions = loaded_model.predict(new_logs)
probabilities = loaded_model.predict_proba(new_logs)

print("\n    Predictions for new logs:")
for i, (pred, prob) in enumerate(zip(predictions, probabilities)):
    status = "CRITICAL" if pred == 1 else "NORMAL"
    conf = max(prob) * 100
    print(f"      Log {i+1}: {status} (confidence: {conf:.0f}%)")

# =============================================================================
# 6. LIST ARTIFACTS IN MINIO
# =============================================================================
print("\n" + "-" * 60)
print("[6] ML artifacts in MinIO:")

print("\n    ml-datasets/")
for obj in client.list_objects("ml-datasets", recursive=True):
    print(f"      - {obj.object_name}")

print("\n    ml-models/")
for obj in client.list_objects("ml-models", recursive=True):
    print(f"      - {obj.object_name}")

# =============================================================================
# SUMMARY
# =============================================================================
print("\n" + "=" * 60)
print("Demo Complete!")
print("=" * 60)
print("""
Pipeline executed:
  1. Generated training data -> uploaded to MinIO
  2. Loaded data from MinIO -> trained model
  3. Saved model artifact -> to MinIO
  4. Loaded model from MinIO -> made predictions

Benefits of MinIO for ML:
  - Centralized data lake for all datasets
  - Version-controlled model artifacts
  - S3-compatible = works with any ML framework
  - Scales to petabytes of data

View in MinIO Console: http://localhost:9001
  - Bucket: ml-datasets (training data)
  - Bucket: ml-models (trained models)
""")
