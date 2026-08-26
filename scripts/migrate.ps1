$ErrorActionPreference = "Stop"

Push-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location ..
. (Join-Path (Get-Location) "scripts/load-azd-env.ps1")
. (Join-Path (Get-Location) "scripts/load-database-url.ps1")

function Invoke-Az {
  param([string[]]$AzArguments)

  $result = & az @AzArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI command failed: az $($AzArguments -join ' ')"
  }

  return $result
}

Write-Host "Running database migration..."

$myIp = (Invoke-RestMethod -Uri "https://api.ipify.org")
$postgresFirewallRuleAdded = $false

try {
  # Add a temporary firewall rule to allow this machine to reach PostgreSQL.
  Write-Host "Opening PostgreSQL firewall for $myIp..."
  Invoke-Az @(
    "postgres", "flexible-server", "firewall-rule", "create",
    "--resource-group", $env:AZURE_RESOURCE_GROUP,
    "--name", $env:AZURE_POSTGRESQL_SERVER_NAME,
    "--rule-name", "MigrationTemp",
    "--start-ip-address", $myIp,
    "--end-ip-address", $myIp,
    "--output", "none"
  )
  $postgresFirewallRuleAdded = $true

  npx prisma migrate deploy --schema=db/schema.prisma
} finally {
  $cleanupFailures = [System.Collections.Generic.List[string]]::new()

  if ($postgresFirewallRuleAdded) {
    Write-Host "Removing temporary PostgreSQL firewall rule..."
    & az postgres flexible-server firewall-rule delete `
      --resource-group $env:AZURE_RESOURCE_GROUP `
      --name $env:AZURE_POSTGRESQL_SERVER_NAME `
      --rule-name "MigrationTemp" `
      --yes --output none
    if ($LASTEXITCODE -ne 0) {
      $cleanupFailures.Add("Failed to remove the temporary PostgreSQL firewall rule.")
    }
  }

  if ($cleanupFailures.Count -gt 0) {
    throw ($cleanupFailures -join " ")
  }
}

Write-Host "Migration complete."
Pop-Location
