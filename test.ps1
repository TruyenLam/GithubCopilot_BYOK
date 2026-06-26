[CmdletBinding()]
param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 4000
)

$EnvFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".env"
$BaseUrl = "http://$HostAddress`:$Port"

# --- Read master key from .env ---
$masterKey = ""
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*LITELLM_MASTER_KEY\s*=\s*(.+)') {
            $masterKey = $Matches[1].Trim()
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   LiteLLM BYOK - Test All Models      " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Proxy : $BaseUrl"
Write-Host ""

$headers = @{ "Content-Type" = "application/json" }
if ($masterKey -and $masterKey -ne "sk-change-me") {
    $headers["Authorization"] = "Bearer $masterKey"
}

# --- Fetch model list from proxy ---
try {
    $modelsResp = Invoke-RestMethod -Uri "$BaseUrl/v1/models" -Headers $headers -Method Get
    $models = $modelsResp.data | Select-Object -ExpandProperty id
} catch {
    Write-Host "ERROR: Cannot reach proxy at $BaseUrl" -ForegroundColor Red
    Write-Host "Make sure start.bat is running first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($models.Count) model(s): $($models -join ', ')" -ForegroundColor DarkGray
Write-Host ""

$prompt = "Reply with exactly one sentence: what model are you?"
$results = @()
$lastGemini = $null   # track last Gemini call to insert delay

foreach ($model in $models) {
    # Gemini free tier has strict RPM — wait 15s between Gemini calls
    if ($model -match '^gemini-' -and $null -ne $lastGemini) {
        Write-Host "  (waiting 15s for Gemini rate limit...)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 15
    }
    if ($model -match '^gemini-') { $lastGemini = $model }

    Write-Host "Testing [$model]..." -NoNewline

    $body = @{
        model      = $model
        messages   = @(@{ role = "user"; content = $prompt })
        max_tokens = 64
    } | ConvertTo-Json -Depth 5

    try {
        $start    = Get-Date
        $response = Invoke-RestMethod -Uri "$BaseUrl/v1/chat/completions" `
                        -Method Post -Headers $headers -Body $body -TimeoutSec 30
        $elapsed  = [int]((Get-Date) - $start).TotalMilliseconds
        $reply    = $response.choices[0].message.content.Trim()

        Write-Host " OK  ($($elapsed)ms)" -ForegroundColor Green
        Write-Host "     $reply" -ForegroundColor White

        $results += [PSCustomObject]@{ Model = $model; Status = "OK"; Ms = $elapsed; Reply = $reply }
    } catch {
        $errMsg = $_.Exception.Message -replace "`n", " "
        Write-Host " FAIL" -ForegroundColor Red
        Write-Host "     $errMsg" -ForegroundColor DarkGray

        $results += [PSCustomObject]@{ Model = $model; Status = "FAIL"; Ms = 0; Reply = $errMsg }
    }
    Write-Host ""
}

# --- Summary ---
Write-Host "========================================"
Write-Host "Summary"
Write-Host "========================================"
foreach ($r in $results) {
    $color = if ($r.Status -eq "OK") { "Green" } else { "Red" }
    Write-Host ("[{0,-4}] {1}" -f $r.Status, $r.Model) -ForegroundColor $color
}
$ok   = ($results | Where-Object Status -eq "OK").Count
$fail = ($results | Where-Object Status -eq "FAIL").Count
Write-Host ""
Write-Host "Passed: $ok / $($results.Count)   Failed: $fail" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
