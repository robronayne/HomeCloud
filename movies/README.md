# Media Stack - Emby + Arr Suite

Self-hosted media server with automated library management and privacy-focused download client.

> **⚠️ Legal Notice**  
> This stack is designed for managing legally obtained media content. Users must ensure compliance with all applicable copyright laws and terms of service. Legitimate use cases include:
> - Managing personal media collections (home videos, purchased content)
> - Downloading content from legal sources (public domain, Creative Commons)
> - Organizing media you own physical copies of
> - Accessing content through legitimate subscription services
>
> The VPN component is provided for privacy protection, not to facilitate illegal activity.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         REQUEST FLOW                                 │
└──────────────────────────────────────────────────────────────────────┘

    User Request        Ombi          Sonarr/Radarr      Prowlarr
    "Add to     ──►  (Request   ──►  (Library      ──►  (Searches
     library"         Manager)        Management)        Sources)
                                           │
                                           ▼
                                    ┌─────────────┐
                                    │  Gluetun    │◄── ProtonVPN
                                    │  (VPN)      │
                                    └──────┬──────┘
                                           │
                                    ┌──────▼──────┐
                                    │ qBittorrent │
                                    │ (Downloads) │
                                    └──────┬──────┘
                                           │
                                           ▼
                                    D:/movies or D:/tv
                                           │
                                           ▼
                                    ┌─────────────┐
                                    │    Emby     │
                                    │   :8096     │
                                    └─────────────┘
```

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Emby | 8096 | Media server |
| Ombi | 5000 | Request manager |
| Sonarr | 8989 | TV show library manager |
| Radarr | 7878 | Movie library manager |
| Prowlarr | 9696 | Indexer/source manager |
| qBittorrent | 8080 | Download client (BitTorrent) |

## Setup

1. Copy `.env.example` to `.env` and add ProtonVPN OpenVPN credentials
2. Create downloads directory: `New-Item -ItemType Directory -Force -Path "D:\downloads"`
3. Start: `docker compose up -d`

## Configuration Guide

### Step 1: Emby - Media Server

1. Open http://localhost:8096
2. Complete the setup wizard:
   - Select language
   - Create admin account (username/password)
   - Skip library setup for now (we'll add after downloads work)
3. **Settings** → **Advanced** → **API Keys**
4. Click **+ New API Key** → Name it `Ombi` → Copy the key (save for later)

### Step 2: qBittorrent - Download Client

1. Open http://localhost:8080
2. Check container logs for temporary password:
   ```powershell
   docker logs qbittorrent --tail 20
   ```
3. Look for: `The WebUI administrator password... temporary password is: XXXXXX`
4. Login with **admin** / **[temp password]**
5. **Change password immediately**: Options → Web UI → Authentication → Save

### Step 3: Prowlarr - Configure Indexers

1. Open http://localhost:9696
2. Go to **Indexers** → **Add Indexer**
3. Configure indexers for your legal content sources
4. Examples of legitimate indexers:
   - Public domain content repositories
   - Creative Commons media libraries
   - Legal torrent distributions (Linux ISOs, open source software, etc.)
5. Click **Test All** to verify connectivity

### Step 4: Sonarr - TV Show Library Manager

1. Open http://localhost:8989
2. **Settings** → **General** → Copy **API Key** (save for later)
3. If it says "restart required", run: `docker restart sonarr`
4. **Settings** → **Download Clients** → **+ Add** → **qBittorrent**:
   - Host: `gluetun`
   - Port: `8080`
   - Username: `admin`
   - Password: (your qBittorrent password)
   - Category: `tv-sonarr`
   - Click **Test** → **Save**
5. **Settings** → **Media Management** → **Root Folders**
6. **Add Root Folder** → Enter: `/tv` → **Save**

### Step 5: Radarr - Movie Library Manager

1. Open http://localhost:7878
2. **Settings** → **General** → Copy **API Key** (save for later)
3. If it says "restart required", run: `docker restart radarr`
4. **Settings** → **Download Clients** → **+ Add** → **qBittorrent**:
   - Host: `gluetun`
   - Port: `8080`
   - Username: `admin`
   - Password: (your qBittorrent password)
   - Category: `movies-radarr`
   - Click **Test** → **Save**
5. **Settings** → **Media Management** → **Root Folders**
6. **Add Root Folder** → Enter: `/movies` → **Save**

> **Note:** Use `gluetun` as host since qBittorrent uses Gluetun's network

### Step 6: Prowlarr - Connect to Sonarr/Radarr

**In Prowlarr (http://localhost:9696):**

1. **Settings** → **Apps** → **+ Add Application**
2. Select **Sonarr**:
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr Server: `http://sonarr:8989`
   - API Key: (paste Sonarr's API key)
   - Click **Test** → **Save**
3. Click **+ Add Application** again
4. Select **Radarr**:
   - Prowlarr Server: `http://prowlarr:9696`
   - Radarr Server: `http://radarr:7878`
   - API Key: (paste Radarr's API key)
   - Click **Test** → **Save**

> **Note:** Use container names (`sonarr`, `radarr`, `prowlarr`), not `localhost`

### Step 7: Ombi - Request Manager

1. Open http://localhost:5000
2. Complete setup wizard (use SQLite)
3. **Settings** → **Media Server** → **Emby**:
   - Hostname: `emby`
   - Port: `8096`
   - API Key: (Emby API key from Step 1)
   - Click **Test** → **Load Libraries** → **Save**
4. **Settings** → **TV** → **Sonarr**:
   - Enable: ✓
   - Hostname: `sonarr`
   - Port: `8989`
   - API Key: (Sonarr's API key)
   - Root Path: `/tv`
   - Click **Test** → **Save**
5. **Settings** → **Movies** → **Radarr**:
   - Enable: ✓
   - Hostname: `radarr`
   - Port: `7878`
   - API Key: (Radarr's API key)
   - Root Path: `/movies`
   - Click **Test** → **Save**

### Step 8: Emby - Add Libraries

1. Open http://localhost:8096
2. **Settings** → **Library** → **Add Media Library**
3. Add **Movies**:
   - Content type: Movies
   - Folders: `/mnt/movies`
   - Save
4. Add **TV Shows**:
   - Content type: TV Shows
   - Folders: `/mnt/tv`
   - Save

### Step 9: Test the System

1. In Ombi, search for content in your library
2. Click **Request** to add to your collection
3. Check Radarr/Sonarr for the new entry
4. Monitor the download progress in qBittorrent (http://localhost:8080)
5. Once complete, content appears in Emby for streaming

## Storage

- **Movies**: `D:/movies`
- **TV Shows**: `D:/tv`
- **Downloads**: `D:/downloads`
- **Config**: `./` (local to this directory)
