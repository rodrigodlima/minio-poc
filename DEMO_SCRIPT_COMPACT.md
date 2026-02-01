# MinIO POC - Demo Compacta (5 minutos)

## Preparação (ANTES da demo)

```bash
# Terminal 1: Erasure Coding
cd /Users/rodrigo/git/github/rodrigodlima/minio-poc/examples/erasure-coding
rm -rf ./data && mkdir -p ./data/disk{1,2,3,4}
docker compose -f docker-compose.erasure.yml up -d
sleep 5
mc alias set erasure-demo http://localhost:9010 myminio minio123
mc mb erasure-demo/test-bucket
echo "CONFIDENTIAL: Financial Report Q1 2025" > /tmp/report.txt
mc cp /tmp/report.txt erasure-demo/test-bucket/

# Terminal 2: OpenSearch
cd /Users/rodrigo/git/github/rodrigodlima/minio-poc
docker-compose up -d --build
sleep 30
curl -X POST http://localhost:8080/generate
```

**Abas do browser:**
- MinIO Erasure: http://localhost:9011 (myminio / minio123)
- MinIO OpenSearch: http://localhost:9001 (myminio / minio123)
- OpenSearch Dashboards: http://localhost:5601

---

## PART 1: Erasure Coding (2 min)

> "Erasure Coding protege dados sem RAID. Divide em pedaços e distribui nos discos."

**Mostrar arquivo funcionando:**
```bash
mc cat erasure-demo/test-bucket/report.txt
```

**Simular falha de disco:**
```bash
docker compose -f docker-compose.erasure.yml stop
rm -rf ./data/disk1/*
rm -rf ./data/disk2/*
docker compose -f docker-compose.erasure.yml start
sleep 3
```

> "Deletei 2 discos. Metade do storage."

**Verificar - ainda funciona:**
```bash
mc cat erasure-demo/test-bucket/report.txt
```

> "Dados intactos! MinIO reconstrói usando paridade dos outros discos."

---

## PART 2: WORM - Object Locking (1 min)

> "WORM para compliance. Dados não podem ser deletados."

**Criar bucket protegido e upload:**
```bash
mc mb erasure-demo/compliance-bucket --with-lock
mc retention set --default COMPLIANCE "1d" erasure-demo/compliance-bucket
echo "AUDIT: $(date)" > /tmp/audit.txt
mc cp /tmp/audit.txt erasure-demo/compliance-bucket/
```

**Tentar deletar - BLOQUEADO:**
```bash
VERSION_ID=$(mc ls --versions --json erasure-demo/compliance-bucket/audit.txt | grep -o '"versionId":"[^"]*"' | head -1 | cut -d'"' -f4)
mc rm --version-id "$VERSION_ID" erasure-demo/compliance-bucket/audit.txt
```

> "WORM protected! Nem admin consegue deletar até o período expirar."

---

## PART 3: OpenSearch - Log Indexing (2 min)

> "Logs armazenados no MinIO, indexados automaticamente no OpenSearch."

**Mostrar arquitetura:** (abrir DEMO_PRESENTATION.md ou slide)

```
Go API → MinIO → Webhook → OpenSearch
```

**Abrir OpenSearch Dashboards:** http://localhost:5601 → Observability → Logs

**Query PPL:**
```sql
source = app-logs-* | where level = "ERROR"
```

> "Busca instantânea. Logs baratos no MinIO, pesquisa rápida no OpenSearch."

---

## Cleanup

```bash
cd /Users/rodrigo/git/github/rodrigodlima/minio-poc/examples/erasure-coding
docker compose -f docker-compose.erasure.yml down
rm -rf ./data

cd /Users/rodrigo/git/github/rodrigodlima/minio-poc
docker-compose down -v
```
