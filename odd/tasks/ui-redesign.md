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
- [ ] U2 — Shared widgets: `AlertStatePill` (state → colors), `SectionCard`, bottom navigation restyle. (route: delegated direct)
- [ ] U3 — Login + Register restyle, Spanish copy. (route: delegated direct)
- [ ] U4 — Emergencia view (blue header, SOS circle, incident grid, SMS row) + report confirmation sheet. (route: delegated direct)
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
  `test/core/theme/app_theme_test.dart`. Commit: recorded in the next
  (U2) commit message trailer, since this file is committed together
  with the U1 sources.
