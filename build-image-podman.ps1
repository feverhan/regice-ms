$ErrorActionPreference = "Stop"

$ImageName = if ($args.Length -gt 0 -and $args[0]) { $args[0] } else { "regice-ms:latest" }

Write-Host "Building Podman image: $ImageName"
podman build -t $ImageName .
Write-Host "Build complete."
