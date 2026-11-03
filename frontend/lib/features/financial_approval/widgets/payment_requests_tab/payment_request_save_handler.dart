import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';

class PaymentRequestSaveHandler {
  PaymentRequestSaveHandler._();

  static bool isVersionConflict(Object e) {
    if (e is! DioException || e.response?.statusCode != 409) return false;
    final data = e.response?.data;
    final detail = (data is Map)
        ? (data['detail'] is Map ? data['detail'] as Map : data)
        : const {};
    return detail.containsKey('current_version') ||
        detail.containsKey('submitted_version');
  }

  static bool isCodedError(Object e) {
    if (e is! DioException) return false;
    final data = e.response?.data;
    return data is Map && data['detail'] is Map;
  }

  static Future<PaymentRequestModel?> save({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, dynamic> payload,
    required int? editingPaymentId,
    required int? editingPaymentVersion,
    required VoidCallback onDiscardAndReload,
    required Future<void> Function() onRetry,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (editingPaymentId != null) {
        if (editingPaymentVersion != null) {
          payload['version'] = editingPaymentVersion;
        }
        final updated = await ref
            .read(paymentRequestsProvider.notifier)
            .updatePaymentRequest(editingPaymentId, payload);
        if (!context.mounted) return null;
        if (updated != null) {
          messenger.showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.paymentRequestUpdatedSuccess(updated.paymentCode),
              severity: AppSeverity.success,
            ),
          );
          return updated;
        }
      } else {
        final created = await ref
            .read(paymentRequestsProvider.notifier)
            .createPaymentRequest(payload);
        if (!context.mounted) return null;
        if (created != null) {
          final taskMsg = (created.smartTaskCode != null)
              ? ' (${created.smartTaskCode})'
              : '';
          messenger.showSnackBar(
            AppTheme.snackBar(
              context,
              '${l10n.paymentRequestCreatedSuccess(created.paymentCode)}$taskMsg',
              severity: AppSeverity.success,
            ),
          );
          return created;
        }
      }
    } catch (e) {
      if (!context.mounted) return null;

      if (isVersionConflict(e)) {
        final data = (e as DioException).response?.data;
        final conflict = (data is Map<String, dynamic> && data['detail'] is Map)
            ? Map<String, dynamic>.from(data['detail'] as Map)
            : (data is Map<String, dynamic> ? data : <String, dynamic>{});
        final resolution = await ConcurrencyConflictDialog.show(
          context,
          entityName: conflict['entity'] as String? ?? 'PaymentRequestSession',
          recordId: conflict['record_id'] ?? editingPaymentId,
          currentVersion: (conflict['current_version'] as num?)?.toInt() ??
              ((editingPaymentVersion ?? 1) + 1),
          submittedVersion: (conflict['submitted_version'] as num?)?.toInt() ??
              (editingPaymentVersion ?? 1),
          updatedAt: conflict['updated_at'] as String?,
          updatedBy: conflict['updated_by'] as String?,
          serverMessage: conflict['message'] as String?,
          currentDraftData: payload,
        );
        if (resolution == ConcurrencyResolution.discardAndReload) {
          onDiscardAndReload();
          await ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
        }
        return null;
      }

      if (isCodedError(e)) {
        messenger.showSnackBar(
          AppTheme.snackBar(context, ApiError.message(e),
              severity: AppSeverity.danger),
        );
      } else {
        await showErrorDetailsDialog(
          context,
          title: l10n.savePaymentFailedTitle,
          error: e,
          onRetry: onRetry,
        );
      }
    }
    return null;
  }
}
