/// Core account row from `public.users`.
///
/// RLS: SELECT allowed only for own row OR if caller is admin.
/// Do NOT expose this to public UI directly — use [ProfileModel]
/// for public-facing data.
class UserModel {
  final String id;
  final String? email;
  final bool isCreator;
  final bool isAdmin;
  final bool privateAccount;
  final String accountStatus;
  final String authProvider;
  final bool emailVerified;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    this.email,
    this.isCreator = false,
    this.isAdmin = false,
    this.privateAccount = false,
    this.accountStatus = 'active',
    this.authProvider = 'email',
    this.emailVerified = false,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      isCreator: json['is_creator'] as bool? ?? false,
      isAdmin: json['is_admin'] as bool? ?? false,
      privateAccount: json['private_account'] as bool? ?? false,
      accountStatus: json['account_status'] as String? ?? 'active',
      authProvider: json['auth_provider'] as String? ?? 'email',
      emailVerified: json['email_verified'] as bool? ?? false,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'is_creator': isCreator,
    'is_admin': isAdmin,
    'private_account': privateAccount,
    'account_status': accountStatus,
    'auth_provider': authProvider,
    'email_verified': emailVerified,
    'last_login_at': lastLoginAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}