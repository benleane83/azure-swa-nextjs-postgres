# azure-swa-nextjs-postgres

Built with [create-azure-app](https://github.com/benleane83/create-azure-app) — a CLI that scaffolds Azure full-stack web app templates instantly. Simply run the CLI, choose your tech stack preferences, and get a complete project with frontend, backend API, infrastructure-as-code (Bicep), and CI/CD workflows pre-configured for Azure deployment.

## Prerequisites

- [Node.js](https://nodejs.org/) 20+
- [Azure Developer CLI (azd)](https://aka.ms/azd) 1.26.0 or later
- [Docker](https://www.docker.com/) (optional, only required when DB is included)
- [GitHub CLI (gh)](https://cli.github.com/) (optional, for CI/CD setup)

> **Note:** SWA CLI and Azure Functions Core Tools are installed as project dev dependencies — no global install needed.

## Quick Start (Local Development)

```bash
# Install root dependencies
npm install

# Install sub-projects and start local PostgreSQL
npm run setup

# Start development server
npm run dev
```

## Deploy to Azure

### First-time setup

`azd up` generates a strong PostgreSQL administrator password on the first run
and stores it in the local, gitignored azd environment under
`AZURE_DB_ADMIN_PASSWORD`. Later runs reuse that password. The postprovision
hook constructs `DATABASE_URL` in memory, opens a temporary PostgreSQL firewall
rule for the current public IP, applies Prisma migrations, and removes the rule.
Key Vault remains private-only throughout the deployment.

```bash
# 1. Provision Azure infrastructure (SWA, PostgreSQL, Key Vault, etc.)
azd up

# 2. Push your code to GitHub
git remote add origin https://github.com/YOUR_USER/azure-swa-nextjs-postgres.git
git push -u origin main

# 3. Configure OIDC credentials for GitHub Actions
azd pipeline config --provider github --auth-type federated
```

`azd pipeline config` creates a service principal with federated credentials and
stores `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
`AZURE_ENV_NAME`, and `AZURE_LOCATION` as GitHub **repository variables**
automatically — no manual setup needed.

### After setup

Every push to `main` triggers the **Deploy** workflow automatically. That's it.

To re-provision infrastructure (e.g., after changing Bicep files), run the
**Provision** workflow manually from the Actions tab.

## CI/CD Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **deploy.yml** | Push to `main`, PR open/sync | Builds the app, deploys to Azure Static Web Apps |
| **deploy.yml** | PR closed | Tears down preview environment |
| **provision.yml** | Manual (`workflow_dispatch`) | Runs `azd provision` to create/update infrastructure |

- **Push to `main`** → deploys to your **production** Static Web App
- **Pull request** → deploys to a **preview environment** with a unique URL
- **PR closed** → automatically tears down the preview environment

The deploy workflow uses OIDC to authenticate with Azure and fetches the SWA
deployment token dynamically — no static secrets to manage.

## Project Structure

```
├── .github/workflows/
│   ├── deploy.yml        # Build + deploy (prod & preview)
│   └── provision.yml     # Azure infra provisioning (manual)
├── src/
│   ├── web/              # Frontend application
│   └── api/              # Azure Functions API
├── db/
│   ├── migrations/       # Database migrations
│   └── schema.*          # ORM schema
├── infra/                # Bicep infrastructure modules
├── azure.yaml            # AZD manifest
└── docker-compose.yml    # Local PostgreSQL
```
