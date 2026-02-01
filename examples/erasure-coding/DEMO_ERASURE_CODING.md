# Erasure Coding Demo Script

## Time: 5 minutes

---

## What is Erasure Coding?

```
Traditional RAID (one server):
┌─────────────────────────────┐
│  [Disk1] [Disk2] [Disk3]    │  ← If server dies = ALL data lost
└─────────────────────────────┘

MinIO Erasure Coding (distributed):
┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐
│Disk 1 │ │Disk 2 │ │Disk 3 │ │Disk 4 │
│ Data  │ │ Data  │ │Parity │ │Parity │
└───────┘ └───────┘ └───────┘ └───────┘
    ↑                   ↑
    └── Can lose up to 2 disks and data is safe!
```

---

## Preparation

```bash
cd examples/erasure-coding
chmod +x demo.sh
```

---

## Demo Steps

### Step 1: Start MinIO with 4 Disks (30 sec)

```bash
./demo.sh start
```

**What to say:**

> "I'm starting MinIO with 4 disks. With 4 disks, MinIO uses Erasure Coding. It splits data into 2 data parts and 2 parity parts."

---

### Step 2: Show Configuration (30 sec)

```bash
./demo.sh info
```

**What to say:**

> "With 4 disks, we can lose up to 2 disks and still access our data. This is because MinIO calculates parity information."

---

### Step 3: Upload Test Files (30 sec)

```bash
./demo.sh upload
```

**What to say:**

> "Now I upload 3 files to MinIO. MinIO will split each file and distribute across all 4 disks."

---

### Step 4: Show Disk Distribution (30 sec)

```bash
./demo.sh show-disks
```

**What to say:**

> "Look: the data is distributed across all disks. No single disk has the complete file. This is the key to data protection."

---

### Step 5: Simulate First Disk Failure (1 min)

```bash
./demo.sh fail-disk 1
```

**What to say:**

> "Now I will simulate a disk failure. I'm deleting all data from Disk 1."

```bash
./demo.sh verify
```

**What to say:**

> "The data is STILL accessible! MinIO reconstructs the missing parts using the parity information from other disks."

---

### Step 6: Simulate Second Disk Failure (1 min)

```bash
./demo.sh fail-two
```

**What to say:**

> "Now let's be more aggressive. I will delete TWO disks - Disk 1 and Disk 2."

```bash
./demo.sh verify
```

**What to say:**

> "Amazing! The data is STILL accessible! With 4 disks and EC:2, we can lose half of our disks and data survives."

---

### Step 7: Wrap Up (30 sec)

**What to say:**

> "This is Erasure Coding. No special hardware needed. No RAID controller. Works across multiple servers. In production, you can have 16 disks and lose up to 8. This is how MinIO protects your data at scale."

---

## Cleanup

```bash
./demo.sh clean
```

---

## Quick Reference

| Disks | Data Shards | Parity Shards | Max Failures | Efficiency |
|-------|-------------|---------------|--------------|------------|
| 4     | 2           | 2             | 2            | 50%        |
| 8     | 4           | 4             | 4            | 50%        |
| 16    | 12          | 4             | 4            | 75%        |

---

## If Something Goes Wrong

If MinIO doesn't start properly:

```bash
./demo.sh clean
./demo.sh start
```

If `mc` command not found:

```bash
# macOS
brew install minio/stable/mc

# Linux
curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
```

---

## Architecture

```
docker-compose.erasure.yml creates:

┌─────────────────────────────────────────────┐
│           MinIO Container                    │
│                                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│  │ /data1  │ │ /data2  │ │ /data3  │ │ /data4  │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘
└───────┼──────────┼──────────┼──────────┼────┘
        │          │          │          │
   ┌────▼────┐┌────▼────┐┌────▼────┐┌────▼────┐
   │ disk1/  ││ disk2/  ││ disk3/  ││ disk4/  │
   │(volume) ││(volume) ││(volume) ││(volume) │
   └─────────┘└─────────┘└─────────┘└─────────┘

When we delete disk1/ folder, we simulate a disk failure.
MinIO detects the missing disk and reconstructs data on read.
```
