#!/bin/sh
set -e

for variable_name in \
  AZURE_DB_ADMIN_PASSWORD \
  AZURE_POSTGRESQL_ADMIN_LOGIN \
  AZURE_POSTGRESQL_HOST \
  AZURE_POSTGRESQL_DATABASE; do
  if [ -z "$(printenv "$variable_name")" ]; then
    echo "ERROR: Required azd environment variable '$variable_name' is not set." >&2
    exit 1
  fi
done

DATABASE_PASSWORD=$(node -p 'encodeURIComponent(process.argv[1])' "$AZURE_DB_ADMIN_PASSWORD")
export DATABASE_URL="postgresql://${AZURE_POSTGRESQL_ADMIN_LOGIN}:${DATABASE_PASSWORD}@${AZURE_POSTGRESQL_HOST}:5432/${AZURE_POSTGRESQL_DATABASE}?sslmode=require"
