import 'profile_model.dart';
import 'creator_model.dart';

/// Aggregated public data for any user (safe to show in UI).
class PublicUserModel {
  final ProfileModel profile;
  final CreatorModel? creator; // null if not a creator

  const PublicUserModel({
    required this.profile,
    this.creator,
  });
}