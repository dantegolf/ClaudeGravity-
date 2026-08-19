$ErrorActionPreference = "Stop"
$HealthUrl = "http://127.0.0.1:8080/health"
Write-Host "=== Лимиты ClaudeGravity ==="
Write-Host ""
try {
  $response = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 3
  $response | ConvertTo-Json -Depth 20
} catch {
  throw "Прокси не запущен. Сначала откройте ClaudeGravity. $($_.Exception.Message)"
}
