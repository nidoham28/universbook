import 'user_model.dart';
import 'profile_model.dart';
import 'creator_model.dart';
import 'consumer_model.dart';

/// Aggregated private data for the currently logged-in user.
class FullCurrentUserModel {
  final UserModel user;
  final ProfileModel profile;
  final CreatorModel? creator;
  final ConsumerModel consumer;

  const FullCurrentUserModel({
    required this.user,
    required this.profile,
    this.creator,
    required this.consumer,
  });
}