import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../models/user_model.dart';

/// Minimum length checked on the client before calling the backend. The
/// backend password policy is the authority; this only catches obvious typos.
const int kMinNewPasswordLength = 8;

/// Failure of `POST /auth/me/change-password`. [message] is the backend
/// `detail` (Arabic) when present, otherwise `null` so the UI can show its own
/// localized fallback.
class PasswordChangeException implements Exception {
  final String? message;
  final int? statusCode;

  const PasswordChangeException({this.message, this.statusCode});

  @override
  String toString() => 'PasswordChangeException($statusCode): $message';
}

/// Result of a successful change: the updated user (flag cleared) plus the raw
/// `UserResponse` JSON so it can be persisted as-is.
class PasswordChangeResult {
  final UserModel user;
  final Map<String, dynamic> userJson;

  const PasswordChangeResult({required this.user, required this.userJson});
}

/// Calls the self-service password change endpoint.
class PasswordChangeRepository {
  final Dio _dio;

  PasswordChangeRepository(this._dio);

  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.changeMyPassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw PasswordChangeException(statusCode: response.statusCode);
      }
      return PasswordChangeResult(user: UserModel.fromJson(data), userJson: data);
    } on DioException catch (e) {
      final data = e.response?.data;
      final hasDetail = data is Map && data['detail'] != null;
      throw PasswordChangeException(
        message: hasDetail ? ApiError.message(e) : null,
        statusCode: e.response?.statusCode,
      );
    }
  }
}

final passwordChangeRepositoryProvider = Provider<PasswordChangeRepository>((ref) {
  return PasswordChangeRepository(ref.watch(dioProvider));
});

/// Client-side checks for the force-change form. Each returns an error kind
/// (mapped to localized text by the screen) or `null` when valid.
enum PasswordFieldError { required, tooShort, sameAsCurrent, mismatch }

class PasswordChangeValidator {
  const PasswordChangeValidator._();

  static PasswordFieldError? current(String? value) =>
      (value == null || value.isEmpty) ? PasswordFieldError.required : null;

  static PasswordFieldError? newPassword(String? value, String current) {
    if (value == null || value.isEmpty) return PasswordFieldError.required;
    if (value.length < kMinNewPasswordLength) return PasswordFieldError.tooShort;
    if (current.isNotEmpty && value == current) return PasswordFieldError.sameAsCurrent;
    return null;
  }

  static PasswordFieldError? confirm(String? value, String newPassword) {
    if (value == null || value.isEmpty) return PasswordFieldError.required;
    if (value != newPassword) return PasswordFieldError.mismatch;
    return null;
  }
}
