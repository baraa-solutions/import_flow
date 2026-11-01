import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';

class AdvancePaymentSubmitHandler {
  AdvancePaymentSubmitHandler._();

  static Future<PaymentRequestModel?> submit({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required int importFileId,
    required int? primaryPoId,
    required int? selectedSupplierId,
    required int? projectId,
    required double selectedPercentage,
    required String currency,
    required DateTime dueDate,
    required TextEditingController titleController,
    required TextEditingController amountController,
    required TextEditingController exchangeRateController,
    required TextEditingController beneficiaryController,
    required TextEditingController bankNameController,
    required TextEditingController swiftController,
    required TextEditingController ibanController,
    required TextEditingController notesController,
  }) async {
    if (!formKey.currentState!.validate()) return null;

    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.faAdvanceAmountInvalid,
          severity: AppSeverity.danger,
        ),
      );
      return null;
    }

    final rate = double.tryParse(exchangeRateController.text.trim());
    if (rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.faFxRateMissing(currency),
          severity: AppSeverity.warning,
        ),
      );
      return null;
    }

    try {
      final payload = {
        'import_file_id': importFileId,
        'po_id': primaryPoId,
        'supplier_id': selectedSupplierId,
        'supplier_name': beneficiaryController.text.trim(),
        'project_id': projectId,
        'payment_type': 'ADVANCE_PAYMENT',
        'title': titleController.text.trim(),
        'requested_amount': amount,
        'advance_percentage': selectedPercentage,
        'currency_code': currency,
        'exchange_rate': rate,
        'beneficiary_name': beneficiaryController.text.trim(),
        'bank_name': bankNameController.text.trim(),
        'swift_code': swiftController.text.trim().toUpperCase(),
        'iban_account_no': ibanController.text.trim().replaceAll(' ', ''),
        'due_date':
            '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
        'notes': notesController.text.trim().isEmpty
            ? 'Advance payment of ${selectedPercentage.toStringAsFixed(0)}% requested via ImportFlow ERP'
            : notesController.text.trim(),
      };

      final created = await ref
          .read(paymentRequestsProvider.notifier)
          .createPaymentRequest(payload);

      ref.invalidate(paymentRequestsProvider);
      ref.invalidate(importFilesProvider);

      if (context.mounted) {
        final taskInfo = (created?.smartTaskCode != null)
            ? (context.l10n.faSmartTaskGenerated(created!.smartTaskCode!))
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.faAdvanceIssued(
                created?.paymentCode ?? context.l10n.faSuccessWord, taskInfo),
            severity: AppSeverity.success,
          ),
        );
      }
      return created;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.faIssuePaymentFailed(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
      return null;
    }
  }
}
