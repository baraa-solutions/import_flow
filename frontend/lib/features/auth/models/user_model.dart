class UserModel {
  final int userId;
  final String username;
  final String email;
  final String fullName;
  final String role; // ADMIN, MANAGER, OPERATOR
  final bool isActive;

  /// Set by the backend for accounts that must replace their password before
  /// using the app (e.g. the seeded `admin` on a new install). Missing in
  /// responses from older backends, which is treated as `false`.
  final bool mustChangePassword;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.mustChangePassword = false,
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get isManager => role.toUpperCase() == 'MANAGER';
  bool get isOperator => role.toUpperCase() == 'OPERATOR';
  bool get canViewAllRecords => isAdmin || isManager;
  bool get canManageStepConfig => isAdmin || isManager;
  /// Email server settings (/smart-email/settings, test-connection, send-email) are admin-only.
  bool get canManageEmailSettings => isAdmin;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String? ?? 'OPERATOR',
      isActive: json['is_active'] as bool? ?? true,
      mustChangePassword: json['must_change_password'] == true,
    );
  }

  UserModel copyWith({bool? mustChangePassword}) {
    return UserModel(
      userId: userId,
      username: username,
      email: email,
      fullName: fullName,
      role: role,
      isActive: isActive,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
      'must_change_password': mustChangePassword,
    };
  }
}
