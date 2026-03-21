$ErrorActionPreference = "Stop"

$ImageName = if ($args.Length -gt 0 -and $args[0]) { $args[0] } else { "crpi-7ove6igc635triub.cn-shanghai.personal.cr.aliyuncs.com/hanqw_ztt/regice_ms:latest" }

Write-Host "Building Docker image: $ImageName"
docker build -t $ImageName .
Write-Host "Build complete."
