param (
    [switch]$StartContainers = $false,
    [switch]$Push = $false
)

. .\helpers.ps1

if ([string]::isNullOrWhitespace($Env:IMAGE_NAME)) {
    $Env:IMAGE_NAME = "traefik-with-plugins:latest"
}

# Ensure we are in Windows containers
if (-not(Test-Path $Env:ProgramFiles\Docker\Docker\DockerCli.exe)) {
    Get-Command docker
    Write-Warning "Docker cli not found at $Env:ProgramFiles\Docker\Docker\DockerCli.exe"
}
else {
    Write-Warning "Switching to Linux Engine"
    & $Env:ProgramFiles\Docker\Docker\DockerCli.exe -SwitchLinuxEngine
}

if ($Env:REGISTRY_USER -and $Env:REGISTRY_PWD) {
    Write-Output "Container registry credentials through environment provided."
    docker login "$($Env:REGISTRY_SERVER)" -u="$($Env:REGISTRY_USER)" -p="$($Env:REGISTRY_PWD)"
    ThrowIfError
}

# Core Server, always build as it is a dependency to other images
Write-Output "Building $($Env:IMAGE_NAME)"
docker compose -f compose.yaml build

if ($StartContainers -eq $true) {
    docker compose -f compose.yaml up
}

if ($Push -eq $true) {
    docker push $Env:IMAGE_NAME;
}
