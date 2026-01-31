# MinIO Use Cases: Analytics & Machine Learning

This directory contains practical examples of using MinIO for Analytics and Machine Learning workloads.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              MinIO Data Platform                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  app-logs   │    │  analytics  │    │ ml-datasets │    │   mlflow    │  │
│  │   bucket    │    │    data     │    │   bucket    │    │  artifacts  │  │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘  │
│         │                  │                  │                  │         │
└─────────┼──────────────────┼──────────────────┼──────────────────┼─────────┘
          │                  │                  │                  │
          ▼                  ▼                  ▼                  ▼
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │  OpenSearch │    │   Spark     │    │   Jupyter   │    │   MLflow    │
   │  (Search)   │    │ (Analytics) │    │  (ML/EDA)   │    │ (Tracking)  │
   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Use Cases

### 1. Analytics (Apache Spark + Trino)

**Location:** [analytics/](analytics/)

Components:
- **Apache Spark** - Distributed data processing
- **Jupyter Notebook** - Interactive analytics
- **Trino** - SQL query engine for data lake
- **Apache Superset** - Business intelligence dashboards

**Key Features:**
- Read/write Parquet, JSON, CSV from MinIO
- Real-time streaming analytics
- SQL queries over data lake
- Visualization dashboards

### 2. Machine Learning (MLflow)

**Location:** [ml/](ml/)

Components:
- **MLflow** - Experiment tracking and model registry
- **Jupyter Notebook** - Model training
- **Label Studio** - Data labeling
- **PostgreSQL** - MLflow metadata

**Key Features:**
- Experiment tracking with MinIO artifact storage
- Model versioning and registry
- Hyperparameter tuning (Optuna)
- Feature store pattern

## Quick Start

### Prerequisites

Make sure the base MinIO stack is running:

```bash
# From the root directory
docker-compose up -d
```

### Running Analytics Example

```bash
cd examples/analytics

# Start analytics services
docker-compose -f docker-compose.analytics.yml up -d

# Access services:
# - Spark UI: http://localhost:8082
# - Jupyter: http://localhost:8888
# - Trino: http://localhost:8083
# - Superset: http://localhost:8088
```

### Running ML Example

```bash
cd examples/ml

# Start ML services
docker-compose -f docker-compose.ml.yml up -d

# Access services:
# - MLflow: http://localhost:5000
# - Jupyter: http://localhost:8889
# - Label Studio: http://localhost:8084
```

## Data Flow Examples

### Analytics Pipeline

```
Raw Logs (JSON) → MinIO → Spark ETL → Parquet → Trino SQL → Superset Dashboard
```

### ML Training Pipeline

```
Training Data → MinIO → Jupyter/Spark → Model Training → MLflow → MinIO (artifacts)
                                              ↓
                                       Model Registry
                                              ↓
                                       Model Serving
```

## MinIO Buckets

| Bucket | Purpose |
|--------|---------|
| `app-logs` | Application log storage (existing) |
| `analytics-data` | Processed analytics data (Parquet) |
| `ml-datasets` | Training/validation datasets |
| `mlflow-artifacts` | MLflow model artifacts |
| `feature-store` | Feature engineering outputs |
| `ml-models` | Exported models for serving |

## Sample Notebooks

### Analytics
- [01_minio_spark_analytics.ipynb](analytics/notebooks/01_minio_spark_analytics.ipynb)
  - Reading logs from MinIO
  - Aggregations and transformations
  - Saving results as Parquet
  - Streaming analytics

### Machine Learning
- [01_minio_mlflow_training.ipynb](ml/notebooks/01_minio_mlflow_training.ipynb)
  - Loading data from MinIO
  - Training with MLflow tracking
  - Hyperparameter tuning
  - Feature store pattern

## Configuration Files

### Spark
- [spark-defaults.conf](analytics/spark-defaults.conf) - S3A connector settings

### Trino
- [minio.properties](analytics/trino/catalog/minio.properties) - Hive connector for MinIO

## Integration with Existing Stack

These examples integrate with your existing MinIO POC:

```yaml
# Shared network
networks:
  minio-network:
    external: true  # Uses existing network from base docker-compose
```

The analytics and ML services can query the same `app-logs` bucket used for log indexing.

## Production Considerations

1. **Security**
   - Enable SSL/TLS for all services
   - Use IAM policies for bucket access
   - Rotate credentials regularly

2. **Performance**
   - Use Parquet format for analytics
   - Partition data by date
   - Enable MinIO caching

3. **Scalability**
   - Distributed MinIO cluster
   - Spark cluster scaling
   - Kubernetes deployment

## Cleanup

```bash
# Stop analytics
cd examples/analytics
docker-compose -f docker-compose.analytics.yml down -v

# Stop ML
cd examples/ml
docker-compose -f docker-compose.ml.yml down -v
```
