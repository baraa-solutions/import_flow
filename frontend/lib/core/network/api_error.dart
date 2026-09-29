import 'package:dio/dio.dart';

/// Helpers for turning backend errors into user-facing text.
///
/// The backend (FastAPI) returns `{"detail": "..."}` for 4xx errors, including
/// 403 for admin-only routes. Always surface that detail instead of the raw
/// DioException string.
class ApiError {
  const ApiError._();

  /// True when [error] is an HTTP 403 Forbidden from the backend.
  static bool isForbidden(Object? error) =>
      error is DioException && error.response?.statusCode == 403;

  /// Backend error code sent while the signed-in account must replace its
  /// password: `403 {"detail": {"code": "PASSWORD_CHANGE_REQUIRED", ...}}`.
  static const String passwordChangeRequiredCode = 'PASSWORD_CHANGE_REQUIRED';

  /// True when [error] is the backend's "change your password first" 403.
  static bool isPasswordChangeRequired(Object? error) {
    if (error is! DioException || error.response?.statusCode != 403) return false;
    final data = error.response?.data;
    if (data is! Map) return false;
    final detail = data['detail'];
    return detail is Map && detail['code'] == passwordChangeRequiredCode;
  }

  /// Backend `detail` when present, otherwise the Dio message, otherwise
  /// [fallback] / `error.toString()`.
  static String message(Object? error, {String? fallback}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) return first['msg'].toString();
        }
        // Structured detail: {"code": "...", "message": "..."}.
        if (detail is Map && detail['message'] != null) return detail['message'].toString();
        return detail.toString();
      }
      final msg = error.message;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return fallback ?? error?.toString() ?? '';
  }
}
