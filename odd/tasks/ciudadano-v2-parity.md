# Feature: ciudadano-v2-parity

## Objective
Bring the Flutter citizen app (`saeta_ciudadano_v2`) to functional parity with the legacy Android app (`saeta-ciudadano`) on the two most critical gaps.

## Problem / Why
- The refresh token is stored but never used: when the access token expires, every authenticated call fails with 401 and the session is effectively broken.
- Emergency contacts + SMS on alert (core safety feature of the legacy app) do not exist in v2.

## Scope
- T1: Token refresh on 401 (Dio interceptor, centralized Bearer header, session-expired handling).
- T2: Emergency contacts management (max 5, picked from device contacts, "send SMS" toggle) + SMS dispatch on alert. Decision made and implemented: open the device SMS composer (no `SEND_SMS` permission, no silent SMS) — see T2 evidence below.

Out of scope: sockets, profile edit, photo upload, maps (tracked as later gaps).

## Constraints
- Clean architecture per feature (data/domain/presentation), get_it DI, dartz Either.
- Backend contract: `POST /v1/auth/refresh` body `{ refreshToken }` → `{ accessToken, refreshToken, user }`.
- TDD: strict (source: user global config). Runner: `flutter test`.
- Repository is not under git: work-unit commits are not possible until the user initializes one.

## Tasks
- [x] T1 — Token refresh interceptor (route: delegated direct — touches http_client, secure_storage, service_locator, 2 datasources, auth bloc/app navigation + tests)
- [x] T2 — Emergency contacts + SMS on alert. Decision: open the device SMS composer (url_launcher `sms:`), no SEND_SMS permission. Also narrowed AuthInterceptor public paths: only `POST /v1/users` and `GET /v1/users/dni/:dni` are public; `PATCH`/`GET /v1/users/:id` need the Bearer header (route: delegated direct — new `emergency_contacts` feature across data/domain/presentation, `AuthInterceptor` fix, `SecureStorage`, `service_locator`, profile/emergency UI hooks + tests).
- [ ] T3 — Socket.IO client: listen to `updatedAlert-{userId}` and `disableUser-{userId}`

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
