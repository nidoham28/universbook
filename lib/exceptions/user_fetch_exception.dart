/// Thrown when a read operation fails due to network, malformed
/// response, or unexpected PostgREST error.
///
/// Note: RLS denial (e.g. private row) returns `null`, NOT an
/// exception — this is by design so callers can distinguish between
/// "doesn't exist" vs "server error".
class UserFetchException implements Exception {
  final String message;
  final dynamic originalError;

  const UserFetchException(this.message, {this.originalError});

  @override
  String toString() => 'UserFetchException: $message';
}