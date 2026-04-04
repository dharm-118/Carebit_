import type {
  FitbitDevicePayload,
  FitbitTokenResponse,
} from './fitbit_service';

export class FitbitCallbackPersistenceError extends Error {
  constructor(message: string, options?: { cause?: unknown }) {
    super(message, options);
    this.name = 'FitbitCallbackPersistenceError';
  }
}

export type PersistedFitbitDevice = {
  connectedAt: string;
  deviceId: string;
  deviceName: string;
  documentId: string;
  firmwareVersion: string | null;
  manufacturer: string;
  metadata: Record<string, unknown>;
  source: string;
  userId: string;
};

type BaseCallbackResult = {
  callbackStateDocumentId: string;
};

export type BeginFitbitCallbackResult =
  | (BaseCallbackResult & { kind: 'processing' })
  | (BaseCallbackResult & { kind: 'ready' })
  | (BaseCallbackResult & { error: string; kind: 'rejected' })
  | (BaseCallbackResult & {
      device: PersistedFitbitDevice;
      kind: 'succeeded';
    });

export type FitbitCallbackStatusResult =
  | (BaseCallbackResult & { kind: 'not_found' })
  | (BaseCallbackResult & { kind: 'processing' })
  | (BaseCallbackResult & { error: string; kind: 'failed' })
  | (BaseCallbackResult & {
      device: PersistedFitbitDevice;
      kind: 'succeeded';
    });

export interface FitbitCallbackPersistence {
  beginCallbackProcessing(args: {
    state: string;
    userId: string;
  }): Promise<BeginFitbitCallbackResult>;

  markCallbackFailed(args: {
    error: string;
    state: string;
    userId: string;
  }): Promise<void>;

  persistSuccessfulCallback(args: {
    device: FitbitDevicePayload;
    state: string;
    tokenResponse: FitbitTokenResponse;
    userId: string;
  }): Promise<{
    callbackStateDocumentId: string;
    device: PersistedFitbitDevice;
  }>;

  readCallbackStatus(args: {
    state: string;
    userId: string;
  }): Promise<FitbitCallbackStatusResult>;
}

export interface FitbitApiClient {
  exchangeCodeForTokens(code: string): Promise<FitbitTokenResponse>;
  fetchDevices(accessToken: string): Promise<unknown>;
  selectPrimaryDevice(devicesPayload: unknown): FitbitDevicePayload | null;
}

export type FitbitCallbackFlowResult =
  | {
      callbackStateDocumentId: string;
      device: PersistedFitbitDevice;
      ok: true;
      reused: boolean;
    }
  | {
      error: string;
      ok: false;
      statusCode: number;
    };

export async function finalizeFitbitCallbackFlow({
  code,
  fitbitApiClient,
  persistence,
  state,
  userId,
}: {
  code: string;
  fitbitApiClient: FitbitApiClient;
  persistence: FitbitCallbackPersistence;
  state: string | null;
  userId: string;
}): Promise<FitbitCallbackFlowResult> {
  if (state == null) {
    return {
      error: 'Missing Fitbit OAuth state. Start the connection again.',
      ok: false,
      statusCode: 400,
    };
  }

  const beginResult = await _runPersistenceOperation(
    'Could not start Fitbit callback persistence.',
    () =>
      persistence.beginCallbackProcessing({
        state,
        userId,
      }),
  );

  switch (beginResult.kind) {
    case 'processing':
      return {
        error:
          'This Fitbit callback is already being finalized. Wait for the current attempt to finish.',
        ok: false,
        statusCode: 409,
      };
    case 'rejected':
      return {
        error: beginResult.error,
        ok: false,
        statusCode: 409,
      };
    case 'succeeded':
      return {
        callbackStateDocumentId: beginResult.callbackStateDocumentId,
        device: beginResult.device,
        ok: true,
        reused: true,
      };
    case 'ready':
      break;
  }

  try {
    const tokenResponse = await fitbitApiClient.exchangeCodeForTokens(code);
    const devicesPayload = await fitbitApiClient.fetchDevices(
      tokenResponse.access_token,
    );
    const primaryDevice = fitbitApiClient.selectPrimaryDevice(devicesPayload);

    if (primaryDevice == null) {
      const error =
        'Fitbit returned no connected device data. Complete device sync in Fitbit and try again.';
      await _markCallbackFailedOrThrow({
        error,
        persistence,
        state,
        userId,
      });
      return { error, ok: false, statusCode: 502 };
    }

    const persistedResult = await _runPersistenceOperation(
      'Could not persist the successful Fitbit callback result.',
      () =>
        persistence.persistSuccessfulCallback({
          device: primaryDevice,
          state,
          tokenResponse,
          userId,
        }),
    );

    return {
      callbackStateDocumentId: persistedResult.callbackStateDocumentId,
      device: persistedResult.device,
      ok: true,
      reused: false,
    };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Fitbit token exchange failed.';

    if (error instanceof FitbitCallbackPersistenceError) {
      throw error;
    }

    await _markCallbackFailedOrThrow({
      error: message,
      persistence,
      state,
      userId,
    });
    return {
      error: message,
      ok: false,
      statusCode: 500,
    };
  }
}

async function _markCallbackFailedOrThrow({
  error,
  persistence,
  state,
  userId,
}: {
  error: string;
  persistence: FitbitCallbackPersistence;
  state: string;
  userId: string;
}): Promise<void> {
  await _runPersistenceOperation(
    'Could not persist the Fitbit callback failure state.',
    () =>
      persistence.markCallbackFailed({
        error,
        state,
        userId,
      }),
  );
}

async function _runPersistenceOperation<T>(
  message: string,
  operation: () => Promise<T>,
): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    throw new FitbitCallbackPersistenceError(message, { cause: error });
  }
}
