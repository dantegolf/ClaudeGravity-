Clear-Host
Write-Host "ClaudeGravity limits"
Write-Host ""

try {
  Invoke-RestMethod http://127.0.0.1:8080/health | ConvertTo-Json -Depth 20
} catch {
  Write-Host "Antigravity proxy is not responding on http://127.0.0.1:8080/health"
  Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Press any key to close..."
[Console]::ReadKey($true) | Out-Null
