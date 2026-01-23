# Immich Photo Backup - Hybrid Model

Run [Immich](https://immich.app/) on your computer with AWS S3 for cloud storage.

**Cost: ~$1.25/month per 100GB** (just S3 storage fees)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Your Computer (Always On)                                  │
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │  Docker Compose                                    │     │
│  │  ┌──────────┬────────────┬────────────┬────────┐   │     │
│  │  │ Immich   │ Immich ML  │ PostgreSQL │ Redis  │   │     │
│  │  │ Server   │ (AI)       │ (metadata) │ (cache)│   │     │
│  │  │ :2283    │            │            │        │   │     │
│  │  └──────────┴────────────┴────────────┴────────┘   │     │
│  │                                                    │     │
│  │  S3 Sync (monthly + quarterly)                     │     │
│  └────────────────────────────────────────────────────┘     │
│                                                             │
│  Local Storage: thumbnails, database, cache                 │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           │ AWS S3 API
                           ▼
    ┌──────────────────────────────────────────────────────────┐
    │                        AWS                               │
    │                                                          │
    │   Primary Bucket              Backup Bucket              │
    │   (us-west-1)                 (us-west-2)                │
    │   ┌─────────────────┐        ┌─────────────────┐         │
    │   │Monthly backups  │  CRR   │ Auto-replicated │         │
    │   │ Standard-IA     │───────▶│ Deep Archive    │         │
    │   └─────────────────┘ (AWS)  └─────────────────┘         │
    │                                                           │
    │   Immich only syncs here     AWS handles this            │
    └──────────────────────────────────────────────────────────┘
```

### Two-Bucket Architecture Explained

This setup uses **two S3 buckets in different AWS regions** with AWS-managed replication:

#### Primary Bucket (us-west-1 - N. California)
- **Purpose**: Monthly backups from your Immich server
- **Location**: Closest to San Diego for fast uploads
- **Storage**: S3 Standard-IA (infrequent access, cost-optimized)
- **Sync**: Every 30 days from local

#### Backup Bucket (us-west-2 - Oregon)
- **Purpose**: Automatic disaster recovery copy
- **Location**: Different region (survives regional outages)
- **Storage**: Glacier Deep Archive (lowest cost, 12-48hr restore time)
- **Replication**: Automatic via AWS Cross-Region Replication (CRR)

#### Photo Upload & Backup Flow

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
    │                      │ docker/upload│                    │
    │                      │ (local disk) │                    │
    │                      └────┬─────────┘                    │
    │                           │                              │
    │                           │  2. Monthly sync             │
    │                      ┌────▼─────┐                        │
    │                      │ s3-sync  │                        │
    │                      │container │                        │
    │                      └────┬─────┘                        │
    │                           │                              │
    │                           │  aws s3 sync                 │
    │                           ├─────────────────────────────▶│
    │                           │                         ┌────▼────────┐
    │                           │                         │  Primary    │
    │                           │                         │  Bucket     │
    │                           │                         │ (us-west-1) │
    │                           │                         │Standard-IA  │
    │                           │                         └────┬────────┘
    │                           │                              │
    │                           │                              │ AWS CRR
    │                           │                              │ (real-time)
    │                           │                         ┌────▼────────┐
    │                           │                         │  Backup     │
    │                           │                         │  Bucket     │
    │                           │                         │ (us-west-2) │
    │                           │                         │Glacier Deep │
    │                           │                         │  Archive    │
    │                           │                         └─────────────┘
    │                           │                              │
    │                           │                         (AWS managed)

┌──────────────────────────────────────────────────────────────────────┐
│  KEY POINTS:                                                         │
│  • Photos stored locally first (instant access)                      │
│  • Monthly sync to primary bucket (Standard-IA)                      │
│  • Automatic replication to backup (Glacier Deep Archive via CRR)    │
│  • Max data loss: 30 days (time between monthly syncs)               │
└──────────────────────────────────────────────────────────────────────┘
```

#### Disaster Recovery Scenarios

| Scenario | What Happens | Recovery |
|----------|--------------|----------|
| **Primary bucket deleted** | Backup bucket has full copy | Restore from backup bucket |
| **us-west-1 region outage** | Backup in us-west-2 unaffected | Switch to backup bucket |
| **Accidental file delete** | Versioning keeps old versions | Restore previous version |
| **Need old photos (90+ days)** | In Glacier on backup bucket | Initiate restore (12-48 hrs) |

#### Cost Breakdown (100GB example)

| Component | Storage | Cost/Month |
|-----------|---------|------------|
| Primary bucket | 100GB Standard-IA | $1.25 |
| Backup bucket | 100GB Glacier Deep Archive | $0.10 |
| Replication (one-time) | 100GB transfer | $1.00 (one-time) |
| **Total ongoing** | | **~$1.35/month** |

**Cost Savings:**
- Monthly backups: Fewer API calls than daily
- Standard-IA for primary: 46% cheaper than Standard ($1.25 vs $2.30)
- Glacier Deep Archive for backup: 92% cheaper than Standard-IA ($0.10 vs $1.25)
- AWS CRR: Automatic replication included in storage costs
- **Total savings: ~63% vs daily Standard storage**

#### Region Selection Guide

**For Southern California:**
- Primary: `us-west-1` (N. California) - 120ms latency
- Backup: `us-west-2` (Oregon) - 180ms latency

**For other locations:**
- Primary: Closest region to you
- Backup: Different region in same country (for compliance)

**Check latency:** https://www.cloudping.info/

## File Structure

```
immich/
├── terraform/
│   ├── locals.tf              # Local variables
│   ├── s3.tf                  # S3 buckets
│   ├── iam.tf                 # IAM user & credentials
│   ├── variables.tf           # Configuration
│   ├── outputs.tf             # AWS credentials output
│   ├── providers.tf           # AWS provider
│   └── terraform.tfvars.example
├── docker/
│   ├── docker-compose.yml     # Immich services
│   └── .env.example           # Environment template
└── README.md
```

## Quick Start

### Prerequisites

```bash
# macOS
brew install awscli terraform docker

# Linux
sudo apt install awscli terraform docker.io docker-compose

# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret, and region (e.g., us-west-2)
```

### Step 1: Create Terraform Config

```bash
cd immich/terraform

# Create config from example
cp terraform.tfvars.example terraform.tfvars

# Edit if needed (defaults work fine)
nano terraform.tfvars
```

**What you can customize in `terraform.tfvars`:**
- `project_name` - Used in S3 bucket name (default: "immich")
- `aws_region` - Where to create bucket (default: "us-west-2")
- `archive_after_days` - When to move to Glacier (default: 90)

### Step 2: Deploy S3 Storage to AWS

```bash
terraform init
terraform apply
# Type 'yes' to confirm
```

**Save the output** - you'll need it for the next step:
```bash
terraform output
# Shows: aws_access_key_id, s3_bucket, s3_bucket_region
# For secret: terraform output -raw aws_secret_access_key
```

### Step 3: Configure Docker

```bash
cd ../docker

# Create environment file
cp .env.example .env

# Generate secure database password
openssl rand -base64 32
# Copy the output

# Edit .env
nano .env
```

**Fill in `docker/.env`:**
```bash
DB_PASSWORD=<paste generated password>

# From terraform output (step 2):
AWS_ACCESS_KEY_ID=<from terraform output aws_access_key_id>
AWS_SECRET_ACCESS_KEY=<from terraform output -raw aws_secret_access_key>
AWS_REGION=<from terraform output primary_region>
S3_BUCKET=<from terraform output s3_primary_bucket>
```

### Step 4: Start Immich

```bash
# From the immich/ directory
make start

# Or manually:
cd docker && docker compose up -d
```

### Step 5: Access Immich

Open http://localhost:2283
- Create your admin account (first user = admin)
- Configure your mobile app (see below)

### Quick Start Summary

```bash
# One-liner setup (after editing config files)
make setup && make deploy-s3 && make configure-docker && make start
```

## Mobile App Setup

### Automatic Backup (Always Available)

Since your computer runs Immich 24/7:

1. Install **Immich** app on iPhone/Android
2. Server URL: `http://YOUR_COMPUTER_IP:2283`
   - Find your IP: `ifconfig | grep "inet "` (macOS/Linux)
3. Create account or login
4. **Immich backs up automatically when you open the app**

### Find Your Computer's IP

```bash
# macOS
ipconfig getifaddr en0

# Linux  
hostname -I | awk '{print $1}'
```

Your Immich URL will be something like: `http://192.168.1.100:2283`

### For Backup Outside Home Network

Options:
1. **Tailscale** (recommended) - Free VPN, access from anywhere
2. **Port forwarding** - Open port 2283 on router (less secure)
3. **Cloudflare Tunnel** - Free, secure remote access

## Adding More Users

Immich handles multiple users internally - no AWS changes needed!

1. Open Immich web UI: http://localhost:2283
2. Log in as admin (first user created)
3. **Administration → Users → Create User**
4. New user logs in with their credentials

All users share the same S3 bucket - Immich manages permissions internally.

## How S3 Sync Works

The sync is handled by a **separate Docker container** (`s3-sync`), not by Immich or your phone app.


### Component Responsibilities

| Component | What It Does |
|-----------|--------------|
| **Phone app** | Uploads photos to Immich server (instant) |
| **Immich server** | Stores photos in `docker/upload/` folder |
| **s3-sync container** | Monthly sync to primary bucket |
| **AWS S3** | Cloud backup (primary + disaster recovery) |

### Sync Schedule

- **Automatic**: Monthly to primary (AWS handles backup replication)
- **Manual**: Run `make sync-now` to force immediate sync
- **Direction**: One-way (local → S3)

### Check Sync Status

```bash
make logs-sync
# Shows: "Sync complete. Next sync in 30 days."
```

### Why Monthly Instead of Real-Time?

| Benefit | Explanation |
|---------|-------------|
| **Lower costs** | Fewer API calls to S3 |
| **Network friendly** | Syncs during off-hours (2 AM) |
| **Local first** | Photos instantly available in Immich |
| **Batch efficiency** | Single large sync vs many small ones |

## Cost Breakdown

| Resource | Cost |
|----------|------|
| S3 Standard-IA (100GB) | $1.25/month |
| S3 Glacier (after 90 days) | $0.10/month |
| Data transfer (upload) | Free |
| Data transfer (download) | $0.09/GB |
| **Total (100GB)** | **~$1.35/month** |

Your computer's electricity is the only other cost.

## Restoring Photos

### From Local (Fast)
Just browse Immich web UI or app - photos load from local cache + S3.

### From Glacier (12-48 hours)
For photos archived >90 days:
1. AWS Console → S3 → Select files
2. Actions → Initiate Restore
3. Wait 12-48 hours
4. Access in Immich

## Logs

Logs are stored in Docker and accessed via `docker compose logs`. They are **not written to files** - Docker manages them.

### Where Logs Are

| Container | What's Logged | Command |
|-----------|---------------|---------|
| `immich-server` | API requests, uploads, errors | `make logs-server` |
| `immich-machine-learning` | Face detection, AI processing | `docker compose logs immich-machine-learning` |
| `database` | PostgreSQL queries | `make logs-db` |
| `redis` | Cache operations | `docker compose logs redis` |
| `s3-sync` | S3 upload status | `make logs-sync` |

### Log Commands

```bash
# Follow all logs
make logs

# Follow specific service
make logs-server
make logs-sync
make logs-db

# Or directly with docker
cd docker && docker compose logs -f immich-server
```

### Log Retention

Docker keeps logs until containers are removed. To limit log size, add to `docker-compose.yml`:

```yaml
services:
  immich-server:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## Makefile Commands

Run `make help` to see all commands:

```bash
make setup          # Initial setup
make deploy-s3      # Deploy S3 buckets
make start          # Start Immich
make stop           # Stop Immich
make logs           # View all logs
make logs-server    # View Immich logs
make logs-sync      # View S3 sync logs
make backup-db      # Backup database
make sync-now       # Force S3 sync
make status         # Container status
```

## Troubleshooting

### Immich Not Starting
```bash
make logs-server
# Check for errors
```

### S3 Sync Not Working
```bash
make logs-sync
# Verify AWS credentials in docker/.env
```

### Database Issues
```bash
make logs-db
make backup-db  # Backup before any fixes
```

### Restart Everything
```bash
make restart
```

### Database Backup
```bash
make backup-db
# Creates backup_YYYYMMDD_HHMMSS.sql
```

## Cleanup

### Stop Immich (Keep Data)
```bash
cd immich/docker
docker compose down
```

### Delete Everything
```bash
# Delete AWS resources
cd immich/terraform
terraform destroy

# Delete local data
cd ../docker
rm -rf postgres redis upload model-cache
```

**Warning**: `terraform destroy` deletes all S3 photos!

## Resources

- [Immich Documentation](https://immich.app/docs)
- [Immich Mobile App](https://immich.app/docs/features/mobile-app)
- [AWS S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [Tailscale](https://tailscale.com/) - Remote access
