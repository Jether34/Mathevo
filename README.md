# Mathevo

Mathevo is an offline-first mathematics app built with Flutter. It brings calculator tools, interactive math views, learning, personal progress, and calculation history into one mobile app.

## Current app

- **Home:** daily challenge, streak and XP summary, shortcuts to app areas, and the ten newest activities.
- **Calculator:** Basic, Scientific, Geometry, Trigonometry, Graphing, Algebra, Calculus, Number Systems, Discrete Math, Statistics, Probability, and Physics modes. The expression card expands into a borderless editor, and the answer replaces the expression after equals. Fraction entry exposes separate numerator and denominator boxes within the expression workspace. Statistics supports mean, median, mode, range, sum, count, quartiles, variance, and standard deviation for finite numeric lists. Probability supports event probability, complement, odds, binomial probability, combinations, and permutations. Physics supports constant-speed motion with `distance(v,t)`, `velocity(d,t)`, and `time(d,v)`; enter values in consistent units. Scientific and graphing modes include selected inverse and hyperbolic functions, cube roots, logarithms, and rounding operations. Graphing accepts `y=f(x)` and `z=f(x,y)` forms. Number Systems has a base-aware digit keypad. Discrete Math supports selected number theory, modular arithmetic, permutations and combinations, ratios and percentages, finite set operations, and propositional logic. Each mode remains limited to the operations listed in [`docs/MATH_IMPLEMENTATION_CHECKLIST.md`](docs/MATH_IMPLEMENTATION_CHECKLIST.md). Draw mode uses ML Kit for full-expression transcription and a compact offline model for suggestions on a single isolated digit or arithmetic symbol. See [`docs/handwriting_symbol_reader.md`](docs/handwriting_symbol_reader.md) for coverage and limitations.
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

The app has Flutter unit/widget tests and Android integration tests. The discrete-math integration test enters commands through the on-screen calculator keys and checks results on the emulator. These checks cover selected examples only, not every mathematical edge case or every listed math field. They do not validate live cloud signup or the accuracy of Mathevo's full-expression handwriting recognition. The isolated-symbol model's reported score comes from the held-out HASYv2 fold documented in [`docs/handwriting_symbol_reader.md`](docs/handwriting_symbol_reader.md).

Run the checks with:

```sh
flutter analyze --no-pub
flutter test --reporter expanded
flutter test test/discrete_math_test.dart
flutter test integration_test/discrete_math_e2e_test.dart -d emulator-5554
```

The Android emulator has the current debug build installed. A dashboard session requires signing in.

## Project map

- `lib/main.dart`: app startup, authentication/session wiring, and shared library imports.
- `lib/ui/app_pages.dart`: calculator, dashboard, lessons, community, settings, and related page widgets.
- `lib/math_engine.dart`: expression evaluation and symbolic/numeric math operations.
- `lib/statistics_probability_engine.dart`: selected descriptive statistics, probability, and constant-speed motion calculations.
- `lib/visualization/plot_formula.dart`: plot-expression classification and central-difference recognition.
- `lib/visualization/math_visualization_painter.dart`: visualization dispatch and existing geometry/surface renderers.
- `lib/visualization/plot_2d_renderer.dart` and `lib/visualization/plot_3d_renderer.dart`: dimension-specific finite-difference/scalar plot rendering.
- `test/`: unit and widget tests.
- `integration_test/`: Android app-flow, calculator, and visualization tests.
- `backend/`: isolated account API, database schema, and deployment files.
- `docs/IMPLEMENTATION_STATUS.md`: implemented scope, known limitations, and ordered next work.
- `docs/MATH_IMPLEMENTATION_CHECKLIST.md`: requested mathematics domains and their current implementation status.
- `Animated/`: app animation assets.

For the central-difference expression `((3+0.01)^2-(3-0.01)^2)/(2*0.01)`, the plot recognizes the underlying `f(x)=x²`, marks the samples around `x=3`, and reports a derivative of 6. The 3D view renders the curve and secant in the coordinate frame. It does not present a curve as a shaded surface or report a surface area.

## License

See [`LICENSE`](LICENSE).
