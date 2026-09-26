# Feature: ciudadano-v2-parity

## Objective
Bring the Flutter citizen app (`saeta_ciudadano_v2`) to functional parity with the legacy Android app (`saeta-ciudadano`) on the two most critical gaps.

## Problem / Why
- The refresh token is stored but never used: when the access token expires, every authenticated call fails with 401 and the session is effectively broken.
- Emergency contacts + SMS on alert (core safety feature of the legacy app) do not exist in v2.

## Scope
- T1: Token refresh on 401 (Dio interceptor, centralized Bearer header, session-expired handling).
- T2: Emergency contacts management (max 5, picked from device contacts, "send SMS" toggle) + SMS dispatch on alert. Decision made and implemented: open the device SMS composer (no `SEND_SMS` permission, no silent SMS) — see T2 evidence below.
- T3: Socket.IO client (real-time `updatedAlert` / `disableUser` from the backend gateway).
- T4: Reset the local "send SMS on alert" preference at every end-of-session path.

- T8/T9 (added 2026-09-25, user-authorized): profile edit and avatar upload, on stacked branch `feat/profile-edit-avatar` (from `fix/realtime-reconnect-autologin`).

- T10 (added 2026-09-25, user-authorized): Google Maps in the alert detail, same branch.

Out of scope: change password (tracked as a later gap).

## Constraints
- Clean architecture per feature (data/domain/presentation), get_it DI, dartz Either.
- Backend contract: `POST /v1/auth/refresh` body `{ refreshToken }` → `{ accessToken, refreshToken, user }`.
- Backend realtime contract (`saeta-backend-v2/src/realtime/presentation/gateways/realtime.gateway.ts`, read-only, already merged on that repo's `main`): client connects with `auth: { token }` (access token only; a refresh token or missing token gets `client.disconnect(true)`); server auto-joins `user:{id}`/`role:{role}` rooms; citizen clients receive `updatedAlert` (payload: `AlertEntity`, only for alerts they own) and `disableUser` (payload: a plain string message, followed by a server-side forced disconnect); citizens never emit anything.
- TDD: strict (source: user global config). Runner: `flutter test`.
- Repository is git-backed; T5–T7 live on branch `fix/realtime-reconnect-autologin` (from `main`); one work-unit commit per task.

## Tasks
- [x] T1 — Token refresh interceptor (route: delegated direct — touches http_client, secure_storage, service_locator, 2 datasources, auth bloc/app navigation + tests)
- [x] T2 — Emergency contacts + SMS on alert. Decision: open the device SMS composer (url_launcher `sms:`), no SEND_SMS permission. Also narrowed AuthInterceptor public paths: only `POST /v1/users` and `GET /v1/users/dni/:dni` are public; `PATCH`/`GET /v1/users/:id` need the Bearer header (route: delegated direct — new `emergency_contacts` feature across data/domain/presentation, `AuthInterceptor` fix, `SecureStorage`, `service_locator`, profile/emergency UI hooks + tests).
- [x] T3 — Socket.IO client: `updatedAlert` live-updates `AlertsProvider`, `disableUser` clears the session and signals the app (route: delegated direct — new `core/realtime` (interface + socket_io_client adapter + service impl), `core/network/account_disabled_notifier.dart`, `service_locator`, `app.dart`, `AlertsProvider`, `MainNavigationProvider`, `main_page.dart` wiring + tests).
- [x] T4 — Reset the local "send SMS on alert" preference on every end-of-session path (manual logout, session expiry, `disableUser`) (route: delegated direct, bundled with T3 since it depends on T3's `disableUser` handling — one-line change in `SecureStorage.clearSession()` + tests).
- [x] T5 — Socket reconnection with exponential backoff + auth-refresh-once, replacing T3's "exactly one retry then dead until restart" policy (route: delegated direct — `core/realtime/realtime_service_impl.dart` + `realtime_service.dart` interface, new `core/network/token_refresher.dart` extracted from `AuthInterceptor`, `AuthInterceptor` refactor to use it, `service_locator`, `app.dart` (foreground-resume hook), `pubspec.yaml` (`fake_async` dev dep) + tests).
- [x] T6 — Auto-login on app start via `GET /v1/auth/me` (route: delegated direct — `AuthBloc._onSessionChecked`, new `GetCurrentUserUseCase` + `AuthRepository.getCurrentUser` + `AuthRemoteDataSource.getCurrentUser`, `service_locator` + tests). Commit `a836a74`.
- [x] T7 — Listen to the backend's new `updatedProfile` socket event and live-update the profile view and emergency contacts (route: delegated direct — writer trigger: `RealtimeService` interface + impl, `MainNavigationProvider`, `EmergencyContactsProvider`, `service_locator`/`main_page` wiring + tests).
- [x] T8 — Edit own profile (name, lastname, phone, email) via `PATCH /v1/users/:id` (route: delegated direct — new `profile` feature data/domain/presentation, edit form UI, `service_locator` + tests).
- [x] T9 — Avatar upload from camera or gallery via `PUT /v1/uploads/:id` and display via `GET /v1/uploads/:photo` (route: delegated direct — `image_picker` dependency, platform permissions, profile feature extension, UI + tests).
- [x] T10 — Google Maps in alert detail: marker at the alert's coordinates, colored by state, legacy map style (route: delegated direct — `google_maps_flutter` dependency, Android/iOS key wiring, `alert_detail_sheet.dart`, map helpers + tests).

## Acceptance criteria
- T1: a 401 on an authenticated request triggers exactly one refresh (concurrent 401s share it), tokens are persisted, the original request is retried once; a failed refresh clears the session and returns the user to login. Refresh endpoint itself never loops.
- T2: `AuthInterceptor` treats exactly `POST /v1/auth/login`, `POST
  /v1/auth/refresh`, `POST /v1/users` (register) and `GET /v1/users/dni/:dni`
  as public; every other `/v1/users/...` call (notably `GET`/`PATCH
  /v1/users/:id`) carries the Bearer header. A user can add up to 5 emergency
  contacts picked from the device contact list (no `READ_CONTACTS`
  permission), remove any of them, and the full list is persisted via `PATCH
  /v1/users/:id` (read back via `GET /v1/users/:id`). A phone number that
  cannot be normalized to a 9-digit Peruvian number is rejected client-side
  with a validation message and never added. A local "send SMS to my
  emergency contacts on alert" switch (default off) is disabled/forced off
  whenever there are no contacts. When on and there is at least one contact,
  sending an alert successfully opens the device SMS composer (`sms:`
  multi-recipient URI, no `SEND_SMS` permission, no silent SMS) prefilled
  with all contact numbers and the legacy-parity message text; a composer
  launch failure never blocks or fails the alert flow.
- T3: `RealtimeService.connect()` reads the stored access token and only
  opens the socket when a token exists (no-op otherwise); the handshake auth
  payload is exactly `{'token': <access token>}`, transport is
  `websocket`-only, and the library's own auto-reconnect is disabled in
  favor of one bounded manual retry. `disconnect()` is called on manual
  logout and on session expiry (`SessionExpiredNotifier`). Every
  reconnection attempt (the app's own retry, or a fresh `connect()` after
  login) re-reads the token from `SecureStorage`, so a token refreshed by
  `AuthInterceptor` is picked up on the socket's next (re)connection without
  a forced immediate reconnect. After any socket disconnect that wasn't
  requested by the app, exactly one reconnect attempt is made with the
  current stored token; a second consecutive disconnect does not retry
  again (no loop) until a connection succeeds or `connect()` is called
  again. A well-formed `updatedAlert` payload triggers
  `AlertsProvider.refreshAlerts()` (a full REST refetch) rather than being
  parsed and rendered directly — see decision below. A `disableUser` event
  clears the stored session (via `SecureStorage.clearSession()`, which also
  covers T4), disconnects the socket, and emits the message on
  `AccountDisabledNotifier` exactly once; the app layer navigates to login
  and shows the message (not covered by automated tests — consistent with
  `app.dart`'s existing untested `SessionExpiredNotifier` wiring from T1).
- T4: `SecureStorage.clearSession()` also resets the local "send SMS on
  alert" preference to `false`; since manual logout
  (`MainNavigationProvider.logout()`), `AuthInterceptor`'s session-expired
  path, and `RealtimeServiceImpl`'s `disableUser` handling all call
  `clearSession()`, this single change resets the preference on all three
  end-of-session paths.
- T5: network-type socket failures (`connect_error`, or `onDisconnect` with
  any reason other than `'io server disconnect'` — covers `transport
  close`/`ping timeout`) retry with unlimited exponential backoff + jitter
  (1s, 2s, 4s, 8s, 16s, capped 30s), reset to the first step after any
  successful connect. Every attempt re-reads the access token from
  `SecureStorage` (via the existing `connect()`, which already does this).
  An `onDisconnect('io server disconnect')` that isn't the `disableUser`
  path (server-initiated, e.g. an expired/invalid token rejected at
  `handleConnection`) attempts exactly one token refresh via the new shared
  `TokenRefresher`, then one reconnect with the new token; a second
  consecutive `'io server disconnect'` after that stops retrying entirely
  (no loop), and a failed refresh is already handled by
  `TokenRefresher`'s own session-expired path. `disconnect()` (manual
  logout, session expiry) and the `disableUser` handler both cancel any
  pending backoff timer and never schedule a retry. Coming back to the
  foreground (`AppLifecycleState.resumed`) triggers an immediate reconnect
  (backoff reset) when the socket isn't already connected and the app
  hasn't explicitly disconnected.
- T6: on splash, a stored session (rememberMe on + token + userId present)
  is validated via `GET /v1/auth/me` through the app's normal `Dio` (so
  `AuthInterceptor` transparently refreshes an expired access token before
  this call ever reaches `AuthBloc`). Success emits `AuthAuthenticated`
  (same state login uses), which both navigates to `routeMain` (existing
  `SplashPage` listener) and connects the realtime service (existing
  app-level `BlocListener` on `AuthAuthenticated`, unchanged from T3).
  `UnauthorizedFailure` (session unrecoverable) clears the session and
  emits `AuthUnauthenticated` (→ login). Any other failure (network error,
  server error) emits `AuthUnauthenticated` (→ login) **without** touching
  the stored session, so the next app launch can retry the same session —
  see the decision gap below.
- T7: backend contract (`saeta-backend-v2` `main`, commit `43801c2`):
  `updatedProfile` is emitted to `user:{id}` only, payload is a sanitized
  `UserEntity` (`id, name, lastname, dni, phone, email, role, statusAccount,
  image, emergencyContacts, averageScore, alertsAttended, availability,
  createdAt, updatedAt`). It fires on any visible profile change and on avatar
  upload, never on password change or disable. `RealtimeService` exposes an
  `updatedProfiles` stream; a malformed (non-map) payload is ignored.
  `MainNavigationProvider` replaces `currentUser` from the payload only when
  its `id` matches the current user, so the profile view re-renders.
  `EmergencyContactsProvider` replaces its contact list from the payload's
  `emergencyContacts` (same id check; missing field leaves the list
  untouched) without a REST call, and forces the SMS-on-alert preference off
  when the list becomes empty. Both providers cancel their subscription in
  `dispose()`.

- T8: backend contract from `saeta-backend-v2/odd/tasks/realtime-profile-sync.md`.
  `PATCH /v1/users/:id` with only `{ name?, lastname?, phone?, email? }` (never
  `role`/`statusAccount`: `role` → 400). Response `{ ok, user }`. 409 on
  duplicate email/phone surfaces the backend message. Client-side validation
  before sending: non-empty name/lastname, phone normalizable to 9 digits
  (reuse `PeruvianPhoneNormalizer`), valid email format. On success the
  profile view shows the new data immediately (from the response, not
  waiting for the `updatedProfile` socket event, which T7 also handles).
  DNI is read-only.
- T9: `PUT /v1/uploads/:id` multipart field `image` (<=5MB,
  png/jpg/jpeg/gif/webp), response `{ ok, user }`. Picker offers camera or
  gallery; images are compressed/resized client-side to stay under 5MB.
  The avatar renders from `GET /v1/uploads/:photo` using the user's `image`
  file id, with a placeholder when empty or on load error. Upload failure
  never loses the current avatar.

- T10: the alert detail shows a non-interactive-by-default Google Map
  centered on the alert's latitude/longitude (legacy zoom level), with one
  marker whose hue depends on the alert state (legacy parity, see
  `saeta-ciudadano` `AlertDetailFragment.markPoiOnMap`) and the legacy map
  style JSON. Missing/invalid coordinates show a placeholder instead of a
  map. The Maps key is never committed: Android reads `MAPS_API_KEY` from
  git-ignored `android/local.properties` via `manifestPlaceholders`; iOS
  reads it from a git-ignored xcconfig. A missing key must not break the
  build.

## Decisions (T3)
- **`updatedAlert` payload handling**: the backend's `emitAlertUpdated`
  broadcasts the raw `AlertEntity` domain object (`typeId`/`stateId` as
  plain ids, not the populated `type`/`state` objects the REST list
  endpoint returns — confirmed by reading
  `saeta-backend-v2/src/alerts/domain/alert.entity.ts` and the
  `AlertRealtimeHandler`/`update-alert.handler.ts` call chain). Parsing it
  through the existing `CitizenAlertModel.fromJson` would silently render
  the raw type/state id as the human-readable name (the fallback branch for
  a bare `String` value). Rather than accept that half-populated render, or
  duplicate the backend's populate logic on the client, `RealtimeService`
  only forwards the raw payload as a signal; `AlertsProvider` reacts by
  calling its existing `refreshAlerts()` (REST refetch, already
  null-safe/no-op when no alerts were loaded yet), which is always fully
  populated. This trades one extra REST round-trip per event for
  correctness and reuses code instead of adding a second parsing path.
- **Reconnection policy**: the library's automatic reconnection
  (`Manager`) is disabled (`disableReconnection()`); the app manages
  exactly one retry per disconnect itself (reset on the next successful
  `connect`). This was chosen over leaving the library's default
  (near-infinite) auto-retry running against a possibly-invalid token,
  which would hammer the server on an auth failure — the task explicitly
  asks for "try reconnecting once ... don't loop."
- **Connect hook points**: `RealtimeService.connect()` is called from
  `app.dart` in two places — once unconditionally in `initState` (covers
  "app start with a stored session"; a no-op today since
  `AuthBloc._onSessionChecked` doesn't yet restore a session automatically,
  a pre-existing T1 limitation, not something T3 changes) and once from a
  `BlocListener<AuthBloc, AuthState>` on `AuthAuthenticated` (covers
  "connect after login"). Both funnel through the same token-gated
  `connect()`.

## Checks
- `flutter test`
- `flutter analyze`

## Progress / Evidence
- Engram mirror: PENDING (engram project for this workspace is ambiguous; awaiting user choice).

### T1 — Token refresh interceptor (done)

TDD: strict, source: user global config, runner: `flutter test`. RED observed first
(compile errors: `updateTokens` undefined on `SecureStorage`/`MockSecureStorage`,
`auth_interceptor.dart`/`session_expired_notifier.dart` did not exist yet), then
implemented to GREEN, no refactor step needed beyond initial clean implementation.

Files added:
- `lib/core/network/auth_interceptor.dart` — `AuthInterceptor extends Interceptor`.
  Attaches `Authorization: Bearer <token>` from `SecureStorage` on every non-public
  request that doesn't already carry the header. Public paths skipped for both header
  attachment and refresh-on-401: `/v1/auth/login`, `/v1/auth/refresh`, `/v1/users` (and
  `/v1/users/...`, covering register + DNI lookup). On a 401 from a non-public request:
  calls `POST /v1/auth/refresh` via a separate `authDio` (no interceptors, avoids
  loops), persists both tokens via `SecureStorage.updateTokens`, retries the original
  request once through the app's `Dio` (marked via `options.extra['auth_interceptor_retried']`).
  Concurrent 401s share exactly one refresh via a cached `Future<String?>? _refreshing`
  (set synchronously before any `await`, so no interleaving can start a second refresh
  call). No refresh token, a failed refresh call, or a 401 on the retried request all
  clear the session (`SecureStorage.clearSession`) and notify `SessionExpiredNotifier`,
  then reject with the original error — no loops (a plain `Interceptor`, not
  `QueuedInterceptor`, was used deliberately: `QueuedInterceptor` fully serializes
  interceptor processing including the manual `dio.fetch()` retry issued from inside
  `onError`, which risks a self-deadlock against its own request queue; a
  `Future`-based mutex gives the same "exactly one refresh" guarantee without that
  risk).
- `lib/core/network/session_expired_notifier.dart` — `SessionExpiredNotifier`, a
  broadcast `Stream<void>` signal, registered as a lazy singleton in get_it.

Files changed:
- `lib/core/storage/secure_storage.dart` — added `updateTokens({token, refreshToken})`,
  writes only the token + refreshToken keys (userId/rememberMe untouched).
- `lib/core/network/http_client.dart` — `HttpClient.create` now accepts an optional
  `interceptors` list, appended after the debug `LogInterceptor` (kept as-is).
- `lib/service_locator.dart` — registers `SessionExpiredNotifier`; registers a second,
  interceptor-free `Dio` under `instanceName: authDioInstanceName` used only for the
  refresh call; the main `Dio` singleton now adds `AuthInterceptor` (using
  `dioProvider: () => sl<Dio>()` to avoid a self-reference at construction time).
  Dropped the now-unused `storage:` argument from the `AlertsRemoteDataSourceImpl` and
  `EmergencyRemoteDataSourceImpl` registrations.
- `lib/features/alerts/data/datasources/alerts_remote_datasource.dart` and
  `lib/features/emergency/data/datasources/emergency_remote_datasource.dart` — removed
  manual `_storage.getToken()` + `Authorization` header code; the interceptor now
  attaches it. `SecureStorage` dependency dropped from both classes.
- `lib/app.dart` — `SaetaCiudadanoApp` converted to a `StatefulWidget`; on
  `SessionExpiredNotifier.stream` it calls `_router.go(AppConstants.routeLogin)`,
  reusing the same navigation target as the manual logout flow in
  `profile_view.dart` (the interceptor already cleared the stored session by the time
  this fires).
- `lib/features/auth/presentation/bloc/auth_bloc.dart` — untouched per instructions;
  `_onSessionChecked` still only checks token presence and always routes to login for
  now — the interceptor handles expiry transparently on the first authenticated call.

Tests added:
- `test/core/network/auth_interceptor_test.dart` (7 tests) — header attached from
  storage; no header + no `getToken()` call on public endpoints; 401 → refresh → retry
  succeeds with new tokens persisted; concurrent 401s → exactly one `POST
  /v1/auth/refresh` call; no refresh token → session cleared + signal + original error
  rejected; refresh call failure (400) → same; retried request 401 again → exactly one
  refresh call, exactly one retry, session cleared, no loop. Uses a hand-written
  `FakeHttpClientAdapter` (`test/core/network/fake_http_client_adapter.dart`) instead of
  a mocked adapter package, and `MockSecureStorage` (mocktail) for storage.
- `test/core/storage/secure_storage_test.dart` (2 tests) — `updateTokens` writes token +
  refreshToken; leaves userId/rememberMe untouched.
- `test/widget_test.dart` — pre-existing placeholder (`expect(true, isTrue)`), not
  stale/failing; left as-is.

Commands run (foreground):
- `flutter pub get`: success — dependencies resolved, no errors (34 packages have newer
  versions available, unrelated to this change).
- `flutter test`: **10/10 passed, 0 failed** (7 interceptor + 2 secure storage + 1
  pre-existing widget test).
- `flutter analyze`: **No issues found!**

Not done / decision gaps: none for T1. The repository is not under git, so no
work-unit commit was created for this task per the feature doc's stated constraint;
the user will need to initialize git before commits are possible.

### T2 — Emergency contacts + SMS on alert (done)

TDD: strict, source: user global config, runner: `flutter test`. Every unit
below was written test-first: RED observed (missing file / undefined
member / compile error), then implemented to GREEN, no separate refactor
step needed beyond writing the clean implementation directly. Total suite
grew from 10 tests (T1 baseline) to **61 tests, all passing**.

#### AuthInterceptor fix (required by T2)

`lib/core/network/auth_interceptor.dart`: `_isPublicPath` is now
`_isPublicPath(String method, String path)` — the path alone could not tell
`POST /v1/users` (register, public) apart from `GET`/`PATCH /v1/users/:id`
(authenticated, used to read/save emergency contacts). Public set is now
exactly: `POST /v1/auth/login`, `POST /v1/auth/refresh`, `POST /v1/users`,
`GET /v1/users/dni` (+ `/v1/users/dni/:dni`). Both `onRequest` (header
attachment) and `onError` (refresh-on-401 skip) call the method-aware check.

RED observed first in `test/core/network/auth_interceptor_test.dart`: the
new "attaches a header on GET/PATCH /v1/users/:id" tests failed with
`Expected: 'Bearer access-1', Actual: <null>` against the old path-only
logic (`/v1/users/...` was entirely public). Also added regression-lock
tests for `POST /v1/users` (register) and `GET /v1/users/dni/:dni` staying
public. All 11 interceptor tests pass after the fix.

#### New feature: `lib/features/emergency_contacts/`

Domain:
- `domain/entities/emergency_contact_entity.dart` — `{name, phone}`
  (Equatable), `phone` always the normalized 9-digit form.
- `domain/repositories/emergency_contacts_repository.dart` — `Either`-based
  `getContacts(userId)` / `saveContacts(userId, contacts)`.
- `domain/usecases/get_emergency_contacts_usecase.dart`,
  `save_emergency_contacts_usecase.dart` — thin pass-throughs, mirroring
  `SendAlertUseCase`'s style (no dedicated tests, consistent with how
  `GetAlertTypesUseCase`/`SendAlertUseCase` aren't unit-tested either).
- `domain/services/peruvian_phone_normalizer.dart` — mirrors the backend's
  `normalizePeruvianPhone` (branch `fix/emergency-contact-phone-normalization`
  in saeta-backend-v2, not yet on `main`): strips non-digits, strips a
  leading `51` country code when the result is 11 digits, accepts only a
  final 9-digit result. 12 tests (7 accepted formats incl.
  `"+51 987 654 321"`, `"(+51) 987-654-321"`; 5 rejected incl. wrong length
  and non-Peruvian `+1` prefix).
- `domain/services/sms_message_builder.dart` — builds the exact legacy
  message text (generic greeting since this app uses one multi-recipient
  composer instead of the legacy per-contact SMS). 2 tests.
- `domain/services/sms_uri_builder.dart` — builds the `sms:` URI
  (`sms:<phone1>,<phone2>?body=<encoded>`). 3 tests.
- `domain/services/sms_launcher.dart` — `SmsLauncher` interface +
  `SmsLaunchException`.
- `domain/services/url_launcher_sms_launcher.dart` — `SmsLauncher` backed by
  `package:url_launcher`; the actual platform call is injected
  (`Future<bool> Function(Uri)`, defaults to `launchUrl`) so it's
  unit-testable with no platform channel. 2 tests (launches built URI;
  throws `SmsLaunchException` when the platform returns `false`).
- `domain/services/device_contact_picker.dart` — `DeviceContactPicker`
  interface + `PickedContact{name, phoneNumber}` (raw, not yet normalized).

Data:
- `data/models/emergency_contact_model.dart` — `fromJson`/`toJson`/
  `toEntity`/`fromEntity` (Equatable, for test comparisons).
- `data/datasources/emergency_contacts_remote_datasource.dart` —
  `getContacts` → `GET /v1/users/:id`, parses `data.user.emergencyContacts`;
  `saveContacts` → `PATCH /v1/users/:id` with `{emergencyContacts: [...]}`,
  parses the same shape from the response. 3 tests (mocked `Dio`).
- `data/repositories/emergency_contacts_repository_impl.dart` — same
  `DioException` → `Failure` mapping pattern as `EmergencyRepositoryImpl`
  (`NetworkFailure` on connection errors, `ServerFailure` with the backend
  message otherwise). 5 tests, incl. one asserting the backend's max-5
  message surfaces as-is (max-5 is enforced server-side; client also
  disables "add" at 5 defensively).
- `data/services/native_device_contact_picker.dart` — wraps
  `flutter_native_contact_picker`'s `selectPhoneNumber()` (not
  `selectContact()`): lets the user pick a specific number when a contact
  has several, matching the legacy Android picker's UX
  (`ACTION_PICK`/`Phone.CONTENT_TYPE`). No dedicated test (thin platform
  wrapper, same as `Geolocator` calls in the existing `EmergencyProvider`
  going untested).

Presentation:
- `presentation/providers/emergency_contacts_provider.dart` —
  `EmergencyContactsProvider extends ChangeNotifier`. `load()` fetches
  `userId` + the contacts list + the local SMS-on-alert preference; forces
  the preference off (and persists it) when there are no contacts.
  `addContactFromPicker()` enforces max 5 before even opening the picker,
  normalizes the picked number (rejects with a validation message if it
  can't become a valid 9-digit number), rejects duplicates by normalized
  phone, then persists the full list via `PATCH`. `removeContact()`
  persists the list without that contact and forces the SMS switch off if
  the list becomes empty. `setSendSmsOnAlert()` can never turn the
  preference on with zero contacts. `sendSmsForAlert()` is a no-op unless
  the preference is on and there's ≥1 contact; wraps the launch in
  try/catch so a launcher failure can never propagate. 17 tests (mocktail
  mocks for both use cases, `SecureStorage`, `DeviceContactPicker`,
  `SmsLauncher`; real `PeruvianPhoneNormalizer`/`SmsMessageBuilder`).
- `presentation/widgets/emergency_contacts_section.dart` — Card with the
  contacts list (remove button per row), an "add" `IconButton` disabled at
  5 contacts, and a `SwitchListTile` disabled when there are no contacts.
  Styled consistently with the existing `profile_view.dart` cards. No
  dedicated widget test (same convention as `profile_view.dart`/
  `emergency_view.dart`, which have none either) — covered by `flutter
  analyze` and manual review only; **this is the one coverage gap** against
  an otherwise-exhaustive TDD pass.

#### `SecureStorage` (local SMS-on-alert preference)

`lib/core/storage/secure_storage.dart` gained `setSendSmsOnAlert(bool)` /
`getSendSmsOnAlert()` (new `AppConstants.keySendSmsOnAlert`), stored via the
same `FlutterSecureStorage` instance as the session (mirrors the legacy
app's `SharedPreferences` flag, but kept in the existing storage
abstraction instead of adding a new `shared_preferences` dependency for one
boolean). Not cleared by `clearSession()` — it's a device/UX preference,
not session state, so it survives logout (decision, not specified by the
task; flagged here in case the reviewer wants it tied to session instead).
3 new tests.

#### Wiring

- `lib/service_locator.dart` — registers the new datasource/repository/
  usecases/provider plus `DeviceContactPicker` → `NativeDeviceContactPicker`,
  `SmsLauncher` → `UrlLauncherSmsLauncher`, `PeruvianPhoneNormalizer`,
  `SmsMessageBuilder` (all lazy singletons; provider is a factory, same
  pattern as `EmergencyProvider`/`AlertsProvider`).
- `lib/features/main/presentation/pages/main_page.dart` — adds
  `ChangeNotifierProvider<EmergencyContactsProvider>(create: (_) =>
  sl<EmergencyContactsProvider>()..load())` to the existing `MultiProvider`.
- `lib/features/main/presentation/pages/profile_view.dart` — inserts
  `const EmergencyContactsSection()` between the user info card and the
  logout button.
- `lib/features/main/presentation/pages/emergency_view.dart` — after
  `EmergencyProvider.sendAlert()` succeeds (and before showing the success
  dialog), awaits
  `EmergencyContactsProvider.sendSmsForAlert(alertTypeName: alertName,
  latitude: sentAlert.latitude, longitude: sentAlert.longitude)` using the
  just-sent `AlertEntity`'s coordinates. This never throws (see provider
  above), so it cannot turn a successful alert into a failure; a
  `context.mounted` check follows before touching the UI again.

#### Platform config

- `android/app/src/main/AndroidManifest.xml` — added the Android 11+
  `<queries>` entry for `android.intent.action.VIEW` / `data
  android:scheme="sms"`, required by `url_launcher` to open the SMS
  composer.
- `ios/Runner/Info.plist` — added `LSApplicationQueriesSchemes: [sms]`.
  Not strictly required for `launchUrl` itself (only for `canLaunchUrl`
  pre-checks, which this implementation doesn't use), but added for
  robustness per `url_launcher`'s iOS configuration guidance.
- **iOS platform note (not verified on a device):** the `sms:` URI's
  multi-recipient prefill behavior in Apple's Messages composer has
  historically been inconsistent across iOS versions/devices (community
  reports of only the first recipient, or none, being prefilled when a
  `body` query param is also present on some iOS versions). Android is
  reliable. This is a known limitation of the chosen "open the composer"
  approach and was accepted as part of the earlier product decision (no
  SEND_SMS permission); flagged here as a decision gap in case the user
  wants an iOS-specific single-SMS-per-contact fallback later.

#### Dependencies added (`pubspec.yaml`)

- `url_launcher: ^6.3.0` (resolved 6.3.2) — opens the `sms:` composer.
- `flutter_native_contact_picker: ^0.0.12` (resolved 0.0.12) — native
  contact/phone-number picker, confirmed via pub.dev: **no
  `READ_CONTACTS` permission required** on either platform; its
  `environment.flutter` constraint (`>=3.41.0`) matches this project's
  installed Flutter exactly.

#### Commands run (foreground)

- `flutter pub get`: success, `url_launcher` (+ platform packages) and
  `flutter_native_contact_picker` added; no errors (36 packages have newer
  versions incompatible with current constraints, pre-existing/unrelated).
- `flutter test`: **61/61 passed, 0 failed** (10 pre-existing + 4 new
  interceptor + 3 new secure-storage + 12 phone normalizer + 2 message
  builder + 3 URI builder + 2 url-launcher wrapper + 3 datasource + 5
  repository + 17 provider).
- `flutter analyze`: **No issues found!** (after fixing 3 `prefer_const_constructors`
  infos in new test files).

#### Size

This task's new/changed code is well beyond the ~400-line-per-task advisory
heuristic (roughly 1,470 lines in new `emergency_contacts` files alone, plus
the interceptor/storage/DI/UI edits) — the full clean-architecture stack
(domain/data/presentation) plus SMS + contact-picker infrastructure plus
exhaustive TDD coverage for 6 independently-tested units naturally exceeds
it. No tests were cut and no code was minified/abbreviated to fit; noting
this per the heuristic's own instructions rather than reworking the split.

#### Not done / decision gaps (do not invent — flagging for the user)

1. **SecureStorage's SMS-on-alert preference survives logout** (not cleared
   by `clearSession()`). This mirrors "local device preference" but wasn't
   explicitly specified either way — confirm if it should reset on logout.
2. **iOS multi-recipient SMS prefill reliability** is unverified on a real
   device/iOS version (see platform note above) — worth a manual QA pass
   before shipping to iOS.
3. **`EmergencyContactsSection` (profile UI) and the `emergency_view.dart`
   SMS-trigger hook have no dedicated widget test** — consistent with this
   codebase's existing convention of leaving `profile_view.dart`/
   `emergency_view.dart` untested, but called out explicitly since T2's
   TDD coverage list didn't explicitly exclude it either.
4. Backend's Peruvian phone normalization (branch
   `fix/emergency-contact-phone-normalization` in saeta-backend-v2) is
   **not yet merged to `main`** as of this work. The client-side
   `PeruvianPhoneNormalizer` mirrors it exactly, but if that backend branch
   isn't deployed, `PATCH /v1/users/:id` will still 400 on any phone that
   needs country-code stripping (plain 9-digit numbers work either way).

### Backend v2 support (saeta-backend-v2, separate repo)
- `f5053f1` (branch `fix/emergency-contact-phone-normalization`): emergency contact phones accept device formats (`+51 987 654 321`) and are normalized to 9 digits. The app can send raw numbers.
- `15ca944` (branch `feat/realtime-user-disabled`): backend emits `disableUser-{userId}` when an admin disables an account. Refresh/login already reject disabled accounts.

### T3 — Socket.IO client (done)

TDD: strict, source: user global config, runner: `flutter test`. Every unit
was written test-first: RED observed (missing `core/realtime` files, so a
compile error — same convention as T1/T2), then implemented to GREEN. Suite
grew from 61 tests (T2 baseline) to **78 tests, all passing** (17 new: 11
`RealtimeServiceImpl`, 3 `AlertsProvider`, 1 `MainNavigationProvider`, 2
`SecureStorage.clearSession` — the last 2 are T4's).

#### Dependency

- `socket_io_client: ^3.1.6` (resolved 3.1.6, `sdk: '>=3.0.0 <4.0.0'`, no
  conflicts). Verified compatible with the backend's `socket.io: ^4.8.3`
  server: this package's 3.x line targets the engine.io v4 protocol (2.x was
  for Socket.IO v2/v3 servers). `context7` had no Dart-specific docs for
  this package (only the JS client), so the version choice and API surface
  were verified by reading pub.dev's package metadata and the installed
  package source directly (`socket_io_client-3.1.6/lib/src/{socket,darty,manager}.dart`
  in the pub cache) rather than from an unavailable doc source.

#### New: `lib/core/realtime/`

- `socket_connection.dart` — `SocketConnection` interface (`auth` setter,
  `connect`/`disconnect`/`dispose`, `on`/`onConnect`/`onConnectError`/
  `onDisconnect`). A seam so `RealtimeServiceImpl` never touches the vendor
  `Socket` class directly, keeping it unit-testable with a mocktail mock
  instead of a real connection.
- `io_socket_connection.dart` — `IoSocketConnection`, the real adapter over
  `package:socket_io_client`. Builds the underlying socket lazily on first
  `connect()` (auto-connect is disabled, so construction alone opens no
  I/O), transport forced to `websocket` only, and the library's own
  automatic reconnection disabled (`disableReconnection()`) — see decision
  below. No dedicated test, consistent with this codebase's convention for
  thin vendor wrappers (`NativeDeviceContactPicker`,
  `UrlLauncherSmsLauncher`).
- `realtime_service.dart` — `RealtimeService` interface: `updatedAlerts`
  stream (raw `Map<String, dynamic>` payloads, see decision below),
  `connect()`, `disconnect()`.
- `realtime_service_impl.dart` — `RealtimeServiceImpl`. `connect()` reads
  the current token from `SecureStorage`; a null/empty token is a no-op
  (never opens the socket). On a token, sets `auth = {'token': token}` and
  calls the socket's `connect()`. `disconnect()` marks the disconnect as
  deliberate (`_manualDisconnect = true`) and calls the socket's
  `disconnect()`. Every disconnect that wasn't deliberate (`onDisconnect`/
  `onConnectError`, which covers both network blips and an auth rejection —
  the vendor client doesn't reliably distinguish the two, see decision
  below) gets exactly one retry via the same `connect()` path (so it always
  re-reads the current — possibly refreshed — token), guarded by
  `_hasRetriedAfterDisconnect`, reset back to `false` only on the next
  successful `onConnect`. `updatedAlert` payloads (`Map`) are forwarded
  as-is onto a broadcast `StreamController`. `disableUser` marks the
  disconnect as deliberate, calls `SecureStorage.clearSession()` (which
  also resets the T4 preference), disconnects the socket, and notifies
  `AccountDisabledNotifier` with the server's message (falls back to a
  generic Spanish message if the payload isn't a non-empty string).

#### New: `lib/core/network/account_disabled_notifier.dart`

`AccountDisabledNotifier` — a broadcast `Stream<String>` signal, structurally
identical to `SessionExpiredNotifier` (T1) but carrying the server's
`disableUser` message. Registered as a lazy singleton in get_it. No
dedicated test, same convention as `SessionExpiredNotifier` (exercised
end-to-end via `RealtimeServiceImpl`'s tests instead).

#### Changed: `AlertsProvider`

`lib/features/alerts/presentation/providers/alerts_provider.dart` — new
required `realtimeService` constructor parameter. Subscribes to
`RealtimeService.updatedAlerts` and calls `refreshAlerts()` (the existing
REST refetch, already a safe no-op before any `loadAlerts()`) on every
event — see the "raw payload" decision below for why it doesn't parse and
apply the event directly. `dispose()` (new override) cancels the
subscription.

#### Changed: `MainNavigationProvider` / `main_page.dart`

`lib/features/main/presentation/providers/main_navigation_provider.dart` —
new required `realtimeService` constructor parameter; `logout()` now calls
`realtimeService.disconnect()` alongside `storage.clearSession()`.
`lib/features/main/presentation/pages/main_page.dart` passes
`sl<RealtimeService>()` into the `MainNavigationProvider` it creates.

#### Changed: `service_locator.dart`

Registers (all lazy singletons unless noted): `AccountDisabledNotifier`,
`SocketConnection` → `IoSocketConnection()`, `RealtimeService` →
`RealtimeServiceImpl(socket:, storage:, accountDisabledNotifier:)`. The
existing `AlertsProvider` factory registration now also injects
`realtimeService: sl<RealtimeService>()`.

#### Changed: `app.dart`

`_SaetaCiudadanoAppState` (already a `State` since T1, for the
`SessionExpiredNotifier` subscription) gained:
- A `GlobalKey<ScaffoldMessengerState>` passed to `MaterialApp.router` so a
  `SnackBar` can be shown from a stream listener with no `BuildContext` of
  its own.
- An `AccountDisabledNotifier` subscription: navigates to login (same
  target as the manual-logout and session-expired flows) and shows the
  server message in a `SnackBar`. `RealtimeServiceImpl` already
  cleared the session and disconnected before this fires.
- The `SessionExpiredNotifier` subscription now also calls
  `sl<RealtimeService>().disconnect()` before navigating (session expiry is
  an end-of-session path for the socket too, not just for `SecureStorage`).
- `sl<RealtimeService>().connect()` called once, unconditionally, in
  `initState` (see "connect hook points" decision below), and again from a
  new `BlocListener<AuthBloc, AuthState>` wrapping `MaterialApp.router`, on
  `AuthAuthenticated`.

Not covered by an automated test — consistent with `app.dart`'s existing
untested `SessionExpiredNotifier` wiring from T1 (there's no widget-test
harness for this file's stream-to-navigation glue in this codebase).

#### Decisions (also recorded above, in Scope, before implementation)

See "## Decisions (T3)" above for: the `updatedAlert` raw-payload/refresh
choice, the reconnection policy (library auto-reconnect disabled, one
bounded manual retry per disconnect, not distinguishing an auth-error
disconnect from a network one since the vendor client doesn't expose that
distinction reliably), and the two `connect()` hook points in `app.dart`.

#### Platform notes

No Android/iOS platform config changes were needed for T3. The backend base
URL (`AppConstants.baseUrlSaeta`) is `https://...`, so the Socket.IO
handshake and the upgraded `websocket` transport both run over TLS
(`wss://`) automatically — no `usesCleartextTraffic`/network-security-config
change, and no new `<queries>` entry (unlike T2's `sms:` scheme, a raw
WebSocket connection isn't an intent the OS needs to resolve).
`AndroidManifest.xml` doesn't declare `android.permission.INTERNET`
explicitly, but this was already true before T3 and the app's existing REST
calls (T1/T2) already depend on network access working, so it's a
pre-existing condition (very likely satisfied by a plugin's merged
manifest) rather than something T3 introduced or needs to fix.

#### Commands run (foreground)

- `flutter pub get`: success, `socket_io_client` (+ `socket_io_common`)
  added; no errors (36 packages have newer versions incompatible with
  current constraints, pre-existing/unrelated).
- `flutter test`: **78/78 passed, 0 failed**.
- `flutter analyze`: **No issues found!** (after switching a test helper
  from a list literal to `List.generate` to satisfy `prefer_const_constructors`
  / `prefer_inlined_adds` without reintroducing an unmodifiable list — see
  `AlertsProvider.loadAlerts`'s in-place `sort()`).

#### Not done / decision gaps (do not invent — flagging for the user)

1. **`app.dart`'s wiring (connect/disconnect hooks, `SnackBar`, navigation)
   has no automated test**, matching this file's pre-existing convention —
   flagging since it's the one piece of T3 that isn't TDD-covered.
2. **"Connect on app start with a stored session" is a no-op today**:
   `AuthBloc._onSessionChecked` (T1) always emits `AuthUnauthenticated`
   regardless of a stored token ("Full token renewal goes in a later
   iteration" per its own comment) — a pre-existing limitation, not
   something T3 changes. `RealtimeService.connect()` is still called
   unconditionally in `app.dart`'s `initState` so the hook is correct and
   ready for whenever session restore is implemented; it just never finds
   a session to use yet in the current app.
3. **The reconnect-retry trigger doesn't distinguish an auth-error
   disconnect from a plain network drop** — both call the same
   single-retry path. The Dart `socket_io_client` client doesn't expose a
   documented, reliable way to tell them apart (the NestJS gateway disables
   an unauthenticated socket, but from the client's perspective this can
   surface as either `connect_error` or `disconnect`). Treating every
   disconnect uniformly (one bounded retry) satisfies the literal
   requirement ("try reconnecting once ... don't loop") without relying on
   an unreliable reason string; flagging in case the user wants a stricter
   auth-only retry policy validated against a real disabled-account run.
4. **Not manually verified against a live server** (no integration/E2E
   test in this task's scope, and none existed for T1/T2's REST flows
   either) — `RealtimeServiceImpl` is fully unit-tested against a mocked
   `SocketConnection`, but the real `IoSocketConnection` adapter (like
   T2's `NativeDeviceContactPicker`) was not exercised against the actual
   `saeta-backend-v2` Socket.IO gateway.

### T4 — Reset "send SMS on alert" preference on logout (done)

TDD: strict, source: user global config, runner: `flutter test`. RED
observed first (the new `clearSession` preference-reset test failed against
the pre-T4 implementation — `flutterSecureStorage.write` for
`keySendSmsOnAlert` was never called), then implemented to GREEN.

Implementation: a single change in `SecureStorage.clearSession()`
(`lib/core/storage/secure_storage.dart`) — added `setSendSmsOnAlert(false)`
to the `Future.wait([...])` alongside the existing key deletions. This is
the one choke point all three end-of-session paths already go through:
manual logout (`MainNavigationProvider.logout()`), `AuthInterceptor`'s
session-expired handling (T1), and T3's `RealtimeServiceImpl` `disableUser`
handling — so the single edit covers all three without touching any of
those three call sites.

Tests added (`test/core/storage/secure_storage_test.dart`, new
`clearSession` group): a regression-lock test that the four existing keys
are still deleted, plus the new test asserting `keySendSmsOnAlert` is
written as `'false'`.

Commands run (foreground): covered by T3's combined `flutter test`
(**78/78 passed**) and `flutter analyze` (**No issues found!**) runs above,
since both tasks were verified together before splitting into separate
commits.

Not done / decision gaps: none for T4 — the acceptance criterion ("reset on
manual logout, session expiry, and `disableUser`") is satisfied structurally
by all three paths sharing `clearSession()`, which is asserted directly by
the new test and by T1/T3's own tests confirming each path still calls
`clearSession()`.

### T5 — Socket reconnection with backoff (done)

Route: delegated direct (touches `core/realtime/realtime_service_impl.dart`
+ `realtime_service.dart`, a new `core/network/token_refresher.dart`
extracted from `AuthInterceptor`, `AuthInterceptor` itself, `service_locator`,
`app.dart`, `pubspec.yaml` + tests). Executed directly by the writer agent
per explicit instruction not to spawn subagents this session; documented as
"delegated direct" only to match this feature doc's existing task-routing
convention from T1–T4.

TDD: strict, source: user global config, runner: `flutter test`. Every unit
was written test-first: RED observed (new/changed constructor signatures —
`TokenRefresher` didn't exist, `RealtimeServiceImpl` didn't accept
`tokenRefresher`/`jitterMillis`, `RealtimeService.reconnectOnResume` was
unimplemented — all compile errors), then implemented to GREEN. Suite grew
from 78 tests (T3/T4 baseline) to **94 tests, all passing** (4 new
`TokenRefresher`, 23 rewritten/expanded `RealtimeServiceImpl` — up from 11 —
`AuthInterceptor`'s existing 11 unchanged behaviorally, only their `setUp`
adapted to the new constructor).

#### Backend confirmation (read-only, `saeta-backend-v2`)

Read `src/realtime/presentation/gateways/realtime.gateway.ts`
(`handleConnection`) and the installed `socket_io_client-3.1.6` package
source (`lib/src/socket.dart`) to confirm the exact client-visible signal
for an auth rejection: the gateway rejects an unauthenticated/expired-token
socket with `client.disconnect(true)`, and the Dart client's `onclose('io
server disconnect')` (socket.dart:562) is what fires `onDisconnect` with
that exact reason string — confirmed distinct from a client-initiated
disconnect (`'io client disconnect'`, socket.dart:604, fired when the app's
own `disconnect()`/`disableUser` handling calls the vendor socket's
`disconnect()`) and from any network-type reason (`'transport close'`,
`'ping timeout'`, etc.). This is the exact signal
`RealtimeServiceImpl._handleAuthRejection` keys off.

#### New: `lib/core/network/token_refresher.dart`

`TokenRefresher` — extracted verbatim from `AuthInterceptor`'s previous
`_performRefresh`/`_refreshTokens` (byte-for-byte identical refresh logic:
reads the refresh token, calls `POST /v1/auth/refresh` via its own
interceptor-free `Dio`, persists both tokens via
`SecureStorage.updateTokens`, and on any failure clears the session +
notifies `SessionExpiredNotifier`), plus the same in-flight-future
single-flight guarantee. Shared by `AuthInterceptor` (401 retries) and
`RealtimeServiceImpl` (auth-rejected socket reconnects) so both callers
observe "exactly one refresh at a time" against the same
`SecureStorage`/`SessionExpiredNotifier`. 4 new tests
(`test/core/network/token_refresher_test.dart`): success persists both
tokens; no refresh token clears session + notifies; a failed refresh call
clears session + notifies; concurrent callers share exactly one call.

#### Changed: `lib/core/network/auth_interceptor.dart`

Constructor now takes `tokenRefresher: TokenRefresher` instead of
`authDio: Dio`; `_refreshTokens()` is now a one-line delegation to
`_tokenRefresher.refresh()`. `_performRefresh`/the old `_refreshing` field
were deleted (moved into `TokenRefresher`). Behavior is unchanged — all 11
existing tests in `test/core/network/auth_interceptor_test.dart` pass
unmodified; only `setUp` changed, to build a `TokenRefresher` from the same
`authDio`/`storage`/`notifier` it already had.

#### Changed: `lib/core/realtime/realtime_service.dart` / `realtime_service_impl.dart`

`RealtimeService` gained `Future<void> reconnectOnResume();`.
`RealtimeServiceImpl`:
- New required `tokenRefresher: TokenRefresher` constructor param, plus
  optional `backoffForAttempt`/`jitterMillis` injection points (both
  default; tests use the latter to zero out jitter for exact-value
  assertions, and one dedicated test overrides it to prove jitter is
  actually added).
- `_scheduleNetworkRetry()` replaces the old single-shot `_retryOnce()`:
  unlimited retries via `Timer`, delay = `_defaultBackoff(attempt)` (1s,
  2s, 4s, 8s, 16s, capped 30s from `attempt` 0..5+) + injected jitter
  (0–250ms by default via `Random`), `_retryAttempt` incremented per
  schedule and reset to 0 on the next successful `onConnect`. Triggered by
  `onConnectError` (always network-type) and by `onDisconnect` whenever the
  reason isn't exactly `'io server disconnect'`.
- `_handleAuthRejection()`: triggered only by `onDisconnect('io server
  disconnect')` that isn't an explicit disconnect. Guarded by
  `_authReconnectAttempted` (reset only on a real successful `onConnect`,
  same as the backoff counter) so it fires at most once per failure streak:
  calls `_tokenRefresher.refresh()` once, and on a non-null result calls
  `connect()` once more (which re-reads the — now refreshed — token from
  `SecureStorage`, since `TokenRefresher.refresh()` already persisted it).
  A `null` result (refresh failed) or a second consecutive `'io server
  disconnect'` both stop without scheduling anything further — no loop.
- `connect()`/`disconnect()` behavior preserved (still token-gated,
  still re-reads storage every call); `disconnect()` and the `disableUser`
  handler (`_handleDisableUser`) both now also cancel any pending backoff
  `Timer` via `_cancelPendingRetry()`.
- New `reconnectOnResume()`: no-op when already connected
  (`_connected`) or explicitly disconnected; otherwise cancels any pending
  timer, resets `_retryAttempt` to 0, and calls `connect()` immediately.
- `dispose()` now also cancels any pending timer.
- Time is driven by plain `Timer`/`Future` APIs (no bespoke clock
  abstraction) so `package:fake_async`'s `fakeAsync()` fully controls it in
  tests.

Tests (`test/core/realtime/realtime_service_impl_test.dart`, rewritten):
groups for `connect`/`disconnect` (adapted), a new `network-type backoff
retry` group (first-retry timing, doubling+cap sequence across 7
consecutive failures, reset-after-success, jitter present, token re-read
per retry, unlimited retries — 10 consecutive failures all retried), a new
`auth-rejected disconnect (io server disconnect)` group (refresh-once +
reconnect-once; stops after a second consecutive rejection; a failed
refresh stops without a second attempt; the guard resets after a later real
connect), `explicit disconnect never retries` (manual disconnect,
`disableUser`, and a dedicated "cancels a pending timer" test for each),
and a new `reconnectOnResume` group (reconnects immediately + resets
backoff when down; no-op when connected; no-op when explicitly
disconnected). `updatedAlert`/`disableUser` payload-handling tests
unchanged from T3.

One test-infrastructure note: repeated `verify(() => socket.connect())
.called(n)` checkpoints within a single test don't behave like
independent cumulative assertions in mocktail — once a set of matching
invocations has been claimed by one `verify()`, a later `verify()` on the
same expression only sees calls made *since* that checkpoint. Discovered
via RED failures when porting the old single-checkpoint-per-test T3 style
to these multi-stage backoff tests; fixed by tracking `socket.connect()`
call counts with a plain incrementing counter (via `when(...).thenAnswer`)
instead of multiple `verify().called()` checkpoints on the same mock call
within one test.

#### Changed: `lib/service_locator.dart`

Registers `TokenRefresher` (needs `authDio`, `storage`,
`sessionExpiredNotifier`, all already registered) as a lazy singleton;
`RealtimeService`'s registration gained `tokenRefresher: sl<TokenRefresher>()`;
`AuthInterceptor`'s registration now passes `tokenRefresher:
sl<TokenRefresher>()` instead of `authDio: sl<Dio>(instanceName:
authDioInstanceName)` directly (the `authDio` singleton itself is
unchanged, just no longer referenced from two places).

#### Changed: `lib/app.dart`

`_SaetaCiudadanoAppState` now mixes in `WidgetsBindingObserver`
(registered/removed in `initState`/`dispose`) and implements
`didChangeAppLifecycleState`: on `AppLifecycleState.resumed`, calls
`sl<RealtimeService>().reconnectOnResume()` (wrapped in `unawaited`, same
convention as this file's existing fire-and-forget `connect()` calls). Not
covered by an automated test — consistent with this file's existing
untested stream-to-navigation/lifecycle glue (same convention flagged for
`SessionExpiredNotifier`/`AccountDisabledNotifier` wiring in T1/T3).

#### Dependencies added (`pubspec.yaml`)

- `fake_async: ^1.3.1` (dev only) — was already present transitively (via
  `flutter_test`); added as a direct dev dependency since the T5 tests
  import `package:fake_async/fake_async.dart` directly and relying on an
  undeclared transitive dependency is fragile.

#### Commands run (foreground)

- `flutter pub get`: success, `fake_async` resolved as a direct dev
  dependency; no errors.
- `flutter test`: **94/94 passed, 0 failed** (78 T1–T4 baseline − 11 old
  `RealtimeServiceImpl` tests + 23 new/rewritten `RealtimeServiceImpl` + 4
  new `TokenRefresher`, `AuthInterceptor`'s 11 unchanged).
- `flutter analyze`: **No issues found!**

#### Not done / decision gaps (do not invent — flagging for the user)

1. **Not manually verified against a live server** (no integration/E2E
   test, consistent with T1–T4) — the auth-rejection path's exact
   `'io server disconnect'` reason string was confirmed by reading the
   vendor client's source (see "Backend confirmation" above), not by
   observing a real disabled/expired-token connection attempt against the
   deployed backend.
2. **Foreground-resume wiring in `app.dart` has no automated test**, same
   convention as T1/T3's other untested `app.dart` stream/lifecycle glue.
3. **Jitter bound (0–250ms) and the backoff cap (30s) are hardcoded**
   constants (`_jitterCapMs`, `_backoffCapMs`), not configurable — the task
   only specified example values ("e.g. 1s, 2s, 4s ... capped at 30s"), so
   these were picked as reasonable literal defaults; flagging in case the
   user wants them tuned or exposed as constructor parameters.

### T6 — Auto-login on app start (done)

TDD: strict, source: user global config, runner: `flutter test`. The
implementation and tests were written in an earlier session; the RED phase
was not recorded in this document, so it is reported as unobserved rather
than claimed. GREEN observed on 2026-09-25.

Implementation:
- `lib/features/auth/domain/usecases/get_current_user_usecase.dart` (new) —
  thin pass-through to `AuthRepository.getCurrentUser()`.
- `AuthRepository.getCurrentUser()` / `AuthRepositoryImpl` /
  `AuthRemoteDataSource.getCurrentUser()` — `GET /v1/auth/me` through the
  app's normal `Dio`, so `AuthInterceptor` refreshes an expired access token
  transparently; a 401 maps to `UnauthorizedFailure`.
- `AuthBloc._onSessionChecked` — requires rememberMe + token + userId, then
  validates via `GetCurrentUserUseCase`. Success emits `AuthAuthenticated`
  (navigates to main and connects the realtime service through the existing
  listeners). `UnauthorizedFailure` clears the session; any other failure
  emits `AuthUnauthenticated` without clearing it.
- `lib/service_locator.dart` — registers `GetCurrentUserUseCase` and injects
  it into `AuthBloc`.

Tests added (`test/features/auth/`): 1 datasource, 4 repository, 5 bloc.

Commands run (foreground, 2026-09-25):
- `flutter test`: **104/104 passed, 0 failed**.
- `flutter analyze`: **No issues found!**

Review: RDD off (decided by global) — no native review.

Not done / decision gaps:
1. A non-401 failure on startup (network or server error) sends the user to
   login but keeps the stored session, so the next launch retries it. An
   offline start therefore still shows the login screen instead of an
   offline main view.
2. The splash/login navigation for the new authenticated path is not
   covered by a widget test (same convention as `app.dart`).

### T7 — updatedProfile live sync (done)

Route: delegated direct (writer trigger — `RealtimeService` interface +
impl, `MainNavigationProvider`, `EmergencyContactsProvider`,
`service_locator.dart` + tests). Executed directly by the writer agent per
explicit instruction not to spawn subagents this session.

TDD: strict, source: user global config, runner: `flutter test`. Every unit
was written test-first. RED observed first (all three are compile errors,
same convention as every prior task):

- `test/core/realtime/realtime_service_impl_test.dart`: `The getter
  'updatedProfiles' isn't defined for the type 'RealtimeServiceImpl'.`
- `test/features/main/presentation/main_navigation_provider_test.dart`:
  `The getter 'updatedProfiles' isn't defined for the type
  'MockRealtimeService'.`
- `test/features/emergency_contacts/presentation/emergency_contacts_provider_test.dart`:
  `No named parameter with the name 'realtimeService'.` (on
  `EmergencyContactsProvider`'s constructor call) plus the same
  `updatedProfiles` getter error on its own `MockRealtimeService`.

Then implemented to GREEN, no refactor step needed beyond the clean
implementation. Suite grew from 104 tests (T6 baseline) to **115 tests, all
passing** (2 new `RealtimeServiceImpl`, 4 new `MainNavigationProvider`, 5 new
`EmergencyContactsProvider`).

#### Backend contract confirmation (read-only, `saeta-backend-v2`)

Read `src/realtime/presentation/gateways/realtime.gateway.ts`
(`emitUserProfileUpdated`/`sanitizeUserForBroadcast`, commit `43801c2` on
`main`) and `src/users/domain/user.entity.ts`: the payload's field names are
exactly `id` (never `_id`), `statusAccount` (never `stateAccount`), plus
`name, lastname, dni, phone, email, role, image, emergencyContacts,
averageScore, alertsAttended, availability, createdAt, updatedAt`.
`sanitizeUserForBroadcast` explicit-picks these fields (defense-in-depth
against `passwordHash` ever leaking), and a `TypeScript`-`undefined` field
(e.g. `averageScore` before the user has ever been scored) is dropped
entirely by JSON serialization rather than sent as `null`/`0` — confirmed by
reading `realtime.gateway.spec.ts`'s `emitUserProfileUpdated` describe block,
whose `baseUser` fixture sets `availability: undefined` and whose assertion
only checks a subset of fields via `objectContaining`, not full equality.
This "absent means untouched, not blanked" behavior is exactly what
`MainNavigationProvider._handleUpdatedProfile`'s merge strategy (below) is
built to preserve.

#### Changed: `lib/core/realtime/realtime_service.dart` / `realtime_service_impl.dart`

`RealtimeService` gained `Stream<Map<String, dynamic>> get updatedProfiles`,
documented identically to `updatedAlerts` (raw sanitized-`UserEntity`-shaped
map, malformed/non-map payloads dropped before reaching the stream).
`RealtimeServiceImpl` adds a second broadcast `StreamController`, fed by
`_socket.on('updatedProfile', (data) { if (data is Map) {...} })` — the
exact same guard-and-forward pattern already used for `updatedAlert`, no new
parsing logic in this class (parsing/merging is the consuming providers'
job, per the "raw payload as signal" decision already established for
`updatedAlert` in T3). `dispose()` now also closes the new controller.

Tests added (`test/core/realtime/realtime_service_impl_test.dart`, new
`updatedProfile` group, 2 tests): payload forwarded as-is; a non-map payload
produces no event (this second case wasn't covered for `updatedAlert`
either — T7's acceptance criterion explicitly calls it out, so it's covered
here even though it's a pre-existing gap for the sibling stream).

#### Changed: `lib/features/main/presentation/providers/main_navigation_provider.dart`

Subscribes to `_realtimeService.updatedProfiles` in the constructor (the
`realtimeService` param already existed, from T3 — no new constructor
parameter, no wiring change needed anywhere else). `_handleUpdatedProfile`:
ignores the event when there's no `currentUser`, or when the payload's
`id`/`_id` doesn't match `currentUser.id`. On a match, it does **not** parse
the payload standalone through `UserModel.fromJson` — instead it builds a
merged map (current user's own field values as the base, `...payload`
spread on top so payload keys win) and parses *that* through
`UserModel.fromJson().toEntity()`, then calls the existing `setUser()`.

**Parsing/preservation decision**: `UserModel.fromJson` already tolerates
both this socket shape and the REST shape without any change (it already
checks `json['statusAccount'] ?? json['stateAccount']` and `json['id'] ??
json['_id']`, from earlier work) — so it's reused as-is, per the task's
"reuse if it handles the payload" instruction. But parsing the raw payload
*alone* would still be wrong: a field silently absent from the payload
(per the backend confirmation above) would fall through to
`UserModel.fromJson`'s own defaults (`''`/`0.0`/`0`), overwriting a real
existing value with a blank one, even though nothing about that field
actually changed server-side. The merge-then-parse approach means an absent
payload key keeps the current entity's value, and a present key (however
falsy) wins — exactly the "preserve sensibly rather than blank" instruction.
`dispose()` (new override) cancels the subscription.

Tests added (`test/features/main/presentation/main_navigation_provider_test.dart`,
new `updatedProfile` group, 4 tests): matching id replaces `currentUser`
and preserves fields the test payload omits (`lastname`, `averageScore`,
`alertsAttended`, `stateAccount` all asserted unchanged from the original
user); mismatched id is a no-op; no current user is a no-op; subscription is
cancelled on `dispose()` (asserted by the absence of an exception — a
`notifyListeners()` after `dispose()` throws in debug mode, so a still-live
subscription would fail the test).

#### Changed: `lib/features/emergency_contacts/presentation/providers/emergency_contacts_provider.dart`

New required `realtimeService: RealtimeService` constructor parameter,
subscribed the same way. `_handleUpdatedProfile`: ignores a payload whose
`id`/`_id` doesn't match the loaded `_userId`, and — separately — ignores a
payload that doesn't carry the `emergencyContacts` key at all (an unrelated
profile change, e.g. a name edit, must leave the contact list untouched, not
wipe it to empty). When both checks pass, `payload['emergencyContacts']` is
parsed via the existing `EmergencyContactModel.fromJson` (same model T2
already uses for the REST shape — `{name, phone}`, identical to the
backend's `EmergencyContact` interface, no translation needed) and replaces
`_contacts` directly, with no REST call. Reuses the existing
`_enforcePreferenceInvariant()` (already written for T2's `load()`/
`removeContact()` paths) to force the SMS-on-alert preference off and
persist that via `SecureStorage` when the new list is empty — no new logic
needed for that half of the acceptance criterion. `dispose()` (new override)
cancels the subscription.

Tests added (`test/features/emergency_contacts/presentation/emergency_contacts_provider_test.dart`,
new `updatedProfile` group, 5 tests): matching id + `emergencyContacts`
present replaces the list without calling `saveContacts` (asserted via
`verifyNever`); mismatched id is a no-op; a payload without the
`emergencyContacts` key leaves the list untouched; an empty new list forces
`sendSmsOnAlert` to `false` and persists it via `storage.setSendSmsOnAlert`;
subscription cancelled on `dispose()` (same no-exception assertion pattern
as `MainNavigationProvider`'s).

#### Changed: `lib/service_locator.dart`

`EmergencyContactsProvider`'s factory registration gained
`realtimeService: sl<RealtimeService>()`. No other registration changed.

#### Wiring: `lib/features/main/presentation/pages/main_page.dart` — no change needed

Re-checked before writing anything: `MainNavigationProvider` is constructed
directly in `main_page.dart`, but its constructor signature didn't change
(the `realtimeService` parameter already existed from T3 and was already
being passed `sl<RealtimeService>()`), so there was nothing to update there.
`EmergencyContactsProvider` is created via `sl<EmergencyContactsProvider>()`
(a get_it factory), so its new required parameter is satisfied entirely by
the `service_locator.dart` change above — `main_page.dart` never
constructs it directly and needed no edit. Confirmed no other call site
constructs either provider directly (`grep`'d for both constructor calls
across `lib/`).

#### Commands run (foreground)

- `flutter test`: **115/115 passed, 0 failed**.
- `flutter analyze`: **No issues found!**

#### Not done / decision gaps (do not invent — flagging for the user)

1. **Not manually verified against a live server** (no integration/E2E
   test, consistent with T1–T6) — the exact `updatedProfile` payload shape
   was confirmed by reading the backend's gateway source and its own spec
   fixtures, not by observing a real profile-edit/avatar-upload event
   against the deployed backend.
2. **`MainNavigationProvider`'s merge strategy assumes the payload's present
   keys are always the authoritative new value** (never a deliberate
   "clear this field" signal using an empty string, since the backend has
   no such semantic today for any of these fields) — if the backend ever
   needs to explicitly blank a field (as opposed to leaving it undefined),
   this merge approach would still apply it correctly (a present key always
   wins), so this is noted for completeness rather than as an actual gap.
3. **No widget test for the profile view or the emergency-contacts section
   actually re-rendering** on these events — consistent with this
   codebase's existing convention of leaving `profile_view.dart`/
   `emergency_contacts_section.dart` without dedicated widget tests (T2
   flagged the same gap); both providers' `ChangeNotifier`/`notifyListeners`
   behavior is fully unit-tested instead.

### T8 — Profile edit (done)

Route: delegated direct (writer trigger — new `profile` feature across
data/domain/presentation, `profile_view.dart` entry point, `service_locator`
+ tests). Executed directly by the writer agent per explicit instruction not
to spawn subagents this session.

TDD: strict, source: user global config, runner: `flutter test`. Every unit
was written test-first. RED observed first (all compile errors, same
convention as every prior task):

- `test/features/profile/data/profile_remote_datasource_test.dart`: `Error
  when reading 'lib/features/profile/data/datasources/profile_remote_datasource.dart':
  El sistema no puede encontrar la ruta especificada` (file didn't exist).
- `test/features/profile/data/profile_repository_impl_test.dart`: same
  pattern, `ProfileRepositoryImpl`/`ProfileRemoteDataSource` not found.
- `test/features/profile/presentation/profile_edit_provider_test.dart`:
  `Type 'UpdateProfileUseCase' not found.` / `'ProfileEditProvider' isn't a
  type.` / `The method 'call' isn't defined for the type
  'MockUpdateProfileUseCase'` (11 call sites).

Then implemented to GREEN, no refactor step needed beyond the clean
implementation. Suite grew from 115 tests (T7 baseline) to **132 tests, all
passing** (2 new `ProfileRemoteDataSourceImpl`, 4 new `ProfileRepositoryImpl`,
11 new `ProfileEditProvider`).

#### Backend contract (read-only, `saeta-backend-v2/odd/tasks/realtime-profile-sync.md`)

Confirmed from the "Citizen profile API contract" table and
`src/users/presentation/dto/update-user.dto.ts`: `PATCH /v1/users/:id` body
`{ name?, lastname?, phone?, email?, ... }`, response `{ ok, user }`. `phone`
must match `/^\d{9}$/` server-side (`Matches` decorator) — confirms the
client must normalize before sending, not just validate length loosely.
`role` isn't a DTO field at all (global `forbidNonWhitelisted` pipe → 400 if
sent); `statusAccount` is a declared field but silently dropped server-side
unless the caller is privileged — this client never sends either. Duplicate
`email`/`phone` → 409 with a backend message, surfaced as-is per T2's
`_extractErrorMessage` pattern.

#### New feature: `lib/features/profile/`

Domain:
- `domain/repositories/profile_repository.dart` — `ProfileRepository`,
  single `Either`-based `updateProfile({userId, name, lastname, phone,
  email})` (all required — this client always sends the full set of four
  editable fields, per the task's "only changed fields is fine too, not
  mandatory" wording; simpler than tracking a dirty-field diff).
- `domain/usecases/update_profile_usecase.dart` — thin pass-through, same
  style as `SaveEmergencyContactsUseCase`.

Data:
- `data/datasources/profile_remote_datasource.dart` —
  `ProfileRemoteDataSourceImpl.updateProfile` PATCHes `/v1/users/:id` with
  exactly `{name, lastname, phone, email}` and parses `response.data['user']`
  via the existing `UserModel.fromJson` (no new model needed — `UserModel`
  already covers every field this response can carry, reused as-is like T7's
  `MainNavigationProvider` reuse). 2 tests (mocked `Dio`): exact
  path/body/parsing; a `captureAny` assertion that the sent body never
  contains `role`/`statusAccount` keys.
- `data/repositories/profile_repository_impl.dart` — same `DioException` →
  `Failure` mapping pattern as `EmergencyContactsRepositoryImpl`
  (`NetworkFailure` on connection errors/timeouts, `ServerFailure` with the
  backend's `message` otherwise, `UnknownFailure` on anything else). 4 tests:
  success maps to the entity; `NetworkFailure` on `connectionError`;
  `ServerFailure` surfacing the backend's exact 409 duplicate-email message;
  `UnknownFailure` on a non-`DioException` error.

Presentation:
- `presentation/providers/profile_edit_provider.dart` —
  `ProfileEditProvider extends ChangeNotifier`. Exposes `validateName`,
  `validatePhone`, `validateEmail` as public methods meant to be wired
  directly as each `TextFormField`'s `validator` (per-field messages, not one
  combined form-level error) — `validatePhone` delegates to the existing
  `PeruvianPhoneNormalizer` (reused from `emergency_contacts`, no
  duplication) and rejects anything that doesn't normalize to a 9-digit
  number; `validateEmail` uses a small `RegExp`
  (`^[^@\s]+@[^@\s]+\.[^@\s]+$`) — deliberately simple (no full RFC 5322
  validation), matching the backend's own `class-validator` `@IsEmail()`
  strictness level, not a stricter client-side gate.
  `save({name, lastname, phone, email})` re-validates all four fields
  defensively (so a caller that skips the `Form`'s own validation, e.g. a
  future test or a different UI, still can't send invalid data), sends the
  **normalized** phone (never the raw typed value) to
  `UpdateProfileUseCase`, and on success replaces `currentUser` and calls the
  optional `onUpdated` callback — see the "wiring" decision below. On
  failure, `currentUser` is left untouched and `errorMessage` carries the
  backend's message verbatim (including the 409 duplicate-email/phone case).
  `isSaving` is `true` only while the use case call is in flight. 3 field
  validation tests + 11 `save` tests (4 per-field-invalid rejections without
  calling the use case, normalized-phone-sent assertion, success updates
  state + callback + clears error/saving, failure keeps old user + surfaces
  message + clears saving, `isSaving` true mid-flight via a manually
  completed `Completer`).
- `presentation/pages/profile_edit_page.dart` — `ProfileEditPage` (takes
  `user` + an optional `onUpdated` callback) wraps a private
  `_ProfileEditForm` in its own `ChangeNotifierProvider<ProfileEditProvider>`
  constructed from `sl<UpdateProfileUseCase>()` +
  `sl<PeruvianPhoneNormalizer>()` (already registered by T2) + the passed-in
  `user`/`onUpdated` — same convention as `MainNavigationProvider` being
  constructed directly with runtime args in `MainPage` rather than via a
  get_it factory, since this provider needs per-instance data a factory
  can't supply. The form: four `TextFormField`s (name, lastname, phone,
  email — DNI is not shown, per "DNI stays read-only"), pre-filled from
  `user`, each wired to the matching `provider.validateXxx` (wrapped
  `(v) => provider.validateXxx(v ?? '')` for `FormFieldValidator<String>`'s
  nullable signature), a `FilledButton` disabled (`onPressed: null`) while
  `provider.isSaving`, showing a small `CircularProgressIndicator` in that
  state. On save: a success `SnackBar` + `Navigator.pop`; a failure shows
  `provider.errorMessage` in a `SnackBar` (inline `Form` validation already
  covers the four field-level cases before the use case is even called). No
  dedicated widget test — consistent with this codebase's existing
  convention of leaving `profile_view.dart`/`emergency_contacts_section.dart`
  without one (T2/T7 already flagged and accepted this gap for view-layer
  files); fully covered indirectly via `ProfileEditProvider`'s exhaustive
  unit tests.

#### Wiring decision: `onUpdated` callback instead of `ProfileEditPage` reading `MainNavigationProvider` itself

`ProfileView`'s "Editar perfil" `TextButton.icon` opens `ProfileEditPage` via
`Navigator.of(context).push(MaterialPageRoute(...))` on the **app-level**
Navigator (the one `MaterialApp.router`/go_router owns), not a
`MainPage`-local one — `MainPage` never wraps its `IndexedStack` children in
their own `Navigator`. That means a page reached via this `push` sits
**above** `MainPage`'s `MultiProvider` in the widget tree, so a
`context.read<MainNavigationProvider>()` call *inside* `ProfileEditPage`
would throw `ProviderNotFoundException` at runtime (this was caught before
writing any test — a build-time constraint, not something TDD against a
mocked provider would have surfaced, since the provider tests never
instantiate a real `MainNavigationProvider`+widget tree together). The fix:
`profile_view.dart` resolves `context.read<MainNavigationProvider>().setUser`
*before* calling `push` (still inside the `MultiProvider`'s subtree) and
passes that bound function down as `ProfileEditPage.onUpdated` /
`ProfileEditProvider.onUpdated`, which fires on a successful save so the
profile view reflects the new data immediately, per the acceptance
criterion — the `updatedProfile` socket event (T7) will also arrive and
re-apply the same data via `MainNavigationProvider._handleUpdatedProfile`,
which is idempotent (same id, same fields) and therefore harmless.

#### Changed: `lib/features/main/presentation/pages/profile_view.dart`

Added a `TextButton.icon` ("Editar perfil") below the email, above the
existing info card; disabled (`onPressed: null`) when there's no
`currentUser` yet. On tap, captures `MainNavigationProvider.setUser` and
pushes `ProfileEditPage(user: user, onUpdated: setUser)`.

#### Changed: `lib/service_locator.dart`

Registers `ProfileRemoteDataSource` → `ProfileRemoteDataSourceImpl`,
`ProfileRepository` → `ProfileRepositoryImpl`, `UpdateProfileUseCase` (all
lazy singletons, same pattern as the `emergency_contacts` registrations).
`ProfileEditProvider` itself is **not** registered here — see the "wiring
decision" above and the existing `MainNavigationProvider` precedent for why
a provider needing runtime-only constructor args (`user`, `onUpdated`) is
built directly at its usage site instead of via a get_it factory.

#### Commands run (foreground)

- `flutter test`: **132/132 passed, 0 failed** (115 T1–T7 baseline + 2
  datasource + 4 repository + 11 provider).
- `flutter analyze`: **No issues found!** (after fixing 4
  `argument_type_not_assignable` errors — `TextFormField.validator` expects
  `FormFieldValidator<String>` i.e. `String? Function(String?)`, but
  `ProfileEditProvider`'s validators are deliberately non-nullable
  `String? Function(String)` for direct unit-testability without a `?? ''`
  at every call site; the four call sites in `profile_edit_page.dart` wrap
  them as `(value) => provider.validateXxx(value ?? '')` instead).

#### Not done / decision gaps (do not invent — flagging for the user)

1. **Not manually verified against a live server** (no integration/E2E
   test, consistent with T1–T7) — the exact `PATCH /v1/users/:id` request/
   response shape and the 409 duplicate-email/phone behavior were confirmed
   by reading the backend's DTO/contract table, not by observing a real
   conflicting update against the deployed backend.
2. **This client always sends all four fields** (`name`, `lastname`,
   `phone`, `email`) rather than only the ones the user actually changed —
   the task explicitly allowed either approach ("only changed fields is
   fine too"); always-send-all was chosen for simplicity (no dirty-field
   tracking) and is harmless given the backend's contract (unsent fields are
   simply left as `undefined` in a partial DTO either way; sending the
   current unchanged value round-trips it back unchanged).
3. **No widget test for `ProfileEditPage`/`ProfileView`'s new "Editar
   perfil" button** — consistent with this codebase's existing convention
   (T2/T7 flagged the same gap for `profile_view.dart`/
   `emergency_contacts_section.dart`); the `ProfileEditPage → Navigator.push
   → ProviderNotFoundException` risk described above was instead caught by
   reasoning about the widget tree before writing the page, not by an
   automated test — a widget test pushing `ProfileEditPage` from within a
   `MainPage`-shaped tree would have caught it mechanically and is a
   reasonable follow-up if the user wants that guarantee codified.
4. **Email validation is a simple regex, not a full RFC 5322 parser** —
   matches the backend's own `class-validator` `@IsEmail()` strictness
   level (also not fully RFC-compliant in practice), so client/server
   rejection behavior should stay aligned for the common cases, but an
   edge-case address accepted by one and rejected by the other is possible
   in theory.
5. **T9 (avatar upload) is explicitly out of scope for this task** and was
   not started, per instruction.

### T9 — Avatar upload (done)

Route: delegated direct (writer trigger — new domain services + a new
`AvatarUploadProvider`/`AvatarSection`, extending the existing `profile`
feature's data/domain layers, `service_locator`, `pubspec.yaml`, iOS
`Info.plist` + tests). Executed directly by the writer agent per explicit
instruction not to spawn subagents this session.

TDD: strict, source: user global config, runner: `flutter test`. Every unit
was written test-first. RED observed first (all compile errors, same
convention as every prior task): `MockAvatarImagePicker`'s
`pickFromCamera`/`pickFromGallery` and `MockUploadAvatarUseCase`'s `call`
undefined (the classes didn't exist yet), plus the new
`ProfileRemoteDataSourceImpl.uploadAvatar`/`ProfileRepositoryImpl.uploadAvatar`
methods and `AvatarFileValidator`/`AvatarUrlBuilder` classes not found — full
list captured in the tool transcript. Then implemented to GREEN, no refactor
step needed beyond the clean implementation. Suite grew from 132 tests (T8
baseline) to **153 tests, all passing** (1 new `ProfileRemoteDataSourceImpl`,
4 new `ProfileRepositoryImpl`, 6 new `AvatarFileValidator`, 3 new
`AvatarUrlBuilder`, 7 new `AvatarUploadProvider`).

#### Backend contract confirmation (read-only, `saeta-backend-v2`)

Read `src/uploads/presentation/uploads.controller.ts`,
`application/commands/upload-avatar.handler.ts`, and
`infrastructure/local-storage.service.ts` directly (beyond the contract
table in `realtime-profile-sync.md`), to confirm exactly:
- `PUT /v1/uploads/:id` expects the file under the multipart field name
  `image` (`FileInterceptor('image', { limits: { fileSize: 5 * 1024 * 1024 }
  } )`), JWT-guarded, owner-or-`ADMIN` only, response `{ ok, user }`.
  Rejected extensions (only `png/jpg/jpeg/gif/webp` allowed, checked
  case-insensitively server-side via the original filename) throw 400 with a
  message naming the invalid extension.
- `GET /v1/uploads/:photo` is **public** (`UploadsController.returnImage`
  carries no `@UseGuards`) and serves the file directly
  (`res.sendFile`) or redirects to a Google Drive fallback URL for a
  legacy/non-local id, or the app's default avatar for the literal string
  `'no-image'`. This client never sends that literal, so only the
  empty-string/load-error placeholder paths apply.
- `LocalStorageService.upload` names every stored file
  `${randomUUID()}.${ext}` — **a replaced avatar always gets a brand-new file
  id**, confirming the URL itself changes on every successful upload with no
  manual cache-busting needed.
- Installed Flutter's own Gradle plugin
  (`packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`)
  defaults `minSdkVersion` to **24** in this SDK version (3.41.0), exactly
  matching `image_picker`'s own minimum — confirmed by reading the installed
  Flutter SDK source directly, not assumed.

#### Dependency added (`pubspec.yaml`)

- `image_picker: ^1.2.3` (resolved 1.2.3, plus `image_picker_android`
  0.8.13+17 / `image_picker_ios` platform packages) — verified via pub.dev's
  package API: latest stable, `Dart: ^3.10.0` / `Flutter: >=3.38.0`, both
  satisfied by this project's installed Flutter 3.41.0 / Dart 3.11.0.
  `flutter pub get` resolved cleanly, no conflicts.

#### New: `lib/features/profile/domain/services/`

- `avatar_image_picker.dart` — `AvatarImagePicker` interface
  (`pickFromCamera()`/`pickFromGallery()`, both `Future<String?>`, `null` on
  cancel), the seam that keeps `AvatarUploadProvider` unit-testable without a
  platform channel.
- `avatar_file_validator.dart` — `AvatarFileValidator.validate({path,
  sizeBytes})`: rejects an unsupported extension or a size over 5MB with a
  Spanish message, mirroring `UploadAvatarHandler`'s own
  `ALLOWED_EXTENSIONS`/the `FileInterceptor`'s 5MB limit exactly, so an
  obviously-bad pick fails fast client-side instead of round-tripping to the
  server. This runs *after* the picker's own
  `maxWidth`/`maxHeight`/`imageQuality` already keep normal photos well
  under the limit — a defensive second check, not the primary size control.
  6 tests: every allowed extension accepted case-insensitively; an
  unsupported extension and a no-extension path rejected; a file over 5MB
  rejected, one at exactly 5MB accepted.
- `avatar_url_builder.dart` — `AvatarUrlBuilder.build(image)`: `null` for an
  empty `image` id (no avatar yet, so the UI shows a placeholder instead of
  requesting a broken URL), otherwise `'$baseUrl/v1/uploads/$image'`
  (`baseUrl` defaults to `AppConstants.baseUrlSaeta`). 3 tests.

#### New: `lib/features/profile/data/services/image_picker_avatar_picker.dart`

`ImagePickerAvatarPicker implements AvatarImagePicker`, wrapping
`package:image_picker`'s `ImagePicker().pickImage()` with `maxWidth`/
`maxHeight` of 1600 and `imageQuality: 85` — keeps typical phone photos well
under 5MB without an extra compression dependency; `AvatarFileValidator`
still catches the rare outlier. Thin platform wrapper, deliberately
untested, same convention as `NativeDeviceContactPicker`/
`UrlLauncherSmsLauncher`.

#### Changed: `lib/features/profile/domain/repositories/profile_repository.dart` / `data/datasources/profile_remote_datasource.dart` / `data/repositories/profile_repository_impl.dart`

Extended the existing T8 `profile` feature (not a new repository) with
`uploadAvatar({userId, filePath})`:
- Datasource: builds `FormData.fromMap({'image': await
  MultipartFile.fromFile(filePath)})` and `PUT`s `/v1/uploads/$userId`.
  Confirmed by reading the installed `dio-5.11.1` source
  (`multipart_file.dart`) that `MultipartFile.fromFile` already infers both
  the filename (basename of the path) and the content-type (via
  `package:mime`, based on the extension) automatically — no explicit
  `filename`/`contentType` needed. Parses `response.data['user']` via the
  existing `UserModel.fromJson`, same as `updateProfile`. 1 test (mocked
  `Dio`, a real temp file on disk since `MultipartFile.fromFile` needs to
  stat/stream an actual file): asserts the exact PUT path, exactly one
  multipart file, and that its field key is `image`.
- Repository: same `DioException` → `Failure` mapping pattern as
  `updateProfile` (`NetworkFailure` on connection errors,
  `ServerFailure` surfacing the backend's message — including the 400
  bad-extension/size case — otherwise, `UnknownFailure` on anything else).
  4 tests.

#### New: `lib/features/profile/domain/usecases/upload_avatar_usecase.dart`

`UploadAvatarUseCase` — thin pass-through, identical style to
`UpdateProfileUseCase`. No dedicated test, same convention as other thin
use-case pass-throughs in this codebase.

#### New: `lib/features/profile/presentation/providers/avatar_upload_provider.dart`

`AvatarUploadProvider extends ChangeNotifier`. Deliberately does **not**
track the current user/avatar itself — `MainNavigationProvider.currentUser`
(already watched by `ProfileView`) already owns that, so "on failure the
current avatar is kept" falls out naturally from `onUpdated` simply not
being called, no separate bookkeeping needed.
`pickAndUploadFromCamera()`/`pickAndUploadFromGallery()` both go through one
private `_pickAndUpload`: a cancelled pick (`null` path) returns `false` and
touches no state; otherwise the file is validated
(size read via an injected `Future<int> Function(String path)
fileSizeReader`, defaulting to `File(path).length()`, so tests never touch
the real filesystem for the size check) — a validation failure sets
`errorMessage` and returns `false` without ever calling
`UploadAvatarUseCase`; only past validation does `isUploading` become `true`
for the duration of the call. On success, `onUpdated` fires with the fresh
`UserEntity` (same wiring convention as `ProfileEditProvider.onUpdated` →
`MainNavigationProvider.setUser`); on failure, `errorMessage` carries the
backend's message and `onUpdated` is never called. 7 tests: cancel is a
no-op; >5MB rejected without calling the use case; unsupported extension
rejected without calling the use case; success calls `onUpdated` and clears
state; failure never calls `onUpdated` and exposes the message; `isUploading`
true only mid-flight (`Completer`-based, same pattern as
`ProfileEditProvider`'s `isSaving` test); gallery delegates to the gallery
picker, not the camera.

#### New: `lib/features/profile/presentation/widgets/avatar_section.dart`

`AvatarSection` (public) + private `_AvatarWithBadge`/`_AvatarPlaceholder`.
Shows a placeholder (no tap target) when `user` is `null` (mirrors
`ProfileView`'s existing disabled "Editar perfil" button under the same
condition). Otherwise wraps a per-user `ChangeNotifierProvider<
AvatarUploadProvider>` (keyed on the user id, constructed from
`sl<UploadAvatarUseCase>()`/`sl<AvatarImagePicker>()`/
`sl<AvatarFileValidator>()` + the passed-in `userId`/`onUpdated` — same
"runtime-args provider built at its usage site" convention as
`ProfileEditProvider`) around the avatar circle: `Image.network` built from
`AvatarUrlBuilder` with an `errorBuilder` falling back to the user's
initial, a small camera badge, a `CircularProgressIndicator` overlay while
`isUploading`, and a tap handler (disabled while uploading) that opens a
`showModalBottomSheet` with "Tomar foto" / "Elegir de galería"; the result
is awaited and a success/error `SnackBar` shown directly from the tap
handler (no separate error-message watcher needed). No dedicated widget
test — consistent with this codebase's existing convention of leaving
`profile_view.dart`/`emergency_contacts_section.dart`/`profile_edit_page.dart`
without one (T2/T7/T8 already flagged and accepted this gap for view-layer
files); fully covered indirectly via `AvatarUploadProvider`'s exhaustive
unit tests.

#### Decision: `AuthInterceptor`'s public-path list does not need `GET /v1/uploads/:photo`

The task asked to decide whether the public `GET /v1/uploads/:photo`
endpoint needs adding to `AuthInterceptor`'s public-path set. It does not,
for a more fundamental reason than "harmless Bearer header": the avatar is
rendered via Flutter's own `Image.network`/`NetworkImage`, which uses
`dart:io`'s `HttpClient` directly and **never goes through the app's `Dio`
instance or `AuthInterceptor` at all**. There is therefore no risk of a 401
there triggering `AuthInterceptor`'s refresh-retry path — that code path is
simply never reached for this request. `AuthInterceptor`'s public-path list
was left unchanged.

#### Decision: no cache-busting query parameter needed

Verified (not assumed) by reading `LocalStorageService.upload`: every
successful upload stores the file under a fresh `randomUUID()`-based
filename and `UploadAvatarHandler` persists that new id as the user's
`image` field. A replaced avatar therefore always changes the `GET
/v1/uploads/:photo` URL itself, so `Image.network`'s own cache (keyed by
URL) can never serve a stale image after a real replace — no manual
cache-busting query parameter was added.

#### Platform config

- iOS (`ios/Runner/Info.plist`): added `NSCameraUsageDescription` and
  `NSPhotoLibraryUsageDescription` (Spanish text, matching the app's
  existing UI copy language) — required by `image_picker`'s iOS
  implementation for camera/gallery access respectively; confirmed via the
  package's own README (fetched from pub.dev), not guessed.
  `NSMicrophoneUsageDescription` was **not** added since this feature never
  records video.
- Android: **no `AndroidManifest.xml` change** — confirmed via
  `image_picker`'s README ("no configuration required on Android") and by
  reading the installed Flutter SDK's Gradle plugin source directly
  (`FlutterExtension.kt`), which shows this project's Flutter 3.41.0
  defaults `minSdkVersion` to 24, exactly meeting `image_picker`'s minimum
  — not assumed from the plugin's docs alone, cross-checked against the
  actual installed toolchain.

#### Changed: `lib/features/main/presentation/pages/profile_view.dart`

Replaced the plain initials-only `CircleAvatar` with `AvatarSection(user:
user, onUpdated: context.read<MainNavigationProvider>().setUser)` — resolved
inline in `ProfileView.build()`, which (unlike `ProfileEditPage`) is *not*
reached via `Navigator.push` and therefore sits inside `MainPage`'s
`MultiProvider`, so `context.read<MainNavigationProvider>()` here is safe
(same reasoning already documented for the existing "Editar perfil" button
in this same file, which does the identical `context.read` call).

#### Changed: `lib/service_locator.dart`

Registers (all lazy singletons): `UploadAvatarUseCase` (via the existing
`ProfileRepository`), `AvatarImagePicker` → `ImagePickerAvatarPicker()`,
`AvatarFileValidator` → `const AvatarFileValidator()`. `AvatarUploadProvider`
itself is not registered here, for the same reason `ProfileEditProvider`
isn't — see the "wiring decision" carried over from T8.

#### Commands run (foreground)

- `flutter pub get`: success — `image_picker` (+ `image_picker_android`/
  `image_picker_ios`) resolved, no errors (38 packages have newer versions
  incompatible with current constraints, pre-existing/unrelated).
- `flutter test`: **153/153 passed, 0 failed** (132 T1–T8 baseline + 1
  datasource + 4 repository + 6 file-validator + 3 URL-builder + 7 provider).
- `flutter analyze`: **No issues found!**

#### Not done / decision gaps (do not invent — flagging for the user)

1. **Not manually verified against a live server or a real device/emulator**
   (no integration/E2E test, consistent with T1–T8) — the multipart field
   name, response shape, and the `minSdkVersion`/content-type-inference
   claims were confirmed by reading the backend's and Dio's/Flutter's own
   source directly, not by performing a real camera/gallery upload against
   the deployed backend or a physical device's camera.
2. **`AvatarSection`/the bottom sheet have no dedicated widget test** —
   consistent with this codebase's existing convention (same gap flagged
   for `profile_view.dart`/`profile_edit_page.dart` in T2/T7/T8); the
   `showModalBottomSheet` → pick → upload → `SnackBar` flow is covered
   indirectly (via `AvatarUploadProvider`'s unit tests) but not end-to-end
   as a widget.
3. **`ImagePickerAvatarPicker` (the real `image_picker` wrapper) is
   untested**, per this codebase's explicit convention for thin platform
   wrappers (same as `NativeDeviceContactPicker`/`UrlLauncherSmsLauncher`)
   — its `maxWidth`/`maxHeight`/`imageQuality` choices (1600px / 85) are
   reasonable defaults, not values verified against real photos from real
   devices for actual resulting file size.
4. **iOS `NSPhotoLibraryUsageDescription`/`NSCameraUsageDescription`
   wording and the whole iOS picker flow are unverified on a real device**
   (no Mac/iOS toolchain available in this session) — same category of gap
   already flagged for T2's iOS SMS behavior.
5. **A legacy user record whose `image` field is literally the string
   `'no-image'`** (the backend's own special-cased redirect target) would
   still be passed through `Image.network` rather than being detected as
   "no avatar" by `AvatarUrlBuilder` — harmless today (the backend redirects
   `'no-image'` to a real fallback image, so it still renders something),
   but this client never produces that literal itself, so it's an
   unexercised edge case rather than a defect against the stated acceptance
   criterion ("placeholder when empty or on load error").

### T10 — Alert detail map (done)

Resumed and finished after the 2026-09-26 pause. Route: delegated direct per
the parent's routing (writer trigger: iOS platform files + `Info.plist` +
`alert_detail_sheet.dart` + a new test — 2+ non-trivial files).

#### Sanity check of the paused-session helpers (no defects found)

Verified all four helpers in `lib/features/alerts/presentation/map/` and
their tests against legacy parity by reading
`saeta-ciudadano/app/src/main/java/com/kazuro/saetaciudadano/Controller/Fragment/alerts/AlertDetailFragment.java`
(`markPoiOnMap`) and `App/Config.java` directly:
- `alert_marker_hue.dart`: the four hardcoded hues match the exact
  hex-to-HSV conversion of the legacy `strings.xml` colors (`textColorState*`:
  `#17E76A`/`#0029FF`/`#FF9900`/`#FF0000` — confirmed byte-for-byte against
  `strings.xml`), and the "unknown state -> hue 0" fallback correctly mirrors
  the legacy Java `switch` having no `default` branch (leaves `color[3]` at
  its zero-initialized value). No change needed.
- `alert_map_card.dart`'s `_legacyMapZoom = 16` matches `Config.MAP_ZOM = 16`
  exactly. No change needed.
- `alert_map_coordinates.dart`: correctly treats exact `(0, 0)` as the
  missing-coordinate sentinel (matches `CitizenAlertModel.fromJson`'s
  default) while still allowing a single axis to legitimately sit at 0; NaN
  and out-of-range lat/lng also rejected. No change needed.
- `alert_maps_url_builder.dart` / `map_style_asset.dart`: straightforward,
  already correct.
- Conclusion: **no defects found in the four helpers or their existing 4
  test files** — nothing was changed here beyond this review.

#### Wiring into `alert_detail_sheet.dart`

Inserted `AlertMapCard` right after the existing "Ubicación GPS"
`_buildDetailTile` (which keeps the raw lat/lng text for accessibility) and
before the "Personal que Atendió" tile, passing `alert.latitude`,
`alert.longitude`, `alert.stateName`, `alert.typeName` directly —
`CitizenAlertEntity.latitude`/`longitude` are non-null `double`s (`required`
in the entity), so no null-handling is needed at the call site; the
(0,0)-sentinel / out-of-range cases are already handled inside
`alertMapCoordinates`, which `AlertMapCard` calls internally to decide
placeholder vs. map.

#### New widget test

`test/features/alerts/presentation/widgets/alert_map_card_test.dart` (2
tests) — covers the placeholder path only (zero coordinates, and an
out-of-range latitude), asserting the `'Ubicación no disponible'` text, the
placeholder icon, and the *absence* of the "Abrir en Google Maps" button.
Deliberately does not attempt to pump a real `GoogleMap` (its platform view
has no test-harness registration in this project and would fail/hang in
`flutter test`) — consistent with the task's instruction to "test what's
testable."

**TDD honesty note (RED/GREEN):** genuine RED was not observed for this
test. `AlertMapCard`'s placeholder branch was already fully implemented
before this session (partial writer output from the paused 2026-09-25
session), so running the new test against the existing implementation
passed immediately on the first run. This is reported honestly per the
task's own instruction rather than inventing a RED that didn't happen; the
rest of the T10 stack (the four map helpers) *was* built test-first in the
paused session per that session's own TDD convention (not independently
re-verified here beyond the code review above).

#### iOS key wiring (git-ignored key, missing key must not break the build)

- `ios/Flutter/Secrets.xcconfig.example` (new, committed) — documents
  `MAPS_API_KEY=` and how it's consumed.
- `ios/.gitignore` — added `Flutter/Secrets.xcconfig`.
- `ios/Flutter/Debug.xcconfig` / `Release.xcconfig` — added
  `#include? "Secrets.xcconfig"` (optional include: a missing file is not an
  error, `MAPS_API_KEY` then resolves to empty).
- `ios/Runner/Info.plist` — added `GMSApiKey` = `$(MAPS_API_KEY)`.
- `ios/Runner/AppDelegate.swift` — `import GoogleMaps`; in
  `application(_:didFinishLaunchingWithOptions:)`, reads `GMSApiKey` from
  the app bundle's `Info.plist` and calls `GMSServices.provideAPIKey(...)`
  only when the value is non-empty, so a missing key never crashes launch
  (the map view just won't render without one).

#### Other

- `assets/images/.gitkeep` added — the directory is declared as a
  `pubspec.yaml` asset dir but was empty and therefore untracked by git;
  per the task's explicit instruction, added a `.gitkeep` so it's tracked.

#### Commands run (foreground, 2026-09-26)

- `flutter test test/features/alerts/presentation/widgets/alert_map_card_test.dart`:
  **2/2 passed** (run first, in isolation, to check RED — see honesty note
  above; both passed immediately).
- `flutter test`: **170/170 passed, 0 failed** (full suite, includes the 4
  pre-existing map-helper test files + the new widget test file on top of
  the prior 165-baseline... exact prior count not independently re-verified
  since T9; this run is the count of record).
- `flutter analyze`: **No issues found!**
- `flutter build apk --debug`: **success** —
  `build\app\outputs\flutter-apk\app-debug.apk` built via Gradle
  `assembleDebug` (confirms a missing/blank `MAPS_API_KEY` in
  `android/local.properties` does not break the Android build, since
  `manifestPlaceholders["MAPS_API_KEY"]` defaults to `""` when the property
  is absent).
- `flutter build ios` (or any iOS build/Xcode step): **not run** — this
  session is on Windows, which cannot build or verify iOS targets. The iOS
  key-wiring code (xcconfig include chain, `Info.plist` key, `AppDelegate`
  Swift change) is unverified beyond visual review and mirrors the working
  Android pattern; flagging as the one acceptance-criterion aspect ("iOS
  reads it from a git-ignored xcconfig... missing key must not break the
  build") that could not be functionally confirmed on this machine.

#### Not done / decision gaps (do not invent — flagging for the user)

1. iOS build/launch is unverified (see above) — worth a manual check on
   macOS before shipping, both with and without a real `MAPS_API_KEY`, to
   confirm the optional-include chain and the `AppDelegate` guard behave as
   intended.
2. No widget test exercises the actual `GoogleMap` (marker/style/zoom)
   rendering path — only the placeholder path is automated, per the task's
   own instruction not to fight the platform-view test harness. The
   marker-hue/zoom/style values were instead verified by direct code
   comparison against the legacy Android source (see sanity-check section
   above), not by a rendered-widget assertion.
3. `alert_detail_sheet.dart` (like `profile_view.dart`/`emergency_view.dart`
   before it) has no dedicated widget test for the sheet as a whole — only
   the new `AlertMapCard` unit gets one, consistent with this codebase's
   existing convention of leaving these larger presentation-layer sheets/
   views untested end-to-end.
