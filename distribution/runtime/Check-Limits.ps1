$ErrorActionPreference = "Stop"
$GatewayHealthUrl = "http://127.0.0.1:17645/health"
$LimitsUrl = "http://127.0.0.1:18080/account-limits"

Write-Host "=== ClaudeGravity status / limits ==="
Write-Host ""
try {
  Invoke-RestMethod -Uri $GatewayHealthUrl -TimeoutSec 3 | Out-Null
} catch {
  throw "ClaudeGravity gateway не запущен. Сначала откройте ClaudeGravity. $($_.Exception.Message)"
}

try {
  $response = Invoke-RestMethod -Uri $LimitsUrl -TimeoutSec 5
  Write-Host "Gateway: http://127.0.0.1:17645/anthropic"
  Write-Host ""
  $response | ConvertTo-Json -Depth 20
} catch {
  throw "Gateway работает, но Antigravity engine не вернул лимиты. $($_.Exception.Message)"
}
