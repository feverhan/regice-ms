$ErrorActionPreference = "Stop"

$ContainerName = "regice-ms"
$ImageName = "regice-ms:latest"
$Port = if ($env:APP_PORT) { $env:APP_PORT } else { "5000" }
$DataFile = Join-Path $PWD "fridge_inventory.json"
$AdviceCacheFile = Join-Path $PWD "daily_advice_cache.json"
$EnvFile = Join-Path $PWD ".env"

if (-not (Test-Path $DataFile)) {
    "[]" | Set-Content -Path $DataFile -Encoding UTF8
}

if (-not (Test-Path $AdviceCacheFile)) {
    "{}" | Set-Content -Path $AdviceCacheFile -Encoding UTF8
}

if (Test-Path $EnvFile) {
    $AppPortLine = Get-Content $EnvFile | Where-Object { $_ -match '^APP_PORT=' } | Select-Object -First 1
    if ($AppPortLine) {
        $Port = ($AppPortLine -split '=', 2)[1].Trim()
    }
}

$existing = podman container exists $ContainerName
if ($LASTEXITCODE -eq 0) {
    Write-Host "Removing existing container: $ContainerName"
    podman rm -f $ContainerName | Out-Null
}

Write-Host "Building image..."
podman build -t $ImageName .

Write-Host "Starting container with Podman..."
if (Test-Path $EnvFile) {
    Write-Host "Loading env file: $EnvFile"
    $EnvArgs = @("--env-file", $EnvFile)
} else {
    Write-Warning ".env not found; trying to pass through shell environment variables."
    $EnvArgs = @()

    $PassThroughEnvNames = @(
        "QWEN_API_KEY",
        "DASHSCOPE_API_KEY",
        "QWEN_MODEL",
        "QWEN_BASE_URLS",
        "HOST",
        "PORT",
        "FLASK_DEBUG"
    )

    foreach ($Name in $PassThroughEnvNames) {
        $Value = [System.Environment]::GetEnvironmentVariable($Name)
        if ($null -ne $Value -and $Value -ne "") {
            $EnvArgs += @("--env", "${Name}=${Value}")
        }
    }
}

$RunArgs = @(
    "run",
    "-d",
    "--name", $ContainerName,
    "-p", "${Port}:5000",
    "-v", "${DataFile}:/app/fridge_inventory.json",
    "-v", "${AdviceCacheFile}:/app/daily_advice_cache.json",
    "--restart", "unless-stopped"
)
$RunArgs += $EnvArgs
$RunArgs += $ImageName

& podman @RunArgs | Out-Null

Write-Host "Service started. Open http://localhost:$Port"
