import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/models/user_model.dart';

// EmailSettingsDialog.canAccess(user) delegates to
// `user?.canManageEmailSettings ?? false`. This test targets the rule on
// UserModel directly so it loads without core/theme/app_theme.dart.
// The widget-level gate is covered in global_header_shortcuts_test.dart.

UserModel _user(String role) => UserModel(
      userId: 1,
      username: 'u',
      email: 'u@importflow.com',
      fullName: 'U',
      role: role,
      isActive: true,
    );

bool canAccess(UserModel? user) => user?.canManageEmailSettings ?? false;

void main() {
  group('Email settings access (admin-only backend routes)', () {
    test('ADMIN is allowed', () {
      expect(canAccess(_user('ADMIN')), isTrue);
      expect(canAccess(_user('admin')), isTrue);
    });

    test('non-admins and no user are denied', () {
      expect(canAccess(_user('MANAGER')), isFalse);
      expect(canAccess(_user('OPERATOR')), isFalse);
      expect(canAccess(null), isFalse);
    });
  });
}
