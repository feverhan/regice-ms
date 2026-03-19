$ErrorActionPreference = "Stop"

$ContainerName = "fridge-inventory"
$ImageName = "fridge-inventory:latest"
$Port = if ($env:APP_PORT) { $env:APP_PORT } else { "5000" }
$DataFile = Join-Path $PWD "fridge_inventory.json"

if (-not (Test-Path $DataFile)) {
    "[]" | Set-Content -Path $DataFile -Encoding UTF8
}

$existing = podman container exists $ContainerName
if ($LASTEXITCODE -eq 0) {
    Write-Host "Removing existing container: $ContainerName"
    podman rm -f $ContainerName | Out-Null
}

Write-Host "Building image..."
podman build -t $ImageName .

Write-Host "Starting container with Podman..."
podman run -d `
  --name $ContainerName `
  -p "${Port}:5000" `
  -v "${DataFile}:/app/fridge_inventory.json" `
  --restart unless-stopped `
  $ImageName | Out-Null

Write-Host "Service started. Open http://localhost:$Port"
