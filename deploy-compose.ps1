$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\fridge_inventory.json")) {
    "[]" | Set-Content -Path ".\fridge_inventory.json" -Encoding UTF8
}

if (-not (Test-Path ".\daily_advice_cache.json")) {
    "{}" | Set-Content -Path ".\daily_advice_cache.json" -Encoding UTF8
}

if (-not (Test-Path ".\.env")) {
    Write-Warning ".env not found; using shell environment variables only."
}

Write-Host "Starting service with Docker Compose..."
docker compose up -d --build
Write-Host "Service started. Open http://localhost:5000"
