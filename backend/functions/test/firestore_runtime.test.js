const test = require('node:test');
const assert = require('node:assert/strict');

const {
  describeFirestorePersistenceError,
  readFirestorePersistenceReadinessIssue,
  readFirestoreRuntimeHealth,
} = require('../lib/services/firestore_runtime.js');

test('readFirestoreRuntimeHealth reports missing Firestore emulator in local Functions development', () => {
  const health = readFirestoreRuntimeHealth({
    FIREBASE_CONFIG: JSON.stringify({ projectId: 'carebit-e30d4' }),
    FUNCTIONS_EMULATOR: 'true',
  });

  assert.equal(health.mode, 'project');
  assert.equal(health.persistenceReady, false);
  assert.equal(health.projectId, 'carebit-e30d4');
  assert.match(health.warning, /Firestore emulator is not running/);
  assert.match(
    readFirestorePersistenceReadinessIssue({
      FIREBASE_CONFIG: JSON.stringify({ projectId: 'carebit-e30d4' }),
      FUNCTIONS_EMULATOR: 'true',
    }),
    /functions,firestore/,
  );
});

test('describeFirestorePersistenceError explains project Firestore NOT_FOUND outside the emulator', () => {
  const message = describeFirestorePersistenceError(
    { code: 5, message: '5 NOT_FOUND: ' },
    {
      GCLOUD_PROJECT: 'carebit-e30d4',
    },
  );

  assert.match(message, /Firestore database is not available/);
  assert.match(message, /carebit-e30d4/);
});

test('describeFirestorePersistenceError explains emulator recovery when Firestore emulator is configured', () => {
  const message = describeFirestorePersistenceError(
    { code: 5, message: '5 NOT_FOUND: ' },
    {
      FIREBASE_CONFIG: JSON.stringify({ projectId: 'carebit-e30d4' }),
      FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
      FUNCTIONS_EMULATOR: 'true',
    },
  );

  assert.match(message, /Firestore emulator could not satisfy/);
});
