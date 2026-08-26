$ErrorActionPreference = "Stop"

Push-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location ..
. (Join-Path (Get-Location) "scripts/load-azd-env.ps1")
. (Join-Path (Get-Location) "scripts/load-database-url.ps1")

Write-Host "🌱 Seeding Azure database..."

# Open temporary firewall rule for local machine
$myIp = (Invoke-RestMethod -Uri "https://api.ipify.org")
$ruleName = "seed-temp-$(Get-Random)"
Write-Host "Opening firewall for $myIp..."
az postgres flexible-server firewall-rule create `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --name $env:AZURE_POSTGRESQL_SERVER_NAME `
  --rule-name $ruleName `
  --start-ip-address $myIp `
  --end-ip-address $myIp 2>$null

try {
  npx tsx db/seed.ts
} finally {
  Write-Host "Closing firewall rule..."
  az postgres flexible-server firewall-rule delete `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --name $env:AZURE_POSTGRESQL_SERVER_NAME `
    --rule-name $ruleName `
    --yes 2>$null
}

Write-Host "✅ Seed complete."
Pop-Location
