# MinIO - Object Locking (WORM)

## Ransomware Protection & Compliance

---

## What is WORM?

```
WORM = Write Once Read Many

┌─────────────────────────────────────────────────────┐
│  Data written CANNOT be:                            │
│    ✗ Modified                                       │
│    ✗ Deleted (not even by admin!)                   │
│                                                     │
│  Until the retention period expires                 │
└─────────────────────────────────────────────────────┘
```

---

## Why does it matter?

```
┌─────────────────────────────────────────────────────┐
│  PROTECTION AGAINST:                                │
│                                                     │
│    🛡️  Ransomware attacks                           │
│    🛡️  Accidental deletion                          │
│    🛡️  Malicious insiders                           │
│    🛡️  Administrator mistakes                       │
│                                                     │
│  COMPLIANCE:                                        │
│    ✓ GDPR    ✓ SOX    ✓ HIPAA    ✓ SEC 17a-4       │
└─────────────────────────────────────────────────────┘
```

---

## Two Retention Modes

```
┌─────────────────────────────────────────────────────┐
│  COMPLIANCE MODE                                    │
│    • Nobody can delete (not even root/support)      │
│    • Required for legal/regulatory requirements     │
│    • Use for: audit logs, legal records             │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  GOVERNANCE MODE                                    │
│    • Special "break-glass" account CAN bypass       │
│    • Requires: s3:BypassGovernanceRetention + MFA   │
│    • Use for: ransomware protection, backups        │
└─────────────────────────────────────────────────────┘
```

---

## Why attackers can't bypass GOVERNANCE?

```
┌─────────────────────────────────────────────────────┐
│  Regular Admin (compromised by attacker)            │
│    ✓ s3:GetObject                                   │
│    ✓ s3:PutObject                                   │
│    ✓ s3:DeleteObject                                │
│    ✗ s3:BypassGovernanceRetention  ← DENIED         │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Break-glass Account (secured)                      │
│    • MFA required                                   │
│    • Credentials in secure vault                    │
│    • Multi-person approval                          │
│    ✓ s3:BypassGovernanceRetention  ← ONLY HERE     │
└─────────────────────────────────────────────────────┘
```

---

# LIVE DEMO

---

## Pre-requisite (run before presentation)

```bash
cd examples/erasure-coding
docker compose -f docker-compose.erasure.yml up -d
sleep 5
mc alias set demo http://localhost:9090 minio minio123
echo "FINANCIAL BACKUP - Revenue: 15M" > /tmp/backup.txt
```

---

```bash
mc mb demo/critical-backup --with-lock
```

```bash
mc retention set --default COMPLIANCE "1d" demo/critical-backup
```

---

```bash
mc cp /tmp/backup.txt demo/critical-backup/
```

---

```bash
mc rm --versions --force demo/critical-backup/backup.txt
```





> **Say:** "Let's simulate an attacker who obtained ADMIN credentials trying to permanently delete all backups..."

**Expected result:** ❌ ERROR - `Object is WORM protected and cannot be overwritten`

---

## STEP 4: Verify data is intact

```bash
mc cat demo/critical-backup/backup.txt
```

> **Say:** "Even with administrator access and using force delete, the attacker COULD NOT delete the data. Data is 100% intact!"

---

## STEP 5: Check retention status (optional)

```bash
mc retention info demo/critical-backup/backup.txt
```

---

## Best Practices

```
┌─────────────────────────────────────────────────────┐
│  Recommended Strategy:                              │
│                                                     │
│  daily-backup     → GOVERNANCE, 30 days             │
│  monthly-backup   → GOVERNANCE, 1 year              │
│  compliance-audit → COMPLIANCE, 7 years             │
│                                                     │
│  Tip: Use GOVERNANCE for flexibility +              │
│       ransomware protection (attacker won't have    │
│       BypassGovernanceRetention permission)         │
└─────────────────────────────────────────────────────┘
```

---

## Summary

```
┌─────────────────────────────────────────────────────┐
│  MinIO Object Locking                               │
│                                                     │
│  ✓ Guaranteed immutability                          │
│  ✓ Ransomware protection                            │
│  ✓ Compliance (GDPR, SOX, HIPAA)                    │
│  ✓ Two modes: COMPLIANCE & GOVERNANCE               │
│  ✓ Much lower cost than enterprise solutions        │
│  ✓ 100% S3-compatible API                           │
└─────────────────────────────────────────────────────┘
```

---

## Cleanup (after demo)

```bash
docker compose -f docker-compose.erasure.yml down -v
rm -rf data/
```
