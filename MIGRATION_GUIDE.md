# Blood Bridge – Firebase → PostgreSQL Migration Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   Flutter UI (Screens)               │
├─────────────────────────────────────────────────────┤
│                  Service Locator (sl)                 │
│         lib/core/service_locator.dart                │
├──────────────────────┬──────────────────────────────┤
│   Repository Interfaces                              │
│   (i_auth_repository.dart, i_user_repository.dart…)  │
├──────────────────────┼──────────────────────────────┤
│  Firebase Impl        │  Supabase Impl (PostgreSQL)  │
│  (lib/repositories/   │  (lib/repositories/          │
│   firebase/)          │   supabase/)                 │
└──────────────────────┴──────────────────────────────┘
```

## Step-by-Step Migration Plan

### Phase 1: Setup Supabase (1–2 days)

1. **Create a Supabase project** at https://supabase.com
2. **Run the schema SQL**:
   - Open Supabase SQL Editor
   - Copy & paste `database/supabase_schema.sql`
   - Click "Run"
3. **Create a storage bucket** named `blood-bridge-files`
4. **Configure auth providers**: Enable Email/Password in Authentication → Providers

### Phase 2: Install Dependencies (1 hour)

Add to `pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.8.0
```

Run:
```bash
flutter pub get
```

### Phase 3: Initialize Supabase (30 min)

In `main.dart`, add before `runApp()`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',      // from Supabase dashboard → Settings → API
    anonKey: 'YOUR_ANON_KEY',      // from Supabase dashboard → Settings → API
  );

  runApp(MyApp());
}
```

### Phase 4: Switch Service Locator (5 minutes)

In `lib/core/service_locator.dart`, change:
```dart
BackendProvider _provider = BackendProvider.firebase;  // OLD
BackendProvider _provider = BackendProvider.supabase;   // NEW
```

And uncomment all Supabase imports + Supabase constructor calls.

### Phase 5: Migrate Data (1–2 days)

Use the **Supabase migration script** (create a Dart script or Node.js script) to:
1. Read all Firestore collections
2. Transform to Postgres format (snake_case)
3. Insert into Supabase tables

### Phase 6: Test Everything (1 week)

- Test auth (sign up, sign in, sign out)
- Test user CRUD
- Test blood requests
- Test chat
- Test broadcasts
- Test file uploads
- Test all admin features

---

## Key Differences: Firebase vs PostgreSQL/Supabase

| Feature | Firebase | PostgreSQL/Supabase |
|---------|----------|---------------------|
| **Auth** | Firebase Auth | Supabase Auth (GoTrue) |
| **Database** | Firestore (NoSQL) | PostgreSQL (SQL) |
| **Real-time** | Firestore listeners | Supabase Realtime |
| **Storage** | Firebase Storage | Supabase Storage (S3) |
| **Queries** | Limited (compound indexes) | Full SQL |
| **Relations** | Subcollections | JOINs / Foreign Keys |
| **RLS** | Firestore Rules | PostgreSQL RLS |
| **Geospatial** | Geohashes | PostGIS |
| **Cost** | Pay per read/write | Pay per database size |

---

## File Structure After Migration

```
lib/
├── core/
│   └── service_locator.dart          # DI container
├── models/
│   ├── user_model.dart               # Unified User model
│   ├── blood_request_model.dart
│   ├── chat_model.dart
│   ├── broadcast_model.dart
│   └── donation_model.dart
├── repositories/
│   ├── i_auth_repository.dart        # Interface
│   ├── i_user_repository.dart
│   ├── i_blood_request_repository.dart
│   ├── i_chat_repository.dart
│   ├── i_broadcast_repository.dart
│   ├── i_donation_repository.dart
│   ├── i_storage_repository.dart
│   ├── firebase/                     # Current (keep as fallback)
│   │   ├── firebase_auth_repository.dart
│   │   ├── firebase_user_repository.dart
│   │   └── ...
│   └── supabase/                     # New PostgreSQL backend
│       ├── supabase_auth_repository.dart
│       └── ...
├── screens/                          # Will be refactored to use sl.*
└── services/                         # Legacy services (can be deprecated)
database/
├── supabase_schema.sql               # Supabase/PostgreSQL schema
└── standalone_schema.sql             # Standalone PostgreSQL/MySQL schema
```

---

## Best Option: Supabase (PostgreSQL)

**Why Supabase over raw PostgreSQL/MySQL:**
1. Managed Auth (no need to build your own JWT system)
2. Managed Storage (S3-compatible)
3. Real-time subscriptions (like Firestore listeners)
4. Auto-generated REST API (PostgREST)
5. Row-Level Security (like Firestore rules)
6. Free tier sufficient for development
7. Open source – can self-host
8. Excellent Flutter SDK

**Why PostgreSQL over MySQL:**
1. PostGIS for geospatial (your app has location features)
2. JSONB for flexible document-like data
3. Better full-text search
4. Stronger SQL standards compliance
5. Supabase is Postgres-only

---

## Quick Start Commands

```bash
# 1. Add Supabase to Flutter
cd fyp
flutter pub add supabase_flutter

# 2. Create a Supabase project at https://supabase.com

# 3. Run the schema in Supabase SQL Editor
# Copy database/supabase_schema.sql content

# 4. Switch the service locator (edit lib/core/service_locator.dart)
# Change _provider to BackendProvider.supabase

# 5. Run the app
flutter run
```
