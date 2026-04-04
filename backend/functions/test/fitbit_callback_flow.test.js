const test = require('node:test');
const assert = require('node:assert/strict');

const {
  FitbitCallbackPersistenceError,
  finalizeFitbitCallbackFlow,
} = require('../lib/services/fitbit_callback_flow.js');
const {
  buildFitbitCallbackStateDocumentId,
  buildFitbitPersistencePayloads,
} = require('../lib/services/firestore_fitbit_callback_persistence.js');

test('finalizeFitbitCallbackFlow reuses an already-successful state without a second token exchange', async () => {
  const persistence = new InMemoryFitbitCallbackPersistence();
  const fitbitApiClient = {
    async exchangeCodeForTokens() {
      fitbitApiClient.exchangeCalls += 1;
      return {
        access_token: 'access-token',
        expires_in: 3600,
        refresh_token: 'refresh-token',
        scope: 'activity profile',
        token_type: 'Bearer',
        user_id: 'fitbit-user',
      };
    },
    exchangeCalls: 0,
    async fetchDevices() {
      fitbitApiClient.fetchDevicesCalls += 1;
      return [{ id: 'device-123', deviceVersion: 'Sense 2', type: 'watch' }];
    },
    fetchDevicesCalls: 0,
    selectPrimaryDevice(devicesPayload) {
      fitbitApiClient.selectCalls += 1;
      const [device] = devicesPayload;
      return {
        battery: 'High',
        batteryLevel: 93,
        deviceId: device.id,
        deviceName: device.deviceVersion,
        deviceType: device.type,
        lastSyncTime: '2026-04-01T00:00:00.000Z',
        macAddress: 'AA:BB:CC',
        rawPayload: device,
      };
    },
    selectCalls: 0,
  };

  const firstResult = await finalizeFitbitCallbackFlow({
    code: 'oauth-code',
    fitbitApiClient,
    persistence,
    state: 'oauth-state',
    userId: 'user-123',
  });
  const secondResult = await finalizeFitbitCallbackFlow({
    code: 'oauth-code',
    fitbitApiClient,
    persistence,
    state: 'oauth-state',
    userId: 'user-123',
  });

  assert.equal(firstResult.ok, true);
  assert.equal(firstResult.reused, false);
  assert.equal(secondResult.ok, true);
  assert.equal(secondResult.reused, true);
  assert.equal(fitbitApiClient.exchangeCalls, 1);
  assert.equal(fitbitApiClient.fetchDevicesCalls, 1);
  assert.equal(fitbitApiClient.selectCalls, 1);
  assert.equal(persistence.persistCalls.length, 1);
});

test('buildFitbitPersistencePayloads creates both connection and watch_data records for a successful callback', () => {
  const payloads = buildFitbitPersistencePayloads({
    callbackStateDocumentId: buildFitbitCallbackStateDocumentId(
      'user-123',
      'oauth-state',
    ),
    connectedAt: '2026-04-01T12:00:00.000Z',
    device: {
      battery: 'Medium',
      batteryLevel: 55,
      deviceId: 'device-123',
      deviceName: 'Fitbit Sense 2',
      deviceType: 'watch',
      lastSyncTime: '2026-04-01T11:59:00.000Z',
      macAddress: 'AA:BB:CC',
      rawPayload: { id: 'device-123' },
    },
    state: 'oauth-state',
    tokenResponse: {
      access_token: 'access-token',
      expires_in: 3600,
      refresh_token: 'refresh-token',
      scope: 'activity profile',
      token_type: 'Bearer',
      user_id: 'fitbit-user',
    },
    userId: 'user-123',
  });

  assert.equal(payloads.connectionDocumentId, 'user-123');
  assert.equal(payloads.watchDataDocumentId, 'user-123_fitbit_device-123');
  assert.equal(
    payloads.connectionPayload.connectedDeviceDocId,
    payloads.watchDataDocumentId,
  );
  assert.equal(payloads.watchDataPayload.documentId, payloads.watchDataDocumentId);
  assert.equal(payloads.watchDataPayload.userId, 'user-123');
  assert.equal(payloads.watchDataPayload.deviceName, 'Fitbit Sense 2');
  assert.equal(payloads.callbackStatePayload.status, 'succeeded');
  assert.deepEqual(
    payloads.callbackStatePayload.savedDevice,
    payloads.watchDataPayload,
  );
});

test('readCallbackStatus reports not_found, processing, failed, and succeeded callback states', async () => {
  const persistence = new InMemoryFitbitCallbackPersistence();

  const missingStatus = await persistence.readCallbackStatus({
    state: 'missing-state',
    userId: 'user-123',
  });
  assert.equal(missingStatus.kind, 'not_found');

  const processingStatus = await persistence.beginCallbackProcessing({
    state: 'oauth-state',
    userId: 'user-123',
  });
  assert.equal(processingStatus.kind, 'ready');

  const inFlightStatus = await persistence.readCallbackStatus({
    state: 'oauth-state',
    userId: 'user-123',
  });
  assert.equal(inFlightStatus.kind, 'processing');

  await persistence.markCallbackFailed({
    error: 'OAuth callback failed.',
    state: 'oauth-state',
    userId: 'user-123',
  });
  const failedStatus = await persistence.readCallbackStatus({
    state: 'oauth-state',
    userId: 'user-123',
  });
  assert.equal(failedStatus.kind, 'failed');
  assert.equal(failedStatus.error, 'OAuth callback failed.');

  await persistence.persistSuccessfulCallback({
    device: {
      battery: 'Medium',
      batteryLevel: 55,
      deviceId: 'device-123',
      deviceName: 'Fitbit Sense 2',
      deviceType: 'watch',
      lastSyncTime: '2026-04-01T11:59:00.000Z',
      macAddress: 'AA:BB:CC',
      rawPayload: { id: 'device-123' },
    },
    state: 'oauth-state',
    tokenResponse: {
      access_token: 'access-token',
      expires_in: 3600,
      refresh_token: 'refresh-token',
      scope: 'activity profile',
      token_type: 'Bearer',
      user_id: 'fitbit-user',
    },
    userId: 'user-123',
  });
  const succeededStatus = await persistence.readCallbackStatus({
    state: 'oauth-state',
    userId: 'user-123',
  });
  assert.equal(succeededStatus.kind, 'succeeded');
  assert.equal(succeededStatus.device.deviceId, 'device-123');
});

test('finalizeFitbitCallbackFlow throws a persistence error when Firestore state initialization fails', async () => {
  const persistence = new InMemoryFitbitCallbackPersistence();
  persistence.beginError = new Error('5 NOT_FOUND: ');

  await assert.rejects(
    () =>
      finalizeFitbitCallbackFlow({
        code: 'oauth-code',
        fitbitApiClient: {
          async exchangeCodeForTokens() {
            throw new Error('exchange should not run');
          },
          async fetchDevices() {
            throw new Error('fetch should not run');
          },
          selectPrimaryDevice() {
            return null;
          },
        },
        persistence,
        state: 'oauth-state',
        userId: 'user-123',
      }),
    (error) => {
      assert.equal(error instanceof FitbitCallbackPersistenceError, true);
      assert.match(
        error.message,
        /Could not start Fitbit callback persistence\./,
      );
      return true;
    },
  );
});

test('finalizeFitbitCallbackFlow throws a persistence error when recording callback failure fails', async () => {
  const persistence = new InMemoryFitbitCallbackPersistence();
  persistence.markError = new Error('5 NOT_FOUND: ');

  await assert.rejects(
    () =>
      finalizeFitbitCallbackFlow({
        code: 'oauth-code',
        fitbitApiClient: {
          async exchangeCodeForTokens() {
            throw new Error('Fitbit token exchange failed.');
          },
          async fetchDevices() {
            throw new Error('fetch should not run');
          },
          selectPrimaryDevice() {
            return null;
          },
        },
        persistence,
        state: 'oauth-state',
        userId: 'user-123',
      }),
    (error) => {
      assert.equal(error instanceof FitbitCallbackPersistenceError, true);
      assert.match(
        error.message,
        /Could not persist the Fitbit callback failure state\./,
      );
      return true;
    },
  );
});

class InMemoryFitbitCallbackPersistence {
  constructor() {
    this.beginError = null;
    this.markError = null;
    this.persistCalls = [];
    this.stateByKey = new Map();
  }

  async beginCallbackProcessing({ state, userId }) {
    if (this.beginError != null) {
      throw this.beginError;
    }

    const callbackStateDocumentId = buildFitbitCallbackStateDocumentId(
      userId,
      state,
    );
    const key = `${userId}:${state}`;
    const record = this.stateByKey.get(key);

    if (record == null) {
      this.stateByKey.set(key, { status: 'processing' });
      return { callbackStateDocumentId, kind: 'ready' };
    }

    if (record.status === 'processing') {
      return { callbackStateDocumentId, kind: 'processing' };
    }

    if (record.status === 'failed') {
      return {
        callbackStateDocumentId,
        error: record.error,
        kind: 'rejected',
      };
    }

    return {
      callbackStateDocumentId,
      device: record.device,
      kind: 'succeeded',
    };
  }

  async markCallbackFailed({ error, state, userId }) {
    if (this.markError != null) {
      throw this.markError;
    }

    this.stateByKey.set(`${userId}:${state}`, { error, status: 'failed' });
  }

  async persistSuccessfulCallback({ device, state, tokenResponse, userId }) {
    const callbackStateDocumentId = buildFitbitCallbackStateDocumentId(
      userId,
      state,
    );
    const payloads = buildFitbitPersistencePayloads({
      callbackStateDocumentId,
      connectedAt: '2026-04-01T12:00:00.000Z',
      device,
      state,
      tokenResponse,
      userId,
    });

    this.persistCalls.push({
      connectionDocumentId: payloads.connectionDocumentId,
      watchDataDocumentId: payloads.watchDataDocumentId,
    });
    this.stateByKey.set(`${userId}:${state}`, {
      device: payloads.watchDataPayload,
      status: 'succeeded',
    });

    return {
      callbackStateDocumentId,
      device: payloads.watchDataPayload,
    };
  }

  async readCallbackStatus({ state, userId }) {
    const callbackStateDocumentId = buildFitbitCallbackStateDocumentId(
      userId,
      state,
    );
    const record = this.stateByKey.get(`${userId}:${state}`);

    if (record == null) {
      return { callbackStateDocumentId, kind: 'not_found' };
    }

    if (record.status === 'processing') {
      return { callbackStateDocumentId, kind: 'processing' };
    }

    if (record.status === 'failed') {
      return {
        callbackStateDocumentId,
        error: record.error,
        kind: 'failed',
      };
    }

    return {
      callbackStateDocumentId,
      device: record.device,
      kind: 'succeeded',
    };
  }
}
