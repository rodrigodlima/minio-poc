# MinIO POC with OpenSearch Logging

A proof of concept demonstrating MinIO object storage with audit logging to OpenSearch, including a Go API application.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Go API    │────▶│    MinIO    │────▶│  Logstash   │────▶│ OpenSearch  │
│  :8080      │     │  :9000/9001 │     │   :5044     │     │   :9200     │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                   │
                                                                   ▼
                                                           ┌─────────────┐
                                                           │ OpenSearch  │
                                                           │ Dashboards  │
                                                           │   :5601     │
                                                           └─────────────┘
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| Go API | 8080 | REST API that stores logs in MinIO |
| MinIO | 9000, 9001 | Object storage (API and Console) |
| Logstash | 5044 | Receives MinIO audit webhooks |
| OpenSearch | 9200, 9600 | Log storage and search engine |
| OpenSearch Dashboards | 5601 | Log visualization UI |

## Prerequisites

- Docker
- Docker Compose

## Quick Start

### 1. Start all services

```bash
docker-compose up -d --build
```

### 2. Verify services are running

```bash
docker-compose ps
```

### 3. Access the UIs

- **MinIO Console**: http://localhost:9001
  - Username: `myminio`
  - Password: `minio`
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

### List All Logs

```bash
curl http://localhost:8080/logs
```

### Get a Specific Log

```bash
curl http://localhost:8080/logs/{id}
```

## Viewing Logs in OpenSearch

### Via API

```bash
# Check if logs are being indexed
curl http://localhost:9200/minio-audit-*/_search?pretty

# Count audit logs
curl http://localhost:9200/minio-audit-*/_count?pretty
```

### Via OpenSearch Dashboards

1. Open http://localhost:5601
2. Go to **Management** → **Stack Management** → **Index Patterns**
3. Create index pattern: `minio-audit-*`
4. Select `@timestamp` as the time field
5. Go to **Discover** to explore the logs

## Testing MinIO Directly

### Using MinIO Client (mc)

```bash
# Set up alias
docker run --rm -it --network minio-poc_minio-network \
  minio/mc alias set myminio http://minio:9000 myminio minio

# Create a bucket
docker run --rm -it --network minio-poc_minio-network \
  minio/mc mb myminio/test-bucket

# Upload a file
echo "test" > /tmp/test.txt
docker run --rm -it --network minio-poc_minio-network \
  -v /tmp/test.txt:/tmp/test.txt \
  minio/mc cp /tmp/test.txt myminio/test-bucket/

# List objects
docker run --rm -it --network minio-poc_minio-network \
  minio/mc ls myminio/test-bucket
```

### Using curl

```bash
# Create bucket
curl -X PUT http://localhost:9000/my-bucket -u myminio:minio

# Upload file
curl -X PUT http://localhost:9000/my-bucket/hello.txt \
  -u myminio:minio \
  -d "Hello World"
```

## Monitoring

### View container logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
docker-compose logs -f minio
docker-compose logs -f logstash
```

### Check Logstash processing

```bash
docker logs logstash -f
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
├── logstash/
│   └── pipeline/
│       └── minio-audit.conf  # Logstash pipeline config
├── docker-compose.yml   # Service orchestration
└── README.md
```

## Configuration

### MinIO Credentials

Set in `docker-compose.yml`:

```yaml
environment:
  MINIO_ROOT_USER: myminio
  MINIO_ROOT_PASSWORD: minio
```

### Audit Webhook

MinIO sends audit logs to Logstash via webhook:

```yaml
environment:
  MINIO_AUDIT_WEBHOOK_ENABLE_primary: "on"
  MINIO_AUDIT_WEBHOOK_ENDPOINT_primary: "http://logstash:5044"
```

## Troubleshooting

### Logs not appearing in OpenSearch

1. Check Logstash is receiving logs:
   ```bash
   docker logs logstash
   ```

2. Verify OpenSearch is healthy:
   ```bash
   curl http://localhost:9200/_cluster/health?pretty
   ```

3. Check MinIO webhook configuration:
   ```bash
   docker logs minio | grep -i webhook
   ```

### API cannot connect to MinIO

1. Ensure MinIO is running:
   ```bash
   docker-compose ps minio
   ```

2. Check API logs:
   ```bash
   docker logs go-api
   ```
