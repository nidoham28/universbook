import 'package:supabase_flutter/supabase_flutter.dart';

import '../exceptions/user_fetch_exception.dart';
import '../models/models.dart';

/// Repository for all user-related data fetching.
///
/// IMPORTANT: This class contains ZERO write methods.
/// All INSERT/UPDATE/DELETE operations MUST go through Supabase
/// Edge Functions using the service_role key, per schema design.
class UserRepository {
  final SupabaseClient _client;

  UserRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ==========================================================
  // 1. public.users — private account data
  // ==========================================================

  /// Fetches the currently authenticated user's core account row.
  ///
  /// RLS: Own row only. Returns `null` if not logged in.
  Future<UserModel?> getCurrentUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return getUserById(userId);
  }

  /// Fetches a single user by ID from `public.users`.
  ///
  /// RLS: You can only see your own row unless you are an admin.
  /// For public profile data, use [getProfile] instead.
  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw UserFetchException('Failed to fetch user', originalError: e);
    }
  }

  // ==========================================================
  // 2. public.profiles — public-facing data
  // ==========================================================

  /// Fetches a public profile by user ID.
  ///
  /// RLS: Returns data if account is public OR if the caller is
  /// the owner. Private accounts return `null` for other users.
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw UserFetchException('Failed to fetch profile', originalError: e);
    }
  }

  /// Fetches the current user's own profile.
  Future<ProfileModel?> getCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfile(userId);
  }

  /// Searches profiles by display name (case-insensitive LIKE).
  ///
  /// For production scale, replace with the `search_profiles` RPC
  /// that uses the `pg_trgm` GIN index defined in 02_profiles.sql.
  Future<List<ProfileModel>> searchProfiles(
      String query, {
        int limit = 20,
      }) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _client
          .from('profiles')
          .select()
          .ilike('display_name', '%\$query%')
          .limit(limit);

      return (response as List)
          .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw UserFetchException('Profile search failed', originalError: e);
    }
  }

  /// Fetches multiple profiles in a single round-trip.
  /// Useful for follower/following lists.
  Future<List<ProfileModel>> getProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      final response = await _client
          .from('profiles')
          .select()
          .inFilter('id', ids);

      return (response as List)
          .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw UserFetchException('Batch profile fetch failed', originalError: e);
    }
  }

  // ==========================================================
  // 3. public.creators — creator stats (public)
  // ==========================================================

  /// Fetches creator data for a user.
  ///
  /// RLS: Public — anyone can read. Returns `null` if user is
  /// not a creator (row doesn't exist).
  Future<CreatorModel?> getCreator(String userId) async {
    try {
      final response = await _client
          .from('creators')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return CreatorModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw UserFetchException('Failed to fetch creator', originalError: e);
    }
  }

  /// Lists all creators, optionally filtered by badge.
  ///
  /// RLS: Public — no restrictions.
  Future<List<CreatorModel>> listCreators({
    String? badge,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('creators').select();

      if (badge != null && badge != 'none') {
        query = query.eq('badge', badge);
      }

      final response = await query
          .order('creator_rating_average', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => CreatorModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw UserFetchException('Creator list fetch failed', originalError: e);
    }
  }

  // ==========================================================
  // 4. public.consumers — private preferences
  // ==========================================================

  /// Fetches the current user's private consumer data.
  ///
  /// RLS: Own row only. Returns `null` if not authenticated.
  Future<ConsumerModel?> getCurrentConsumer() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('consumers')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ConsumerModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw UserFetchException('Failed to fetch consumer', originalError: e);
    }
  }

  /// Fetches consumer data by ID.
  ///
  /// WARNING: RLS blocks this unless [userId] == current user.
  /// Prefer [getCurrentConsumer] for safety.
  Future<ConsumerModel?> getConsumerById(String userId) async {
    try {
      final response = await _client
          .from('consumers')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ConsumerModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw UserFetchException('Failed to fetch consumer', originalError: e);
    }
  }

  // ==========================================================
  // 5. Aggregated / Composite fetches
  // ==========================================================

  /// Fetches public data for any user — profile + optional creator.
  ///
  /// Safe to call for any user ID. Private accounts will return
  /// `null` unless the caller is the owner.
  Future<PublicUserModel?> getPublicUser(String userId) async {
    try {
      // Single joined query: profiles + creators
      final response = await _client
          .from('profiles')
          .select('*, creators(*)')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      final profile = ProfileModel.fromJson(response);
      final creatorData = response['creators'] as Map<String, dynamic>?;
      final creator =
      creatorData != null ? CreatorModel.fromJson(creatorData) : null;

      return PublicUserModel(profile: profile, creator: creator);
    } on PostgrestException catch (e) {
      throw UserFetchException('Public user fetch failed', originalError: e);
    }
  }

  /// Fetches EVERYTHING for the currently logged-in user across
  /// all four tables in a single round-trip.
  ///
  /// Returns `null` if not authenticated.
  Future<FullCurrentUserModel?> getFullCurrentUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('users')
          .select('*, profiles(*), creators(*), consumers(*)')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      final user = UserModel.fromJson(response);
      final profile = ProfileModel.fromJson(response['profiles']);
      final creatorData = response['creators'] as Map<String, dynamic>?;
      final creator =
      creatorData != null ? CreatorModel.fromJson(creatorData) : null;
      final consumer = ConsumerModel.fromJson(response['consumers']);

      return FullCurrentUserModel(
        user: user,
        profile: profile,
        creator: creator,
        consumer: consumer,
      );
    } on PostgrestException catch (e) {
      throw UserFetchException('Full user fetch failed', originalError: e);
    }
  }

  // ==========================================================
  // 6. Auth helpers
  // ==========================================================

  /// Returns true if a user is currently logged in.
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Returns the current Supabase Auth user ID, or null.
  String? get currentUserId => _client.auth.currentUser?.id;
}