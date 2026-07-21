# Add Supabase Integration

This plan outlines the steps to integrate Supabase into the Universbook Flutter project for authentication and data management.

## User Review Required

> [!IMPORTANT]
> You will need to provide your Supabase URL and Anon Key. I will use placeholders for now, which you should replace with your actual project credentials in `lib/core/config/supabase_config.dart`.

## Proposed Changes

### Configuration & Dependencies

#### [MODIFY] [pubspec.yaml](file:///C:/Users/AC/StudioProjects/universbook/pubspec.yaml)
- Add `supabase_flutter` dependency.

#### [NEW] [supabase_config.dart](file:///C:/Users/AC/StudioProjects/universbook/lib/core/config/supabase_config.dart)
- Define `SupabaseConfig` class with static constants for `url` and `anonKey`.

### Initialization

#### [MODIFY] [main.dart](file:///C:/Users/AC/StudioProjects/universbook/lib/main.dart)
- Initialize Supabase using `Supabase.initialize()` before `runApp()`.

### Service Layer

#### [NEW] [auth_service.dart](file:///C:/Users/AC/StudioProjects/universbook/lib/core/services/auth_service.dart)
- Create a `AuthService` class to handle:
    - `signInWithEmail(email, password)`
    - `signUpWithEmail(email, password)`
    - `signOut()`
    - `currentUser` stream/getter.

### UI Integration

#### [MODIFY] [home_page.dart](file:///C:/Users/AC/StudioProjects/universbook/lib/presentation/home/home_page.dart)
- Integrate `AuthService` to handle authentication logic.
- Replace placeholder `_isAuthenticated` logic with real Supabase session check.

## Verification Plan

### Automated Tests
- I'll check for any obvious syntax errors after implementation.

### Manual Verification
- The user will need to:
    1. Run `flutter pub get`.
    2. Add their Supabase credentials to `lib/core/config/supabase_config.dart`.
    3. Run the app and verify the auth flow.
