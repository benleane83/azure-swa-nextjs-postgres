import { randomInt } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const passwordVariable = 'AZURE_DB_ADMIN_PASSWORD';
const minimumAzdVersion = [1, 26, 0];
const lowercase = 'abcdefghijkmnopqrstuvwxyz';
const uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const digits = '23456789';
const symbols = '!#$%&*+-=?@^_';
const alphabet = lowercase + uppercase + digits + symbols;

function randomCharacter(characters) {
  return characters[randomInt(characters.length)];
}

function shuffle(characters) {
  for (let index = characters.length - 1; index > 0; index--) {
    const swapIndex = randomInt(index + 1);
    [characters[index], characters[swapIndex]] = [characters[swapIndex], characters[index]];
  }
  return characters;
}

export function generatePassword(length = 40) {
  if (length < 8) {
    throw new Error('PostgreSQL administrator passwords must contain at least 8 characters.');
  }

  const characters = [
    randomCharacter(lowercase),
    randomCharacter(uppercase),
    randomCharacter(digits),
    randomCharacter(symbols),
  ];

  while (characters.length < length) {
    characters.push(randomCharacter(alphabet));
  }

  return shuffle(characters).join('');
}

function runAzd(arguments_, options = {}) {
  return spawnSync('azd', arguments_, {
    cwd: fileURLToPath(new URL('..', import.meta.url)),
    encoding: 'utf8',
    windowsHide: true,
    ...options,
  });
}

function isAtLeastVersion(installedVersion, requiredVersion) {
  for (let index = 0; index < requiredVersion.length; index++) {
    if (installedVersion[index] !== requiredVersion[index]) {
      return installedVersion[index] > requiredVersion[index];
    }
  }

  return true;
}

function ensureSupportedAzdVersion() {
  const result = runAzd(['version']);
  if (result.error) {
    throw result.error;
  }

  const output = [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
  if (result.status !== 0) {
    throw new Error(output || 'Failed to determine the installed Azure Developer CLI version.');
  }

  const match = output.match(/\bazd version (\d+)\.(\d+)\.(\d+)\b/i);
  if (!match) {
    throw new Error('Could not determine the installed Azure Developer CLI version.');
  }

  const installedVersion = match.slice(1, 4).map(Number);
  if (!isAtLeastVersion(installedVersion, minimumAzdVersion)) {
    throw new Error(
      `Azure Developer CLI 1.26.0 or later is required because older versions pass an invalid environment name to Static Web Apps. ` +
      `Upgrade azd and rerun 'azd up'. On Windows: winget upgrade Microsoft.Azd`,
    );
  }
}

function getExistingPassword() {
  if (process.env[passwordVariable]) {
    return process.env[passwordVariable];
  }

  const result = runAzd(['env', 'get-value', passwordVariable, '--no-prompt']);
  if (result.error) {
    throw result.error;
  }

  if (result.status === 0) {
    return result.stdout.trim();
  }

  const errorOutput = [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
  if (errorOutput.includes('key not found in environment values')) {
    return '';
  }

  throw new Error(errorOutput || `Failed to read ${passwordVariable} from the azd environment.`);
}

export function prepareProvision() {
  ensureSupportedAzdVersion();

  if (getExistingPassword()) {
    console.log('Using the existing generated PostgreSQL administrator password.');
    return;
  }

  const password = generatePassword();
  const result = runAzd(
    ['env', 'set', passwordVariable, password, '--no-prompt'],
    { stdio: ['ignore', 'pipe', 'pipe'] },
  );

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error((result.stderr ?? '').trim() || `Failed to save ${passwordVariable} in the azd environment.`);
  }

  console.log('Generated and saved a PostgreSQL administrator password for this azd environment.');
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  prepareProvision();
}
