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

Out of scope: profile edit, photo upload, maps (tracked as later gaps).

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
- [x] T6 — Auto-login on app start via `GET /v1/auth/me` (route: delegated direct — `AuthBloc._onSessionChecked`, new `GetCurrentUserUseCase` + `AuthRepository.getCurrentUser` + `AuthRemoteDataSource.getCurrentUser`, `service_locator` + tests).

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
