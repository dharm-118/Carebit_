## Backend emulator setup on Windows

Carebit local Fitbit callback development uses both the Firebase Functions emulator and the Cloud Firestore emulator.

Why Java is required:
- the Cloud Firestore emulator is Java-based
- `npm run serve` in `backend/functions` starts `functions,firestore`

Recommended startup flow:

```powershell
java -version
where java
cd backend\functions
npm run serve
```

If Java is missing from PATH, the checked-in emulator launcher now fails early with an actionable message before Firebase CLI shuts the emulator suite down.

If you only want to validate prerequisites:

```powershell
cd backend\functions
npm run preflight:emulators
```
