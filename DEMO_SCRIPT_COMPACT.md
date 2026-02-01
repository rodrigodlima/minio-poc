# MinIO POC - Compact Demo (7 minutes)

## Preparation (BEFORE the demo)

```bash
# Terminal 1: Erasure Coding
cd /home/ubuntu/minio-poc/examples/erasure-coding
rm -rf ./data && mkdir -p ./data/disk{1,2,3,4}
docker compose -f docker-compose.erasure.yml up -d
sleep 5
mc alias set erasure-demo http://ec2-34-228-15-199.compute-1.amazonaws.com:9010 myminio minio123
mc mb erasure-demo/test-bucket
echo "CONFIDENTIAL: Financial Report Q1 2025" > /tmp/report.txt
mc cp /tmp/report.txt erasure-demo/test-bucket/

# Terminal 2: OpenSearch
cd /home/ubuntu/minio-poc
docker-compose up -d --build
sleep 30

# Install ML dependencies (for demo)
pip install boto3 pandas numpy scikit-learn
```

**Browser tabs:**
- MinIO Erasure: http://ec2-34-228-15-199.compute-1.amazonaws.com:9011 (myminio / minio123)
- MinIO OpenSearch: http://ec2-34-228-15-199.compute-1.amazonaws.com:9001 (myminio / minio123)
- OpenSearch Dashboards: http://ec2-34-228-15-199.compute-1.amazonaws.com:5601

---

## PART 1: Erasure Coding (2 min)

> "Erasure Coding protects data without RAID. It splits data into pieces and distributes across disks."

**Show file working:**
```bash
mc cat erasure-demo/test-bucket/report.txt
```

**Simulate disk failure:**
```bash
docker compose -f docker-compose.erasure.yml stop
rm -rf ./data/disk1/*
rm -rf ./data/disk2/*
docker compose -f docker-compose.erasure.yml start
sleep 3
```

> "I deleted 2 disks. Half of the storage."

**Verify - still works:**
```bash
mc cat erasure-demo/test-bucket/report.txt
```

> "Data is intact! MinIO reconstructs it using parity from the other disks."

---

## PART 2: WORM - Object Locking (1 min)

> "WORM is for compliance. Data cannot be deleted or modified."

**Create protected bucket and upload:**
```bash
mc mb erasure-demo/compliance-bucket --with-lock
mc retention set --default COMPLIANCE "1d" erasure-demo/compliance-bucket
echo "AUDIT: $(date)" > /tmp/audit.txt
mc cp /tmp/audit.txt erasure-demo/compliance-bucket/
```

**Try to delete - BLOCKED:**
```bash
VERSION_ID=$(mc ls --versions --json erasure-demo/compliance-bucket/audit.txt | grep -o '"versionId":"[^"]*"' | head -1 | cut -d'"' -f4)
mc rm --version-id "$VERSION_ID" erasure-demo/compliance-bucket/audit.txt
```

> "WORM protected! Not even admin can delete until retention expires."

---

## PART 3: OpenSearch - Log Indexing (2 min)

> "Logs stored in MinIO, automatically indexed in OpenSearch."

**Show architecture:** (open DEMO_PRESENTATION.md or slide)

```
Go API → MinIO → Webhook → OpenSearch
```

**Generate logs in real-time (run during demo):**
```bash
# Generate 5 random logs
curl -X POST http://ec2-34-228-15-199.compute-1.amazonaws.com:8080/generate

# Generate a specific ERROR log
curl -X POST http://ec2-34-228-15-199.compute-1.amazonaws.com:8080/logs \
  -H "Content-Type: application/json" \
  -d '{"level":"ERROR","message":"Payment processing failed"}'

# Generate a specific INFO log
curl -X POST http://ec2-34-228-15-199.compute-1.amazonaws.com:8080/logs \
  -H "Content-Type: application/json" \
  -d '{"level":"INFO","message":"User login successful"}'

# Generate multiple logs at once
for i in {1..3}; do curl -s -X POST http://ec2-34-228-15-199.compute-1.amazonaws.com:8080/generate; done
```

**Open OpenSearch Dashboards:** http://ec2-34-228-15-199.compute-1.amazonaws.com:5601 → Observability → Logs

**PPL Query:**
```sql
source = app-logs-* | where level = "ERROR"
```

> "Instant search. Cheap storage in MinIO, fast queries in OpenSearch."

---

## PART 4: Machine Learning Pipeline (2 min)

> "MinIO as data lake for ML. Store datasets, train models, version artifacts."

**Show the code** (open in editor or cat):
```bash
cat examples/ml/demo_ml_simple.py
```

**Key points to highlight in the code:**
- Line 1-30: Connect to MinIO using boto3 (AWS S3 SDK) - proves S3 compatibility!
- Line 40-50: Upload training data using s3.put_object()
- Line 60-70: Load data using s3.get_object(), train model
- Line 80-95: Save model artifact using S3 API
- Line 100+: Load model from MinIO, make predictions

**Run the ML demo:**
```bash
cd /home/ubuntu/minio-poc/examples/ml
python demo_ml_simple.py
```

**Expected output:**
```
[1] Connected to MinIO at http://localhost:9000 (using boto3/S3 SDK)
[2] Uploaded: s3://ml-datasets/logs/training_data.csv
[3] Model trained! Accuracy: 92%
[4] Saved: s3://ml-models/log-classifier/v_20250201/model.pkl
[5] Predictions: CRITICAL / NORMAL / NORMAL
```

**Show MinIO Console:** http://ec2-34-228-15-199.compute-1.amazonaws.com:9001
- `ml-datasets/` - training data
- `ml-models/` - trained model artifacts (versioned by timestamp)

> "Complete ML pipeline using standard AWS boto3 SDK! Data lake in MinIO, models versioned. 100% S3-compatible."

---

## Cleanup

```bash
# Stop Erasure Coding
cd /home/ubuntu/minio-poc/examples/erasure-coding
docker compose -f docker-compose.erasure.yml down
rm -rf ./data

# Stop OpenSearch
cd /home/ubuntu/minio-poc
docker-compose down -v
```
