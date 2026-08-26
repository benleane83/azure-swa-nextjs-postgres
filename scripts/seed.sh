#!/bin/bash
set -e

cd "$(dirname "$0")/.."
. "$(pwd)/scripts/load-azd-env.sh"
. "$(pwd)/scripts/load-database-url.sh"

echo "Seeding Azure database..."

MY_IP=$(curl -s https://api.ipify.org)
RULE_NAME="seed-temp-$$"
echo "Opening firewall for $MY_IP..."
az postgres flexible-server firewall-rule create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_POSTGRESQL_SERVER_NAME" \
  --rule-name "$RULE_NAME" \
  --start-ip-address "$MY_IP" \
  --end-ip-address "$MY_IP" \
  --output none

cleanup() {
  echo "Closing firewall rule..."
  az postgres flexible-server firewall-rule delete \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$AZURE_POSTGRESQL_SERVER_NAME" \
    --rule-name "$RULE_NAME" \
    --yes \
    --output none
}
trap cleanup EXIT

npx tsx db/seed.ts

echo "Seed complete."
