[CmdletBinding()]
param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 4000
)

$ErrorActionPreference = "Stop"
$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$LiteLlm  = Join-Path $Root ".venv\Scripts\litellm.exe"
$Config   = Join-Path $Root "config.yaml"
$EnvFile  = Join-Path $Root ".env"

if (-not (Test-Path -LiteralPath $LiteLlm)) {
    throw "Khong tim thay LiteLLM. Cai dat bang: .\.venv\Scripts\python.exe -m pip install `"litellm[proxy]`""
}
if (-not (Test-Path -LiteralPath $Config)) {
    throw "Khong tim thay config.yaml"
}
if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Khong tim thay .env. Sao chep .env.example thanh .env roi dien key vao."
}

# --- Doc .env ---
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

# --- Xay dung danh sach profiles dong ---
$profiles = @()
$i = 1
while ($true) {
    $label  = $envData["PROFILE_${i}_LABEL"]
    $envVar = $envData["PROFILE_${i}_ENV_VAR"]
    $key    = $envData["PROFILE_${i}_KEY"]
    if (-not $label) { break }
    if ($key -and $key -notmatch '^your-|^sk-your-') {
        $profiles += [PSCustomObject]@{ Label = $label; EnvVar = $envVar; Key = $key }
    } else {
        $profiles += [PSCustomObject]@{ Label = "$label  [CHUA CO KEY]"; EnvVar = $envVar; Key = "" }
    }
    $i++
}

if ($profiles.Count -eq 0) {
    throw "Khong co profile nao trong .env. Them PROFILE_1_LABEL / PROFILE_1_ENV_VAR / PROFILE_1_KEY."
}

# --- Hien thi menu ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   LiteLLM BYOK - Chon Provider / Key  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
for ($j = 0; $j -lt $profiles.Count; $j++) {
    $num = $j + 1
    Write-Host "  $num) $($profiles[$j].Label)"
}
Write-Host ""

$choice = $null
while ($null -eq $choice) {
    $input = Read-Host "Nhap so (1-$($profiles.Count))"
    if ($input -match '^\d+$') {
        $idx = [int]$input - 1
        if ($idx -ge 0 -and $idx -lt $profiles.Count) {
            $choice = $profiles[$idx]
        }
    }
    if ($null -eq $choice) {
        Write-Host "Lua chon khong hop le, thu lai." -ForegroundColor Yellow
    }
}

if (-not $choice.Key) {
    throw "Profile '$($choice.Label)' chua co key. Dien key vao file .env truoc."
}

# --- Set env vars ---
[System.Environment]::SetEnvironmentVariable($choice.EnvVar, $choice.Key, "Process")
$env:LITELLM_MASTER_KEY = $envData["LITELLM_MASTER_KEY"]
$env:PYTHONUTF8          = "1"
$env:PYTHONIOENCODING    = "utf-8"
$env:PYTHON_DOTENV_DISABLED = "1"
Remove-Item Env:DATABASE_URL              -ErrorAction SilentlyContinue
Remove-Item Env:DIRECT_URL                -ErrorAction SilentlyContinue
Remove-Item Env:DATABASE_URL_READ_REPLICA -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=> Da chon : $($choice.Label)" -ForegroundColor Green
Write-Host "=> Bien    : $($choice.EnvVar)" -ForegroundColor Green
Write-Host "=> Proxy   : http://$HostAddress`:$Port" -ForegroundColor Green
Write-Host ""

& $LiteLlm --config $Config --host $HostAddress --port $Port
