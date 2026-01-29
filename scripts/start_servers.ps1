# ============================
# Start HomeCloud Services
# ============================

# Path to Docker Desktop executable
$dockerDesktopPath = "$Env:ProgramFiles\Docker\Docker\Docker Desktop.exe"

# Launch Docker Desktop if it's not already running
if (-not (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue)) {
    Write-Output "Starting Docker Desktop..."
    Start-Process -FilePath $dockerDesktopPath
    Write-Output "Waiting 30 seconds for Docker Desktop to initialize..."
    Start-Sleep -Seconds 30
} else {
    Write-Output "Docker Desktop is already running."
}

# Start Emby (Movies Service)
Write-Output "`nStarting Emby container..."
Set-Location "C:\Users\Rob\Desktop\HomeCloud\movies"
docker compose up -d
if ($LASTEXITCODE -eq 0) {
    Write-Output "✓ Emby container started successfully."
} else {
    Write-Output "✗ Failed to start Emby container."
}

# Start Immich (Photos Service)
Write-Output "`nStarting Immich containers..."
Set-Location "C:\Users\Rob\Desktop\HomeCloud\photos\docker"
docker compose up -d
if ($LASTEXITCODE -eq 0) {
    Write-Output "✓ Immich containers started successfully."
} else {
    Write-Output "✗ Failed to start Immich containers."
}

Write-Output "`nAll HomeCloud services startup complete."
Write-Output "Emby: http://localhost:8096"
Write-Output "Immich: Check your photos docker-compose configuration for port"
