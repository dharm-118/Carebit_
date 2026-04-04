import { createHash } from 'crypto';

import type { Firestore } from 'firebase-admin/firestore';

import type {
  BeginFitbitCallbackResult,
  FitbitCallbackPersistence,
  FitbitCallbackStatusResult,
  PersistedFitbitDevice,
} from './fitbit_callback_flow';
import type {
  FitbitDevicePayload,
  FitbitTokenResponse,
} from './fitbit_service';

const fitbitCallbackStatesCollection = 'fitbit_callback_states';
const fitbitConnectionsCollection = 'fitbit_connections';
const fitbitProvider = 'fitbit';
const fitbitCallbackProcessingLeaseMs = 60_000;
const watchDataCollection = 'watch_data';

export function buildFitbitCallbackStateDocumentId(
  userId: string,
  state: string,
): string {
  return createHash('sha256').update(`${userId}:${state}`).digest('hex');
}

export function buildWatchDataDocumentId(userId: string, deviceId: string): string {
  return `${userId}_${fitbitProvider}_${deviceId}`;
}

export function buildFitbitPersistencePayloads({
  callbackStateDocumentId,
  connectedAt,
  device,
  existingConnectionCreatedAt,
  state,
  tokenResponse,
  userId,
}: {
  callbackStateDocumentId: string;
  connectedAt: string;
  device: FitbitDevicePayload;
  existingConnectionCreatedAt?: string;
  state: string;
  tokenResponse: FitbitTokenResponse;
  userId: string;
}): {
  callbackStatePayload: Record<string, unknown>;
  connectionDocumentId: string;
  connectionPayload: Record<string, unknown>;
  watchDataDocumentId: string;
  watchDataPayload: PersistedFitbitDevice;
} {
  const watchDataDocumentId = buildWatchDataDocumentId(userId, device.deviceId);
  const watchDataPayload: PersistedFitbitDevice = {
    connectedAt,
    deviceId: device.deviceId,
    deviceName: device.deviceName,
    documentId: watchDataDocumentId,
    firmwareVersion: null,
    manufacturer: 'Fitbit',
    metadata: {
      battery: device.battery,
      batteryLevel: device.batteryLevel,
      deviceType: device.deviceType,
      lastSyncTime: device.lastSyncTime,
      macAddress: device.macAddress,
      rawDevice: device.rawPayload,
    },
    source: fitbitProvider,
    userId,
  };
  const connectionPayload: Record<string, unknown> = {
    userId,
    provider: fitbitProvider,
    fitbitUserId: tokenResponse.user_id,
    accessToken: tokenResponse.access_token,
    refreshToken: tokenResponse.refresh_token,
    tokenType: tokenResponse.token_type,
    scopes: tokenResponse.scope
      .split(/\s+/)
      .map((scope) => scope.trim())
      .filter(Boolean),
    accessTokenExpiresAt: new Date(
      Date.parse(connectedAt) + tokenResponse.expires_in * 1000,
    ).toISOString(),
    connectedDeviceId: device.deviceId,
    connectedDeviceDocId: watchDataDocumentId,
    connectedAt,
    lastState: state,
    updatedAt: connectedAt,
  };

  if (existingConnectionCreatedAt != null) {
    connectionPayload.createdAt = existingConnectionCreatedAt;
  } else {
    connectionPayload.createdAt = connectedAt;
  }

  const callbackStatePayload: Record<string, unknown> = {
    userId,
    status: 'succeeded',
    watchDataDocumentId,
    savedDevice: watchDataPayload,
    updatedAt: connectedAt,
  };

  return {
    callbackStatePayload,
    connectionDocumentId: userId,
    connectionPayload,
    watchDataDocumentId,
    watchDataPayload,
  };
}

export class FirestoreFitbitCallbackPersistence
  implements FitbitCallbackPersistence
{
  constructor(private readonly firestore: Firestore) {}

  async beginCallbackProcessing(args: {
    state: string;
    userId: string;
  }): Promise<BeginFitbitCallbackResult> {
    const callbackStateDocumentId = buildFitbitCallbackStateDocumentId(
      args.userId,
      args.state,
    );
    const callbackStateReference = this.firestore
      .collection(fitbitCallbackStatesCollection)
      .doc(callbackStateDocumentId);
    const watchDataCollectionReference = this.firestore.collection(
      watchDataCollection,
    );

    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(callbackStateReference);
      const now = new Date().toISOString();

      if (!snapshot.exists) {
        transaction.set(callbackStateReference, {
          userId: args.userId,
          status: 'processing',
          createdAt: now,
          updatedAt: now,
        });
        return { callbackStateDocumentId, kind: 'ready' };
      }

      const payload = snapshot.data() ?? {};
      const status = readStringValue(payload.status);

      if (status === 'succeeded') {
        const savedDevice = readPersistedFitbitDevice(payload.savedDevice);
        if (savedDevice != null) {
          return {
            callbackStateDocumentId,
            device: savedDevice,
            kind: 'succeeded',
          };
        }

        const watchDataDocumentId = readStringValue(payload.watchDataDocumentId);
        if (watchDataDocumentId != null) {
          const watchDataSnapshot = await transaction.get(
            watchDataCollectionReference.doc(watchDataDocumentId),
          );
          const watchDataPayload = readPersistedFitbitDevice(
            watchDataSnapshot.data(),
          );

          if (watchDataPayload != null) {
            return {
              callbackStateDocumentId,
              device: watchDataPayload,
              kind: 'succeeded',
            };
          }
        }

        return {
          callbackStateDocumentId,
          error:
            'Fitbit callback was already completed, but the saved device record could not be found.',
          kind: 'rejected',
        };
      }

      if (status === 'processing') {
        if (isFitbitCallbackProcessingStale(payload, now)) {
          transaction.set(
            callbackStateReference,
            {
              status: 'processing',
              updatedAt: now,
              lastError: null,
            },
            { merge: true },
          );
          return { callbackStateDocumentId, kind: 'ready' };
        }

        return { callbackStateDocumentId, kind: 'processing' };
      }

      if (status === 'failed') {
        return {
          callbackStateDocumentId,
          error:
            readStringValue(payload.lastError) ??
            'This Fitbit callback has already been rejected. Start the connection again.',
          kind: 'rejected',
        };
      }

      transaction.set(
        callbackStateReference,
        {
          status: 'processing',
          updatedAt: now,
          lastError: null,
        },
        { merge: true },
      );
      return { callbackStateDocumentId, kind: 'ready' };
    });
  }

  async markCallbackFailed(args: {
    error: string;
    state: string;
    userId: string;
  }): Promise<void> {
    const callbackStateDocumentId = buildFitbitCallbackStateDocumentId(
      args.userId,
      args.state,
    );
    const callbackStateReference = this.firestore
      .collection(fitbitCallbackStatesCollection)
      .doc(callbackStateDocumentId);
    const now = new Date().toISOString();

    await callbackStateReference.set(
      {
        userId: args.userId,
        status: 'failed',
        lastError: args.error,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  async persistSuccessfulCallback(args: {
    device: FitbitDevicePayload;
    state: string;
    tokenResponse: FitbitTokenResponse;
    userId: string;
  }): Promise<{
    callbackStateDocumentId: string;
    device: PersistedFitbitDevice;
  }> {
    const callbackStateDocumentId = buildFitbitCallbackStateDocumentId(
      args.userId,
      args.state,
    );
    const callbackStateReference = this.firestore
      .collection(fitbitCallbackStatesCollection)
      .doc(callbackStateDocumentId);
    const connectionReference = this.firestore
      .collection(fitbitConnectionsCollection)
      .doc(args.userId);
    const existingConnectionSnapshot = await connectionReference.get();
    const existingConnectionCreatedAt = readStringValue(
      existingConnectionSnapshot.data()?.createdAt,
    );
    const connectedAt = new Date().toISOString();
    const payloads = buildFitbitPersistencePayloads({
      callbackStateDocumentId,
      connectedAt,
      device: args.device,
      existingConnectionCreatedAt: existingConnectionCreatedAt ?? undefined,
      state: args.state,
      tokenResponse: args.tokenResponse,
      userId: args.userId,
    });
    const watchDataReference = this.firestore
      .collection(watchDataCollection)
      .doc(payloads.watchDataDocumentId);
    const batch = this.firestore.batch();

    batch.set(connectionReference, payloads.connectionPayload, { merge: true });
    batch.set(watchDataReference, payloads.watchDataPayload, { merge: true });
    batch.set(
      callbackStateReference,
      payloads.callbackStatePayload,
      { merge: true },
    );
    await batch.commit();

    return {
      callbackStateDocumentId,
      device: payloads.watchDataPayload,
    };
  }

  async readCallbackStatus(args: {
    state: string;
    userId: string;
  }): Promise<FitbitCallbackStatusResult> {
    const callbackStateDocumentId = buildFitbitCallbackStateDocumentId(
      args.userId,
      args.state,
    );
    const callbackStateReference = this.firestore
      .collection(fitbitCallbackStatesCollection)
      .doc(callbackStateDocumentId);
    const callbackStateSnapshot = await callbackStateReference.get();

    if (!callbackStateSnapshot.exists) {
      return { callbackStateDocumentId, kind: 'not_found' };
    }

    const payload = callbackStateSnapshot.data() ?? {};
    const status = readStringValue(payload.status);

    if (status === 'succeeded') {
      const savedDevice = readPersistedFitbitDevice(payload.savedDevice);
      if (savedDevice != null) {
        return {
          callbackStateDocumentId,
          device: savedDevice,
          kind: 'succeeded',
        };
      }

      const watchDataDocumentId = readStringValue(payload.watchDataDocumentId);
      if (watchDataDocumentId != null) {
        const watchDataSnapshot = await this.firestore
          .collection(watchDataCollection)
          .doc(watchDataDocumentId)
          .get();
        const watchDataPayload = readPersistedFitbitDevice(
          watchDataSnapshot.data(),
        );

        if (watchDataPayload != null) {
          return {
            callbackStateDocumentId,
            device: watchDataPayload,
            kind: 'succeeded',
          };
        }
      }

      return {
        callbackStateDocumentId,
        error:
          'Fitbit callback was already completed, but the saved device record could not be found.',
        kind: 'failed',
      };
    }

    if (status === 'failed') {
      return {
        callbackStateDocumentId,
        error:
          readStringValue(payload.lastError) ??
          'This Fitbit callback has already been rejected. Start the connection again.',
        kind: 'failed',
      };
    }

    return { callbackStateDocumentId, kind: 'processing' };
  }
}

function readPersistedFitbitDevice(
  value: unknown,
): PersistedFitbitDevice | null {
  const payload = readRecord(value);
  if (payload == null) {
    return null;
  }

  const documentId = readStringValue(payload.documentId);
  const userId = readStringValue(payload.userId);
  const deviceId = readStringValue(payload.deviceId);
  const deviceName = readStringValue(payload.deviceName);
  const manufacturer = readStringValue(payload.manufacturer);
  const connectedAt = readStringValue(payload.connectedAt);
  const source = readStringValue(payload.source);

  if (
    documentId == null ||
    userId == null ||
    deviceId == null ||
    deviceName == null ||
    manufacturer == null ||
    connectedAt == null ||
    source == null
  ) {
    return null;
  }

  return {
    connectedAt,
    deviceId,
    deviceName,
    documentId,
    firmwareVersion: readStringValue(payload.firmwareVersion),
    manufacturer,
    metadata: readRecord(payload.metadata) ?? {},
    source,
    userId,
  };
}

function readRecord(value: unknown): Record<string, unknown> | null {
  if (typeof value !== 'object' || value == null || Array.isArray(value)) {
    return null;
  }

  return value as Record<string, unknown>;
}

function readStringValue(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalizedValue = value.trim();
  return normalizedValue.length === 0 ? null : normalizedValue;
}

function isFitbitCallbackProcessingStale(
  payload: Record<string, unknown>,
  nowIsoString: string,
): boolean {
  const updatedAt =
    readStringValue(payload.updatedAt) ?? readStringValue(payload.createdAt);
  const updatedAtMs = updatedAt == null ? Number.NaN : Date.parse(updatedAt);
  const nowMs = Date.parse(nowIsoString);

  if (!Number.isFinite(updatedAtMs) || !Number.isFinite(nowMs)) {
    return true;
  }

  return nowMs - updatedAtMs >= fitbitCallbackProcessingLeaseMs;
}
