const fs = require('node:fs');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');

const FIREBASE_ARGS = ['emulators:start', '--only', 'functions,firestore'];

function runJavaPreflight() {
  const result = spawnSync('java', ['-version'], {
    encoding: 'utf8',
    shell: false,
  });

  if (result.error != null) {
    if (result.error.code === 'ENOENT') {
      failWithMessage(buildMissingJavaMessage());
    }

    failWithMessage(
      [
        'Could not run `java -version` before starting the Firebase emulator suite.',
        `Underlying error: ${result.error.message}`,
      ].join('\n'),
    );
  }

  const versionOutput = `${result.stdout ?? ''}\n${result.stderr ?? ''}`.trim();
  const javaMajorVersion = parseJavaMajorVersion(versionOutput);

  if (javaMajorVersion != null && javaMajorVersion < 11) {
    failWithMessage(buildOutdatedJavaMessage(javaMajorVersion, versionOutput));
  }

  if (javaMajorVersion != null && javaMajorVersion < 21) {
    console.warn(
      [
        `Detected Java ${javaMajorVersion}. Firebase Emulator Suite docs currently require Java JDK 11 or higher, and the Cloud Firestore emulator docs note that Java 21 will be required in an upcoming release.`,
        'The emulator suite can continue for now, but upgrading to Java 21+ will avoid future Firestore emulator breakage.',
      ].join('\n'),
    );
  }
}

function parseJavaMajorVersion(versionOutput) {
  const normalizedOutput = versionOutput.trim();
  if (normalizedOutput.length === 0) {
    return null;
  }

  const quotedVersionMatch = normalizedOutput.match(/version\s+"([^"]+)"/i);
  const versionToken = quotedVersionMatch?.[1] ?? normalizedOutput.split(/\s+/)[0];
  const versionParts = versionToken.split(/[._-]/).filter(Boolean);
  if (versionParts.length === 0) {
    return null;
  }

  const rawMajor = Number.parseInt(versionParts[0], 10);
  if (!Number.isFinite(rawMajor)) {
    return null;
  }

  if (rawMajor === 1 && versionParts.length > 1) {
    const legacyMajor = Number.parseInt(versionParts[1], 10);
    return Number.isFinite(legacyMajor) ? legacyMajor : null;
  }

  return rawMajor;
}

function getLocalFirebaseCliEntrypoint(rootDir = path.resolve(__dirname, '..')) {
  const entrypoint = path.join(
    rootDir,
    'node_modules',
    'firebase-tools',
    'lib',
    'bin',
    'firebase.js',
  );

  return fs.existsSync(entrypoint) ? entrypoint : null;
}

function buildFirebaseLaunchConfig({
  platform = process.platform,
  execPath = process.execPath,
  comspec = process.env.ComSpec,
  rootDir = path.resolve(__dirname, '..'),
} = {}) {
  const localEntrypoint = getLocalFirebaseCliEntrypoint(rootDir);
  if (localEntrypoint != null) {
    return {
      command: execPath,
      args: [localEntrypoint, ...FIREBASE_ARGS],
      options: {
        shell: false,
        stdio: 'inherit',
      },
    };
  }

  if (platform === 'win32') {
    return {
      command: comspec || 'cmd.exe',
      args: ['/d', '/s', '/c', ['firebase', ...FIREBASE_ARGS].join(' ')],
      options: {
        shell: false,
        stdio: 'inherit',
      },
    };
  }

  return {
    command: 'firebase',
    args: FIREBASE_ARGS,
    options: {
      shell: false,
      stdio: 'inherit',
    },
  };
}

function startFirebaseEmulators() {
  const launchConfig = buildFirebaseLaunchConfig();
  const child = spawn(
    launchConfig.command,
    launchConfig.args,
    launchConfig.options,
  );

  child.on('error', (error) => {
    failWithMessage(
      [
        'Could not start the Firebase CLI after Java preflight succeeded.',
        `Underlying error: ${error.message}`,
        'Verify that the Firebase CLI is installed and available on PATH by running `firebase --version`.',
        'If you want this repo to use a project-pinned CLI instead of a global install, add `firebase-tools` to `backend/functions` and this script will use it automatically.',
      ].join('\n'),
    );
  });

  child.on('exit', (code, signal) => {
    if (signal != null) {
      process.kill(process.pid, signal);
      return;
    }

    process.exit(code ?? 1);
  });
}

function buildMissingJavaMessage() {
  return [
    'Java is required to start the Firebase emulator suite for this project.',
    'This repo starts both the Functions and Cloud Firestore emulators for Fitbit callback persistence, and the Cloud Firestore emulator is Java-based.',
    '',
    'Fix on Windows:',
    '1. Install a Java JDK and add its `bin` directory to your PATH.',
    '2. Close and reopen the terminal.',
    '3. Verify the installation with `java -version` and `where java`.',
    '4. Run `npm run serve` again from `backend/functions`.',
    '',
    'Firebase docs currently require Java JDK 11 or higher for the Local Emulator Suite, and the Cloud Firestore emulator docs note that Java 21 will be required in an upcoming release.',
  ].join('\n');
}

function buildOutdatedJavaMessage(javaMajorVersion, versionOutput) {
  return [
    `Java ${javaMajorVersion} was detected, but the Firebase Local Emulator Suite requires Java JDK 11 or higher.`,
    'Upgrade Java, reopen the terminal, and verify with `java -version` before rerunning `npm run serve`.',
    '',
    `Detected output: ${versionOutput}`,
  ].join('\n');
}

function failWithMessage(message) {
  console.error(message);
  process.exit(1);
}

if (require.main === module) {
  runJavaPreflight();
  if (!process.argv.includes('--preflight-only')) {
    startFirebaseEmulators();
  }
}

module.exports = {
  buildFirebaseLaunchConfig,
  buildMissingJavaMessage,
  buildOutdatedJavaMessage,
  getLocalFirebaseCliEntrypoint,
  parseJavaMajorVersion,
};
