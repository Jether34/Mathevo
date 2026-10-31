# Mathevo implementation status

This document distinguishes working app flows from planned features. Test coverage demonstrates selected examples and does not establish correctness for every input.

## Implemented

| Area | Current scope |
| --- | --- |
| App shell | Five compact floating navigation destinations, with active-page color and transparent space around the navigation island. |
| Onboarding and accounts | Welcome, onboarding, signup, login, and logout flows. Cloud signup and login use the separate backend service. The calculator and local app data remain available without an account. |
| Dashboard | Daily challenge, local streak and XP, feature shortcuts, and ten newest activities. History opens the saved calculation list. |
| Calculator | Basic and scientific expression evaluation, geometry calculations, trigonometric calculations, graph plotting and function evaluation, selected algebra equation solving, selected differentiation and integration, and number-system conversions and operations. Keys and available operations change by calculator mode. |
| Calculator workflow | Live expression evaluation, explicit equals action for committing a result, continuation after a result, calculation sessions, local history, calculation detail, and a continue action. |
| Visualization | Selected geometry and trigonometry visualizations, with interactive parameters for supported views. Graphing supports the implemented function and plot types only. |
| Lessons | Search, category navigation, a starter lesson, local progress, and XP awards for supported lesson actions. |
| Community | Search and feed tabs are present. Shared posts, accounts, messages, and ranking data are not connected, and unavailable states are shown. |
| Local profile and settings | Device-local profile details and photo, appearance preference, and locally stored progress. |
| Cloud account backend | Separate API and PostgreSQL schema with signup, login, refresh, logout, and current-user routes. See [`../backend/README.md`](../backend/README.md). |

Calculation results are limited to the operations implemented by the app's math engine and mode-specific handlers. They do not amount to a general symbolic computer algebra system.

## Known limitations

- Geometry, trigonometry, graphing, algebra, calculus, and number systems each cover selected operations. They do not support every topic or every operation in their fields.
- Algebra solving handles selected linear and quadratic equations and supported small systems. General symbolic solving and proof are not implemented.
- Calculus supports selected derivatives, antiderivatives, and definite numerical integration. General symbolic calculus, differential equations, vector calculus, and formal solution derivations are not implemented.
- Graphs and geometry views cover selected two-dimensional and three-dimensional examples. There is no general-purpose 3D math visualization workspace.
- The solution and explanation experience is not a general verified tutor. Unsupported inputs must be treated as unsupported rather than inferred as solved.
- Handwriting input is present, but recognition accuracy and complex math structure recognition are not verified by the Android end-to-end test.
- Calculation history, profile, learning progress, appearance, streaks, and XP are local to the device. Account synchronization and cross-device recovery are not implemented.
- Community feed controls do not connect to shared user content, messaging, moderation, or global rankings.
- Local challenge and XP data are not protected against device modification. There are no server-validated achievements or leaderboards.
- Settings do not yet provide complete account recovery, biometrics, notification delivery controls, broad localization, or all accessibility and math-input preferences.
- Android emulator use was verified. iOS device builds and releases require verification on a supported macOS host.

## Verification record

- `flutter analyze --no-pub`: passed with no issues.
- `flutter test --reporter expanded`: 23 unit and widget tests passed.
- `flutter test integration_test/calculator_e2e_test.dart -d emulator-5554`: passed for the included onboarding, in-memory signup, representative calculator modes, and drawing-route smoke check.
- Emulator was cleared of stale app form/session state, rebuilt from this workspace, and left on the welcome screen. No cloud account was created during this verification.

The integration test uses an in-memory authentication service. It does not test the live VPS backend, recognition accuracy, or all operation combinations.

## Next work in order

1. Expand the math engine into separate tested modules for exact arithmetic, algebra, geometry, trigonometry, graphing, calculus, number systems, linear algebra, probability, and statistics. Define domain rules, precision, and unsupported cases for each operation.
2. Add broad property-based and reference-based numerical tests, edge cases, and independent checks for calculations and transformations.
3. Improve the math editor with structured fractions, exponents, matrices, LaTeX input, keyboard navigation, validation, and editing at arbitrary expression positions.
4. Complete responsive and accessibility review across screen sizes, orientations, text scaling, themes, and assistive technologies.
5. Add reviewed learning materials, meaningful progress tracking, and verified explanation steps derived from supported transformations.
6. Build shared account data and synchronization with authorization, privacy, account recovery, user-controlled export and deletion, and schema migrations.
7. Connect community posts, replies, messaging, moderation, and server-backed leaderboards only after identity and safety controls are in place.
8. Improve handwriting recognition with editable recognition results and clear uncertainty. Validate device-specific camera and input behavior.
9. Add release automation, monitoring, backups, recovery procedures, and Android and iOS release validation.
