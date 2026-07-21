# Supabase Integration Walkthrough

I have successfully integrated Supabase into the Universbook project.

## Changes Made

### Configuration
- Added `supabase_flutter` to `pubspec.yaml`.
- Created `lib/core/config/supabase_config.dart` to hold Supabase credentials.
- Initialized Supabase in `lib/main.dart`.

### Services
- Created `AuthService` in `lib/core/services/auth_service.dart` to manage authentication logic (sign in, sign up, sign out, and auth state).

### UI Integration
- Updated `HomePage` to use `AuthService` for real-time authentication state management.
- Wired up `showAuthBottomSheet` handlers to use Supabase authentication.

## Next Steps

> [!IMPORTANT]
> You must update the placeholders in `lib/core/config/supabase_config.dart` with your actual Supabase project credentials.

```dart
// lib/core/config/supabase_config.dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL'; // Replace with your URL
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY'; // Replace with your Anon Key
}
```

## Verification

### Manual Verification Required
1. Run `flutter pub get` to install the new dependency.
2. Update `supabase_config.dart` with your credentials.
3. Run the application.
4. Test the Sign In and Sign Up flows via the bottom sheet.
