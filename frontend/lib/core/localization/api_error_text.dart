import 'package:dio/dio.dart';

import '../network/api_error.dart';
import 'app_localizations.dart';
import 'system_messages/system_message_renderer.dart';

/// Backend error codes the screens react to (the text itself comes from the system-message catalog).
class ApiErrorCode {
  ApiErrorCode._();

  static const customsFxRateMissing = 'CUSTOMS_FX_RATE_MISSING';
  static const irAssessmentExists = 'IR_ASSESSMENT_EXISTS';
  static const scenarioSessionExists = 'SCENARIO_SESSION_EXISTS';
  static const consultationExists = 'CONSULTATION_EXISTS';
  static const currencyNotFound = 'CURRENCY_NOT_FOUND';
  static const currencyRateMissing = 'CURRENCY_RATE_MISSING';
  static const ctCustomsRateMissing = 'CT_CUSTOMS_RATE_MISSING';
  static const importFileClosed = 'IMPORT_FILE_CLOSED';
  static const currencyCodeUnknown = 'CURRENCY_CODE_UNKNOWN';
}

/// User-facing, localized text for a failed API call.
///
/// - 403: "you do not have permission" (no global SnackBar handler exists, so each
///   screen shows this text);
/// - a structured detail `{code, message, ...}`: rendered from the code in the user's
///   language via the system-message catalog, falling back to the backend `message`;
/// - anything else: [ApiError.message].
class ApiErrorText {
  ApiErrorText._();

  /// The `detail` object of a 4xx response, or null.
  static Map<String, dynamic>? detail(Object? error) {
    if (error is! DioException) return null;
    final data = error.response?.data;
    if (data is! Map) return null;
    final d = data['detail'];
    return d is Map ? Map<String, dynamic>.from(d) : null;
  }

  /// `detail.code` of a structured error response, or null.
  static String? code(Object? error) => detail(error)?['code']?.toString();

  static String of(AppLocalizations l10n, Object? error, {String? fallback}) {
    if (ApiError.isForbidden(error) && !ApiError.isPasswordChangeRequired(error)) {
      return l10n.apiNoPermission;
    }
    final d = detail(error);
    final c = d?['code']?.toString();
    if (d != null && c != null) {
      // Backend system-message catalog (note / body part); the detail carries the params.
      for (final part in const [SystemMessagePart.note, SystemMessagePart.body]) {
        final rendered = SystemMessageRenderer.tryRender(code: c, params: d, part: part, l10n: l10n);
        if (rendered != null) return rendered;
      }
      final message = d['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return ApiError.message(error, fallback: fallback);
  }
}
