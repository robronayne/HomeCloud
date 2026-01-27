# Immich Photo Backup - Local Primary + Cold Storage

Run [Immich](https://immich.app/) on your computer with D: drive Cloud SSD as primary storage and AWS Glacier Deep Archive for daily disaster recovery backups.

**Cost: ~$0.20/month per 100GB**

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Your Computer (Always On)                                  │
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │  Docker Compose                                    │     │
│  │  ┌──────────┬────────────┬────────┐                │     │
│  │  │ Immich   │ PostgreSQL │ Redis  │                │     │
│  │  │ Server   │ (metadata) │ (cache)│                │     │
│  │  │ :2283    │            │        │                │     │
│  │  └──────────┴────────────┴────────┘                │     │
│  │                                                    │     │
│  │  S3 Sync (daily cold storage backup)               │     │
│  └────────────────────────────────────────────────────┘     │
│                                                             │
│  D: DRIVE - CLOUD SSD (PRIMARY STORAGE)                     │
│  └── D:\immich\upload  ← All photos stored here             │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           │ Daily backup (every 24 hours)
                           ▼
    ┌──────────────────────────────────────────────────────────┐
    │                   AWS COLD STORAGE                       │
    │                                                          │
    │   Cold Storage 1              Cold Storage 2             │
    │   (us-west-1)                 (us-west-2)                │
    │   ┌─────────────────┐        ┌─────────────────┐         │
    │   │ Glacier Deep    │        │ Glacier Deep    │         │
    │   │ Archive         │        │ Archive         │         │
    │   │ $0.00099/GB/mo  │        │ $0.00099/GB/mo  │         │
    │   └─────────────────┘        └─────────────────┘         │
    │                                                          │
    │   Both buckets synced daily from local                   │
    └──────────────────────────────────────────────────────────┘
```

### Upload & Sync Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                        UPLOAD & SYNC FLOW                            │
└──────────────────────────────────────────────────────────────────────┘

  📱 Phone                🖥️  Your Computer              ☁️  AWS Cloud
  ─────                   ─────────────────              ──────────────

    │                           │                              │
    │  1. Upload photos         │                              │
    │  via Immich app           │                              │
    ├──────────────────────────▶│                              │
    │                           │                              │
    │                      ┌────▼─────┐                        │
    │                      │  Immich  │                        │
    │                      │  Server  │                        │
    │                      └────┬─────┘                        │
    │                           │                              │
    │                      ┌────▼─────────┐                    │
    │                      │ D: DRIVE     │                    │
    │                      │ (Cloud SSD)  │                    │
    │                      └────┬─────────┘                    │
    │                           │                              │
    │                           │  2. Daily backup             │
    │                      ┌────▼─────┐                        │
    │                      │ s3-sync  │                        │
    │                      │container │                        │
    │                      └────┬─────┘                        │
    │                           │                              │
    │                           │  aws s3 sync (DEEP_ARCHIVE)  │
    │                           ├─────────────────────────────▶│
    │                           │                         ┌────▼────────┐
    │                           │                         │Cold Storage │
    │                           │                         │  Bucket 1   │
    │                           │                         │ (us-west-1) │
    │                           │                         │Deep Archive │
    │                           │                         └─────────────┘
    │                           │                              │
    │                           ├─────────────────────────────▶│
    │                           │                         ┌────▼────────┐
    │                           │                         │Cold Storage │
    │                           │                         │  Bucket 2   │
    │                           │                         │ (us-west-2) │
    │                           │                         │Deep Archive │
    │                           │                         └─────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  KEY POINTS:                                                         │
│  • Photos + database stored on D: drive (Cloud SSD)              │
│  • Daily backup to Glacier Deep Archive (2 regions)                │
│  • Max data loss: 24 hours (time between daily backups)             │
│  • Restore time: 12-48 hours (Glacier retrieval)                     │
└──────────────────────────────────────────────────────────────────────┘
```

### Cost Breakdown

| Component | Cost/Month |
|-----------|------------|
| Local SSD (100GB) | $0.00 |
| Glacier Deep Archive (100GB x 2 regions) | $0.20 |
| **Total** | **~$0.20** |

---

## Quick Start

### Prerequisites

```bash
# macOS
brew install awscli terraform docker

# Windows (run as Administrator in PowerShell)
winget install Amazon.AWSCLI HashiCorp.Terraform Docker.DockerDesktop

# Configure AWS
aws configure
```

### Step 1: Deploy AWS Infrastructure

```bash
# macOS/Linux                          # Windows (PowerShell)
cd photos/terraform                    cd photos\terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply                        # Type 'yes' to confirm
```

Save the output - you'll need it for Step 2.

### Step 2: Configure Docker

```bash
# macOS/Linux                          # Windows (PowerShell)
cd ../docker                           cd ..\docker
cp .env.example .env                   copy .env.example .env
```

Edit `.env` and fill in:
```bash
DB_PASSWORD=<generate with: openssl rand -base64 32>
AWS_ACCESS_KEY_ID=<from terraform output>
AWS_SECRET_ACCESS_KEY=<from: terraform output -raw aws_secret_access_key>
AWS_REGION_1=<from terraform output region_1>
S3_BUCKET_1=<from terraform output s3_cold_storage_1>
AWS_REGION_2=<from terraform output region_2>
S3_BUCKET_2=<from terraform output s3_cold_storage_2>
```

### Step 3: Start Immich

```bash
docker compose up -d
```

Open http://localhost:2283 and create your admin account.

---

## Essential Commands

| Action | macOS/Linux | Windows (PowerShell) |
|--------|-------------|----------------------|
| **Start** | `docker compose up -d` | `docker compose up -d` |
| **Stop** | `docker compose down` | `docker compose down` |
| **View logs** | `docker compose logs -f` | `docker compose logs -f` |
| **Restart** | `docker compose restart` | `docker compose restart` |
| **Force backup now** | `docker compose restart s3-sync` | `docker compose restart s3-sync` |
| **Check status** | `docker compose ps` | `docker compose ps` |
| **Find local IP** | `ipconfig getifaddr en0` | `ipconfig` (look for IPv4) |

---

## Mobile App Setup

1. Install **Immich** app on iPhone/Android
2. Server URL: `http://YOUR_COMPUTER_IP:2283`
3. Create account and enable auto-backup

**Find your IP:**
```bash
# macOS                                # Windows
ipconfig getifaddr en0                 ipconfig | findstr IPv4
```

---

## Disaster Recovery

### If Your SSD Fails

**Step 1: Initiate Glacier Restore (via AWS Console - easier)**
1. Go to S3 Console → Your bucket
2. Select all files in `upload/` folder
3. Actions → Initiate Restore → Choose "Bulk" (12-48 hrs, cheapest)

**Step 2: Download After Restore Completes**
```bash
# macOS/Linux
aws s3 sync s3://YOUR_BUCKET/upload /path/to/new/ssd/upload

# Windows (to D: drive Cloud SSD)
aws s3 sync s3://YOUR_BUCKET/upload D:\immich\upload
```

**Step 3: Update docker-compose.yml volume path and restart**
```bash
docker compose up -d
```

### Restore Costs

| Tier | Time | Cost (100GB) |
|------|------|--------------|
| **Bulk** | 12-48 hrs | ~$0.25 |
| **Standard** | 3-5 hrs | ~$2.00 |

---

## Troubleshooting

```bash
# Check logs for errors
docker compose logs -f immich-server
docker compose logs -f s3-sync

# Verify backup integrity
aws s3 ls s3://YOUR_BUCKET/upload/ --recursive --summarize
```

---

## Cleanup

```bash
# Stop Immich (keep data)
docker compose down

# Delete AWS resources (WARNING: deletes all cloud backups!)
cd ../terraform && terraform destroy
```

---

## Resources

- [Immich Documentation](https://immich.app/docs)
- [AWS S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [Tailscale](https://tailscale.com/) - Remote access
