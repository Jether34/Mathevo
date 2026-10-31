# Mathevo

Mathevo is an offline-first mathematics app built with Flutter. It brings calculator tools, interactive math views, learning, personal progress, and calculation history into one mobile app.

## Current app

- **Home:** daily challenge, streak and XP summary, shortcuts to app areas, and the ten newest activities.
- **Calculator:** Basic, Scientific, Geometry, Trigonometry, Graphing, Algebra, Calculus, and Number Systems modes. Mode-specific input keys and tools are available where implemented. Drawing mode opens handwriting input; recognition depends on the installed device plugin and is not covered by the calculator end-to-end test.
- **History:** saved calculation sessions with a detail view and a continue action. Records are stored locally on the device.
- **Learning:** lesson search and categories, a starter lesson, and local progress rewards.
- **Community:** feed controls and search with explicit unavailable states when shared content is not connected.
- **Settings and profile:** local profile and appearance preferences, plus the cloud account flow.
- **Cloud account service:** optional signup and login through the separately deployed backend in [`backend/`](backend/README.md). The calculator remains usable offline.

The calculator implements a finite set of operations, not a general-purpose computer algebra system. See [`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md) for verified scope and remaining work.

## Run locally

Requirements: Flutter 3.44 or later, Dart 3.12 or later, and Android Studio or an Android SDK for Android builds.

```sh
flutter pub get
flutter run
```

Build an Android APK:

```sh
flutter build apk
```

Cloud signup, email verification, login, and password reset use the existing HTTPS account service and pinned certificate configuration. The deployed API address and public certificate are defaults in the app. For a different environment, override them at build time:

```sh
flutter run --dart-define=MATHVERSE_API_BASE_URL=https://your-api-host:18443 --dart-define=MATHVERSE_API_CERTIFICATE_ASSET=assets/certs/server.crt
```

The app communicates with the existing account service. Keep `.env`, database credentials, JWT signing secrets, and TLS private keys out of source control.

## Verification

The app has Flutter unit/widget tests and an Android integration test at [`integration_test/calculator_e2e_test.dart`](integration_test/calculator_e2e_test.dart). The integration test uses an in-memory auth service and exercises representative operations across the calculator modes, then checks the drawing-mode route. It does not validate live cloud signup, handwriting recognition accuracy, or every mathematical edge case.

Run the checks with:

```sh
flutter analyze --no-pub
flutter test --reporter expanded
flutter test integration_test/calculator_e2e_test.dart -d emulator-5554
```

The Android emulator has the current debug build installed. A dashboard session requires signing in.

## Project map

- `lib/`: Flutter app, authentication flow, math engine, and local data.
- `test/`: unit and widget tests.
- `integration_test/`: Android app-flow and calculator test.
- `backend/`: isolated account API, database schema, and deployment files.
- `docs/IMPLEMENTATION_STATUS.md`: implemented scope, known limitations, and ordered next work.
- `Animated/`: app animation assets.

## License

See [`LICENSE`](LICENSE).
