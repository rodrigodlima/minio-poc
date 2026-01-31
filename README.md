# MinIO POC with OpenSearch Logging

A proof of concept demonstrating MinIO as a low-cost log storage with OpenSearch for searchable logs. Application logs are stored in MinIO and automatically indexed in OpenSearch via event notifications.

## Architecture

```
                                    ┌─────────────────────────────────────────────────┐
                                    │            Log Content Flow                      │
                                    │                                                  │
┌─────────────┐     ┌─────────────┐ │  ┌─────────────┐     ┌─────────────┐            │
│   Go API    │────▶│    MinIO    │─┼─▶│   Webhook   │────▶│ OpenSearch  │            │
│   :8080     │     │ :9000/:9001 │ │  │   :8081     │     │   :9200     │            │
└─────────────┘     └─────────────┘ │  └─────────────┘     └─────────────┘            │
                           │        │         │                    │                   │
                           │        │   (reads content)            │                   │
                           │        │                              ▼                   │
                           │        │                      ┌─────────────┐            │
                           │        │                      │ OpenSearch  │            │
                           │        │                      │ Dashboards  │            │
                           │        │                      │   :5601     │            │
                           │        └──────────────────────┴─────────────┴────────────┘
                           │
                           │        ┌─────────────────────────────────────────────────┐
                           │        │            Audit Log Flow (S3 operations)       │
                           │        │                                                  │
                           └───────▶│  ┌─────────────┐     ┌─────────────┐            │
                                    │  │  Logstash   │────▶│ OpenSearch  │            │
                                    │  │   :5044     │     │ (minio-audit│            │
                                    │  └─────────────┘     │    index)   │            │
                                    │                      └─────────────┘            │
                                    └─────────────────────────────────────────────────┘
```

## How It Works

1. **Go API** receives log requests and stores them as JSON files in MinIO (`app-logs` bucket)
2. **MinIO** stores the logs cheaply (object storage) and triggers an **Event Notification** when a new file is created
3. **Webhook Service** receives the event, reads the file content from MinIO, and indexes it in OpenSearch
4. **OpenSearch** makes the logs searchable with full-text search capabilities
5. **Logstash** (optional) captures MinIO audit logs (S3 operations metadata)

## Services

| Service | Port | Description |
|---------|------|-------------|
| Go API | 8080 | REST API that stores logs in MinIO |
| MinIO | 9000, 9001 | Object storage (API and Console) |
| Webhook | 8081 | Processes MinIO events and indexes logs |
| OpenSearch | 9200, 9600 | Log storage and search engine |
| OpenSearch Dashboards | 5601 | Log visualization UI |
| Logstash | 5044 | Receives MinIO audit webhooks (S3 ops) |

## Prerequisites

- Docker
- Docker Compose

## Quick Start

### 1. Start all services

```bash
docker-compose up -d --build
```

### 2. Wait for setup to complete

The `minio-setup` container configures event notifications automatically. Check its logs:

```bash
docker logs minio-setup
```

You should see: `MinIO event notification configured!`

### 3. Verify services are running

```bash
docker-compose ps
```

### 4. Access the UIs

- **MinIO Console**: http://localhost:9001
  - Username: `myminio`
  - Password: `minio123`
- **OpenSearch Dashboards**: http://localhost:5601

## API Usage

### Health Check

```bash
curl http://localhost:8080/health
```

### Generate Sample Logs

Generates 10 sample log entries with different levels (INFO, WARN, ERROR, DEBUG):

```bash
curl -X POST http://localhost:8080/generate
```

### Create a Custom Log

```bash
curl -X POST http://localhost:8080/logs \
  -H "Content-Type: application/json" \
  -d '{"level": "INFO", "message": "User authentication successful"}'
```

### List All Logs (from MinIO)

```bash
curl http://localhost:8080/logs
```

## Searching Logs in OpenSearch

### Via API

```bash
# Search application logs (content)
curl -s 'http://localhost:9200/app-logs-*/_search?pretty' \
  -H 'Content-Type: application/json' \
  -d '{"query":{"match":{"message":"authentication"}}}'

# Search by log level
curl -s 'http://localhost:9200/app-logs-*/_search?pretty' \
  -H 'Content-Type: application/json' \
  -d '{"query":{"match":{"level":"ERROR"}}}'

# Count logs
curl -s 'http://localhost:9200/app-logs-*/_count'
```

### Via OpenSearch Dashboards

1. Open http://localhost:5601
2. Go to **Management** → **Stack Management** → **Index Patterns**
3. Create index pattern: `app-logs-*`
4. Select `timestamp` as the time field
5. Go to **Discover** to explore and search logs

### PPL Queries (in OpenSearch Dashboards)

```sql
-- Search for specific message
source = app-logs-* | where message = "User authentication successful"

-- Filter by log level
source = app-logs-* | where level = "ERROR"

-- Search with wildcard
source = app-logs-* | where match(message, "authentication")
```

## Index Patterns

| Index Pattern | Content | Description |
|---------------|---------|-------------|
| `app-logs-*` | Application logs | Log content (level, message, service) |
| `minio-audit-*` | Audit logs | S3 operations (PutObject, GetObject, etc.) |

## Monitoring

### View container logs

```bash
# All services
docker-compose logs -f

# Specific services
docker-compose logs -f webhook
docker-compose logs -f api
docker-compose logs -f minio
```

### Check webhook processing

```bash
docker logs log-webhook -f
```

### Verify event notifications

```bash
docker run --rm --network minio-poc_minio-network minio/mc \
  alias set myminio http://minio:9000 myminio minio123 && \
  mc event list myminio/app-logs
```

## Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (clears all data)
docker-compose down -v
```

## Project Structure

```
.
├── api/
│   ├── main.go          # Go API application
│   ├── go.mod           # Go module dependencies
│   └── Dockerfile       # API container build
├── webhook/
│   ├── main.go          # Webhook service (MinIO events → OpenSearch)
│   ├── go.mod           # Go module dependencies
│   └── Dockerfile       # Webhook container build
├── logstash/
│   └── pipeline/
│       └── minio-audit.conf  # Logstash pipeline for audit logs
├── docker-compose.yml   # Service orchestration
└── README.md
```

## Configuration

### MinIO Credentials

```yaml
environment:
  MINIO_ROOT_USER: myminio
  MINIO_ROOT_PASSWORD: minio123
```

### Event Notification

MinIO sends events to the webhook when new objects are created:

```bash
mc event add myminio/app-logs arn:minio:sqs::logwebhook:webhook --event put --suffix .json
```

## Troubleshooting

### Logs not appearing in OpenSearch (app-logs index)

1. Check webhook is receiving events:
   ```bash
   docker logs log-webhook
   ```

2. Verify event notification is configured:
   ```bash
   docker logs minio-setup
   ```

3. Re-run setup if needed:
   ```bash
   docker-compose restart minio-setup
   ```

### Verify OpenSearch health

```bash
curl 'http://localhost:9200/_cluster/health?pretty'
```

### Check MinIO bucket events

```bash
docker run --rm --network minio-poc_minio-network minio/mc \
  sh -c "mc alias set myminio http://minio:9000 myminio minio123 && mc event list myminio/app-logs"
```
