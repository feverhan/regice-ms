$ErrorActionPreference = "Stop"

$Repo = "hanqw/regice-ms"
$Version = if ($args.Length -gt 0 -and $args[0]) { $args[0] } else { (Get-Date -Format "yyyyMMddHHmmss") }
$LatestTag = "$Repo`:latest"
$VersionTag = "$Repo`:$Version"

Write-Host "Building Docker image: $LatestTag"
docker build -t $LatestTag .

Write-Host "Tagging version image: $VersionTag"
docker tag $LatestTag $VersionTag

Write-Host "Pushing image: $LatestTag"
docker push $LatestTag

Write-Host "Pushing image: $VersionTag"
docker push $VersionTag

Write-Host "Build and push complete."
Write-Host "Published tags: $LatestTag, $VersionTag"
