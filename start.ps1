[CmdletBinding()]
param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 4000,
    [int]$AutoProfile = -1   # -1 = show menu; 0 = all; 1..N = specific profile
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

# --- Parse config.yaml: map each env var -> list of model_name + underlying model ---
# Reads blocks of: model_name, then model: and api_key: under litellm_params
$modelMap = @{}  # envVarName -> list of [model_name, underlying_model]
$yamlLines = Get-Content $Config
$currentModelName = $null
$currentEnvVar    = $null
$currentModel     = $null
foreach ($line in $yamlLines) {
    if ($line -match '^\s*-\s*model_name:\s*(.+)') {
        $currentModelName = $Matches[1].Trim()
        $currentEnvVar    = $null
        $currentModel     = $null
    } elseif ($line -match '^\s*model:\s*(.+)') {
        $currentModel = $Matches[1].Trim()
    } elseif ($line -match '^\s*api_key:\s*os\.environ/(\S+)') {
        $currentEnvVar = $Matches[1].Trim()
        if ($currentModelName -and $currentEnvVar) {
            if (-not $modelMap.ContainsKey($currentEnvVar)) {
                $modelMap[$currentEnvVar] = @()
            }
            $modelMap[$currentEnvVar] += [PSCustomObject]@{
                Name  = $currentModelName
                Model = $currentModel
            }
        }
    }
}

# --- Show menu or use AutoProfile ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   LiteLLM BYOK - Select Provider/Key  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  0) ALL providers (use all keys at once)" -ForegroundColor Yellow
for ($j = 0; $j -lt $profiles.Count; $j++) {
    Write-Host ("  {0}) {1}" -f ($j + 1), $profiles[$j].Label)
}
Write-Host ""

$selection = $null

if ($AutoProfile -ge 0) {
    # Non-interactive mode: use the value passed by caller
    if ($AutoProfile -eq 0) {
        $selection = "all"
        Write-Host "Auto-selected: ALL providers" -ForegroundColor Yellow
    } elseif ($AutoProfile -ge 1 -and $AutoProfile -le $profiles.Count) {
        $selection = $profiles[$AutoProfile - 1]
        Write-Host "Auto-selected: $($selection.Label)" -ForegroundColor Yellow
    } else {
        throw "AutoProfile $AutoProfile is out of range (0-$($profiles.Count))."
    }
} else {
    while ($null -eq $selection) {
        $input = Read-Host "Enter number (0 = all, 1-$($profiles.Count) = single)"
        if ($input -match '^\d+$') {
            $idx = [int]$input
            if ($idx -eq 0) {
                $selection = "all"
            } elseif ($idx -ge 1 -and $idx -le $profiles.Count) {
                $selection = $profiles[$idx - 1]
            }
        }
        if ($null -eq $selection) {
            Write-Host "Invalid selection, please try again." -ForegroundColor Yellow
        }
    }
}

# --- Set environment variables ---
$env:LITELLM_MASTER_KEY     = $envData["LITELLM_MASTER_KEY"]
$env:PYTHONUTF8             = "1"
$env:PYTHONIOENCODING       = "utf-8"
$env:PYTHON_DOTENV_DISABLED = "1"
Remove-Item Env:DATABASE_URL              -ErrorAction SilentlyContinue
Remove-Item Env:DIRECT_URL                -ErrorAction SilentlyContinue
Remove-Item Env:DATABASE_URL_READ_REPLICA -ErrorAction SilentlyContinue

if ($selection -eq "all") {
    $missing = @()
    foreach ($p in $profiles) {
        if ($p.Key) {
            [System.Environment]::SetEnvironmentVariable($p.EnvVar, $p.Key, "Process")
        } else {
            $missing += $p.Label
        }
    }
    Write-Host ""
    Write-Host "Selected : ALL providers" -ForegroundColor Yellow
    foreach ($p in $profiles) {
        if ($p.Key) {
            Write-Host "  [OK] $($p.Label)" -ForegroundColor Green
        } else {
            Write-Host "  [--] $($p.Label)  (key not set, model will be unavailable)" -ForegroundColor DarkGray
        }
    }
} else {
    if (-not $selection.Key) {
        throw "Profile '$($selection.Label)' has no API key set. Edit .env and fill in the key."
    }
    [System.Environment]::SetEnvironmentVariable($selection.EnvVar, $selection.Key, "Process")
    Write-Host ""
    Write-Host "Selected : $($selection.Label)"  -ForegroundColor Green
    Write-Host "Env var  : $($selection.EnvVar)" -ForegroundColor Green
    Write-Host "Models available via this key:" -ForegroundColor Cyan
    $models = $modelMap[$selection.EnvVar]
    if ($models) {
        foreach ($m in $models) {
            Write-Host ("  - {0,-35} ({1})" -f $m.Name, $m.Model) -ForegroundColor White
        }
    } else {
        Write-Host "  (no models found for $($selection.EnvVar) in config.yaml)" -ForegroundColor DarkGray
    }
}

Write-Host "Proxy    : http://$HostAddress`:$Port" -ForegroundColor Green
Write-Host ""

& $LiteLlm --config $Config --host $HostAddress --port $Port
