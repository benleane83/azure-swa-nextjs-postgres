foreach ($name in @(
  "AZURE_DB_ADMIN_PASSWORD",
  "AZURE_POSTGRESQL_ADMIN_LOGIN",
  "AZURE_POSTGRESQL_HOST",
  "AZURE_POSTGRESQL_DATABASE"
)) {
  if (-not (Get-Item "Env:$name" -ErrorAction SilentlyContinue)?.Value) {
    throw "Required azd environment variable '$name' is not set."
  }
}

$databasePassword = [System.Uri]::EscapeDataString($env:AZURE_DB_ADMIN_PASSWORD)
$env:DATABASE_URL = "postgresql://$($env:AZURE_POSTGRESQL_ADMIN_LOGIN):$databasePassword@$($env:AZURE_POSTGRESQL_HOST):5432/$($env:AZURE_POSTGRESQL_DATABASE)?sslmode=require"
