const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  buildFirebaseLaunchConfig,
  buildMissingJavaMessage,
  buildOutdatedJavaMessage,
  parseJavaMajorVersion,
} = require('../scripts/start-emulators.cjs');

test('parseJavaMajorVersion reads current Java version strings', () => {
  assert.equal(
    parseJavaMajorVersion('openjdk version "21.0.2" 2024-01-16'),
    21,
  );
  assert.equal(
    parseJavaMajorVersion('java version "17.0.10" 2024-01-16 LTS'),
    17,
  );
  assert.equal(
    parseJavaMajorVersion('java version "1.8.0_401"'),
    8,
  );
});

test('Java preflight messages include actionable Windows guidance', () => {
  const missingJavaMessage = buildMissingJavaMessage();
  const outdatedJavaMessage = buildOutdatedJavaMessage(
    8,
    'java version "1.8.0_401"',
  );

  assert.match(missingJavaMessage, /where java/);
  assert.match(missingJavaMessage, /Cloud Firestore emulator/);
  assert.match(outdatedJavaMessage, /requires Java JDK 11 or higher/);
  assert.match(outdatedJavaMessage, /1.8.0_401/);
});

test('buildFirebaseLaunchConfig prefers a local firebase-tools install', () => {
  const tempRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'carebit-start-emulators-local-cli-'),
  );
  const entrypoint = path.join(
    tempRoot,
    'node_modules',
    'firebase-tools',
    'lib',
    'bin',
    'firebase.js',
  );

  fs.mkdirSync(path.dirname(entrypoint), { recursive: true });
  fs.writeFileSync(entrypoint, '');

  const launchConfig = buildFirebaseLaunchConfig({
    platform: 'win32',
    execPath: 'C:\\Program Files\\nodejs\\node.exe',
    comspec: 'C:\\Windows\\System32\\cmd.exe',
    rootDir: tempRoot,
  });

  assert.equal(launchConfig.command, 'C:\\Program Files\\nodejs\\node.exe');
  assert.deepEqual(launchConfig.args, [
    entrypoint,
    'emulators:start',
    '--only',
    'functions,firestore',
  ]);
  assert.deepEqual(launchConfig.options, {
    shell: false,
    stdio: 'inherit',
  });
});

test('buildFirebaseLaunchConfig uses cmd.exe for Windows PATH resolution', () => {
  const launchConfig = buildFirebaseLaunchConfig({
    platform: 'win32',
    comspec: 'C:\\Windows\\System32\\cmd.exe',
    rootDir: path.join(os.tmpdir(), 'carebit-start-emulators-no-local-cli'),
  });

  assert.equal(launchConfig.command, 'C:\\Windows\\System32\\cmd.exe');
  assert.deepEqual(launchConfig.args, [
    '/d',
    '/s',
    '/c',
    'firebase emulators:start --only functions,firestore',
  ]);
  assert.deepEqual(launchConfig.options, {
    shell: false,
    stdio: 'inherit',
  });
});

test('buildFirebaseLaunchConfig uses firebase directly on non-Windows hosts', () => {
  const launchConfig = buildFirebaseLaunchConfig({
    platform: 'linux',
    rootDir: path.join(os.tmpdir(), 'carebit-start-emulators-linux'),
  });

  assert.equal(launchConfig.command, 'firebase');
  assert.deepEqual(launchConfig.args, [
    'emulators:start',
    '--only',
    'functions,firestore',
  ]);
  assert.deepEqual(launchConfig.options, {
    shell: false,
    stdio: 'inherit',
  });
});
