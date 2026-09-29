import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/network_security.dart';
import '../models/user_model.dart';

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.token,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'importflow_jwt_token';
  static const String _userKey = 'importflow_user_profile';

  AuthNotifier(this._dio, this._storage)
      : super(const AuthState(
          isAuthenticated: false,
          user: null,
        )) {
    _initFromStorage();
  }

  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payloadBytes = base64Url.decode(normalized);
      final payload = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp == null) return true;
      final expSec = exp is int ? exp : int.tryParse(exp.toString()) ?? 0;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // 15-second buffer to avoid race conditions
      return nowSec >= (expSec - 15);
    } catch (_) {
      return true;
    }
  }

  Future<void> _initFromStorage() async {
    try {
      final savedToken = await _storage.read(key: _tokenKey);
      final savedUserJson = await _storage.read(key: _userKey);

      if (savedToken != null && savedToken.isNotEmpty && savedUserJson != null) {
        final userData = jsonDecode(savedUserJson) as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);

        if (!isTokenExpired(savedToken)) {
          state = state.copyWith(
            token: savedToken,
            user: user,
            isAuthenticated: true,
          );
          // The stored profile may predate a password reset (or an older
          // backend): re-read /auth/me so must_change_password is current.
          unawaited(refreshCurrentUser());
          return;
        }

        // Token expired -> attempt silent refresh before clearing
        final refreshed = await _performTokenRefresh(savedToken);
        if (refreshed) {
          return;
        }

        // Refresh failed -> clear stale token and prompt login
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _userKey);
        state = state.copyWith(
          user: null,
          token: null,
          isAuthenticated: false,
          errorMessage: 'انتهت صلاحية جلسة العمل السابقة. يرجى تسجيل الدخول مجددًا.',
        );
      } else {
        // No valid token stored -> stay unauthenticated, display LoginScreen
        state = state.copyWith(
          user: null,
          token: null,
          isAuthenticated: false,
        );
      }
    } catch (_) {
      state = state.copyWith(
        user: null,
        token: null,
        isAuthenticated: false,
      );
    }
  }

  Future<bool> refreshToken() async {
    final currentToken = state.token;
    if (currentToken == null || currentToken.isEmpty) {
      final savedToken = await _storage.read(key: _tokenKey);
      if (savedToken == null || savedToken.isEmpty) return false;
      return _performTokenRefresh(savedToken);
    }
    return _performTokenRefresh(currentToken);
  }

  Future<bool> _performTokenRefresh(String token) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/auth/refresh',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final newToken = response.data['access_token'] as String?;
      final userJson = response.data['user'] as Map<String, dynamic>?;

      if (newToken != null && newToken.isNotEmpty && userJson != null) {
        final user = UserModel.fromJson(userJson);
        await _storage.write(key: _tokenKey, value: newToken);
        await _storage.write(key: _userKey, value: jsonEncode(userJson));

        state = state.copyWith(
          user: user,
          token: newToken,
          isAuthenticated: true,
          errorMessage: null,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Re-reads the signed-in user from `GET /auth/me` (allowed by the backend
  /// even while a password change is pending) so flags such as
  /// [UserModel.mustChangePassword] reflect the server. Best effort: network
  /// or auth failures keep the current user and return `false`.
  Future<bool> refreshCurrentUser() async {
    final token = state.token;
    if (!state.isAuthenticated || token == null || token.isEmpty) return false;
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      // Ignore the answer if the session changed while the call was in flight.
      if (data is Map<String, dynamic> && state.token == token && state.isAuthenticated) {
        await applyUserJson(data);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Replaces the signed-in user with a backend `UserResponse` (e.g. the body
  /// of `POST /auth/me/change-password`) and persists it.
  Future<void> applyUserJson(Map<String, dynamic> userJson) async {
    if (!state.isAuthenticated) return;
    final user = UserModel.fromJson(userJson);
    state = state.copyWith(user: user);
    await _persistUser(user);
  }

  /// Called by the HTTP layer when the backend answers
  /// `403 PASSWORD_CHANGE_REQUIRED`: flags the current user so the
  /// password-change gate takes over. Idempotent.
  void markPasswordChangeRequired() {
    final user = state.user;
    if (!state.isAuthenticated || user == null || user.mustChangePassword) return;
    final flagged = user.copyWith(mustChangePassword: true);
    state = state.copyWith(user: flagged);
    unawaited(_persistUser(flagged));
  }

  Future<void> _persistUser(UserModel user) async {
    try {
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<void> handleSessionExpired() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (_) {}
    state = const AuthState(
      isAuthenticated: false,
      user: null,
      token: null,
      errorMessage: 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى.',
    );
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/auth/login',
        data: {
          'username_or_email': usernameOrEmail.trim(),
          'password': password.trim(),
        },
      );

      final token = response.data['access_token'] as String;
      final userJson = response.data['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      // Persist to secure storage
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userKey, value: jsonEncode(userJson));

      state = state.copyWith(
        user: user,
        token: token,
        isAuthenticated: true,
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      String msg = 'اسم المستخدم أو كلمة المرور غير صحيحة.';
      if (e.response != null && e.response?.data != null && e.response?.data['detail'] != null) {
        msg = e.response?.data['detail'].toString() ?? msg;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر الاتصال بخادم المصادقة: $e');
      return false;
    }
  }

  /// Demo role switching fabricates a local user profile without a backend
  /// login. It is a development aid only and is disabled in release/profile
  /// builds. Tests may flip it to exercise both paths.
  @visibleForTesting
  static bool demoRoleSwitchEnabled = kDebugMode;

  void switchDemoRole(String role) async {
    if (!demoRoleSwitchEnabled) return;
    UserModel user;
    if (role == 'ADMIN') {
      user = UserModel(
        userId: 1,
        username: 'admin',
        email: 'admin@sorourlogistics.com',
        fullName: 'System Admin (مدير النظام)',
        role: 'ADMIN',
        isActive: true,
      );
    } else if (role == 'MANAGER') {
      user = UserModel(
        userId: 2,
        username: 'manager',
        email: 'manager@sorourlogistics.com',
        fullName: 'General Logistics Manager (مدير العمليات)',
        role: 'MANAGER',
        isActive: true,
      );
    } else {
      user = UserModel(
        userId: 3,
        username: 'operator1',
        email: 'operator1@sorourlogistics.com',
        fullName: 'Ahmed Import Specialist (أخصائي استيراد)',
        role: 'OPERATOR',
        isActive: true,
      );
    }

    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    state = state.copyWith(user: user, isAuthenticated: true);
  }

  Future<void> logout() async {
    try {
      if (state.token != null && state.token!.isNotEmpty) {
        // Invalidate session on backend server (TokenRevocationManager)
        await _dio.post(
          '${ApiConstants.baseUrl}/auth/logout',
          options: Options(headers: {
            'Authorization': 'Bearer ${state.token}',
          }),
        );
      }
    } catch (_) {}
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (_) {}
    state = const AuthState(isAuthenticated: false, user: null, token: null);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = Dio();
  configureDioTls(dio);
  return AuthNotifier(dio, storage);
});
