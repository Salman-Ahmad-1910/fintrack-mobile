# Completion report — FinTrack ERP Flutter app

> **Verification status.** This work was done in an environment with no
> Flutter/Dart SDK and no network access to the FinTrack server. Nothing here
> has been compiled, analyzed, tested or run against the live API. All code
> was checked by reading it against the Go backend and the Next.js web source.
> Run `flutter pub get`, `flutter analyze`, `flutter test` and an Android
> build before relying on it, and report any errors back.

## 1. Web application (reference) — summary

- **Backend:** Go (Gin + GORM + PostgreSQL), multi-tenant. Every route is
  under `/api/v1`; company is chosen with the `x-company-id` header (or
  `companyId` query). JWT in `Authorization: Bearer`. Responses use the
  envelope `{success, message, data, error}`. `/health` for liveness.
- **Frontend:** Next.js static export embedded in the Go binary; uses relative
  `/api/v1`, so the deployed server address only appears in the mobile app.
- **Auth:** `/auth/login`, `/auth/signup`, `/auth/forgot-password`,
  `/auth/reset-password`, `/auth/me`, `/auth/logout`, `/companies`.
- **Authorization:** roles (admin, owner, manager, dealer, sub_dealer, staff,
  recovery_officer) + per-user page permissions (`PERMISSION_PAGES`) + per-page
  CRUD child permissions (`<pageId>:create|update|delete`, global fallbacks
  15362/15363/15364). Admin/owner/manager bypass page filtering.
- **Generic CRUD:** most lookup tables use `RegisterGenericCRUD` — `GET` list
  (any query param becomes an equality filter), `POST`, `PUT /:id` (GORM
  `Save()`, i.e. full replace), `DELETE /:id`.

## 2. Feature comparison

| Area | Web | Flutter (before) | Flutter (now) |
|---|---|---|---|
| Login / signup / company / `/auth/me` | ✓ | ✓ | ✓ (profile re-read on app start) |
| Logout (`POST /auth/logout`) | ✓ | session cleared only | ✓ |
| Forgot / reset password (OTP) | ✓ | "contact admin" message | ✓ new screen |
| Role-based menu | ✓ | ✓ | ✓ |
| Per-user page permissions in menu | ✓ | ✗ | ✓ (`page_permissions.dart`), plus guard on opening hidden pages |
| Dashboard, Network, Messages, CRM, Sales/POS, Transactions, Inventory, Accounts, Recovery officers, Company profile, Roles, Settings | ✓ | ✓ (existing) | ✓ unchanged |
| Complaint Type / Subject Type | ✓ | placeholder | ✓ CRUD |
| Subscriber Complaint (create, edit, status, allocate, delete) | ✓ | placeholder | ✓ |
| Allocated Complaints (own-only for staff/ROs) | ✓ | placeholder | ✓ |
| Complaint Report (filter, print, export) | ✓ | placeholder | ✓ (print → PDF, CSV) |
| HR: Staff | ✓ (5-tab form) | placeholder | ✓ personal/accounts/other fields; qualifications, experience, work times and attachments are kept on update but not editable on mobile |
| HR: Salary, Attendance (day), Attendance report, Advances & Loans | ✓ | placeholder | ✓ |
| System Log (filters, paging, restore deleted, export) | ✓ | placeholder | ✓ |
| Downloads: Drivers / Application | ✓ | placeholder | ✓ list, download (browser), upload .exe/.msi/.zip, delete |
| My Dealers | ✓ | placeholder | ✓ CRUD + change status |
| Pending Subscribers (server-side filters/paging) | ✓ | placeholder | ✓ + print/CSV of full result |
| Advance Subscribers (+ reset) | ✓ | placeholder | ✓ |
| Deactivate Users, Expiry Defaulters, New Subscribers, Package Wise, Creator Summary | ✓ | placeholder | ✓ |
| Dealer Dashboard, Dealer reports (Collections, Defaulters, New Dealers, Invoices) | ✓ | placeholder | **not done** |
| Abstract Stock / Abstract Sale | ✓ | placeholder | **not done** |
| Subscriber reports: Collections, Promise Dates, Allocated Defaulters, Month Defaulters, Monthly Collections, Allocated Collections, Month-wise Collection Monthly, Not Generated, Unpaid, Subscribers Defaulters | ✓ | placeholder | **not done** (still show the placeholder) |
| Admin "Reports" page | ✓ | placeholder | **not done** |
| Service Desk (Alerts, Support Tickets) | no page / no sidebar entry in web | placeholder | removed from mobile menu |

## 3. Files changed

**New**
- `lib/core/page_permissions.dart` — port of `PERMISSION_PAGES` + `getAllowedHrefs`
- `lib/features/shared/crud_kit.dart` — shared form sheet, selects, paging, error/empty states
- `lib/features/auth/forgot_password_screen.dart`
- `lib/features/support/support_common.dart`, `lib/features/support/complaints_screens.dart`
- `lib/features/hr/hr_screens.dart`
- `lib/features/admin/system_log_screen.dart` (System Log + Downloads)
- `lib/features/dealers/my_dealers_screen.dart`
- `lib/features/reports/subscriber_reports_screens.dart`
- `android/app/src/{main,debug,profile}/res/xml/network_security_config.xml`
- `android/key.properties.example`, `test/completion_logic_test.dart`, `COMPLETION_REPORT.md`

**Modified**
- `lib/core/api_client.dart` — clear TLS/timeout/offline messages, `isForbidden`/`isNetworkError`, multipart field name, no JSON content-type on uploads, dropped undeclared `package:meta`
- `lib/core/api_config.dart` — longer health-probe timeout, certificate notes
- `lib/core/session.dart`, `lib/models/models.dart`, `lib/features/auth/auth_flow.dart` — store user id; logout clears permissions
- `lib/features/shell/app_shell.dart` — new routes, `/auth/logout`, profile refresh, access guard
- `lib/features/shell/nav_items.dart` — page-permission filtering, removed dead Service Desk group
- `lib/features/shell/coming_soon.dart` — optional message
- `lib/features/auth/login_screen.dart`, `lib/main.dart` — forgot-password route, fixed garbled "Locating server…" text
- `lib/features/sales/sales_common.dart` — **Android fix:** CSV export crashed (file_picker needs bytes on mobile); HTML print/receipts failed (Android blocks `file://`) → now uses the system print / Save-as-PDF sheet
- `lib/features/crm/subscriber_detail_screen.dart` — same CSV fix
- `android/app/build.gradle.kts` — release signing from `key.properties`
- `android/app/src/main/AndroidManifest.xml` — HTTPS-only network security config instead of global cleartext
- `README.md`

## 4. APIs used by the new screens

`POST /auth/forgot-password`, `POST /auth/reset-password`, `POST /auth/logout`,
`GET /auth/me`;
`/support/complaints`, `/support/complaint-types`, `/support/complaint-subjects`
(GET/POST/PUT/DELETE);
`GET /admin/connections`, `PUT /admin/connections/:id`, `GET /subscribers`,
`GET /network/areas`, `GET /billing/packages`, `GET /admin/users?includeAdmin=true`,
`GET /admin/recovery-officers`;
`/hr/staff`, `/hr/departments`, `/hr/salary`, `/hr/attendance`, `/hr/advances`;
`GET /admin/logs`, `POST /admin/logs/:id/restore`;
`GET /drivers`, `GET /applications`, `POST /upload/driver`,
`POST /upload/application` (multipart field `file`), `DELETE /files/:id`,
`GET /api/v1/uploads/files/:name`;
`/dealers` (GET/POST/PUT/DELETE);
`GET /collection/pending-subscribers`.

## 5. Backend issues found (not changed — need your approval)

1. **Unauthenticated route groups:** `/billing`, `/recovery`, `/sales`,
   `/corporate`, `/bill-creator`, `/payments`, `/products`, `/plans`, `/pos`
   and `/support` have no auth middleware; `/accounts`, `/crm`, `/inventory`
   use optional auth. Anyone with a company UUID can read/write that data.
2. **Password reset OTP leak:** without SMTP, `/auth/forgot-password` returns
   the OTP in the response (and the web shows it) → account takeover. The
   mobile app never displays it.
3. **SQL built from query-param names** in generic `FindAll`
   (`db.Where(key+" = ?")`).
4. **Generic `PUT` = full overwrite** (`Save()`): clients must send the whole
   record. The new mobile screens do; check other clients.
5. **`UpdateDealer` clears the address** on every update that omits it — the
   web's status change (`{status}` only) wipes dealer addresses. Mobile sends
   the address along.
6. **Plain-text staff passwords** (`plainPassword`) are stored and shown on the
   web staff table. Mobile does not display them.
7. Production TLS falls back to a self-signed localhost certificate (see
   README §2).

## 6. Known limitations / not done

- Modules marked **not done** above still show the "coming soon" placeholder.
- Staff form does not edit qualifications, experience, work times or
  attachment images (preserved on update).
- Offline mode: new screens read from the existing Hive cache when offline and
  writes are queued by `OfflineApi`, but only payments/promises/dealer
  collections get optimistic list updates; queued complaint/HR writes appear
  after sync.
- `invHasPermission` treats `manager` as admin for CRUD buttons, while the web
  `useCrudPermissions` only treats admin/owner that way (server still enforces).
- Not verified on a device, emulator, or against the live server.

## 7. Tests / checks to run

```powershell
flutter pub get
flutter analyze
flutter test                       # includes test/completion_logic_test.dart
flutter build apk --debug
```
