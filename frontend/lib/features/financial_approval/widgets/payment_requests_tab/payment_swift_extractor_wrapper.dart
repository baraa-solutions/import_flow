import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../swift_ocr_extractor_card.dart';
import 'payment_swift_autofill_service.dart';

class PaymentSwiftExtractorWrapper extends ConsumerStatefulWidget {
  final TextEditingController amountController;
  final TextEditingController exchangeRateController;
  final TextEditingController supplierNameController;
  final TextEditingController bankNameController;
  final TextEditingController swiftCodeController;
  final TextEditingController ibanController;
  final TextEditingController payTitleController;
  final TextEditingController payNotesController;
  final double? Function(String) getExchangeRateForCurrency;
  final String Function(double?) formatRateText;
  final int? currentImportFileId;
  final void Function({
    required Map<String, dynamic> summary,
    required String currency,
    required DateTime? dueDate,
    required int? supplierId,
    required int? importFileId,
  }) onApplyFields;

  const PaymentSwiftExtractorWrapper({
    super.key,
    required this.amountController,
    required this.exchangeRateController,
    required this.supplierNameController,
    required this.bankNameController,
    required this.swiftCodeController,
    required this.ibanController,
    required this.payTitleController,
    required this.payNotesController,
    required this.getExchangeRateForCurrency,
    required this.formatRateText,
    required this.currentImportFileId,
    required this.onApplyFields,
  });

  @override
  ConsumerState<PaymentSwiftExtractorWrapper> createState() =>
      _PaymentSwiftExtractorWrapperState();
}

class _PaymentSwiftExtractorWrapperState
    extends ConsumerState<PaymentSwiftExtractorWrapper> {
  final TextEditingController _rawTextController = TextEditingController();
  bool _isExpanded = true;
  bool _isExtracting = false;
  Map<String, dynamic>? _extractedSummary;

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  Future<void> _autoFillFromText(String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _isExtracting = true);
    try {
      final parsed = await PaymentSwiftAutofillService.extractFromText(
        l10n: l10n,
        ref: ref,
        rawText: text,
      );

      if (parsed != null && mounted) {
        PaymentSwiftAutofillService.applyParsedData(
          messenger: messenger,
          context: context,
          l10n: l10n,
          ref: ref,
          parsed: parsed,
          amountController: widget.amountController,
          exchangeRateController: widget.exchangeRateController,
          supplierNameController: widget.supplierNameController,
          bankNameController: widget.bankNameController,
          swiftCodeController: widget.swiftCodeController,
          ibanController: widget.ibanController,
          payTitleController: widget.payTitleController,
          payNotesController: widget.payNotesController,
          getExchangeRateForCurrency: widget.getExchangeRateForCurrency,
          formatRateText: widget.formatRateText,
          onApplyFields: ({
            required Map<String, dynamic> summary,
            required String currency,
            required DateTime? dueDate,
            required int? supplierId,
            required int? importFileId,
          }) {
            setState(() => _extractedSummary = summary);
            widget.onApplyFields(
              summary: summary,
              currency: currency,
              dueDate: dueDate,
              supplierId: supplierId,
              importFileId: importFileId,
            );
          },
        );
      } else if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftTextParseError,
            severity: AppSeverity.warning,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _autoFillFromFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _isExtracting = true);
    try {
      final result = await PaymentSwiftAutofillService.pickAndExtractFile(
        ref: ref,
      );
      if (result != null && mounted) {
        if (result.errorMessage != null) {
          messenger.showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.swiftFileExtractError(result.errorMessage!),
              severity: AppSeverity.danger,
            ),
          );
          return;
        }
        if (result.rawText != null && result.rawText!.isNotEmpty) {
          _rawTextController.text = result.rawText!;
        }
        if (result.parsed != null) {
          PaymentSwiftAutofillService.applyParsedData(
            messenger: messenger,
            context: context,
            l10n: l10n,
            ref: ref,
            parsed: result.parsed!,
            amountController: widget.amountController,
            exchangeRateController: widget.exchangeRateController,
            supplierNameController: widget.supplierNameController,
            bankNameController: widget.bankNameController,
            swiftCodeController: widget.swiftCodeController,
            ibanController: widget.ibanController,
            payTitleController: widget.payTitleController,
            payNotesController: widget.payNotesController,
            getExchangeRateForCurrency: widget.getExchangeRateForCurrency,
            formatRateText: widget.formatRateText,
            fileName: result.fileName,
            onApplyFields: ({
              required Map<String, dynamic> summary,
              required String currency,
              required DateTime? dueDate,
              required int? supplierId,
              required int? importFileId,
            }) {
              setState(() => _extractedSummary = summary);
              widget.onApplyFields(
                summary: summary,
                currency: currency,
                dueDate: dueDate,
                supplierId: supplierId,
                importFileId: importFileId,
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftFileExtractError(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwiftOcrExtractorCard(
      rawSwiftTextController: _rawTextController,
      isSmartSectionExpanded: _isExpanded,
      onToggleExpanded: () => setState(() => _isExpanded = !_isExpanded),
      isExtracting: _isExtracting,
      onPickAndExtractFile: _autoFillFromFile,
      onExtractFromText: () => _autoFillFromText(_rawTextController.text),
      isAutoFillMode: true,
      autoFillSummary: _extractedSummary,
      onReset: () {
        setState(() {
          _extractedSummary = null;
          _rawTextController.clear();
        });
      },
    );
  }
}
