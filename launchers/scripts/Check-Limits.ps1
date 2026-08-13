$ErrorActionPreference = "Continue"
Clear-Host
Write-Host "=== Лимиты ClaudeGravity ==="
Write-Host ""

try {
  Invoke-RestMethod http://127.0.0.1:8080/health | ConvertTo-Json -Depth 20
} catch {
  Write-Host "Прокси не ответил на http://127.0.0.1:8080/health"
  Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Нажмите любую клавишу для закрытия..."
[Console]::ReadKey($true) | Out-Null
