# Carebit Frontend

## Development

`flutter run` now uses the deployed Carebit Firebase Functions backend by
default. That keeps the Fitbit connection flow working on physical Android
devices without extra shell commands or `--dart-define` flags.

## Optional Local Backend Override

If you want to target a local Functions emulator instead of the deployed
backend, run the app with:

```bash
flutter run --dart-define=CAREBIT_BACKEND_HOST=<HOST>
```

Examples:

- Android emulator: `10.0.2.2`
- Physical Android phone on the same LAN as your machine: your PC LAN IP

The local Functions emulator is expected on port `5002`.
