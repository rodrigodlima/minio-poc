# MinIO POC - Demo Script (10 minutes)

## Focus: Advanced Features

> **Note:** This demo comes after slides explaining MinIO basics. We focus on advanced features that differentiate MinIO from simple storage.

**Commands file:** `examples/erasure-coding/COMMANDS.md`

---

## Preparation (do this BEFORE the demo)

```bash
cd /Users/rodrigo/git/github/rodrigodlima/minio-poc/examples/erasure-coding

# Clean and create disk folders
rm -rf ./data
mkdir -p ./data/disk{1,2,3,4}

# Start MinIO with 4 disks
docker compose -f docker-compose.erasure.yml up -d

# Wait and configure client
sleep 5
mc alias set erasure-demo http://localhost:9010 myminio minio123

# Create bucket and upload test file
mc mb erasure-demo/test-bucket
echo "CONFIDENTIAL: Financial Report Q1 2025" > /tmp/report.txt
mc cp /tmp/report.txt erasure-demo/test-bucket/
```

**Browser tab:** http://localhost:9011 (myminio / minio123)

---

## DEMO SCRIPT

---

### PART 1: MinIO Console - Quick Tour (1 min)

**Action:** Open http://localhost:9011

**What to say:**

> "This is MinIO Console. Here we have a bucket with a file. MinIO looks simple, but it has powerful features. Let me show you."

---

### PART 2: Erasure Coding - Data Protection (5 min)

**What to say:**

> "The first feature is Erasure Coding. This is how MinIO protects your data without RAID."

#### 2.1 Explain the Concept (30 sec)

**What to say:**

> "Traditional storage uses RAID. RAID has problems: you need special hardware, it only works in one server, and rebuild is very slow."

> "MinIO uses Erasure Coding. It splits data into pieces and distributes across disks. No special hardware needed."

```
With 4 disks:
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│Disk 1│ │Disk 2│ │Disk 3│ │Disk 4│
│ Data │ │ Data │ │Parity│ │Parity│
└──────┘ └──────┘ └──────┘ └──────┘

We can lose up to 2 disks!
```

#### 2.2 Show the 4 Disks (30 sec)

**Command:**
```bash
ls -la ./data/
```

**What to say:**

> "Here are our 4 disks. In production, these would be physical disks or different servers."

#### 2.3 Show Data Distribution (30 sec)

**Command:**
```bash
ls ./data/disk1/test-bucket/
ls ./data/disk2/test-bucket/
ls ./data/disk3/test-bucket/
ls ./data/disk4/test-bucket/
```

**What to say:**

> "The file is distributed across all 4 disks. No single disk has the complete file."

#### 2.4 Read the File (30 sec)

**Command:**
```bash
mc cat erasure-demo/test-bucket/report.txt
```

**What to say:**

> "The file is readable. Now let's break things."

#### 2.5 Simulate Disk 1 Failure (1 min)

**Command:**
```bash
docker compose -f docker-compose.erasure.yml stop
rm -rf ./data/disk1/*
docker compose -f docker-compose.erasure.yml start
sleep 3
```

**What to say:**

> "I stopped MinIO, deleted all data from Disk 1, and started again. This simulates a disk failure."

#### 2.6 Verify Data - Still Works! (30 sec)

**Command:**
```bash
mc cat erasure-demo/test-bucket/report.txt
```

**What to say:**

> "The data is still there! MinIO reconstructs the missing parts using parity from other disks."

**Command:**
```bash
ls ./data/disk1/
```

> "Disk 1 is empty, but data is accessible."

#### 2.7 Simulate Disk 2 Failure (1 min)

**Command:**
```bash
docker compose -f docker-compose.erasure.yml stop
rm -rf ./data/disk2/*
docker compose -f docker-compose.erasure.yml start
sleep 3
```

**What to say:**

> "Now I delete Disk 2 as well. We lost HALF of our disks."

#### 2.8 Verify Data - STILL Works! (30 sec)

**Command:**
```bash
mc cat erasure-demo/test-bucket/report.txt
```

**What to say:**

> "Data is STILL accessible! With 4 disks, we can lose 2. With 16 disks, we can lose up to 4."

**Command:**
```bash
echo "Disk 1:" && ls ./data/disk1/
echo "Disk 2:" && ls ./data/disk2/
```

> "Both disks are empty, but data survives."

#### 2.9 Compare with RAID (30 sec)

**What to say:**

> "Compare with RAID:"

| | RAID | MinIO Erasure Coding |
|--|------|----------------------|
| Hardware | Special controller | No special hardware |
| Scope | One server | Multiple servers |
| Rebuild | Hours or days | Automatic, fast |
| Scale | Limited | Exabytes |

---

### PART 3: WORM - Object Locking for Compliance (2 min)

**What to say:**

> "The second feature is WORM - Write Once Read Many. This is for compliance. LGPD, SOX, HIPAA require that some data cannot be deleted."

#### 3.1 Create WORM Bucket (30 sec)

**Command:**
```bash
mc mb erasure-demo/compliance-bucket --with-lock
```

**Command:**
```bash
mc retention set --default COMPLIANCE "1d" erasure-demo/compliance-bucket
```

**What to say:**

> "I create a bucket with Object Locking. COMPLIANCE mode means nobody can delete - not even administrators. Retention is 1 day. In production, this could be 7 years."

#### 3.2 Upload Protected File (30 sec)

**Command:**
```bash
echo "AUDIT LOG: $(date) - User accessed financial data" > /tmp/audit.txt
mc cp /tmp/audit.txt erasure-demo/compliance-bucket/
```

**Command:**
```bash
mc cat erasure-demo/compliance-bucket/audit.txt
```

**What to say:**

> "I upload an audit log. This file is now protected."

#### 3.3 Try to Delete - BLOCKED! (30 sec)

**Command:**
```bash
VERSION_ID=$(mc ls --versions --json erasure-demo/compliance-bucket/audit.txt | grep -o '"versionId":"[^"]*"' | head -1 | cut -d'"' -f4)
mc rm --version-id "$VERSION_ID" erasure-demo/compliance-bucket/audit.txt
```

**Output will show:**
```
Object 'audit.txt' is WORM protected and cannot be overwritten
```

**What to say:**

> "Look at this error: WORM protected, cannot be overwritten. Not hackers, not ransomware, not even administrators can delete this file until retention ends."

#### 3.4 File Still There (30 sec)

**Command:**
```bash
mc cat erasure-demo/compliance-bucket/audit.txt
```

**What to say:**

> "The file is still there and readable. Protected until retention period ends."

---

### PART 4: Wrap Up (2 min)

**What to say:**

> "Let me summarize the advanced features we saw:"

> "**Erasure Coding**: Data protection without RAID. Can lose multiple disks. No special hardware. Works across servers."

> "**WORM / Object Locking**: Data cannot be deleted or modified. Required for compliance. Protects against ransomware."

> "MinIO has more features:"

| Feature | What it does |
|---------|--------------|
| **Versioning** | Keep all versions of files |
| **Replication** | Copy data between datacenters |
| **Encryption** | Automatic encryption at rest |
| **Lifecycle Rules** | Auto-delete old data |

**Architecture diagram:**

```
         ┌──────────────────────────────┐
         │            MinIO             │
         │   • Erasure Coding           │
         │   • WORM / Object Locking    │
         │   • Encryption               │
         │   • Replication              │
         └──────────────────────────────┘
              ▲         ▲         ▲
              │         │         │
           Spark     MLflow    Apps
```

**What to say:**

> "MinIO is free, runs on your servers, and your data stays under your control."

> "Any questions?"

---

## Time Breakdown

| Part | Content | Time |
|------|---------|------|
| 1 | MinIO Console quick tour | 1 min |
| 2 | Erasure Coding demo | 5 min |
| 3 | WORM / Object Locking demo | 2 min |
| 4 | Wrap up | 2 min |
| **Total** | | **10 min** |

---

## Cleanup After Demo

```bash
docker compose -f docker-compose.erasure.yml down
rm -rf ./data
mc alias rm erasure-demo
```

---

## Tips

- **Have terminal with large font** - everyone should see the commands
- **Copy-paste from COMMANDS.md** - avoid typos
- **Key messages:**
  - Erasure Coding: "Lost 2 disks, data still works"
  - WORM: "Even admin cannot delete"
