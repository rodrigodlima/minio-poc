# MinIO - Advanced Features

---

## Erasure Coding

```
With 4 disks:
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│Disk 1│ │Disk 2│ │Disk 3│ │Disk 4│
│ Data │ │ Data │ │Parity│ │Parity│
└──────┘ └──────┘ └──────┘ └──────┘

We can lose up to 2 disks!
```

---

## OpenSearch - Log Indexing

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌────────────┐
│  Go API │────▶│  MinIO  │────▶│ Webhook │────▶│ OpenSearch │
│  :8080  │     │  :9000  │     │  :8081  │     │   :9200    │
└─────────┘     └─────────┘     └─────────┘     └────────────┘
                     │
              Event Notification
```

---

## MinIO Ecosystem

```
         ┌──────────────────────────────────┐
         │              MinIO               │
         │   • Erasure Coding               │
         │   • WORM / Object Locking        │
         │   • Event Notifications          │
         │   • Encryption / Replication     │
         └──────────────────────────────────┘
              ▲         ▲         ▲         ▲
              │         │         │         │
           Spark     MLflow    Apps    OpenSearch
```
