# Simple POS — Project Overview

> A point-of-sale application for small Algerian shops (kiosks, hardware stores). The product is bilingual (Arabic / French), supports two stores, runs offline-first against a local Hive database, and (optionally) syncs to a Supabase backend with realtime updates for multi-device use. It targets Flutter for Android, iOS, and the Web.

---

## 1. Project Summary

`simple_pos` is a Flutter app used as the day-to-day POS at **Kiosque Djalil Ranim** and **Quincaillerie Djalil Ranim**, two stores located in Annaba, Algeria. The app lets the shop owner:

- Manage inventory (stock) per store with prices, buying price, barcode, and quantity.
- Make sales (full or partial payment) that update inventory and customer debt atomically.
- Manage customers and record debt payments.
- Browse sales history with date filters, search, and PDF invoice export.
- View an "overview / private space" (password-gated) showing total debts, total profit, and per-product price editing.
- Work fully offline; optionally sync to Supabase when configured, with realtime updates between devices on the web.

The UI is in Arabic and French (Arabic being the dominant UI language), uses RTL layout, and renders Arabic glyphs correctly in PDF invoices via a bundled Noto Naskh Arabic variable font.

---

## 2. Tech Stack

| Layer | Technology | Version (from pubspec / build files) |
| --- | --- | --- |
| Language | Dart | SDK `^3.5.3` |
| UI framework | Flutter | (stable, channel) |
| State management | `flutter_bloc` | `^8.1.3` |
| Reactive helpers | `provider` | `^6.0.5` |
| Local DB | Hive (via `hive_flutter`) | `hive: ^2.2.3`, `hive_flutter: ^1.1.0` |
| Cloud backend | Supabase (Flutter SDK) | `supabase_flutter: ^2.8.0` |
| Realtime | Supabase Postgres Changes | bundled in `supabase_flutter` |
| Tables UI | `data_table_2` | `2.5.3` |
| Autocomplete | `flutter_typeahead` | `^5.2.0` |
| CSV import/export | `csv` | `^5.1.0` |
| File picking | `file_picker` | `^10.3.1` |
| Paths | `path: ^1.9.1`, `path_provider: ^2.1.5` |
| IDs | `uuid` | `^4.5.1` |
| Intl / formatting | `intl` | `^0.18.1` |
| PDF generation | `pdf` | `^3.11.0` |
| PDF printing/sharing | `printing` | `^5.11.1` |
| Lints | `flutter_lints` | `^4.0.0` |
| Android | Kotlin / Gradle | `applicationId = com.example.simple_pos`, `compileSdk = flutter.compileSdkVersion` |
| iOS | Swift (Runner.xcodeproj) | default Flutter scaffolding |
| Optional web server | Flask | `Flask==3.1.0` (see `deploy/flask_app/`) |
| CI | GitHub Actions | `subosito/flutter-action@v2`, `peaceiris/actions-gh-pages@v3` |

Versions above are quoted directly from `pubspec.yaml`, `deploy/flask_app/requirements.txt`, and the workflow file.

---

## 3. Folder / File Structure

```
simple_pos/
├── .github/workflows/deploy.yml       # GitHub Pages build + deploy for Flutter web
├── .flutter-plugins, .flutter-plugins-dependencies
├── .gitignore
├── .metadata                          # Flutter project metadata
├── analysis_options.yaml              # flutter_lints preset
├── pubspec.yaml                       # Flutter dependencies + asset declarations
├── android/                           # Android host project (Kotlin, Gradle 8.x)
│   ├── app/build.gradle               # applicationId com.example.simple_pos
│   └── settings.gradle, gradle.properties, gradlew[.bat], gradle/wrapper/
├── ios/                               # iOS host project (Swift, Runner.xcodeproj)
├── assets/
│   ├── fonts/NotoNaskhArabic-VariableFont_wght.ttf   # PDF Arabic rendering
│   └── icons/{customers,history,locked,price,sell,stock}.png   # landing buttons
├── deploy/
│   └── flask_app/
│       ├── app.py                     # Tiny Flask static server for the Flutter web build
│       └── requirements.txt          # Flask==3.1.0
├── lib/                               # All Dart source
│   ├── main.dart                      # App entry: Supabase init → DB init → Auth → Sync → runApp
│   ├── components/                    # Reusable widgets (dialogs, tables, app bar, ...)
│   │   ├── addCustomerDialog.dart
│   │   ├── addProductDialog.dart
│   │   ├── alphaNumericInputField.dart
│   │   ├── AutoComplete.dart
│   │   ├── clientSelector.dart        # Customer picker (ID lookup by trailing space)
│   │   ├── customersTable.dart
│   │   ├── deleteProductDialog.dart
│   │   ├── editCustomerDialog.dart
│   │   ├── invoicePreviewPage.dart    # Post-sale invoice screen w/ PDF export
│   │   ├── landingIconButton.dart
│   │   ├── myAppBar.dart              # Animated title + live clock + logout
│   │   ├── payDebtDialog.dart
│   │   ├── paying.dart                # Partial-payment dialog
│   │   ├── priceDialog.dart           # Quick barcode price lookup
│   │   ├── scrollArrowButtons.dart
│   │   ├── sellButton.dart
│   │   ├── sellTable.dart             # Cart table during a sale
│   │   ├── stockTable.dart
│   │   ├── storeSwitchToggle.dart     # 1↔2 store switch
│   │   ├── suggestionsInput.dart
│   │   └── updateProductDialog.dart
│   ├── pages/                         # Top-level routes
│   │   ├── landing.dart               # Home grid + "Private Space" gate (password 18071970)
│   │   ├── login.dart                 # Username + password against Supabase auth
│   │   ├── vendre.dart                # POS / make-a-sale
│   │   ├── stock.dart                 # Inventory CRUD + CSV import/export + sort
│   │   ├── customers.dart             # Customer CRUD + debt payments + CSV
│   │   ├── history.dart               # Invoice history + filters + PDF export
│   │   └── overview.dart              # Private Space: profit/debt totals + price edit
│   ├── services/
│   │   ├── auth/simple_auth_service.dart       # Supabase Auth gate (username = "djalil")
│   │   ├── cubits/storeCubit.dart              # Bloc<int> holding active store id (1 or 2)
│   │   ├── formatters/display_formatters.dart  # price / quantity / customerId formatters
│   │   ├── local_database/
│   │   │   ├── dbFactory.dart         # Box handles, ID allocator, sync metadata
│   │   │   ├── dbTable.dart           # (mostly unused) abstract base
│   │   │   ├── deleteDB.dart          # Wipe local DB
│   │   │   ├── hive_database.dart     # Thin wrapper around Hive boxes + a fake "transaction" queue
│   │   │   └── model/                 # One file per table; each is the only data-access class for that table
│   │   │       ├── tablecustomers.dart
│   │   │       ├── tabledebt.dart
│   │   │       ├── tableinvoice.dart  # Also defines DInvoiceItemsTable
│   │   │       ├── tablestock.dart
│   │   │       └── tablestores.dart
│   │   ├── platform/                  # Conditional imports (web vs io vs stub)
│   │   │   ├── download_text.dart
│   │   │   ├── download_text_io.dart
│   │   │   ├── download_text_stub.dart
│   │   │   ├── download_text_web.dart
│   │   │   ├── file_text.dart
│   │   │   ├── file_text_io.dart
│   │   │   └── file_text_stub.dart
│   │   ├── supabase/
│   │   │   ├── supabase_project_config.dart    # Reads compile-time env vars (SUPABASE_URL, etc.)
│   │   │   ├── supabase_row_mapper.dart        # Camel ↔ snake + per-table renames for stock/invoice_items
│   │   │   ├── web_pos_repository.dart         # Web-only Supabase queries (read-through)
│   │   │   ├── web_realtime_service.dart       # Subscribes to Postgres changes for live refresh
│   │   │   └── web_runtime.dart                # `useSupabaseWeb = kIsWeb && isConfigured`
│   │   ├── sync/sync_service.dart              # Periodic push/pull sync with outbox + LWW merge
│   │   ├── transactions/
│   │   │   ├── customer_account_service.dart   # Record a debt payment in one transaction
│   │   │   └── local_sale_service.dart         # Sell a cart in one transaction
│   │   └── utils/sort_utils.dart               # Arabic / Latin collation for product lists
│   └── styles/my_colors.dart                   # Store-keyed theme colors (1 = purple, 2 = green)
└── android/, ios/                               # standard Flutter platform hosts
```

There is no `test/` folder — no automated tests are committed.

---

## 4. How to Run This Project Locally

### Prerequisites

- Flutter SDK with Dart `^3.5.3` (matches `pubspec.yaml`). Verify with `flutter --version`.
- An Android / iOS toolchain if you target those platforms (Android Studio + SDKs, Xcode).
- A Chrome install if you target the web (`kIsWeb` branch is heavily exercised).
- Python 3 + pip **only** if you want to serve the built web bundle via the Flask helper.

### Optional: Supabase backend

The app works fully offline. The Supabase bits are gated on these compile-time defines:

- `SUPABASE_URL` — your project URL.
- `SUPABASE_ANON_KEY` — your anon key.
- `SUPABASE_AUTH_EMAIL` — the email account allowed to log in (must equal the username "djalil"; the password is whatever Supabase auth uses).
- `SYNC_INTERVAL_SECONDS` — sync cadence (default 20, clamped to ≥5).

Pass them to `flutter run` with `--dart-define`, e.g.:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
            --dart-define=SUPABASE_AUTH_EMAIL=you@example.com
```

Without these, the app still runs: login is disabled, sync is a no-op, and the local DB is the only source of truth.

### Common commands

```bash
# 1. Fetch packages
flutter pub get

# 2. Run on a connected device or emulator
flutter run                                    # auto-detect
flutter run -d chrome                          # web (recommended for the realtime+sync path)
flutter run -d android                         # Android

# 3. Static analysis
flutter analyze

# 4. Production build (web, the path CI uses)
flutter build web --release --base-href "/simple_pos/"

# 5. Tests
# (none committed)
flutter test          # will report "No tests found"
```

### Building for Android / iOS

```bash
flutter build apk --release         # Android APK
flutter build appbundle --release   # Android App Bundle
flutter build ios --release --no-codesign   # iOS (no codesign)
```

> The Android `release` build is currently signed with the debug key (`signingConfig = signingConfigs.debug`, see `android/app/build.gradle`). For a real release you must add a proper signing config.

### Serving the web build with the included Flask helper

```bash
# from repo root
flutter build web --release
python -m venv .venv && . .venv/bin/activate   # optional
pip install -r deploy/flask_app/requirements.txt
python deploy/flask_app/app.py                  # serves on http://0.0.0.0:8080
```

The Flask app is a thin static file server that always serves `index.html` for non-file paths (SPA fallback). It will refuse to start if `build/web/` is missing.

### CI / deployment

`.github/workflows/deploy.yml` runs on every push to `main` (and `workflow_dispatch`):

1. Checks out the repo.
2. Installs Flutter stable.
3. `flutter pub get`.
4. `flutter build web --release --base-href "/simple_pos/"`.
5. Publishes `build/web` to GitHub Pages via `peaceiris/actions-gh-pages@v3`.

---

## 5. Architecture & Key Concepts

### App boot (`lib/main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `SupabaseProjectConfig.initialize()` — only does anything when the env vars are set.
3. `DBfactory.getDatabase()` — opens Hive and seeds `stores` with two rows (`Kiosque Djalil Ranim`, `Quincaillerie`) on first run, plus a per-device UUID.
4. `SimpleAuthService.instance.initialize()` — wires Supabase auth state.
5. `SyncService.instance.initialize()` — starts the periodic timer and triggers one immediate sync.
6. `runApp(BlocProvider(StoreCubit()) → MainApp → AuthGate)`.

`AuthGate` swaps between `LoginPage` and `Landing` based on `SimpleAuthService.instance.isLoggedIn`. Logging in also kicks off `WebRealtimeService` and a sync.

### State management

- A single `StoreCubit extends Cubit<int>` holds the active store ID (1 or 2). The UI watches it via `flutter_bloc`.
- Each page reads its store-scoped data through table classes (e.g. `DStockTable().getProductsByStore(store)`) and uses `setState` for local UI state (search filters, sort order, etc.).
- `MyColors.mainColor(context)` / `MyColors.secondColor(context)` read the cubit to swap theme colors per store.

### Persistence layer (the "fake SQL" wrapper)

- `HiveDatabase` opens boxes lazily and exposes a `transaction` API built on a chained `Future` queue. There is no real locking; it serializes operations on the same isolate.
- `DBfactory` defines one `StoreRef<int, Map<String, Object?>>` per logical table: `stores`, `stock`, `customers`, `debt_payments`, `invoices`, `invoice_items`, `sync_outbox`, plus a `meta` box for counters and the per-device UUID.
- Each row carries sync metadata: `sync_id` (UUID v4), `sync_status` (`pending`/`synced`), `updated_at`, `last_synced_at`, `device_id`.
- IDs are allocated via a per-table counter stored in the `meta` box (`{table}_last_id`). This avoids Hive's key collision issues when the same record is written from multiple devices.

### Sync engine

`SyncService` (lib/services/sync/sync_service.dart) is a timer-driven, outbox-based, last-writer-wins replica:

- **Push**: every N seconds (and on app resume, and after each local write that calls `flush()`/`scheduleSync()`), drains `sync_outbox` rows ordered by id. For each row it upserts into the corresponding Supabase table using `onConflict: 'sync_id'`; on `delete`, it removes by `sync_id`. Failures bump `retry_count` and are retried next cycle.
- **Pull**: pulls `stores`, `customers`, `stock`, `invoices`, `invoice_items`, `debt_payments` in that order. Each remote row is matched to a local row by `sync_id`. If the local row exists and is **pending** with a newer `updated_at`, the local row wins (LWW). Otherwise the remote row overwrites and the corresponding outbox entries are removed.
- **Foreign keys across devices**: `_buildLocalRecord` remaps `customer_sync_id` → `customer_id` and `invoice_sync_id` → `invoice_id` by looking up the local row that owns that sync id. This is how invoices/items stay linked across devices even though the integer IDs differ.

On the **web**, `WebRealtimeService` opens Postgres-changes channels on the six managed tables and, on any change, kicks off a full `triggerSync()` and broadcasts a `Set<String>` so the active page refreshes.

### Sales flow

`LocalSaleService.sellCart` does the entire sale atomically:

1. Allocate a new invoice id and a UUID `sync_id`.
2. For each cart item, find the matching product by code or name in the active store, validate stock.
3. Optionally update customer debt (`currentDebt + (total - paid)`).
4. Persist invoice, each updated product (with the new lower quantity), and each `invoice_item` row.
5. Queue each write into the outbox.
6. Outside the transaction, call `SyncService.instance.flush()`.

The whole operation runs inside `db.transaction` so a partial failure leaves the DB untouched.

### Auth

- Login is gated behind `SimpleAuthService` which compares `username == 'djalil'` and then calls `Supabase.instance.client.auth.signInWithPassword(email: SUPABASE_AUTH_EMAIL, password: …)`. The session is accepted only if the resulting user's email matches `SUPABASE_AUTH_EMAIL` (case-insensitive).
- A separate "Private Space" gate on the landing page uses a hard-coded PIN (`18071970`).
- Logout disposes the realtime channels and pops to root.

### File / platform shims

`lib/services/platform/` uses Dart's conditional imports so the same code compiles for mobile (uses `dart:io` for file I/O), web (uses `dart:html` for downloads), and unknown targets (stub that throws `UnsupportedError`).

### Known patterns / idioms

- Most table classes follow the same shape: allocate ID → build record with `DBfactory.withSyncMetadata` → `put` in box → `queueUpsert` → optional `SyncService.flush()` (web) or `scheduleSync()` (mobile).
- All user-facing copy is in Arabic; product code, names, and store names are mixed Arabic / French.
- `data_table_2` is used for the data grids in customers / stock, with custom sorting in the stock page (Latin vs Arabic collation).
- PDF invoice rendering uses the bundled Noto Naskh Arabic variable font and forces RTL text direction.

---

## 6. Data Models / Schema

> Hive stores rows as `Map<String, Object?>`; below is the conceptual schema. Each row also has `sync_id`, `sync_status`, `updated_at`, `last_synced_at`, `device_id` (added by `DBfactory.withSyncMetadata`).

### `stores`
| Field | Type | Notes |
| --- | --- | --- |
| id | int | PK, allocated by `DBfactory.allocateId('stores')` |
| name | string | e.g. "Kiosque Djalil Ranim" |
| location | string? | e.g. "Annaba" |
| is_active | int (0/1) | |

Seeded on first run with stores 1 (Kiosque) and 2 (Quincaillerie).

### `stock`
| Field | Type | Notes |
| --- | --- | --- |
| id | int | PK |
| store_id | int | FK → stores.id |
| productName | string | |
| productPrice | string | displayed/parsed as double |
| productBuyingPrice | string | |
| productCodeBar | string? | |
| productQuantity | string | parsed as double / int depending on context |

Remote column names on Supabase are lowercase: `productname`, `productprice`, `productbuyingprice`, `productcodebar`, `productquantity`. The mapper handles both directions.

### `customers`
| Field | Type | Notes |
| --- | --- | --- |
| id | int | PK |
| store_id | int | FK → stores.id |
| name | string | |
| phone | string? | |
| debt | double | running debt balance |

### `invoices`
| Field | Type | Notes |
| --- | --- | --- |
| id | int | PK |
| store_id | int | FK → stores.id |
| date | string (ISO 8601) | UTC |
| total | string | formatted |
| profit | string | sum of (price − buyingPrice) × qty |
| customer_name | string? | |
| customer_id | int? | FK → customers.id |
| customer_sync_id | string? | survives across devices |
| total_debt_customer | string | snapshot of the customer debt at sale time |

### `invoice_items`
| Field | Type | Notes |
| --- | --- | --- |
| id | int | PK |
| invoice_id | int | FK → invoices.id |
| invoice_sync_id | string? | used during sync resolution |
| productCodeBar | string | |
| productName | string | |
| quantity | string | |
| price | string | |
| profit | string | |
| totalPrice | string | |

### `debt_payments`
| Field | Type | Notes |
| --- | --- | --- |
| id | int | PK |
| store_id | int | FK |
| customer_id | int | FK |
| customer_sync_id | string? | |
| customer_name | string | snapshot |
| customer_phone | string? | snapshot |
| amount_paid | double | |
| payment_date | string (ISO 8601) | UTC |

### `sync_outbox` (local-only)
| Field | Type | Notes |
| --- | --- | --- |
| id | int | PK |
| table | string | target remote table |
| record_id | int? | local row id |
| record_sync_id | string | remote `sync_id` to upsert/delete |
| operation | string | `upsert` or `delete` |
| payload | map | record to write (without `id`) |
| status | string | `pending`/`failed` |
| retry_count | int | |
| last_error | string? | |
| created_at, updated_at | ISO 8601 | |

### Relationships

```
stores 1 ── n stock
stores 1 ── n customers
stores 1 ── n invoices
invoices 1 ── n invoice_items
customers 1 ── n debt_payments
customers 1 ── n invoices (customer_id nullable)
```

Foreign keys between devices are tracked by `*_sync_id` so a fresh device can resolve `invoice.customer_id` to its own local id when the row arrives via pull.

---

## 7. Known Issues / Potential Bugs

> Each item lists file + approximate line, what's wrong, why it matters, and a suggested fix.

### Bugs / logic errors

1. **`lib/services/auth/simple_auth_service.dart:13`** — The username is hard-coded to `'djalil'`; the login form accepts any username but `login()` rejects anything that isn't `'djalil'`. This is silently insecure (any password is accepted if Supabase is misconfigured to accept it; the rest of the app is gated behind this single name).
   *Fix:* pull the allowed username list from config or at least log rejected attempts; consider allowing only the email-derived login and dropping the username altogether.

2. **`lib/pages/landing.dart:15`** — The "Private Space" PIN (`18071970`) is hard-coded in the source. Anyone with the binary can grep it.
   *Fix:* move to `String.fromEnvironment('PRIVATE_SPACE_PIN', defaultValue: '18071970')` and define it at build time.

3. **`lib/services/local_database/hive_database.dart:33-44`** — `transaction` is implemented as a chained `Future` queue, not an actual lock. Two concurrent calls can interleave because each callback is just an `async` lambda; there's no `await`-boundary per call to the same `Hive.openBox`. For example, `customersStore.record(id).get(txn)` and `customersStore.record(id).put(txn, …)` from two parallel transactions may both pass the existence check before either writes.
   *Fix:* protect critical sections with a real mutex (e.g. acquire a lock on each `(table, key)` pair), or batch all reads/writes inside a single `Box.putAll`-style API that operates atomically against Hive.

4. **`lib/services/sync/sync_service.dart:330-340`** — When push fails, `retry_count` is incremented and `status` is set to `'failed'`, but the next iteration still re-reads outbox rows ordered only by `id`. After many failures the queue can grow unbounded; there's no exponential backoff and no max-retry cap, so a perpetually failing row keeps retrying every cycle forever.
   *Fix:* clamp `retry_count`, skip (or quarantine) rows past a threshold, and back off by `retry_count` minutes.

5. **`lib/services/local_database/dbFactory.dart:305-352`** — `_ensureSyncMetadata` runs on every startup and re-queues an outbox upsert for every existing local row that isn't `synced` — including rows that were just pulled from Supabase moments ago. This means a freshly opened device will spam duplicate upserts on its first sync.
   *Fix:* distinguish "pulled and synced" rows from "genuinely pending local writes" and only re-queue the latter.

6. **`lib/services/local_database/model/tablestock.dart:319`** — `updateQuantity` parses `productQuantity` as `double` but the field is treated as `int` in `_findProductForSale` (lib/services/transactions/local_sale_service.dart:84) and in `addItem` (lib/pages/vendre.dart:99). Fractional stock quantities are supported by the type but rejected by the sale path.
   *Fix:* decide on a single numeric type for `productQuantity` and parse consistently.

7. **`lib/pages/vendre.dart:521-528`** — The "partial sale" path checks `if (amount > total)` and shows a SnackBar, but does not `return`. After the message it falls through to `_commitSale(... paidAmount: amount)` which itself checks the same condition and throws a `LocalSaleException`. The user sees both messages and the dialog closes.
   *Fix:* add `return;` after the SnackBar.

8. **`lib/pages/vendre.dart:60`** — Local `int quantity` shadows the State field `bool quantity` (line 47), which then is implicitly `dynamic` inside `addItem`. The `_handleEnter` in `build` reads/writes the bool one. This works but is a sharp edge — if anyone renames either, behaviour changes silently.
   *Fix:* rename one of them (e.g. `quantityField` for the bool toggle).

9. **`lib/components/selleTable.dart:92`** — `int.parse(normalized)` will throw `FormatException` on empty strings (e.g. when the user deletes all digits). The error is unhandled and will surface as a red screen.
   *Fix:* guard with `int.tryParse(normalized) ?? 1`.

10. **`lib/pages/history.dart:377`** — `_buildTotalField` creates a brand new `TextEditingController` on every rebuild without disposing the old one — a memory leak.
    *Fix:* move the controller into State and dispose in `dispose`.

11. **`lib/services/sync/sync_service.dart:101-104`** — `_pullRemoteTable` reads `select()` from each table with no pagination. A store with thousands of invoices will load everything into memory and then iterate a Hive transaction. The DB write transaction holds the (fake) lock for the duration.
    *Fix:* paginate with `.range(from, to)` or use Supabase's `count`/`head` and chunked fetches.

12. **`lib/services/supabase/supabase_row_mapper.dart:18-26`** — `toRemote` for `invoice_items` sets `'invoice_sync_id': normalized['invoice_sync_id'] ?? normalized['invoice_sync_id']` (the same key twice, with no fallback). On the web write path the FK resolution is done by the `SyncService._buildLocalRecord` step on pull, but on push the payload may miss the foreign-key relationship entirely when the upstream caller never set the sync_id.
    *Fix:* either propagate `invoice_sync_id` correctly from the caller (the invoice create flow does, but `LocalSaleService` is the only producer) or drop the redundant line.

13. **`lib/services/local_database/model/tablestock.dart:50-60`** — `getProductById` and `getProductByCode` etc. silently return `null` on any exception (just `print`'ing). The caller often cannot distinguish "not found" from "DB error", so users see "product not found" for transient failures.
    *Fix:* propagate the error to the UI or at least log to a proper channel.

### Security concerns

14. **`lib/services/auth/simple_auth_service.dart`** — No rate-limiting on login; the UI shows a generic SnackBar on failure and there's no lock-out.
    *Fix:* rate-limit on Supabase side and/or show attempts remaining.

15. **`lib/services/local_database/dbFactory.dart:128-145`** — `withSyncMetadata` accepts a `sync_id` from the caller. If a caller forgets it, a fresh UUID is minted — fine. But if the caller passes a hand-crafted one and the field ever gets exposed to a remote write, it could be used to overwrite another device's record.
    *Fix:* restrict `sync_id` to a UUID v4 pattern; reject otherwise.

16. **`lib/pages/landing.dart:15`** (already noted) — hard-coded PIN in source.
17. **`lib/services/auth/simple_auth_service.dart:13`** (already noted) — hard-coded username.

### Error-handling gaps

18. **`lib/services/local_database/model/tablestock.dart` (and the other `model/*` files)** — Every public method wraps its body in `try { ... } catch (e, stacktrace) { print(...); return null/[]/false; }`. Failures are swallowed. The UI can't tell users anything went wrong; they just see empty lists or "not found".
    *Fix:* introduce a typed result (success/failure) or rethrow and handle in the UI.

19. **`lib/services/sync/sync_service.dart:48, 54`** — `unawaited(triggerSync())` after timer / lifecycle events means any exception in `triggerSync` is dropped on the floor. The `try/finally` only protects the sync flag; a thrown error escapes to the zone error handler (i.e. red screen in debug, silent in release).
    *Fix:* wrap `triggerSync()` body in try/catch and log.

20. **`lib/services/transactions/customer_account_service.dart:17`** — Throws `StateError('Customer not found: $customerId')`. `pages/customers.dart:272` calls this inside `showPayDebtDialog`; a thrown `StateError` is not caught and will crash the dialog.
    *Fix:* catch in the page and show a SnackBar.

21. **`lib/services/platform/download_text_web.dart:12`** — `html.document.body?.append(anchor)` uses `!` on the `body` getter result. When the document hasn't been laid out yet (theoretically possible early in app boot), `append` will throw `NoSuchMethodError`. The download helper is fire-and-forget.
    *Fix:* null-check and defer.

22. **`lib/services/local_database/model/tableinvoice.dart:92`** — `print('inserted:\t$data')` logs the full invoice record (including customer name, total, debt). PHI / PII leaking to logs.
    *Fix:* remove or redact.

23. **`lib/pages/history.dart:460`** — `FutureBuilder` uses `DInvoiceItemsTable().getItemsByInvoiceId(invoice['id'])` as the future. Each rebuild creates a new future, re-fetching every expansion.
    *Fix:* memoise by invoice id.

### Performance red flags

24. **`lib/services/local_database/model/tablecustomers.dart:131-149`** — `getCustomerByName` calls `getCustomers(storeId)` (which loads every customer) and then filters in memory. This is `O(n)` per keystroke from the typeahead UI.
    *Fix:* push the filter down to the box (e.g. add a prefix filter) or cache per-store customer lists.

25. **`lib/services/transactions/local_sale_service.dart:221-244`** — `_findProductForSale` calls `stockStore.find()` for every item in the cart. With N items and a Hive box that has M products, that's `N × M` reads per sale. Same for `updateProductById` in stock.dart — every quantity edit re-reads the entire stock box via `getProductsByStore` before writing.
    *Fix:* keep an in-memory cache keyed by id within the transaction; for the sale service, load products once and iterate.

26. **`lib/pages/stock.dart:84`** — `_loadItems` is called on every store switch, every realtime change, every route pop, and every quantity edit error. Each call does `getProductsByStore` which reads the whole box.
    *Fix:* debounce or use a stream from the underlying box.

27. **`lib/components/myAppBar.dart:33-37`** — `Timer.periodic(seconds: 1)` triggers `setState` on every tick on every AppBar across the app (including those not visible). On web this can be heavy.
    *Fix:* use a single global tick provider, or only start the timer when the AppBar is the visible route.

28. **`lib/pages/history.dart:438`** — `ListView.builder` with 50+ items each triggers a `FutureBuilder` per item; each future creates a new DB query on first build.

### Dead code / unused dependencies / inconsistencies

29. **`lib/services/local_database/dbTable.dart`** — `DBBaseTable` is an abstract base that returns empty data and prints. No subclass extends it; all model files implement their own CRUD instead.
    *Fix:* delete the file or actually use it as the base.

30. **`pubspec.yaml:24`** — `uuid: ^4.5.1` is declared and used in `dbFactory.dart`. **However**, `lib/services/auth/simple_auth_service.dart` and other places still use `String.fromEnvironment` directly — fine — but the `uuid` package is only imported by `dbFactory.dart`. Not a problem, but worth noting it could be inlined if not needed elsewhere.

31. **`lib/services/sync/sync_service.dart:185-188`** — `payload['local_id']` is read as the foreign-key hint, but on the `invoice` upsert path `payload` is the result of `SupabaseRowMapper.toRemote(...)` which removes `id` (line 6 of mapper). For invoices, no rename happens in the default branch, so `local_id` is preserved. Worth double-checking all non-stock, non-invoice_items tables keep `local_id`.

32. **`lib/services/supabase/web_pos_repository.dart`** — A whole web-only repository class exists (`getStockByStore`, `getCustomerById`, `getInvoices`, …) but none of it is called from any page in `lib/pages/`. Pages go through `DStockTable` / `DCustomersTable` etc., which always use the local Hive DB. The repository is dead code.
    *Fix:* either wire it in (for a web-only Supabase mode) or delete it.

33. **`lib/services/local_database/model/tabledebt.dart`** — Note that despite the file naming, debt payments are actually implemented in `lib/services/transactions/customer_account_service.dart`; `tabledebt.dart`'s `DDebtPaymentsTable` is unused. The sync flow references `debt_payments` store via `DBfactory.debtPaymentsStore` and writes to it from `customer_account_service.dart`.

34. **`lib/services/local_database/deleteDB.dart`** — `deleteDatabaseFile()` is exported but not referenced anywhere in `lib/`.

35. **`lib/services/platform/download_text_stub.dart` / `file_text_stub.dart`** — Both throw `UnsupportedError` for non-io, non-web targets. The conditional imports only cover `dart.library.io` and `dart.library.html`. Mobile targets work (io), web works (html), but anything exotic (e.g. a future Fuchsia target) would crash at runtime rather than at compile time.

### TODOs / hacks left in

36. **`android/app/build.gradle:23, 35`** — `TODO: Specify your own unique Application ID` and `TODO: Add your own signing config for the release build.` Both must be addressed before shipping.

37. **`lib/pages/vendre.dart:1-3`** — The file starts with a `/** maybe start using the loaded items instead of database calls? */` comment. The TODO is unaddressed.

38. **`lib/services/auth/simple_auth_service.dart:23`** — `_isConfigured` returns false when either Supabase or the email env var is missing. The login UI then shows "Supabase غير مهيأ لتسجيل الدخول" and the user has no way to even reach the landing page. There is no documented offline-only mode flag.

---

## 8. Open Questions / Ambiguities

These are points where the code doesn't make the intent clear and a human should confirm:

- **Multi-store behaviour.** `StoreCubit` only knows stores 1 and 2 (the seeded ones). `MyColors` has a stub for store 3 (`0xFFFF6600`). Is store 3 ever planned, or is the third colour dead code?
- **Two sync paths.** The web sets `useSupabaseWeb` and routes through `WebRealtimeService` + the live `WebPosRepository`; the mobile build never sees that code. Is the intent for mobile to remain offline-only, or should `supabase_flutter` work there too?
- **Authentication model.** Username is hard-coded to `'djalil'`; password goes to Supabase. Is "djalil" the only intended user, or is this a placeholder? Should login be removed for a single-operator POS?
- **Private Space password.** `18071970` looks like a date (July 19, 1970). Is this a personal PIN that needs to be moved out of source?
- **Pricing precision.** Prices are stored as strings in Hive and parsed at every read. Profit math mixes doubles. Should this move to integers (in cents/dinars) or `decimal`?
- **CSV format.** Stock CSV columns are: `productName, productPrice, productBuyingPrice, productCodeBar, productQuantity`. Customers CSV columns are: `Name, Phone, Debt`. There's no schema check on import; mismatched headers silently produce blank rows.
- **Outbox growth.** No retention cap on `sync_outbox`. Is it expected to grow indefinitely?
- **Sync conflict resolution.** LWW with "pending local beats newer remote". What happens if the remote also has a pending local change? Is there a documented merge rule for debts / payments?
- **`DInvoiceItemsTable.deleteItemsByInvoiceId`** exists but no caller invokes it. Was it planned for an "edit invoice" feature that never shipped?
- **The `analyzer` rule.** `analysis_options.yaml` only includes `flutter_lints`. There's no test coverage threshold. Are stricter rules (e.g. `prefer_const_constructors`) wanted?
- **Repository URL.** The deploy workflow targets `--base-href "/simple_pos/"` — is the GitHub Pages URL `RandaBasmalaBenmaiche/simple_pos`? Worth confirming the org/user name so the page deploys correctly.

---

## 9. Updates

> This section is appended over time. **Read this file before starting new work, and update it after significant changes.**

<!-- Add new dated notes below. Keep most recent at the top. -->
