[CmdletBinding()]
param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 4000,
    [int]$TimeoutSec = 60
)

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $Root ".env"
$StartPs = Join-Path $Root "start.ps1"
$TestPs  = Join-Path $Root "test.ps1"
$BaseUrl = "http://$HostAddress`:$Port"

if (-not (Test-Path $EnvFile)) {
    throw ".env not found. Copy .env.example to .env and fill in your API keys."
}

# --- Parse .env to build profile list for menu ---
$envData = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#')) {
        $parts = $line -split '=', 2
        if ($parts.Count -eq 2) { $envData[$parts[0].Trim()] = $parts[1].Trim() }
    }
}

$profiles = @()
$i = 1
while ($true) {
    $label = $envData["PROFILE_${i}_LABEL"]
    if (-not $label) { break }
    $key     = $envData["PROFILE_${i}_KEY"]
    $missing = (-not $key) -or ($key -match '^your-|^sk-your-')
    $profiles += [PSCustomObject]@{
        Label = if ($missing) { "$label  [KEY NOT SET]" } else { $label }
    }
    $i++
}

# --- Show menu and get selection here (before launching proxy) ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   LiteLLM BYOK - Select Provider/Key  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  0) ALL providers (use all keys at once)" -ForegroundColor Yellow
for ($j = 0; $j -lt $profiles.Count; $j++) {
    Write-Host ("  {0}) {1}" -f ($j + 1), $profiles[$j].Label)
}
Write-Host ""

$autoProfile = $null
while ($null -eq $autoProfile) {
    $input = Read-Host "Enter number (0 = all, 1-$($profiles.Count) = single)"
    if ($input -match '^\d+$') {
        $idx = [int]$input
        if ($idx -ge 0 -and $idx -le $profiles.Count) {
            $autoProfile = $idx
        }
    }
    if ($null -eq $autoProfile) {
        Write-Host "Invalid selection, please try again." -ForegroundColor Yellow
    }
}

# --- Launch proxy non-interactively in a new window ---
Write-Host ""
Write-Host "Starting proxy in background window..." -ForegroundColor Cyan
Start-Process powershell.exe -ArgumentList (
    "-NoProfile -ExecutionPolicy Bypass -File `"$StartPs`"",
    "-HostAddress $HostAddress -Port $Port -AutoProfile $autoProfile"
)

# --- Poll /health until proxy is ready ---
Write-Host "Waiting for proxy at $BaseUrl" -NoNewline
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$ready    = $false
while ((Get-Date) -lt $deadline) {
    try {
        $null = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 2 -ErrorAction Stop
        $ready = $true
        break
    } catch {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
    }
}
Write-Host ""

if (-not $ready) {
    Write-Host "ERROR: Proxy did not start within ${TimeoutSec}s." -ForegroundColor Red
    exit 1
}

Write-Host "Proxy is ready." -ForegroundColor Green
Write-Host ""

# --- Run tests ---
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TestPs -HostAddress $HostAddress -Port $Port
