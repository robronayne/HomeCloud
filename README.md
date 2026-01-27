# HomeCloud

![HomeCloud Logo](HomeCloud.png)

**Self-hosted home cloud solution for cost-effective media management and backups.**

---

## Project Goals

Build a complete home media server and backup solution with minimal monthly costs:

- **Photos & Videos**: D: drive (Cloud SSD) primary + daily cold storage backup (~$0.20/month for 100GB)
- **Movies, TV, Books, Music**: Local storage on 26TB SSD (no cloud costs)
- **Total Cost**: ~$0.20/month (just cold storage backup) vs $10-20/month for commercial services

### Architecture

- **Photos**: D: drive Cloud SSD (primary) + Glacier Deep Archive (daily backup, 2 regions)
- **Everything Else**: 26TB SSD only (movies, TV, books, music - replaceable if lost)
- **Auto-Start**: All services start automatically on Windows boot

---

## Project Structure

```
HomeCloud/
├── photos/                   # Photos & Videos (cold storage backup)
│   ├── terraform/            # AWS S3 infrastructure
│   ├── docker/               # Immich server
│   └── README.md             # Setup guide
│
├── movies/                   # Movies & TV Shows (26TB SSD)
│   ├── docker/               # Emby, Jellyseerr, Sonarr, Radarr
│   └── README.md             # Setup guide
│
├── books/                    # Books & Audiobooks (26TB SSD)
│   ├── docker/               # LazyLibrarian, Calibre
│   └── README.md             # Setup guide
│
├── music/                    # Music (26TB SSD)
│   ├── docker/               # Navidrome
│   └── README.md             # Setup guide
│
├── scripts/                  # Windows startup scripts
│   └── start-all.bat         # Start all Docker containers on boot
│
└── README.md
```

---

## Services

| Category | Service | Purpose | Storage |
|----------|---------|---------|---------|
| **Photos** | Immich | Photo/video backup | D: drive (Cloud SSD) + Glacier (daily backup) |
| **Movies** | Emby | Media server for streaming | 26TB SSD |
| **Movies** | Jellyseerr | Request management | 26TB SSD |
| **Movies** | Sonarr | TV show automation | 26TB SSD |
| **Movies** | Radarr | Movie automation | 26TB SSD |
| **Books** | LazyLibrarian | Book management | 26TB SSD |
| **Books** | Calibre | eBook server | 26TB SSD |
| **Music** | Navidrome | Music streaming | 26TB SSD |

---

## Architecture

```
Windows Computer + D: Drive (Cloud SSD)
───────────────────────────────────────
┌───────────────────────────────────────────┐
│  Docker Containers (Auto-start on boot)   │
│                                           │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
│  │ Immich  │  │  Emby   │  │Navidrome│    │
│  │ Photos  │  │ Movies  │  │  Music  │    │
│  └────┬────┘  └────┬────┘  └────┬────┘    │
│       │            │            │         │
│       │            └─────┬──────┘         │
│       │                  │                │
│       │      D: Drive (Cloud SSD)        │
│       │      D:\immich\upload             │
│       │                                   │
│       │ Monthly Cold Storage Backup       │
│       └──────────────────┐                │
└───────────────────────────────────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ AWS Glacier │
                    │ Deep Archive│
                    │             │
                    │ Bucket 1    │
                    │ us-west-1   │
                    │             │
                    │ Bucket 2    │
                    │ us-west-2   │
                    └─────────────┘
```

**Key Points:**
- D: drive (Cloud SSD) is primary storage for photos at `D:\immich\upload`
- Daily backup to Glacier Deep Archive (photos + database, 2 regions)
- Movies, TV, books, music stored on 26TB SSD only (replaceable content)
- All services auto-start on Windows boot
- Monthly cost: ~$0.20 for 100GB cold storage backup (daily backups)

---

See individual service directories for setup instructions.
