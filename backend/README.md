## Local emulators

Start the local backend with both the Functions and Firestore emulators:

```bash
cd backend/functions
npm run serve
```

On Windows, `npm run serve` now runs a Java preflight before starting Firebase. If Java is missing from PATH, it will fail early with exact setup steps instead of letting the Firebase CLI shut the emulators down with `Could not spawn java -version`.

This starts:

- Functions emulator on `http://127.0.0.1:5002`
- Firestore emulator on `127.0.0.1:8080`

Running only the Functions emulator is not enough for Fitbit callback finalization because the callback persistence flow writes callback state, Fitbit connection, and `watch_data` documents to Firestore.

Windows verification:

```powershell
java -version
where java
cd backend\functions
npm run serve
```

If you only want to check prerequisites without starting the emulators:

```powershell
cd backend\functions
npm run preflight:emulators
```
