import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../financial_ui.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import 'swift_reconciliation_common.dart';
import 'dialog/swift_extract_actions_bar.dart';
import 'dialog/swift_matching_matrix_box.dart';
import 'dialog/swift_payment_summary_banner.dart';

/// Modal dialog for resolving SWIFT reconciliation differences, discrepancy handling,
/// and live synchronization with financial records.
class SwiftDiscrepancyDialog extends ConsumerStatefulWidget {
  final PaymentRequestModel pay;
  final VoidCallback? onReconciled;

  const SwiftDiscrepancyDialog({
    super.key,
    required this.pay,
    this.onReconciled,
  });

  static Future<void> show(
    BuildContext context, {
    required PaymentRequestModel pay,
    VoidCallback? onReconciled,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SwiftDiscrepancyDialog(
        pay: pay,
        onReconciled: onReconciled,
      ),
    );
  }

  @override
  ConsumerState<SwiftDiscrepancyDialog> createState() =>
      _SwiftDiscrepancyDialogState();
}

class _SwiftDiscrepancyDialogState
    extends ConsumerState<SwiftDiscrepancyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _swiftRefController;
  late final TextEditingController _transferredAmountController;
  late final TextEditingController _notesController;

  String? _selectedCurrency;
  DateTime? _receiptDate;
  late final DateTime _requestDate;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _swiftRefController =
        TextEditingController(text: widget.pay.swiftReferenceNo ?? '');
    _transferredAmountController = TextEditingController(
      text: widget.pay.swiftTransferredAmount != null
          ? widget.pay.swiftTransferredAmount!.toStringAsFixed(2)
          : '',
    );
    _notesController =
        TextEditingController(text: widget.pay.swiftReconciliationNotes ?? '');

    _selectedCurrency = widget.pay.swiftTransferredCurrency ??
        (widget.pay.currencyCode.isNotEmpty ? widget.pay.currencyCode : null);

    if (widget.pay.swiftReceiptDate != null &&
        widget.pay.swiftReceiptDate!.isNotEmpty) {
      _receiptDate = DateTime.tryParse(widget.pay.swiftReceiptDate!);
    }

    if (widget.pay.requestDate.isNotEmpty) {
      _requestDate =
          DateTime.tryParse(widget.pay.requestDate) ?? DateTime.now();
    } else {
      _requestDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _swiftRefController.dispose();
    _transferredAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyExtractedData(Map<String, dynamic> p) {
    setState(() {
      if (p['transaction_reference'] != null) {
        _swiftRefController.text = p['transaction_reference'].toString();
      }
      if (p['amount'] != null) {
        _transferredAmountController.text = p['amount'].toString();
      }
      if (p['currency'] != null) {
        _selectedCurrency = p['currency'].toString();
      }
      if (p['value_date'] != null) {
        _receiptDate =
            DateTime.tryParse(p['value_date'].toString()) ?? _receiptDate;
      }
    });
  }

  Future<void> _handleSampleExtract() async {
    final res = await ref.read(paymentRequestsProvider.notifier).smartExtractSwift(
          rawText: kSampleSwiftMT103,
          targetPaymentId: widget.pay.paymentId,
        );
    if (res['success'] == true && res['parsed_swift'] != null) {
      _applyExtractedData(res['parsed_swift'] as Map<String, dynamic>);
    }
  }

  Future<void> _handlePasteExtract() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final res = await ref.read(paymentRequestsProvider.notifier).smartExtractSwift(
            rawText: data.text!,
            targetPaymentId: widget.pay.paymentId,
          );
      if (res['success'] == true && res['parsed_swift'] != null) {
        _applyExtractedData(res['parsed_swift'] as Map<String, dynamic>);
      }
    }
  }

  Future<void> _handleUploadExtract() async {
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
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      if (f.bytes != null) {
        final res = await ref
            .read(paymentRequestsProvider.notifier)
            .smartExtractSwiftFromFile(
              fileBytes: f.bytes!,
              filename: f.name,
              targetPaymentId: widget.pay.paymentId,
            );
        if (res['success'] == true && res['parsed_swift'] != null) {
          _applyExtractedData(res['parsed_swift'] as Map<String, dynamic>);
        }
      }
    }
  }

  Future<void> _handleSaveAndSync() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate() || _receiptDate == null) return;
    Navigator.of(context).pop();

    setState(() => _isProcessing = true);
    try {
      final transferredAmt =
          double.tryParse(_transferredAmountController.text.trim()) ?? 0.0;
      final updated = await ref
          .read(paymentRequestsProvider.notifier)
          .reconcileSwift(
            paymentId: widget.pay.paymentId,
            swiftReferenceNo: _swiftRefController.text.trim(),
            swiftReceiptDate: _receiptDate!.toString().substring(0, 10),
            swiftTransferredAmount: transferredAmt,
            swiftTransferredCurrency: _selectedCurrency!,
            swiftReconciliationNotes: _notesController.text.trim(),
          );

      ref.read(importFilesProvider.notifier).fetchImportFiles();
      widget.onReconciled?.call();

      if (mounted && updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftReconcileSuccessSnack(
              updated.swiftReferenceNo ?? '',
              updated.paymentCode,
            ),
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftReconcileErrorSnack(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pay = widget.pay;

    final transferredAmt =
        double.tryParse(_transferredAmountController.text.trim()) ?? 0.0;
    final processingDays = _receiptDate?.difference(_requestDate).inDays;
    final safeDays = processingDays != null
        ? (processingDays < 0 ? 0 : processingDays)
        : null;

    return SelectionArea(
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_balance, color: AppTheme.cobalt),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.swiftReconcileDialogTitle(pay.paymentCode),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 680,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwiftPaymentSummaryBanner(pay: pay),
                  const SizedBox(height: 12),
                  SwiftExtractActionsBar(
                    onSampleExtract: _handleSampleExtract,
                    onPasteExtract: _handlePasteExtract,
                    onUploadExtract: _handleUploadExtract,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppDatePickerField(
                          key: const Key('swiftReceiptDateField'),
                          label: l10n.swiftReceiptDateLabel,
                          value: _receiptDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          isRequired: true,
                          validator: (v) =>
                              (_receiptDate == null && v == null)
                                  ? l10n.requiredField
                                  : null,
                          onChanged: (picked) {
                            setState(() {
                              _receiptDate = picked;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _swiftRefController,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: '${l10n.swiftColSwiftRef} *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.tag,
                                color: AppTheme.cobalt),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: l10n.swiftCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(
                                context,
                                _swiftRefController.text,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? l10n.swiftEnterSwiftRefError
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _transferredAmountController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText:
                                '${l10n.swiftTransferredAmountLabel} *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.attach_money,
                                color: AppTheme.emerald),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: l10n.swiftCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(
                                context,
                                _transferredAmountController.text,
                              ),
                            ),
                          ),
                          onChanged: (v) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return l10n.swiftEnterAmountError;
                            }
                            final num = double.tryParse(v.trim());
                            if (num == null || num <= 0) {
                              return l10n.swiftAmountGreaterThanZeroError;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final currs =
                                ref.watch(currenciesProvider).valueOrNull ?? [];
                            final items = currs
                                .map((c) => SearchableDropdownItem<String>(
                                      value: c.currencyCode,
                                      label:
                                          '${c.currencyCode} (${c.currencyName})',
                                      searchValue:
                                          '${c.currencyCode} ${c.currencyName}',
                                    ))
                                .toList();
                            if (_selectedCurrency != null &&
                                _selectedCurrency!.isNotEmpty &&
                                !items.any((i) => i.value == _selectedCurrency)) {
                              items.insert(
                                0,
                                SearchableDropdownItem<String>(
                                  value: _selectedCurrency!,
                                  label: _selectedCurrency!,
                                ),
                              );
                            }
                            return SearchableDropdownField<String>(
                              value: _selectedCurrency,
                              labelText: '${l10n.swiftCurrencyLabel} *',
                              isRequired: true,
                              items: items,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? l10n.swiftCurrencyRequiredError
                                      : null,
                              onChanged: (val) {
                                setState(() {
                                  _selectedCurrency = val;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwiftMatchingMatrixBox(
                    pay: pay,
                    transferredAmt: transferredAmt,
                    safeDays: safeDays,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.orangeLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt,
                            color: AppTheme.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.swiftSyncShipmentNotice,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.wcagOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.swiftReconciliationNotesLabel,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: l10n.swiftCopyFieldTooltip,
                        onPressed: () =>
                            CopyHelper.copy(context, _notesController.text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          FinancialUi.fit(AppButton(
            label: l10n.swiftCancelBtn,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          )),
          FinancialUi.fit(AppButton(
            label: l10n.swiftSaveAndSyncBtn,
            variant: AppButtonVariant.success,
            icon: Icons.check,
            isLoading: _isProcessing,
            onPressed: _isProcessing ? null : _handleSaveAndSync,
          )),
        ],
      ),
    );
  }
}
