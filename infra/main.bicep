targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment used to generate a unique resource token')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('PostgreSQL administrator login')
param dbAdminLogin string = 'pgadmin'

@secure()
@description('PostgreSQL administrator password')
param dbAdminPassword string

var tags = {
  'azd-env-name': environmentName
}
var resourceToken = uniqueString(subscription().subscriptionId, environmentName, location)

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// Static Web App
module swa 'modules/swa.bicep' = {
  scope: rg
  name: 'swa'
  params: {
    name: 'swa-${resourceToken}'
    location: location
    tags: tags
  }
}

// PostgreSQL Flexible Server
module postgres 'modules/postgres.bicep' = {
  scope: rg
  name: 'postgres'
  params: {
    name: 'psql-${resourceToken}'
    location: location
    tags: tags
    administratorLogin: dbAdminLogin
    administratorLoginPassword: dbAdminPassword
    databaseName: environmentName
  }
}

// Monitoring (Log Analytics + Application Insights)
module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'monitoring'
  params: {
    name: 'ai-${resourceToken}'
    location: location
    tags: tags
  }
}

// Key Vault — stores DATABASE_URL secret, grants SWA managed identity access
module keyvault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault'
  params: {
    name: 'kv-${resourceToken}'
    location: location
    tags: tags
    principalId: swa.outputs.principalId
    databaseUrl: 'postgresql://${dbAdminLogin}:${uriComponent(dbAdminPassword)}@${postgres.outputs.fqdn}:5432/${postgres.outputs.databaseName}?sslmode=require'
  }
}

// Inject app settings into SWA — DATABASE_URL set directly (SWA managed functions don't resolve Key Vault references)
module swaAppSettings 'modules/swa-appsettings.bicep' = {
  scope: rg
  name: 'swa-appsettings'
  params: {
    swaName: swa.outputs.name
    appInsightsConnectionString: monitoring.outputs.connectionString
    databaseUrl: 'postgresql://${dbAdminLogin}:${uriComponent(dbAdminPassword)}@${postgres.outputs.fqdn}:5432/${postgres.outputs.databaseName}?sslmode=require'
  }
}

// Outputs — azd saves these as environment variables
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_SWA_NAME string = swa.outputs.name
output AZURE_SWA_HOSTNAME string = swa.outputs.defaultHostname
output AZURE_POSTGRESQL_HOST string = postgres.outputs.fqdn
output AZURE_POSTGRESQL_SERVER_NAME string = postgres.outputs.name
output AZURE_POSTGRESQL_DATABASE string = postgres.outputs.databaseName
output AZURE_POSTGRESQL_ADMIN_LOGIN string = dbAdminLogin
output AZURE_APPINSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString
output AZURE_KEY_VAULT_NAME string = keyvault.outputs.name
output AZURE_KEY_VAULT_URI string = keyvault.outputs.uri
