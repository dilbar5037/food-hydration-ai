# AI Copilot Instructions for food_hydration_ai

## Project Overview
A Flutter mobile app for tracking food hydration and nutrition with ML-powered food recognition. Uses Supabase for backend/auth and TensorFlow Lite for on-device image classification. Multi-role system: **admin** (manage foods/users), **mentor** (support users), **user** (track meals/hydration).

## Architecture

### Core Layers
- **Config** ([`lib/config/`](lib/config/)) — Supabase credentials & validation
- **Core** ([`lib/core/`](lib/core/)) — Auth, routing, networking, utilities
- **Services** ([`lib/services/`](lib/services/)) — Food inference, image capture, TensorFlow integration
- **Features** ([`lib/features/`](lib/features/)) — Role-based screens (admin, user, mentor) + domain-specific features
- **UI** ([`lib/ui/`](lib/ui/)) — Shared components, theme, spacing constants

### Data Flow
1. **Authentication** → [AuthService](lib/core/auth/auth_service.dart) (email/password via Supabase)
2. **Authorization** → [RoleService](lib/core/auth/role_service.dart) queries `app_users.role`, routes via [RoleGate](lib/core/routing/app_router.dart)
3. **Food Scanning** → Image → [FoodClassifier](lib/services/food_classifier.dart) loads TFLite model → [FoodInferenceService](lib/services/food_inference_service.dart) runs inference (224×224 input, normalized 0–1) → [FoodScanLogService](lib/features/foods/data/services/food_scan_log_service.dart) logs to Supabase
4. **Routing** → [GoRouter](lib/core/routing/app_router.dart) with session/role-based redirects; auth state listener refreshes on login/logout

### Key Integrations
- **Supabase**: Auth, RLS-protected `app_users`/`food_scan_logs`/`meal_logs` tables
- **TensorFlow Lite**: Food classification from camera/gallery images (Food101 dataset)
- **Connectivity/Network**: [SupabaseAutoRefreshGuard](lib/core/services/supabase_auto_refresh_guard.dart) pauses token refresh when offline
- **Notifications**: Reminders via `awesome_notifications` + `flutter_local_notifications`

## Critical Patterns

### Role-Based Routing
- **RoleGate** (post-login) fetches user role from `app_users.role` and redirects:
  - `admin` → [AdminHomeScreen](lib/features/admin/admin_home_screen.dart)
  - `mentor` → [MentorHomeScreen](lib/features/mentor/mentor_home_screen.dart)
  - `user` → [UserHomeScreen](lib/features/user/user_home_screen.dart)
- Role changes via RPC `admin_set_user_role` (admin-only)
- **Never** set role in client; relies on Supabase RLS policies

### Food Inference Pipeline
- Model loads once; interpreter reused across captures
- Input: Uint8List → decode → resize to 224×224 → normalize → inference
- Output: confidence scores per class; threshold `_confThreshold = 0.60` (check [FoodScanScreen](lib/features/foods/ui/food_scan_screen.dart) L23)
- Low-confidence predictions logged but flagged in UI

### Offline Handling
- [SupabaseAutoRefreshGuard](lib/core/services/supabase_auto_refresh_guard.dart) monitors connectivity; stops auth refresh when offline
- Logs queue locally, sync deferred until online
- Network check in [RoleGate](lib/core/routing/app_router.dart) before resolving role

### Database Schema
- `foods` (id, food_key, display_name) — Food101 labels
- `food_nutrition` (food_id, serving_size_g, calories, protein, carbs, fat) — Nutrition facts
- `app_users` (id, email, name, role) — Auth + role assignment
- `food_scan_logs` (user_id, predicted_label, confidence, imagePath, dedupeKey) — Inference results
- Seed script: [supabase/seed_food101.sql](supabase/seed_food101.sql)

## Development Workflows

### Build & Run
```bash
flutter pub get
flutter run  # Debug mode (Android/iOS/Web)
flutter build apk  # Production Android
```

### Supabase Setup
- Update credentials in [supabase_config.dart](lib/config/supabase_config.dart)
- Run seed SQL for Food101 taxonomy via Supabase Studio
- Enable RLS policies on `app_users`, `food_scan_logs`, `meal_logs`

### TFLite Model Integration
- Place `.tflite` model in [assets/models/](assets/models/)
- Update [FoodClassifier.loadModel()](lib/services/food_classifier.dart) path if renamed
- Verify input/output tensor shapes (expect 1×224×224×3 → 1×101 for Food101)

## Code Conventions

### File Organization
- **Services** (singleton-like, instantiated in UI) — stateless logic
- **Data Layer** (repos, services with DB access) — under `features/<feature>/data/`
- **UI Layer** — under `features/<feature>/ui/` (screens, widgets)
- **Models** — POD classes with `.toJson()` / `fromJson()` constructors

### Error Handling
- Use try-catch with debug logs: `debugPrint('Context: $e')`
- Rethrow only if critical; prefer graceful degradation (e.g., defer sync if offline)
- Network errors wrapped in [StateError](lib/core/routing/app_router.dart#L161) for routing

### Naming
- Classes: PascalCase; Screens suffix `Screen`, Services suffix `Service`
- Private methods: `_methodName`; private variables: `_variable`
- Dart/Flutter idioms (e.g., `const` constructors, `late` for deferred init)

## Common Tasks

### Add New Role-Based Screen
1. Create [lib/features/role_name/](lib/features/role_name/) directory
2. Build screen inheriting `authService` parameter in constructor
3. Register route in [AppRouter.router](lib/core/routing/app_router.dart) GoRoute
4. Add role case in [RoleGate._resolveRole()](lib/core/routing/app_router.dart#L195)

### Extend Food Inference
- Modify [FoodInferenceService.runInference()](lib/services/food_inference_service.dart) for new model architectures
- Update confidence threshold in [FoodScanScreen](lib/features/foods/ui/food_scan_screen.dart#L23)
- Test with Food101 validation set before deploying

### Manage User Roles
- UI: [AdminUsersScreen._editUserRole()](lib/features/admin/admin_users_screen.dart#L59) calls `admin_set_user_role` RPC
- Backend validates; client never writes role directly
- Changes propagate on next login via [RoleGate](lib/core/routing/app_router.dart)

## Debugging Tips
- Auth state: Check `Supabase.instance.client.auth.currentUser` in breakpoints
- TFLite issues: Inspect tensor shapes in [FoodInferenceService](lib/services/food_inference_service.dart#L35) debug output
- Routing: Monitor GoRouter logs; ensure session listener in [AppRouter._authNotifier](lib/core/routing/app_router.dart#L89) fires on state changes
- Network: [SupabaseAutoRefreshGuard](lib/core/services/supabase_auto_refresh_guard.dart) logs all connectivity transitions

## Key Dependencies
- `supabase_flutter: ^2.5.6` — Auth, DB, RLS
- `go_router: ^14.6.0` — Route management
- `tflite_flutter: ^0.12.1` — Inference
- `image_picker: ^1.1.2` — Camera/gallery
- `awesome_notifications: ^0.10.1` — Local alerts
