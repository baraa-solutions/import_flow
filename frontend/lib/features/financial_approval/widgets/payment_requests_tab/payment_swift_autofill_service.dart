import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../providers/financial_approval_provider.dart';
import 'swift_client_parser.dart';

class PaymentSwiftAutofillService {
  PaymentSwiftAutofillService._();

  static void applyParsedData({
    required ScaffoldMessengerState messenger,
    required BuildContext context,
    required AppLocalizations l10n,
    required WidgetRef ref,
    required Map<String, dynamic> parsed,
    required TextEditingController amountController,
    required TextEditingController exchangeRateController,
    required TextEditingController supplierNameController,
    required TextEditingController bankNameController,
    required TextEditingController swiftCodeController,
    required TextEditingController ibanController,
    required TextEditingController payTitleController,
    required TextEditingController payNotesController,
    required double? Function(String) getExchangeRateForCurrency,
    required String Function(double?) formatRateText,
    required void Function({
      required Map<String, dynamic> summary,
      required String currency,
      required DateTime? dueDate,
      required int? supplierId,
      required int? importFileId,
    }) onApplyFields,
    String? fileName,
  }) {
    String? resolvedCurrency;
    DateTime? resolvedDueDate;
    int? resolvedSupplierId;
    int? resolvedImportFileId;

    if (parsed['amount'] != null && (parsed['amount'] as num) > 0) {
      amountController.text = (parsed['amount'] as num).toString();
    }
    if (parsed['currency'] != null &&
        (parsed['currency'] as String).isNotEmpty) {
      resolvedCurrency = (parsed['currency'] as String).toUpperCase();
      exchangeRateController.text =
          formatRateText(getExchangeRateForCurrency(resolvedCurrency));
    }
    if (parsed['beneficiary_name'] != null &&
        (parsed['beneficiary_name'] as String).isNotEmpty) {
      supplierNameController.text = parsed['beneficiary_name'];
      final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
      final bName = (parsed['beneficiary_name'] as String)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final matchedSup = suppliers.where((s) {
        final sName =
            s.companyName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        return sName.isNotEmpty &&
            (sName.contains(bName) || bName.contains(sName));
      }).firstOrNull;
      if (matchedSup != null) {
        resolvedSupplierId = matchedSup.supplierId;
        if (matchedSup.bankName != null && matchedSup.bankName!.isNotEmpty) {
          bankNameController.text = matchedSup.bankName!;
        }
        if (matchedSup.swiftCode != null &&
            matchedSup.swiftCode!.isNotEmpty &&
            (parsed['beneficiary_bank_swift'] == null ||
                (parsed['beneficiary_bank_swift'] as String).isEmpty)) {
          swiftCodeController.text = matchedSup.swiftCode!;
        }
        final supIban = matchedSup.iban ?? matchedSup.accountNumber;
        if (supIban != null &&
            supIban.isNotEmpty &&
            (parsed['beneficiary_account_or_iban'] == null ||
                (parsed['beneficiary_account_or_iban'] as String).isEmpty)) {
          ibanController.text = supIban;
        }
      }
    }
    if (parsed['beneficiary_bank_swift'] != null &&
        (parsed['beneficiary_bank_swift'] as String).isNotEmpty) {
      swiftCodeController.text = parsed['beneficiary_bank_swift'];
    }
    if (parsed['beneficiary_account_or_iban'] != null &&
        (parsed['beneficiary_account_or_iban'] as String).isNotEmpty) {
      ibanController.text = parsed['beneficiary_account_or_iban'];
    }
    if (parsed['value_date'] != null &&
        (parsed['value_date'] as String).isNotEmpty) {
      try {
        resolvedDueDate = DateTime.parse(parsed['value_date']);
      } catch (_) {}
    }

    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final piNum = parsed['pi_number']
        ?.toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final poNum = parsed['po_number']
        ?.toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final transRef = parsed['transaction_reference']
        ?.toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    final matchedFile = importFiles.where((f) {
      final fCode =
          f.importFileCode.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final cNum = (f.customFileNumber ?? '')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final pNum =
          (f.poNumber ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (piNum != null &&
          piNum.isNotEmpty &&
          (fCode.contains(piNum) ||
              cNum.contains(piNum) ||
              pNum.contains(piNum))) {
        return true;
      }
      if (poNum != null &&
          poNum.isNotEmpty &&
          (fCode.contains(poNum) ||
              cNum.contains(poNum) ||
              pNum.contains(poNum))) {
        return true;
      }
      if (transRef != null &&
          transRef.isNotEmpty &&
          (fCode.contains(transRef) || cNum.contains(transRef))) {
        return true;
      }
      return false;
    }).firstOrNull;
    if (matchedFile != null) {
      resolvedImportFileId = matchedFile.importFileId;
    }

    if (payTitleController.text.trim().isEmpty &&
        parsed['beneficiary_name'] != null) {
      final refNo = parsed['transaction_reference'] ?? '';
      final piText =
          parsed['pi_number'] != null ? ' - PI: ${parsed['pi_number']}' : '';
      payTitleController.text =
          '${l10n.swiftPaymentPrefix}: ${parsed['beneficiary_name']}$piText ($refNo)';
    }
    final notesParts = <String>[];
    if (parsed['transaction_reference'] != null) {
      notesParts.add('SWIFT Ref: ${parsed['transaction_reference']}');
    }
    if (parsed['pi_number'] != null) notesParts.add('PI: ${parsed['pi_number']}');
    if (parsed['ordering_customer_name'] != null) {
      notesParts
          .add('${l10n.orderingCustomerPrefix}: ${parsed['ordering_customer_name']}');
    }
    if (parsed['payment_details'] != null) {
      notesParts.add('${l10n.paymentDetailsPrefix}: ${parsed['payment_details']}');
    }
    if (notesParts.isNotEmpty) {
      payNotesController.text = notesParts.join(' | ');
    }

    onApplyFields(
      summary: parsed,
      currency: resolvedCurrency ?? 'USD',
      dueDate: resolvedDueDate,
      supplierId: resolvedSupplierId,
      importFileId: resolvedImportFileId,
    );

    final msg = fileName != null
        ? l10n.swiftDataExtractedSuccess(fileName)
        : l10n.swiftMatchedSuccess;
    messenger.showSnackBar(
      AppTheme.snackBar(context, msg, severity: AppSeverity.success),
    );
  }

  static Future<Map<String, dynamic>?> extractFromText({
    required AppLocalizations l10n,
    required WidgetRef ref,
    required String rawText,
  }) async {
    Map<String, dynamic>? parsed;
    try {
      final res = await ref
          .read(paymentRequestsProvider.notifier)
          .smartExtractSwift(rawText: rawText);
      if (res['success'] == true && res['parsed_swift'] != null) {
        parsed = res['parsed_swift'] as Map<String, dynamic>;
      }
    } catch (_) {}

    if (parsed == null ||
        ((parsed['amount'] as num?) == 0 &&
            parsed['beneficiary_name'] == null)) {
      final clientFallback = SwiftClientParser.parse(rawText, l10n);
      if (clientFallback['success'] == true) {
        parsed = clientFallback;
      }
    }
    return parsed;
  }

  static Future<({Map<String, dynamic>? parsed, String? rawText, String? fileName, String? errorMessage})?>
      pickAndExtractFile({
    required WidgetRef ref,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'docx',
        'doc',
        'xlsx',
        'xls',
        'csv',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'bmp',
        'txt'
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null) return null;

    final res = await ref
        .read(paymentRequestsProvider.notifier)
        .smartExtractSwiftFromFile(
          fileBytes: file.bytes!,
          filename: file.name,
        );
    if (res['success'] == true && res['parsed_swift'] != null) {
      return (
        parsed: res['parsed_swift'] as Map<String, dynamic>,
        rawText: res['raw_text'] as String?,
        fileName: file.name,
        errorMessage: null,
      );
    } else {
      final err = res['error']?.toString() ?? 'Failed to extract file';
      return (
        parsed: null,
        rawText: null,
        fileName: file.name,
        errorMessage: err,
      );
    }
  }
}
