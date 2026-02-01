# MinIO Demo - Commands to Copy & Paste

## Preparation (before demo)

```bash
cd /Users/rodrigo/git/github/rodrigodlima/minio-poc/examples/erasure-coding
```

---

## PART 1: Start MinIO with 4 Disks

### 1.1 Clean previous data and create disk folders

```bash
rm -rf ./data
mkdir -p ./data/disk{1,2,3,4}
```

### 1.2 Start MinIO

```bash
docker compose -f docker-compose.erasure.yml up -d
```

### 1.3 Wait and configure mc client

```bash
sleep 5
mc alias set erasure-demo http://localhost:9010 myminio minio123
```

### 1.4 Create bucket and upload test files

```bash
mc mb erasure-demo/test-bucket
```

```bash
echo "CONFIDENTIAL: Financial Report Q1 2025" > /tmp/report.txt
mc cp /tmp/report.txt erasure-demo/test-bucket/
```

```bash
mc ls erasure-demo/test-bucket/
```

---

## PART 2: Erasure Coding Demo

### 2.1 Show the 4 disks (volumes)

```bash
ls -la ./data/
```

### 2.2 Show data distributed across disks

```bash
ls ./data/disk1/test-bucket/
ls ./data/disk2/test-bucket/
ls ./data/disk3/test-bucket/
ls ./data/disk4/test-bucket/
```

### 2.3 Read the file (works normally)

```bash
mc cat erasure-demo/test-bucket/report.txt
```

### 2.4 Simulate DISK 1 failure (delete all data)

```bash
docker compose -f docker-compose.erasure.yml stop
rm -rf ./data/disk1/*
docker compose -f docker-compose.erasure.yml start
sleep 3
```

### 2.5 Verify data is still accessible

```bash
mc cat erasure-demo/test-bucket/report.txt
```

### 2.6 Show disk1 is empty

```bash
ls ./data/disk1/
```

### 2.7 Simulate DISK 2 failure (now 2 disks are dead)

```bash
docker compose -f docker-compose.erasure.yml stop
rm -rf ./data/disk2/*
docker compose -f docker-compose.erasure.yml start
sleep 3
```

### 2.8 Verify data is STILL accessible!

```bash
mc cat erasure-demo/test-bucket/report.txt
```

### 2.9 Show both disks are empty

```bash
echo "Disk 1:" && ls ./data/disk1/
echo "Disk 2:" && ls ./data/disk2/
echo "Disk 3:" && ls ./data/disk3/test-bucket/
echo "Disk 4:" && ls ./data/disk4/test-bucket/
```

---

## PART 3: WORM (Object Locking) Demo

### 3.1 Create bucket with Object Locking enabled

```bash
mc mb erasure-demo/compliance-bucket --with-lock
```

### 3.2 Set retention policy (COMPLIANCE mode, 1 day)

```bash
mc retention set --default COMPLIANCE "1d" erasure-demo/compliance-bucket
```

### 3.3 Upload a protected file

```bash
echo "CONFIDENTIAL: Audit Log $(date)" > /tmp/audit.txt
mc cp /tmp/audit.txt erasure-demo/compliance-bucket/
```

### 3.4 Show the file

```bash
mc cat erasure-demo/compliance-bucket/audit.txt
```

### 3.5 Get file version ID

```bash
mc ls --versions erasure-demo/compliance-bucket/audit.txt
```

### 3.6 Try to delete (WILL FAIL!)

```bash
VERSION_ID=$(mc ls --versions --json erasure-demo/compliance-bucket/audit.txt | grep -o '"versionId":"[^"]*"' | head -1 | cut -d'"' -f4)
mc rm --version-id "$VERSION_ID" erasure-demo/compliance-bucket/audit.txt
```

### 3.7 Show retention info

```bash
mc retention info erasure-demo/compliance-bucket
```

### 3.8 File is still there

```bash
mc cat erasure-demo/compliance-bucket/audit.txt
```

---

## PART 4: Cleanup

```bash
docker compose -f docker-compose.erasure.yml down
rm -rf ./data
mc alias rm erasure-demo
```

---

## Quick Reference

| Command | What it does |
|---------|--------------|
| `mc mb ALIAS/BUCKET` | Create bucket |
| `mc mb ALIAS/BUCKET --with-lock` | Create bucket with Object Locking |
| `mc cp FILE ALIAS/BUCKET/` | Upload file |
| `mc cat ALIAS/BUCKET/FILE` | Read file content |
| `mc ls ALIAS/BUCKET/` | List files |
| `mc ls --versions ALIAS/BUCKET/` | List all versions |
| `mc rm ALIAS/BUCKET/FILE` | Delete file |
| `mc rm --version-id VID ALIAS/BUCKET/FILE` | Delete specific version |
| `mc retention set --default MODE DURATION ALIAS/BUCKET` | Set retention policy |
| `mc retention info ALIAS/BUCKET` | Show retention policy |

---

## Error Messages You Will See

### Erasure Coding (disk failure)
No error - data is reconstructed automatically!

### WORM (try to delete)
```
Object 'audit.txt' is WORM protected and cannot be overwritten
```
