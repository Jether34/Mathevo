# Mathevo

Mathevo is an offline-first mathematics app built with Flutter. It brings calculator tools, interactive math views, learning, personal progress, and calculation history into one mobile app.

## Current app

- **Home:** daily challenge, streak and XP summary, shortcuts to app areas, and the ten newest activities.
- **Calculator:** Basic, Scientific, Geometry, Trigonometry, Graphing, Algebra, Calculus, Number Systems, and Discrete Math modes. Scientific, graphing, and trigonometry keys include selected inverse and hyperbolic functions, cube roots, logarithms, and rounding operations. Graphing accepts `y=f(x)` and `z=f(x,y)` forms. Number Systems has a base-aware digit keypad. Discrete Math supports selected number theory, modular arithmetic, permutations and combinations, ratios and percentages, finite set operations, and propositional logic. Each mode remains limited to the operations listed in [`docs/MATH_IMPLEMENTATION_CHECKLIST.md`](docs/MATH_IMPLEMENTATION_CHECKLIST.md). Drawing mode opens handwriting input; recognition depends on the installed device plugin and is not covered by calculator end-to-end tests.
- **History:** saved calculation sessions with a detail view and a continue action. Records are stored locally on the device.
- **Learning:** lesson search and categories, a starter lesson, and local progress rewards.
- **Community:** feed controls and search with explicit unavailable states when shared content is not connected.
- **Settings and profile:** local profile and appearance preferences, plus the cloud account flow.
- **Cloud account service:** optional signup and login through the separately deployed backend in [`backend/`](backend/README.md). The calculator remains usable offline.

The calculator implements a finite set of operations, not a general-purpose computer algebra system. See [`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md) for verified scope and [`docs/MATH_IMPLEMENTATION_CHECKLIST.md`](docs/MATH_IMPLEMENTATION_CHECKLIST.md) for the complete requested-domain checklist and remaining work.

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

The app has Flutter unit/widget tests and Android integration tests. The discrete-math integration test enters commands through the on-screen calculator keys and checks results on the emulator. These checks cover selected examples only, not every mathematical edge case or every listed math field. They do not validate live cloud signup or handwriting recognition accuracy.

Run the checks with:

```sh
flutter analyze --no-pub
flutter test --reporter expanded
flutter test test/discrete_math_test.dart
flutter test integration_test/discrete_math_e2e_test.dart -d emulator-5554
```

The Android emulator has the current debug build installed. A dashboard session requires signing in.

## Project map

- `lib/`: Flutter app, authentication flow, math engine, and local data.
- `test/`: unit and widget tests.
- `integration_test/`: Android app-flow and calculator tests.
- `backend/`: isolated account API, database schema, and deployment files.
- `docs/IMPLEMENTATION_STATUS.md`: implemented scope, known limitations, and ordered next work.
- `docs/MATH_IMPLEMENTATION_CHECKLIST.md`: requested mathematics domains and their current implementation status.
- `Animated/`: app animation assets.

## License

See [`LICENSE`](LICENSE).
