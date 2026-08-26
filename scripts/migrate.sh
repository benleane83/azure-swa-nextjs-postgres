#!/bin/bash
set -e

cd "$(dirname "$0")/.."
. "$(pwd)/scripts/load-azd-env.sh"
. "$(pwd)/scripts/load-database-url.sh"

echo "Running database migration..."

MY_IP=$(curl -s https://api.ipify.org)
POSTGRES_FIREWALL_RULE_ADDED=0

cleanup() {
  cleanup_status=0

  if [ "$POSTGRES_FIREWALL_RULE_ADDED" -eq 1 ]; then
    echo "Removing temporary PostgreSQL firewall rule..."
    if ! az postgres flexible-server firewall-rule delete \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --name "$AZURE_POSTGRESQL_SERVER_NAME" \
      --rule-name "MigrationTemp" \
      --yes --output none; then
      echo "ERROR: Failed to remove the temporary PostgreSQL firewall rule." >&2
      cleanup_status=1
    fi
  fi

  return "$cleanup_status"
}

trap cleanup EXIT

# Add a temporary firewall rule to allow this machine to reach PostgreSQL.
echo "Opening PostgreSQL firewall for $MY_IP..."
az postgres flexible-server firewall-rule create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_POSTGRESQL_SERVER_NAME" \
  --rule-name "MigrationTemp" \
  --start-ip-address "$MY_IP" \
  --end-ip-address "$MY_IP" \
  --output none
POSTGRES_FIREWALL_RULE_ADDED=1

npx prisma migrate deploy --schema=db/schema.prisma

echo "Migration complete."
