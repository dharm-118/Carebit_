type FirestoreRuntimeMode = 'emulator' | 'project';

export type FirestoreRuntimeHealth = {
  emulatorHost: string | null;
  mode: FirestoreRuntimeMode;
  persistenceReady: boolean;
  projectId: string | null;
  warning: string | null;
};

export function readFirestoreRuntimeHealth(
  env: NodeJS.ProcessEnv = process.env,
): FirestoreRuntimeHealth {
  const emulatorHost = readEnvString(env.FIRESTORE_EMULATOR_HOST);
  const projectId = readProjectId(env);
  const runningFunctionsEmulator = readEnvString(env.FUNCTIONS_EMULATOR) === 'true';
  const warning =
    runningFunctionsEmulator && emulatorHost == null
      ? 'Firestore emulator is not running for local Fitbit callback persistence. Start the emulator suite with `firebase emulators:start --only functions,firestore` or run `npm run serve` from `backend/functions`.'
      : null;

  return {
    emulatorHost,
    mode: emulatorHost == null ? 'project' : 'emulator',
    persistenceReady: warning == null,
    projectId,
    warning,
  };
}

export function readFirestorePersistenceReadinessIssue(
  env: NodeJS.ProcessEnv = process.env,
): string | null {
  return readFirestoreRuntimeHealth(env).warning;
}

export function describeFirestorePersistenceError(
  error: unknown,
  env: NodeJS.ProcessEnv = process.env,
): string {
  const runtimeHealth = readFirestoreRuntimeHealth(env);
  if (runtimeHealth.warning != null) {
    return runtimeHealth.warning;
  }

  const message = readErrorMessage(error);
  const errorCode = readErrorCode(error);
  if (
    errorCode === 5 ||
    message.includes('5 NOT_FOUND') ||
    message.includes('NOT_FOUND')
  ) {
    if (runtimeHealth.mode === 'emulator') {
      return 'Firestore emulator could not satisfy the Fitbit callback persistence request. Restart the Firestore emulator and try again.';
    }

    const projectId = runtimeHealth.projectId ?? 'the configured Firebase project';
    return `Firestore database is not available for Firebase project \`${projectId}\`. Create the Firestore database or point the Admin SDK at the correct project before finalizing Fitbit callbacks.`;
  }

  if (message.length > 0) {
    return `Firestore persistence failed: ${message}`;
  }

  return 'Firestore persistence failed.';
}

function readEnvString(value: string | undefined): string | null {
  if (value == null) {
    return null;
  }

  const normalizedValue = value.trim();
  return normalizedValue.length === 0 ? null : normalizedValue;
}

function readProjectId(env: NodeJS.ProcessEnv): string | null {
  const directProjectId =
    readEnvString(env.GCLOUD_PROJECT) ?? readEnvString(env.GOOGLE_CLOUD_PROJECT);
  if (directProjectId != null) {
    return directProjectId;
  }

  const firebaseConfig = readEnvString(env.FIREBASE_CONFIG);
  if (firebaseConfig == null) {
    return null;
  }

  try {
    const parsedConfig = JSON.parse(firebaseConfig) as unknown;
    if (typeof parsedConfig !== 'object' || parsedConfig == null) {
      return null;
    }

    const projectId = (parsedConfig as Record<string, unknown>).projectId;
    return typeof projectId === 'string' && projectId.trim().length > 0
      ? projectId.trim()
      : null;
  } catch (_) {
    return null;
  }
}

function readErrorCode(error: unknown): number | null {
  if (typeof error !== 'object' || error == null) {
    return null;
  }

  const value = (error as Record<string, unknown>).code;
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function readErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message.trim();
  }

  if (typeof error === 'string') {
    return error.trim();
  }

  return '';
}
