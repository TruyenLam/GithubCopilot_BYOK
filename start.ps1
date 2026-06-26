[CmdletBinding()]
param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 4000
)

$ErrorActionPreference = "Stop"
$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$LiteLlm = Join-Path $Root ".venv\Scripts\litellm.exe"
$Config  = Join-Path $Root "config.yaml"
$EnvFile = Join-Path $Root ".env"

if (-not (Test-Path -LiteralPath $LiteLlm)) {
    throw "LiteLLM not found. Install it with: .\.venv\Scripts\python.exe -m pip install `"litellm[proxy]`""
}
if (-not (Test-Path -LiteralPath $Config)) {
    throw "config.yaml not found at $Config"
}
if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw ".env not found. Copy .env.example to .env and fill in your API keys."
}

# --- Parse .env ---
$envData = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#')) {
        $parts = $line -split '=', 2
        if ($parts.Count -eq 2) {
            $envData[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
}

# --- Build profile list dynamically ---
$profiles = @()
$i = 1
while ($true) {
    $label  = $envData["PROFILE_${i}_LABEL"]
    $envVar = $envData["PROFILE_${i}_ENV_VAR"]
    $key    = $envData["PROFILE_${i}_KEY"]
    if (-not $label) { break }

    $missing = (-not $key) -or ($key -match '^your-|^sk-your-')
    $profiles += [PSCustomObject]@{
        Label   = if ($missing) { "$label  [KEY NOT SET]" } else { $label }
        EnvVar  = $envVar
        Key     = if ($missing) { "" } else { $key }
    }
    $i++
}

if ($profiles.Count -eq 0) {
    throw "No profiles found in .env. Add PROFILE_1_LABEL / PROFILE_1_ENV_VAR / PROFILE_1_KEY."
}

# --- Show menu ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   LiteLLM BYOK - Select Provider/Key  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
for ($j = 0; $j -lt $profiles.Count; $j++) {
    Write-Host ("  {0}) {1}" -f ($j + 1), $profiles[$j].Label)
}
Write-Host ""

$choice = $null
while ($null -eq $choice) {
    $input = Read-Host "Enter number (1-$($profiles.Count))"
    if ($input -match '^\d+$') {
        $idx = [int]$input - 1
        if ($idx -ge 0 -and $idx -lt $profiles.Count) {
            $choice = $profiles[$idx]
        }
    }
    if ($null -eq $choice) {
        Write-Host "Invalid selection, please try again." -ForegroundColor Yellow
    }
}

if (-not $choice.Key) {
    throw "Profile '$($choice.Label)' has no API key set. Edit .env and fill in the key."
}

# --- Set environment variables ---
[System.Environment]::SetEnvironmentVariable($choice.EnvVar, $choice.Key, "Process")
$env:LITELLM_MASTER_KEY      = $envData["LITELLM_MASTER_KEY"]
$env:PYTHONUTF8              = "1"
$env:PYTHONIOENCODING        = "utf-8"
$env:PYTHON_DOTENV_DISABLED  = "1"
Remove-Item Env:DATABASE_URL              -ErrorAction SilentlyContinue
Remove-Item Env:DIRECT_URL                -ErrorAction SilentlyContinue
Remove-Item Env:DATABASE_URL_READ_REPLICA -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Selected : $($choice.Label)"  -ForegroundColor Green
Write-Host "Env var  : $($choice.EnvVar)" -ForegroundColor Green
Write-Host "Proxy    : http://$HostAddress`:$Port" -ForegroundColor Green
Write-Host ""

& $LiteLlm --config $Config --host $HostAddress --port $Port
