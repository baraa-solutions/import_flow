import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../financial_ui.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../swift_extraction_review_widget.dart';
import 'swift_reconciliation_common.dart';

/// Card for uploading SWIFT documents (PDF, Docx, Image), smart field extraction,
/// human review verification, and automated bank reconciliation matching.
class SwiftUploadStepCard extends ConsumerStatefulWidget {
  final List<PaymentRequestModel> paymentsList;
  final VoidCallback? onReconciliationCompleted;

  const SwiftUploadStepCard({
    super.key,
    required this.paymentsList,
    this.onReconciliationCompleted,
  });

  @override
  ConsumerState<SwiftUploadStepCard> createState() =>
      _SwiftUploadStepCardState();
}

class _SwiftUploadStepCardState extends ConsumerState<SwiftUploadStepCard> {
  final TextEditingController _rawSwiftTextController =
      TextEditingController();

  bool _isExtracting = false;
  bool _isSmartReconciling = false;
  bool _isSmartSectionExpanded = true;

  Map<String, dynamic>? _extractedSwift;
  Map<String, dynamic>? _matchedPayment;
  int? _selectedPaymentIdForReconcile;
  String? _uploadedFileName;
  String? _detectedFileType;
  int? _uploadedFileSize;
  SwiftBatchModel? _currentBatch;
  bool _isMatchingUnlocked = false;

  @override
  void dispose() {
    _rawSwiftTextController.dispose();
    super.dispose();
  }

  Future<void> _pickAndExtractFile({int? targetPaymentId}) async {
    final l10n = context.l10n;
    try {
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

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileBytes = file.bytes;
      final filename = file.name;

      if (fileBytes == null || fileBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.swiftFileReadErrorSnack,
              severity: AppSeverity.warning,
            ),
          );
        }
        return;
      }

      setState(() {
        _isExtracting = true;
        _uploadedFileName = filename;
        _uploadedFileSize = fileBytes.length;
      });

      final res = await ref
          .read(paymentRequestsProvider.notifier)
          .smartExtractSwiftFromFile(
            fileBytes: fileBytes,
            filename: filename,
            targetPaymentId: targetPaymentId,
          );

      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _extractedSwift = res['parsed_swift'] as Map<String, dynamic>?;
            _matchedPayment =
                res['matched_payment_request'] as Map<String, dynamic>?;
            _detectedFileType = res['detected_file_type'] as String?;
            if (res['batch'] != null) {
              _currentBatch = SwiftBatchModel.fromJson(
                  res['batch'] as Map<String, dynamic>);
              _isMatchingUnlocked =
                  _currentBatch!.status == 'REVIEWED_CONFIRMED' ||
                      _currentBatch!.status == 'RECONCILED';
            }
            if (res['raw_text'] != null &&
                (res['raw_text'] as String).isNotEmpty) {
              _rawSwiftTextController.text = res['raw_text'] as String;
            }
            if (_matchedPayment != null &&
                _matchedPayment!['payment_id'] != null) {
              _selectedPaymentIdForReconcile =
                  _matchedPayment!['payment_id'] as int;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.swiftExtractSuccessSnack(
                filename,
                _detectedFileType ?? l10n.swiftDocumentDefaultType,
              ),
              severity: AppSeverity.success,
            ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftExtractErrorSnack(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _runSmartSwiftExtraction({int? targetPaymentId}) async {
    final l10n = context.l10n;
    final text = _rawSwiftTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l10n.swiftEmptyInputErrorSnack,
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    setState(() => _isExtracting = true);
    try {
      final res =
          await ref.read(paymentRequestsProvider.notifier).smartExtractSwift(
                rawText: text,
                targetPaymentId: targetPaymentId,
              );

      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _extractedSwift = res['parsed_swift'] as Map<String, dynamic>?;
            _matchedPayment =
                res['matched_payment_request'] as Map<String, dynamic>?;
            if (res['batch'] != null) {
              _currentBatch = SwiftBatchModel.fromJson(
                  res['batch'] as Map<String, dynamic>);
              _isMatchingUnlocked =
                  _currentBatch!.status == 'REVIEWED_CONFIRMED' ||
                      _currentBatch!.status == 'RECONCILED';
            }
            if (_matchedPayment != null &&
                _matchedPayment!['payment_id'] != null) {
              _selectedPaymentIdForReconcile =
                  _matchedPayment!['payment_id'] as int;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.swiftParseSuccessSnack,
              severity: AppSeverity.success,
            ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftConnectionErrorSnack(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _executeSmartReconciliation(PaymentRequestModel pay) async {
    if (_extractedSwift == null) return;
    final l10n = context.l10n;

    final rawRef = _extractedSwift!['transaction_reference']?.toString().trim();
    final swiftRef = (rawRef != null && rawRef.isNotEmpty) ? rawRef : null;

    final rawDateStr = _extractedSwift!['value_date']?.toString().trim();
    DateTime? parsedDate;
    if (rawDateStr != null && rawDateStr.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDateStr);
    }

    final amtVal = _extractedSwift!['amount'];
    final double? amt = (amtVal is num)
        ? amtVal.toDouble()
        : (amtVal != null ? double.tryParse(amtVal.toString().trim()) : null);

    final rawCurr = _extractedSwift!['currency']?.toString().trim();
    final curr = (rawCurr != null && rawCurr.isNotEmpty) ? rawCurr : null;

    final swiftCode =
        _extractedSwift!['beneficiary_bank_swift']?.toString() ?? pay.swiftCode;
    final iban =
        _extractedSwift!['beneficiary_account_or_iban']?.toString() ?? pay.ibanAccountNo;

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
      return;
    }

    if (_currentBatch != null &&
        _currentBatch!.status != 'REVIEWED_CONFIRMED' &&
        !(_currentBatch!.status == 'RECONCILED' &&
            _currentBatch!.matchedPaymentId == pay.paymentId)) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          l10n.swiftBatchNotConfirmed,
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    setState(() => _isSmartReconciling = true);
    try {
      PaymentRequestModel? updated;
      if (_currentBatch != null) {
        updated = await ref
            .read(paymentRequestsProvider.notifier)
            .reconcileReviewedSwiftBatch(
              batchId: _currentBatch!.batchId,
              paymentId: pay.paymentId,
              notes: null,
            );
      } else {
        final receiptDateStr =
            '${parsedDate!.year.toString().padLeft(4, '0')}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
        updated = await ref
            .read(paymentRequestsProvider.notifier)
            .smartReconcileSwift(
              paymentId: pay.paymentId,
              rawText: _rawSwiftTextController.text.trim(),
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
      widget.onReconciliationCompleted?.call();

      if (mounted && updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.swiftReconcileSuccessSnack(swiftRef!, updated.paymentCode),
            severity: AppSeverity.success,
            duration: const Duration(seconds: 4),
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
      if (mounted) setState(() => _isSmartReconciling = false);
    }
  }

  Widget _buildInfoField(String label, String value, Color color,
      {bool isBold = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            InkWell(
              onTap: () => CopyHelper.copy(context, value),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.copy_rounded,
                      size: 12, color: color.withValues(alpha: 0.7)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareRow(
    String label,
    String sysVal,
    String swiftVal,
    bool isMatch,
    String badgeText, {
    Color? customBadgeBg,
    Color? customBadgeBorder,
    Color? customBadgeText,
    Widget? trailingAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => CopyHelper.copy(context, sysVal),
                child: Text(
                  sysVal,
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Icon(Icons.arrow_right_alt,
                color: AppTheme.textMuted, size: 16),
            Expanded(
              child: InkWell(
                onTap: () => CopyHelper.copy(context, swiftVal),
                child: Text(
                  swiftVal,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMatch
                        ? AppTheme.emerald
                        : (customBadgeText ?? AppTheme.crimson),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: customBadgeBg ??
                    (isMatch ? AppTheme.emeraldLight : AppTheme.crimsonLight),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: customBadgeBorder ??
                      (isMatch
                          ? AppTheme.emeraldBorder
                          : AppTheme.crimsonBorder),
                ),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: customBadgeText ??
                      (isMatch ? AppTheme.wcagEmerald : AppTheme.crimson),
                ),
              ),
            ),
          ],
        ),
        if (trailingAction != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 130),
            child: trailingAction,
          ),
        ],
      ],
    );
  }

  Widget _buildMatchingMatrixBox(List<PaymentRequestModel> paymentsList) {
    final l10n = context.l10n;
    PaymentRequestModel? matchedPay;
    if (_selectedPaymentIdForReconcile != null) {
      matchedPay = paymentsList.firstWhere(
        (p) => p.paymentId == _selectedPaymentIdForReconcile,
        orElse: () => paymentsList.first,
      );
    } else if (_matchedPayment != null &&
        _matchedPayment!['payment_id'] != null) {
      matchedPay = paymentsList.firstWhere(
        (p) => p.paymentId == _matchedPayment!['payment_id'],
        orElse: () => paymentsList.first,
      );
    }

    if (matchedPay == null) {
      return Center(child: Text(l10n.swiftNoMatchingRecords));
    }
    final score = _matchedPayment?['confidence_score'] ?? 100;
    final amtInfo =
        _matchedPayment?['amount_matching'] as Map<String, dynamic>?;
    final isAmtMatched = amtInfo?['is_matched'] ?? false;
    final variance = (amtInfo?['variance'] as num?)?.toDouble() ??
        ((_extractedSwift?['amount'] is num)
            ? ((_extractedSwift!['amount'] as num).toDouble() -
                matchedPay.requestedAmount)
            : 0.0);

    final benInfo =
        _matchedPayment?['beneficiary_matching'] as Map<String, dynamic>?;
    final isBenMatched = benInfo?['is_matched'] ?? true;

    final bankInfo =
        _matchedPayment?['bank_swift_matching'] as Map<String, dynamic>?;
    final isSwiftMatched = bankInfo?['is_matched'] ??
        (matchedPay.swiftCode == null ||
            matchedPay.swiftCode == _extractedSwift!['beneficiary_bank_swift']);
    final matchedBankType = bankInfo?['matched_bank_type'] as String?;

    final accInfo =
        _matchedPayment?['account_iban_matching'] as Map<String, dynamic>?;
    final isAccMatched = accInfo?['is_matched'] ?? true;

    final mismatchLabel = context.l10n.faMismatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows,
                    color: AppTheme.emerald, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.swiftMatchingMatrixTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.charcoal,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: score >= 80
                    ? AppTheme.emeraldLight
                    : (score >= 50
                        ? AppTheme.orangeLight
                        : AppTheme.crimsonLight),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: score >= 80 ? AppTheme.emerald : AppTheme.orange,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(score >= 80 ? Icons.check_circle : Icons.warning_amber,
                      size: 13,
                      color: score >= 80 ? AppTheme.emerald : AppTheme.orange),
                  const SizedBox(width: 4),
                  Text(
                    l10n.swiftConfidenceScoreTag(score),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: score >= 80
                          ? AppTheme.wcagEmerald
                          : AppTheme.wcagOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Dropdown to change or select Payment Request
        SearchableDropdownField<int>(
          labelText: l10n.swiftTargetPaymentLabel,
          items: paymentsList.where((p) => p.isActive).map((p) {
            final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
            final isArLocale =
                Localizations.localeOf(context).languageCode == 'ar';
            final shipName = DisplayNameResolver.resolveShipmentNameByCode(
              p.importFileCode,
              shipments: allFiles,
              isArabic: isArLocale,
            );
            final shipBadge =
                (shipName.isNotEmpty && shipName != '-') ? ' [$shipName]' : '';
            return SearchableDropdownItem<int>(
              value: p.paymentId,
              label:
                  '${p.paymentCode}$shipBadge - ${p.supplierName} (${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}) [${p.status}]',
              icon: Icons.receipt_long,
            );
          }).toList(),
          value: matchedPay.paymentId,
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedPaymentIdForReconcile = val);
              _runSmartSwiftExtraction(targetPaymentId: val);
            }
          },
        ),
        const SizedBox(height: 10),

        // Checklist Comparison Table
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.cloudWhite),
          ),
          child: Column(
            children: [
              _buildCompareRow(
                '${l10n.swiftRequestedAmountLabel}:',
                '${matchedPay.requestedAmount.toStringAsFixed(2)} ${matchedPay.currencyCode}',
                '${_extractedSwift!['amount'] ?? '-'} ${_extractedSwift!['currency'] ?? '-'}',
                isAmtMatched,
                isAmtMatched
                    ? (variance == 0.0
                        ? l10n.swiftBadgeMatchedFull
                        : l10n.swiftBadgeDeficit(
                            variance.abs().toStringAsFixed(2),
                            matchedPay.currencyCode))
                    : mismatchLabel,
              ),
              const Divider(height: 12),
              _buildCompareRow(
                l10n.swiftBeneficiaryLabel,
                matchedPay.beneficiaryName ?? matchedPay.supplierName,
                _extractedSwift!['beneficiary_name'] ?? '-',
                isBenMatched,
                isBenMatched ? l10n.swiftBadgeMatchedFull : mismatchLabel,
              ),
              const Divider(height: 12),
              _buildCompareRow(
                context.l10n.faBeneficiarySwift57a,
                matchedPay.swiftCode ?? '-',
                _extractedSwift!['beneficiary_bank_swift'] ?? '-',
                isSwiftMatched && matchedBankType != 'SENDER_BANK',
                (isSwiftMatched && matchedBankType != 'SENDER_BANK')
                    ? l10n.swiftBadgeMatchedFull
                    : (matchedBankType == 'SENDER_BANK'
                        ? (context.l10n.faMatchedSenderBank)
                        : mismatchLabel),
                customBadgeBg: matchedBankType == 'SENDER_BANK'
                    ? AppTheme.orangeLight
                    : null,
                customBadgeBorder:
                    matchedBankType == 'SENDER_BANK' ? AppTheme.orange : null,
                customBadgeText: matchedBankType == 'SENDER_BANK'
                    ? AppTheme.wcagOrange
                    : null,
              ),
              if (_extractedSwift!['sender_bank_swift'] != null &&
                  _extractedSwift!['sender_bank_swift']
                      .toString()
                      .isNotEmpty) ...[
                const Divider(height: 12),
                _buildCompareRow(
                  context.l10n.faRemittingBankEg,
                  _extractedSwift!['sender_bank_name'] ??
                      (context.l10n.faRemittingBankInEgypt),
                  _extractedSwift!['sender_bank_swift'],
                  true,
                  context.l10n.faIssuingBank,
                  customBadgeBg: AppTheme.cobaltLight,
                  customBadgeBorder: AppTheme.cobaltBorder,
                  customBadgeText: AppTheme.wcagCobalt,
                ),
              ],
              const Divider(height: 12),
              _buildCompareRow(
                l10n.swiftAccountLabel,
                matchedPay.ibanAccountNo ?? '-',
                _extractedSwift!['beneficiary_account_or_iban'] ?? '-',
                isAccMatched,
                isAccMatched ? l10n.swiftBadgeMatchedFull : mismatchLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action Button: Auto-Reconcile & Mark as Paid
        SizedBox(
          width: double.infinity,
          child: FinancialUi.fit(AppButton(
            label: l10n.swiftExecuteReconcileBtn,
            variant: AppButtonVariant.success,
            icon: Icons.verified,
            isLoading: _isSmartReconciling,
            onPressed: _isSmartReconciling
                ? null
                : () => _executeSmartReconciliation(matchedPay!),
          )),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.cobalt.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cobalt.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar with gradient and toggles
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.charcoal,
                    AppTheme.cobalt.withValues(alpha: 0.9)
                  ],
                  begin: AlignmentDirectional.centerEnd,
                  end: AlignmentDirectional.centerStart,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: AppTheme.orange, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.swiftExtractorHeader,
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  FinancialUi.fit(AppButton(
                    label: l10n.swiftLoadSampleBtn,
                    variant: AppButtonVariant.secondary,
                    icon: Icons.description,
                    onPressed: () {
                      _rawSwiftTextController.text = kSampleSwiftMT103;
                      _runSmartSwiftExtraction();
                    },
                  )),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _isSmartSectionExpanded
                        ? l10n.swiftCollapseToolTooltip
                        : l10n.swiftExpandToolTooltip,
                    icon: Icon(
                      _isSmartSectionExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.white,
                    ),
                    onPressed: () => setState(
                      () => _isSmartSectionExpanded = !_isSmartSectionExpanded,
                    ),
                  ),
                ],
              ),
            ),

            if (_isSmartSectionExpanded)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Uploaded File Info Banner (if any)
                    if (_uploadedFileName != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.cobaltLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cobaltBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _uploadedFileName!.toLowerCase().endsWith('.pdf')
                                  ? Icons.picture_as_pdf
                                  : (_uploadedFileName!
                                              .toLowerCase()
                                              .endsWith('.docx') ||
                                          _uploadedFileName!
                                              .toLowerCase()
                                              .endsWith('.doc')
                                      ? Icons.description
                                      : (_uploadedFileName!
                                                  .toLowerCase()
                                                  .endsWith('.xlsx') ||
                                              _uploadedFileName!
                                                  .toLowerCase()
                                                  .endsWith('.xls') ||
                                              _uploadedFileName!
                                                  .toLowerCase()
                                                  .endsWith('.csv')
                                          ? Icons.table_chart
                                          : Icons.image)),
                              color: AppTheme.wcagCobalt,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${l10n.swiftExtractedDocLabel} ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppTheme.wcagCobalt,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _uploadedFileName!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppTheme.wcagCobalt,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${l10n.swiftDocTypePrefix} ${_detectedFileType ?? l10n.swiftDocumentDefaultType} ${_uploadedFileSize != null ? "• ${l10n.swiftDocSizePrefix} ${(_uploadedFileSize! / 1024).toStringAsFixed(1)} KB" : ""}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.wcagCobalt,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FinancialUi.fit(AppButton(
                              label: l10n.swiftUploadFileBtn,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              icon: Icons.refresh,
                              onPressed: () => _pickAndExtractFile(),
                            )),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: AppTheme.wcagCobalt),
                              tooltip: l10n.swiftCloseBtn,
                              onPressed: () {
                                setState(() {
                                  _uploadedFileName = null;
                                  _detectedFileType = null;
                                  _uploadedFileSize = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                    // Text Area + Action Buttons
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _rawSwiftTextController,
                            maxLines: 5,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.swiftRawTextPlaceholder,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: AppTheme.charcoalSurface,
                              contentPadding: const EdgeInsets.all(12),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: l10n.swiftCopyFieldTooltip,
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  _rawSwiftTextController.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          children: [
                            FinancialUi.fit(AppButton(
                              label: l10n.swiftUploadFileBtn,
                              variant: AppButtonVariant.primary,
                              icon: Icons.upload_file,
                              isLoading: _isExtracting,
                              onPressed: _isExtracting
                                  ? null
                                  : () => _pickAndExtractFile(),
                            )),
                            const SizedBox(height: 8),
                            FinancialUi.fit(AppButton(
                              label: l10n.swiftExtractFromTextBtn,
                              variant: AppButtonVariant.primary,
                              icon: Icons.bolt,
                              isLoading: _isExtracting,
                              onPressed: _isExtracting
                                  ? null
                                  : () => _runSmartSwiftExtraction(),
                            )),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                FinancialUi.fit(AppButton(
                                  label: l10n.swiftPasteAndExtractChip,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  icon: Icons.paste,
                                  onPressed: () async {
                                    final data = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    if (data != null &&
                                        data.text != null &&
                                        data.text!.isNotEmpty) {
                                      _rawSwiftTextController.text = data.text!;
                                      _runSmartSwiftExtraction();
                                    }
                                  },
                                )),
                                const SizedBox(width: 4),
                                FinancialUi.fit(AppButton(
                                  label: l10n.swiftCancelBtn,
                                  variant: AppButtonVariant.secondary,
                                  icon: Icons.clear,
                                  onPressed: () {
                                    _rawSwiftTextController.clear();
                                    setState(() {
                                      _currentBatch = null;
                                      _isMatchingUnlocked = false;
                                      _extractedSwift = null;
                                      _matchedPayment = null;
                                      _selectedPaymentIdForReconcile = null;
                                      _uploadedFileName = null;
                                      _detectedFileType = null;
                                      _uploadedFileSize = null;
                                    });
                                  },
                                )),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    // 1. SWIFT Extraction Review Layer (Mandatory Human Review)
                    if (_currentBatch != null) ...[
                      const SizedBox(height: 16),
                      SwiftExtractionReviewWidget(
                        initialBatch: _currentBatch!,
                        onBatchConfirmed: (confirmedBatch) async {
                          setState(() {
                            _currentBatch = confirmedBatch;
                            _isMatchingUnlocked = true;
                          });
                          try {
                            final matchRes = await ref
                                .read(paymentRequestsProvider.notifier)
                                .matchReviewedSwiftBatch(
                                  batchId: confirmedBatch.batchId,
                                  targetPaymentId:
                                      _selectedPaymentIdForReconcile,
                                );
                            if (mounted && matchRes['success'] == true) {
                              setState(() {
                                _matchedPayment =
                                    matchRes['matched_payment_request']
                                        as Map<String, dynamic>?;
                                if (_matchedPayment != null &&
                                    _matchedPayment!['payment_id'] != null) {
                                  _selectedPaymentIdForReconcile =
                                      _matchedPayment!['payment_id'] as int;
                                }
                              });
                            }
                          } catch (e) {
                            debugPrint("Error matching reviewed batch: $e");
                          }
                        },
                        onCancel: () {
                          setState(() {
                            _currentBatch = null;
                            _isMatchingUnlocked = false;
                            _extractedSwift = null;
                            _matchedPayment = null;
                          });
                        },
                      ),
                    ],

                    // 2. Matching Matrix Box (Only unlocked after user explicitly confirms the review!)
                    if (_isMatchingUnlocked && _currentBatch != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.emerald, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.lock_open,
                                    color: AppTheme.emerald, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  context.l10n.faApprovedMatchingMatrix,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.l10n.faDataHumanVerified,
                                    style: const TextStyle(
                                      color: AppTheme.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildMatchingMatrixBox(widget.paymentsList),
                          ],
                        ),
                      ),
                    ] else if (_currentBatch == null &&
                        _extractedSwift != null) ...[
                      // Legacy fallback if no batch was returned
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Box: Extracted SWIFT Details
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.cobaltLight
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: AppTheme.cobaltBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.account_balance,
                                                color: AppTheme.cobalt,
                                                size: 18),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                l10n.swiftExtractorHeader,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: AppTheme.charcoal,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Ref: ${_extractedSwift!['transaction_reference'] ?? l10n.swiftStatusUnregistered}',
                                            style: const TextStyle(
                                              color: AppTheme.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _buildInfoField(
                                        l10n.swiftColTransferredAmount,
                                        '${_extractedSwift!['amount']} ${_extractedSwift!['currency']}',
                                        AppTheme.emerald,
                                        isBold: true,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildInfoField(
                                        l10n.swiftColSwiftDate,
                                        _extractedSwift![
                                                'value_date_formatted'] ??
                                            _extractedSwift!['value_date'] ??
                                            '-',
                                        AppTheme.charcoal,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildInfoField(
                                        l10n.swiftChargesLabel,
                                        _extractedSwift!['charge_details'] ??
                                            'SHA',
                                        AppTheme.emerald,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${l10n.swiftExtractedReceiverPrefix.replaceAll(':', '')}: ${_extractedSwift!['beneficiary_name'] ?? "-"}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${l10n.swiftCodeLabel.replaceAll(':', '')}: ${_extractedSwift!['beneficiary_bank_swift'] ?? "-"}',
                                          style:
                                              const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${l10n.swiftAccountLabel.replaceAll(':', '')}: ${_extractedSwift!['beneficiary_account_or_iban'] ?? "-"}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${l10n.swiftExtractedSenderPrefix.replaceAll(':', '')}: ${_extractedSwift!['ordering_customer_name'] ?? "-"} (${_extractedSwift!['ordering_account_or_iban'] ?? "-"})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textStrong,
                                    ),
                                  ),
                                  if (_extractedSwift!['pi_number'] != null ||
                                      _extractedSwift!['payment_details'] !=
                                          null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${l10n.swiftRequestTitleLabel} ${_extractedSwift!['pi_number'] ?? _extractedSwift!['payment_details']}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.cobalt,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 6,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.emeraldLight.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: AppTheme.emeraldBorder),
                              ),
                              child:
                                  _buildMatchingMatrixBox(widget.paymentsList),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
