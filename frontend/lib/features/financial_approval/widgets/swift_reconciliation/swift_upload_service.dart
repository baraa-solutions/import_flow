import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';

class SwiftExtractionResult {
  final Map<String, dynamic>? extractedSwift;
  final Map<String, dynamic>? matchedPayment;
  final String? detectedFileType;
  final SwiftBatchModel? currentBatch;
  final bool isMatchingUnlocked;
  final String? rawText;
  final int? selectedPaymentId;

  const SwiftExtractionResult({
    this.extractedSwift,
    this.matchedPayment,
    this.detectedFileType,
    this.currentBatch,
    this.isMatchingUnlocked = false,
    this.rawText,
    this.selectedPaymentId,
  });
}

class SwiftUploadService {
  static Future<SwiftExtractionResult?> pickAndExtractFile({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l10n,
    int? targetPaymentId,
    required void Function(String filename, int size) onFilePicked,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'docx', 'doc', 'xlsx', 'xls', 'csv', 'jpg', 'jpeg', 'png', 'webp', 'bmp', 'txt'
        ],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final fileBytes = file.bytes;
      final filename = file.name;

      if (fileBytes == null || fileBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.swiftFileReadErrorSnack,
              severity: AppSeverity.warning,
            ),
          );
        }
        return null;
      }

      onFilePicked(filename, fileBytes.length);

      final res = await ref.read(paymentRequestsProvider.notifier).smartExtractSwiftFromFile(
            fileBytes: fileBytes,
            filename: filename,
            targetPaymentId: targetPaymentId,
          );

      if (context.mounted) {
        if (res['success'] == true) {
          SwiftBatchModel? batch;
          bool matchingUnlocked = false;
          if (res['batch'] != null) {
            batch = SwiftBatchModel.fromJson(res['batch'] as Map<String, dynamic>);
            matchingUnlocked = batch.status == 'REVIEWED_CONFIRMED' || batch.status == 'RECONCILED';
          }
          final matchedPay = res['matched_payment_request'] as Map<String, dynamic>?;
          final detectedType = res['detected_file_type'] as String?;

          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.swiftExtractSuccessSnack(
                filename,
                detectedType ?? l10n.swiftDocumentDefaultType,
              ),
              severity: AppSeverity.success,
            ),
          );

          return SwiftExtractionResult(
            extractedSwift: res['parsed_swift'] as Map<String, dynamic>?,
            matchedPayment: matchedPay,
            detectedFileType: detectedType,
            currentBatch: batch,
            isMatchingUnlocked: matchingUnlocked,
            rawText: res['raw_text'] as String?,
            selectedPaymentId: matchedPay?['payment_id'] as int?,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.swiftExtractErrorSnack(res['error']?.toString() ?? ''),
              severity: AppSeverity.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftExtractErrorSnack(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
    return null;
  }

  static Future<SwiftExtractionResult?> runSmartSwiftExtraction({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l10n,
    required String rawText,
    int? targetPaymentId,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.swiftEmptyInputErrorSnack, severity: AppSeverity.warning),
      );
      return null;
    }

    try {
      final res = await ref.read(paymentRequestsProvider.notifier).smartExtractSwift(
            rawText: text,
            targetPaymentId: targetPaymentId,
          );

      if (context.mounted) {
        if (res['success'] == true) {
          SwiftBatchModel? batch;
          bool matchingUnlocked = false;
          if (res['batch'] != null) {
            batch = SwiftBatchModel.fromJson(res['batch'] as Map<String, dynamic>);
            matchingUnlocked = batch.status == 'REVIEWED_CONFIRMED' || batch.status == 'RECONCILED';
          }
          final matchedPay = res['matched_payment_request'] as Map<String, dynamic>?;

          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l10n.swiftParseSuccessSnack, severity: AppSeverity.success),
          );

          return SwiftExtractionResult(
            extractedSwift: res['parsed_swift'] as Map<String, dynamic>?,
            matchedPayment: matchedPay,
            currentBatch: batch,
            isMatchingUnlocked: matchingUnlocked,
            selectedPaymentId: matchedPay?['payment_id'] as int?,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.swiftParseErrorSnack(res['error']?.toString() ?? ''),
              severity: AppSeverity.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftConnectionErrorSnack(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
    return null;
  }

  static Future<bool> executeSmartReconciliation({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l10n,
    required PaymentRequestModel pay,
    required Map<String, dynamic> extractedSwift,
    required SwiftBatchModel? currentBatch,
    required String rawText,
    required VoidCallback onReconciliationCompleted,
  }) async {
    final rawRef = extractedSwift['transaction_reference']?.toString().trim();
    final swiftRef = (rawRef != null && rawRef.isNotEmpty) ? rawRef : null;

    final rawDateStr = extractedSwift['value_date']?.toString().trim();
    DateTime? parsedDate;
    if (rawDateStr != null && rawDateStr.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDateStr);
    }

    final amtVal = extractedSwift['amount'];
    final double? amt = (amtVal is num)
        ? amtVal.toDouble()
        : (amtVal != null ? double.tryParse(amtVal.toString().trim()) : null);

    final rawCurr = extractedSwift['currency']?.toString().trim();
    final curr = (rawCurr != null && rawCurr.isNotEmpty) ? rawCurr : null;

    final swiftCode = extractedSwift['beneficiary_bank_swift']?.toString() ?? pay.swiftCode;
    final iban = extractedSwift['beneficiary_account_or_iban']?.toString() ?? pay.ibanAccountNo;

    final missingFields = <String>[];
    if (swiftRef == null) missingFields.add(l10n.swiftFieldRef);
    if (parsedDate == null) missingFields.add(l10n.swiftFieldValueDate);
    if (amt == null || amt <= 0) missingFields.add(l10n.swiftFieldAmount);
    if (curr == null) missingFields.add(l10n.swiftFieldCurrency);

    final messenger = ScaffoldMessenger.of(context);
    if (missingFields.isNotEmpty) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          l10n.swiftReconcileMissingFields(missingFields.join(', ')),
          severity: AppSeverity.warning,
        ),
      );
      return false;
    }

    if (currentBatch != null &&
        currentBatch.status != 'REVIEWED_CONFIRMED' &&
        !(currentBatch.status == 'RECONCILED' && currentBatch.matchedPaymentId == pay.paymentId)) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        AppTheme.snackBar(context, l10n.swiftBatchNotConfirmed, severity: AppSeverity.warning),
      );
      return false;
    }

    try {
      PaymentRequestModel? updated;
      if (currentBatch != null) {
        updated = await ref.read(paymentRequestsProvider.notifier).reconcileReviewedSwiftBatch(
              batchId: currentBatch.batchId,
              paymentId: pay.paymentId,
              notes: null,
            );
      } else {
        final receiptDateStr =
            '${parsedDate!.year.toString().padLeft(4, '0')}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
        updated = await ref.read(paymentRequestsProvider.notifier).smartReconcileSwift(
              paymentId: pay.paymentId,
              rawText: rawText.trim(),
              swiftReferenceNo: swiftRef!,
              swiftReceiptDate: receiptDateStr,
              swiftTransferredAmount: amt!,
              swiftTransferredCurrency: curr!,
              swiftCode: swiftCode,
              ibanAccountNo: iban,
              swiftReconciliationNotes: null,
              autoExecute: true,
            );
      }

      ref.read(importFilesProvider.notifier).fetchImportFiles();
      onReconciliationCompleted();

      if (context.mounted && updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftReconcileSuccessSnack(swiftRef!, updated.paymentCode),
            severity: AppSeverity.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftReconcileErrorSnack(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
      return false;
    }
  }
}
