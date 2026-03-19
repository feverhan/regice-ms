$ErrorActionPreference = "Stop"

$ImageName = if ($args.Length -gt 0 -and $args[0]) { $args[0] } else { "fridge-inventory:latest" }

Write-Host "Building Docker image: $ImageName"
docker build -t $ImageName .
Write-Host "Build complete."
