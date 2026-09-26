# UI redesign — SAETA Ciudadano v2

## Objective
Apply the approved redesign (design canvas
https://claude.ai/artifact/231FGbF8v6tJEeQz63rAsz, version "Frontend v2
palette, pro look") to the Flutter citizen app.

## Problem / why
The current UI uses a seed-generated Material palette, mixed English/Spanish
copy and ad-hoc styling. The user wants a professional look aligned with the
`saeta-frontend-v2` admin palette.

## Scope
- Theme foundation: colors, typography (IBM Plex Sans + IBM Plex Mono,
  bundled), component themes.
- Shared UI widgets: state pill, section card, bottom navigation.
- Screens: Login (+ Register restyle), Emergencia + report confirmation,
  Mis alertas + alert detail, Mi perfil + profile edit.
- All UI copy in Spanish (Login/Register currently use English labels).

Out of scope: behavior changes to data/domain layers, backend contracts,
new features beyond presentation (the alerts summary and Active/History
grouping are derived from already-loaded alerts).

## Constraints
- Clean architecture per feature; presentation-only changes unless a task
  says otherwise.
- TDD: strict (source: user global config). Runner: `flutter test`.
- Checks per task: `flutter test`, `flutter analyze`.
- Branch `feat/ui-redesign` from `feat/profile-edit-avatar` (T8–T10 of
  `ciudadano-v2-parity`, not pushed). One work-unit commit per task,
  Conventional Commits, no AI attribution lines.

## Design tokens (from saeta-frontend-v2)
- Primary `#1976D2`, primary dark `#1565C0`, primary tint `#E8F1FB`.
- Heading `#2B354F`, text `#334155`, muted `#64748B`, border `#E2E8F0`,
  background `#F4F6F9`, surface `#FFFFFF`.
- Danger (SOS / send alert) `#E11D48`, danger tint `#FFE4E6`/`#FFF1F2`.
- States (bg / border / text / dot):
  - Pendiente `#FFFBEB` / `#FDE68A` / `#B45309` / `#F59E0B`
  - En proceso `#F0F9FF` / `#BAE6FD` / `#0369A1` / `#0EA5E9`
  - Resuelta `#ECFDF5` / `#A7F3D0` / `#047857` / `#10B981`
  - Cancelada `#FFF1F2` / `#FECDD3` / `#BE123C` / `#F43F5E`
- Radii: cards 12, hero cards 16, buttons/inputs 10. Touch targets >= 44.

## Tasks
- [x] U1 — Theme foundation: `AppColors`, `AppTheme` (ThemeData, text theme with bundled IBM Plex Sans/Mono, input/button/card/nav themes), wire into `app.dart`. (route: delegated direct)
- [x] U2 — Shared widgets: `AlertStatePill` (state → colors), `SectionCard`, bottom navigation restyle. (route: delegated direct)
- [x] U3 — Login + Register restyle, Spanish copy. (route: delegated direct)
- [x] U4 — Emergencia view (blue header, SOS circle, incident grid, SMS row) + report confirmation sheet. (route: delegated direct)
- [ ] U5 — Mis alertas (summary counts, Active/History grouping, cards) + alert detail sheet (summary, map, tracking timeline, attention data, rating). (route: delegated direct)
- [ ] U6 — Mi perfil (identity card, personal data, contacts, SMS switch, logout) + profile edit page. (route: delegated direct)

## Acceptance criteria
- Every screen matches the canvas layout, tokens and Spanish copy; no
  existing behavior (auth, alerts, realtime, SMS, avatar, rating, map) is
  lost.
- `flutter test` and `flutter analyze` pass at every task closure.
- Tests updated for new copy; new tests for derived presentation logic
  (state → pill colors, Active/History grouping, summary counts).

## Delivery
- Forecast: well above 400 authored changed lines (6 tasks). Strategy:
  `ask-on-risk` (default); chain strategy `feature-branch-chain` (user
  choice, 2026-09-26): slice PRs target `feat/ui-redesign`, one final PR
  from the branch to `main`. Push/PR creation remains the user's decision.
- Slices: (to be recorded per PR once the user decides to open them).

## Progress
- 2026-09-26: document created; branch `feat/ui-redesign` created.
- 2026-09-26: U1 done. Fonts bundled from the official IBM/plex GitHub
  releases (`@ibm/plex-sans@1.1.0`, `@ibm/plex-mono@2.5.0` — the
  `google/fonts` mirror only ships a variable font, not discrete weight
  TTFs) into `assets/fonts/` (Regular/Medium/SemiBold/Bold for IBM Plex
  Sans, Medium for IBM Plex Mono) + `OFL.txt`, declared in `pubspec.yaml`
  `fonts:`. Added `lib/core/theme/app_colors.dart` (`AppColors`,
  `AlertStatePalette`, the 4 state palettes + neutral fallback) and
  `lib/core/theme/app_theme.dart` (`AppTheme.light`, `AppRadii`,
  `AppDimens`, `AppFonts`). Wired into `lib/app.dart` (replaced the seed
  `ThemeData`). TDD: RED observed (compile error, `Undefined name
  'AppColors'`/`'AppFonts'`) on `test/core/theme/app_colors_test.dart` +
  `test/core/theme/app_theme_test.dart` before writing the sources; GREEN
  after (14/14 new tests). Checks: `flutter test` 184/184 passed (170
  baseline + 14 new); `flutter analyze` 0 issues (fixed 3 `prefer_const`/
  `unnecessary_const` infos along the way). Files: `pubspec.yaml`,
  `assets/fonts/*`, `lib/app.dart`, `lib/core/theme/app_colors.dart`,
  `lib/core/theme/app_theme.dart`, `test/core/theme/app_colors_test.dart`,
  `test/core/theme/app_theme_test.dart`. Commit: `d5f7140`.
- 2026-09-26: U2 done. Added
  `lib/features/alerts/presentation/widgets/alert_state_pill.dart`
  (`AlertStatePill`, `paletteFor` mapping — same case-insensitive
  substring convention as `CitizenAlertEntity.isResolved`/etc. and
  `alertMarkerHue`; unmatched state -> `AppColors.neutral`) and
  `lib/core/widgets/section_card.dart` (`SectionCard`, generic enough to
  be reused outside the alerts feature, hence `core/widgets` over
  `features/alerts`). Restyled the bottom nav in `main_page.dart`:
  replaced the Material 3 `NavigationBar` (which has no per-item top
  indicator bar or a themeable top border) with a new public
  `AppBottomNavigationBar` widget in the same file (white bg, `E2E8F0`
  top border, 3px primary top indicator + semibold label on the active
  item) — kept `MainPage`'s existing `MainNavigationProvider`/index
  wiring unchanged. Mechanically swapped the existing ad-hoc state
  chips for `AlertStatePill` in `alert_card.dart` (the colored
  `Container`+`Text` badge) and `alert_detail_sheet.dart` (the plain
  uncolored `Chip`); left `alert_card.dart`'s `_getStatusColor`/
  `_getStatusBackgroundColor` in place since the type-icon `CircleAvatar`
  still uses them (full card restyle is U5). TDD: RED observed
  (`Method not found: 'SectionCard'/'AppBottomNavigationBar'`, missing
  `alert_state_pill.dart`) on all 3 new test files before writing the
  sources; GREEN after (14/14 new tests: 8 pill + 3 SectionCard + 3 nav).
  Checks: `flutter test` 198/198 passed (184 baseline + 14 new);
  `flutter analyze` 0 issues; `flutter build apk --debug` succeeded
  (`app-debug.apk`, not installed/run — emulator has little disk space
  per instructions). Files:
  `lib/features/alerts/presentation/widgets/alert_state_pill.dart`,
  `lib/core/widgets/section_card.dart`,
  `lib/features/main/presentation/pages/main_page.dart`,
  `lib/features/alerts/presentation/widgets/alert_card.dart`,
  `lib/features/alerts/presentation/widgets/alert_detail_sheet.dart`,
  `test/features/alerts/presentation/widgets/alert_state_pill_test.dart`,
  `test/core/widgets/section_card_test.dart`,
  `test/features/main/presentation/pages/app_bottom_navigation_bar_test.dart`.
  Commit: `88afb34`.
- 2026-09-26: U3 done. Restyled `LoginPage`/`RegisterPage` to the canvas:
  blue `#1976D2` header band (`SaetaLogo.brandMark` — new named
  constructor added to the existing `saeta_logo.dart` rather than a
  duplicate widget: white 56px rounded-14 icon tile + "SAETA" wordmark +
  optional subtitle, white-on-primary) overlapped by a white radius-16
  hero card (`Transform.translate` paint-only shift, since
  `Container.margin` asserts non-negative insets — leaves a harmless
  sliver of extra scrollable space below the card, no test/behavior
  impact). Restyled `saeta_text_field.dart` (label rendered above the
  input as its own 13px semibold `Text`, not `InputDecoration.labelText`;
  `prefixIcon` now optional; added `onChanged`) and reused it for
  register's DNI field (dropped the separate `_DniField` private widget).
  Added `AppColors.onPrimaryMuted` (`#D6E6F7`, header subtitle). All
  copy translated to Spanish, including validation messages (e.g. "El
  correo es obligatorio", "Ingresa un correo válido", "La contraseña es
  obligatoria", "Las contraseñas no coinciden") and the error dialog's
  dismiss button ("Cerrar", matching the existing convention in
  `profile_view.dart`/`emergency_view.dart` — was "OK"). Register's old
  outlined "Cancel" button was replaced by the canvas's "¿Ya tienes
  cuenta? Inicia sesión" link (same `context.pop()` behavior). Kept all
  bloc events, validators' rules (email format, DNI 8 digits, phone 9
  digits starting with 9, password confirmation), remember-me, DNI
  RENIEC auto-fill lookup and navigation unchanged. TDD: RED observed
  (compile errors — `Member not found: 'SaetaLogo.brandMark'`,
  `AppColors.onPrimaryMuted`, `SaetaTextField`'s now-required
  `prefixIcon`/missing `onChanged` — plus 11-14 runtime failures for the
  still-English copy) on all 4 new test files before writing the
  sources; GREEN after (19/19 new tests: 3 `SaetaLogo` + 4
  `SaetaTextField` + 6 `LoginPage` + 6 `RegisterPage`). One mid-GREEN
  fix: `Container.margin` doesn't accept negative `EdgeInsets`
  (assertion failure), switched the overlap to `Transform.translate`;
  and widget tests needed `tester.ensureVisible(...)` before tapping the
  submit buttons (off-screen in the default 800x600 test viewport inside
  the `SingleChildScrollView`). Checks: `flutter test` 217/217 passed
  (198 baseline + 19 new); `flutter analyze` 0 issues (fixed 1 unused
  test import). Files: `lib/core/theme/app_colors.dart`,
  `lib/features/auth/presentation/pages/login_page.dart`,
  `lib/features/auth/presentation/widgets/saeta_logo.dart`,
  `lib/features/auth/presentation/widgets/saeta_text_field.dart`,
  `lib/features/register/presentation/pages/register_page.dart`,
  `test/features/auth/presentation/widgets/saeta_logo_test.dart`,
  `test/features/auth/presentation/widgets/saeta_text_field_test.dart`,
  `test/features/auth/presentation/pages/login_page_test.dart`,
  `test/features/register/presentation/pages/register_page_test.dart`.
  Commit: `1bdbe3a`.
- 2026-09-26: U4 done. Restyled `EmergencyView`: blue `#1976D2` header
  band (small 34px icon tile + "SAETA"/"Ciudadano", 40px initials avatar
  → switches to the Perfil tab, "Hola, {nombre}") overlapped by a white
  radius-16 hero card (`Transform.translate`, same paint-only overlap
  technique as U3's login/register cards). No GPS pill: `MainNavigationProvider`
  has no location state and this task is presentation-only, so adding one
  was out of scope — omitted per the task's own instruction. Restyled
  `SosButton` to the two-circle design (168px `AppColors.dangerTint` ring
  / 136px `AppColors.danger` circle, "SOS" + label) and `EmergencyTypeCard`
  to a white bordered tile with a 38px `AppColors.primaryTint` icon square
  (dropped its `backgroundColor` param — only ever used by this view).
  Reordered/relabeled the incident grid to the canvas's single-line
  Spanish labels ("Robo", "Incendio", "Accidente de tránsito",
  "Pandillaje", "Violencia familiar", "Otro") while keeping the
  backend-facing type name passed to `sendAlert`/the SMS body unchanged
  (e.g. grid shows "Accidente de tránsito", `_triggerSendAlert` still
  gets "Accidente de Tránsito") — decouples display copy from the
  existing type-matching/SMS-text behavior. Added the "SMS a contactos de
  emergencia" row (reuses `AppColors.resuelta.background/.text`, an exact
  hex match for the canvas's `#ECFDF5`/`#047857`) driven by
  `EmergencyContactsProvider.sendSmsOnAlert`/`.contacts`, tapping it also
  switches to Perfil. Replaced the `AlertDialog` confirmation with a
  modal bottom sheet (top radius 20, grabber, type icon, bordered info
  list) — GPS row always shows "Se obtendrá al enviar" (position isn't
  fetched until after confirmation, so there's never a coordinate to
  show at this point) and the SMS row only when enabled with ≥1 contact;
  kept the exact same post-confirmation flow (`sendAlert`,
  `AlertsProvider.refreshAlerts`, `EmergencyContactsProvider.sendSmsForAlert`,
  success/error dialogs) — success dialog title restyled to "Alerta
  enviada" (spec's lowercase, was "Alerta Enviada"); the error dialog's
  dismiss button was already "Cerrar". SOS button's own alert flow (type
  "Emergencia") is unchanged. TDD: RED observed (10/11 new tests failing
  — missing header/grid/SMS-row copy, sheet not opening, wrong dialog
  title) on the new `emergency_view_test.dart` before writing the
  sources; GREEN after (11/11). Two mid-GREEN fixes: (1) a same-named
  "SMS a contactos de emergencia" label exists both in the persistent row
  and, conditionally, inside the sheet, so the "hidden when SMS is off"
  assertion had to check the value text instead of the shared label; (2)
  `EmergencyProvider.sendAlert()` calls the real Geolocator plugin, which
  hangs forever under `flutter test` with no platform binding registered
  — mocked the `flutter.baseflow.com/geolocator` method channel
  (`isLocationServiceEnabled: false`) so `_determinePosition()`'s own
  fallback kicks in immediately, and used bounded `tester.pump(...)`
  calls instead of `pumpAndSettle()` after sending (the loading overlay's
  indeterminate `CircularProgressIndicator` never lets `pumpAndSettle`
  converge). Checks: `flutter test` 228/228 passed (217 baseline + 11
  new); `flutter analyze` 0 issues. Files:
  `lib/features/main/presentation/pages/emergency_view.dart`,
  `lib/features/main/presentation/widgets/sos_button.dart`,
  `lib/features/main/presentation/widgets/emergency_type_card.dart`,
  `test/features/main/presentation/pages/emergency_view_test.dart`.
  Commit: left for the user to record.
