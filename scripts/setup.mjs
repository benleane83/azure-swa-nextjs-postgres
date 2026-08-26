import { execSync } from 'node:child_process';
import { copyFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const commands = [
  "npm install",
  "docker compose up -d",
  "npm run install:api",
  "npm run install:web",
  "npm run build:api",
  "npm run db:migrate",
  "npm run db:seed"
];

export function ensureEnvFile(projectDir = process.cwd()) {
  const envPath = join(projectDir, '.env');

  if (!existsSync(envPath)) {
    copyFileSync(join(projectDir, '.env.example'), envPath);
  }
}

export function ensureDockerEnvFile(projectDir = process.cwd()) {
  const dockerEnvPath = join(projectDir, '.env.docker');

  if (!existsSync(dockerEnvPath)) {
    copyFileSync(join(projectDir, '.env.docker.example'), dockerEnvPath);
  }
}

export function getSetupCommands() {
  return [...commands];
}

export function runSetup() {
  ensureEnvFile();

  ensureDockerEnvFile();

  for (const command of commands) {
    console.log(`> ${command}`);
    execSync(command, { stdio: 'inherit', shell: true });
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  runSetup();
}
