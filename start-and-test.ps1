[CmdletBinding()]
param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 4000,
    [int]$TimeoutSec = 60
)

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartPs = Join-Path $Root "start.ps1"
$TestPs  = Join-Path $Root "test.ps1"
$BaseUrl = "http://$HostAddress`:$Port"

# --- Launch proxy in a new window ---
Write-Host ""
Write-Host "Starting proxy in background window..." -ForegroundColor Cyan
$proxyJob = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$StartPs`" -HostAddress $HostAddress -Port $Port" -PassThru

# --- Wait until proxy is ready ---
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
