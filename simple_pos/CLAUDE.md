## STEP 4 — Migrate database from sqflite to Isar

### Why Isar
sqflite does not support Flutter Web. Isar works on mobile, desktop, and web
with the same API. No migration of logic patterns needed — it fits setState-only apps well.

---

### 4A — Read before touching anything
1. Run `find lib/ -name "*.dart" | sort` and read every file
2. Identify every place sqflite is used:
   - Database initialization
   - Table creation / schema
   - Insert, update, delete, query operations
   - Any raw SQL strings
3. List all the models/entities that are currently stored in sqflite
4. Confirm the full list to the user before writing a single line of code

STOP here and print:
`📋 FOUND [N] models: [list them] — starting migration now`

---

### 4B — pubspec.yaml
- Remove: `sqflite` and any sqflite-related packages
- Add: `isar`, `isar_flutter_libs`, `path_provider`
- Add to dev_dependencies: `isar_generator`, `build_runner`
- Print the updated pubspec.yaml block and say:
`⚠️ Run: flutter pub get && dart run build_runner build --delete-conflicting-outputs`
- Then STOP and wait for user to say "continue"

---

### 4C — Migrate models one by one
For each model identified in 4A, do the following IN ORDER, finishing one before starting the next:
- Add Isar annotations (`@collection`, `@Id`, field types)
- Generate the correct Isar schema (no raw SQL, no manual ID management — Isar handles IDs)
- Keep all existing fields, do not rename or remove anything
- Print: `📝 Migrated model: [ModelName]`

---

### 4D — Migrate database service / repository
- Replace the sqflite database helper/service class entirely with an Isar equivalent
- Replace every raw SQL query with the equivalent Isar query:
  - `INSERT` → `isar.writeTxn(() => isar.collection.put(obj))`
  - `SELECT WHERE` → `isar.collection.filter()...findAll()`
  - `UPDATE` → `isar.writeTxn(() => isar.collection.put(obj))` (same as insert, Isar upserts by ID)
  - `DELETE` → `isar.writeTxn(() => isar.collection.delete(id))`
- Keep all method names and signatures identical to what the rest of the app already calls
  so that no other file needs to change
- Print: `📝 Migrated: database service`

---

### 4E — Isar initialization
- Initialize Isar in `main.dart` before `runApp()`
- Open all collections in one `Isar.open()` call
- Make the Isar instance accessible to the rest of the app
  the same way the old database was accessed (singleton, passed down, or however it was done before)
- Print: `📝 Updated: main.dart`

---

### 4F — Verify nothing is broken
- Search for any remaining imports of `sqflite` or `package:sqflite` → remove them all
- Search for any remaining raw SQL strings → flag them if found
- Check that every screen/widget that used to call the old DB methods still compiles
  (method names should be unchanged from 4D)
- Print a final checklist:

| File | Status |
|------|--------|
| pubspec.yaml | ✅ updated |
| main.dart | ✅ updated |
| [model files] | ✅ migrated |
| [service file] | ✅ migrated |
| sqflite imports remaining | ✅ none |

---

STOP after this. Say: `✅ STEP 4 COMPLETE — run build_runner then test on web and mobile`