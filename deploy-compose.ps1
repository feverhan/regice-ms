$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\fridge_inventory.json")) {
    "[]" | Set-Content -Path ".\fridge_inventory.json" -Encoding UTF8
}

Write-Host "Starting service with Docker Compose..."
docker compose up -d --build
Write-Host "Service started. Open http://localhost:5000"
