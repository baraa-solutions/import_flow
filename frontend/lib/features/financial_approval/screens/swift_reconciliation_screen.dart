import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../services/financial_export_service.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../widgets/swift_extraction_review_widget.dart';

import 'package:flutter/services.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/localization/stored_text.dart';

const String kSampleSwiftMT103 = '''{1:F01ARAIECXXXXX.SN...ISN.}{2:I103CITIUS33XXXXN}{3:{108:xxxxx}}{4:
:20/TRANSACTION REFERENCE NUMBER       : FT/26228/KZ70Q
:23B/BANK OPERATION CODE              : CRED
:32A/Value Date, CCY, Amount          : 260818USD43704,00
:50K/ORDERING CUST                     : /EG780057004001017153610010101
                                        SCAS FOR CONSTRUCTION AND FINISHING
                                        ROAD 18
                                        EGYPT,44 ROAD 18
                                        SARIAT EL MAADI,CAIRO
:57A/Account with Bank                : PCBCCNBJJSS
:59/Beneficiary Customer              : /32250198613609841015
                                        SUZHOU YUHENG TEXTILE CO., LTD
                                        16 KANGSHENG ROAD ZHITANG TOWN
                                        CHANGSHU CITY SUZHOU CHINA
:70/DETAILS OF PAYMENT                : EG0010040 PI NO.YH20260730.6
                                        ALL DOCUMENTS SHOULD BE TRADED
                                        THROUGH AAIB
:71A/DETAILS OF CHARGES               : SHA
-}''';

class SwiftReconciliationScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const SwiftReconciliationScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<SwiftReconciliationScreen> createState() => _SwiftReconciliationScreenState();
}

class _SwiftReconciliationScreenState extends ConsumerState<SwiftReconciliationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _rawSwiftTextController = TextEditingController();

  String _selectedStatusFilter = 'ALL'; // ALL, PENDING, MATCHED, DEFICIT, SURPLUS
  bool _isProcessing = false;
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
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(paymentRequestsProvider).isLoading) {
        ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rawSwiftTextController.dispose();
    super.dispose();
  }

  void _exportTsv(List<PaymentRequestModel> payments) {
    final l10n = context.l10n;
    final buffer = StringBuffer();
    // Header
    buffer.writeln([
      l10n.swiftTsvHeaderPaymentCode,
      l10n.swiftTsvHeaderImportFile,
      l10n.swiftTsvHeaderBeneficiary,
      l10n.swiftTsvHeaderBank,
      l10n.swiftTsvHeaderRequestDate,
      l10n.swiftTsvHeaderSwiftReceiptDate,
      l10n.swiftTsvHeaderProcessingDays,
      l10n.swiftTsvHeaderRequestedAmount,
      l10n.swiftTsvHeaderTransferredAmount,
      l10n.swiftTsvHeaderVariance,
      l10n.swiftTsvHeaderSwiftRef,
      l10n.swiftTsvHeaderStatus,
    ].join('\t'));

    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    for (final p in payments) {
      final days = p.swiftProcessingDays != null ? '${p.swiftProcessingDays}' : '-';
      final transferred = p.swiftTransferredAmount != null
          ? '${p.swiftTransferredAmount} ${p.swiftTransferredCurrency ?? p.currencyCode}'
          : '-';
      final variance = p.swiftVarianceAmount != null
          ? '${p.swiftVarianceAmount} ${p.swiftTransferredCurrency ?? p.currencyCode}'
          : '-';
      final status = p.swiftVarianceStatus ??
          (p.swiftReferenceNo != null && p.swiftReferenceNo!.isNotEmpty
              ? l10n.swiftBadgeMatchedFull
              : l10n.swiftBadgePending);
      final resolvedShipTitle = DisplayNameResolver.resolveShipmentTitleByCode(p.importFileCode, shipments: allFiles, isArabic: isAr);

      buffer.writeln([
        p.paymentCode,
        resolvedShipTitle,
        p.beneficiaryName ?? p.supplierName,
        p.bankName ?? '-',
        p.requestDate,
        p.swiftReceiptDate ?? '-',
        days,
        '${p.requestedAmount} ${p.currencyCode}',
        transferred,
        variance,
        p.swiftReferenceNo ?? '-',
        status,
      ].join('\t'));
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.swiftExportTsvSuccess),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  void _copyPaymentDossier(PaymentRequestModel pay) {
    final l10n = context.l10n;
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final resolvedShipTitle = DisplayNameResolver.resolveShipmentTitleByCode(pay.importFileCode, shipments: allFiles, isArabic: isAr);
    final status = pay.swiftVarianceStatus ??
        (pay.swiftReferenceNo != null && pay.swiftReferenceNo!.isNotEmpty
            ? l10n.swiftBadgeMatchedFull
            : l10n.swiftBadgePending);
    final text = '''
${l10n.swiftDetailsDialogTitle(pay.paymentCode)}
${l10n.swiftRequestTitleLabel} ${pay.title}
${l10n.swiftTsvHeaderImportFile}: $resolvedShipTitle
${l10n.swiftBeneficiaryLabel} ${pay.beneficiaryName ?? pay.supplierName}
${l10n.swiftBankLabel} ${pay.bankName ?? "-"} | SWIFT: ${pay.swiftCode ?? "-"} | ${l10n.swiftAccountLabel} ${pay.ibanAccountNo ?? "-"}
${l10n.swiftRequestDateLabel}: ${pay.requestDate.isNotEmpty ? pay.requestDate : "-"}
${l10n.swiftReceiptDateLabel}: ${pay.swiftReceiptDate ?? l10n.swiftBadgePending}
${l10n.swiftProcessingTimeLabel}: ${pay.swiftProcessingDays != null ? "${pay.swiftProcessingDays}" : "-"}
${l10n.swiftRequestedAmountLabel}: ${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}
${l10n.swiftTransferredAmountLabel}: ${pay.swiftTransferredAmount != null ? "${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}" : "-"}
${l10n.swiftVarianceLabel}: ${pay.swiftVarianceAmount != null ? "${pay.swiftVarianceAmount!.toStringAsFixed(2)} ${pay.currencyCode}" : "-"} ($status)
${l10n.swiftColSwiftRef}: ${pay.swiftReferenceNo ?? l10n.swiftStatusUnregistered}
${l10n.swiftReconciliationNotesLabel}: ${pay.swiftReconciliationNotes ?? "-"}
'''.trim();

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.swiftCopySummarySuccess),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  void _copyFilteredSummary(List<PaymentRequestModel> payments) {
    final l10n = context.l10n;
    final matchedCount = payments.where((p) => p.swiftVarianceStatus == 'Matched').length;
    final pendingCount = payments.where((p) => p.swiftReferenceNo == null || p.swiftReferenceNo!.isEmpty).length;
    final varianceCount = payments.where((p) => p.swiftVarianceStatus == 'Deficit' || p.swiftVarianceStatus == 'Surplus').length;

    final summary = '''
${l10n.swiftScreenTitle}
${l10n.swiftTableTitle(payments.length)}
${l10n.swiftTotalRequestsMetric}: ${payments.length}
${l10n.swiftMatchedSwiftMetric}: $matchedCount
${l10n.swiftPendingSwiftMetric}: $pendingCount
${l10n.swiftVariancesMetric}: $varianceCount
'''.trim();

    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.swiftCopySummarySuccess),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  Future<void> _pickAndExtractFile({int? targetPaymentId}) async {
    final l10n = context.l10n;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'xlsx', 'xls', 'csv', 'jpg', 'jpeg', 'png', 'webp', 'bmp', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileBytes = file.bytes;
      final filename = file.name;

      if (fileBytes == null || fileBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.swiftFileReadErrorSnack), backgroundColor: AppTheme.orange),
          );
        }
        return;
      }

      setState(() {
        _isExtracting = true;
        _uploadedFileName = filename;
        _uploadedFileSize = fileBytes.length;
      });

      final res = await ref.read(paymentRequestsProvider.notifier).smartExtractSwiftFromFile(
        fileBytes: fileBytes,
        filename: filename,
        targetPaymentId: targetPaymentId,
      );

      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _extractedSwift = res['parsed_swift'] as Map<String, dynamic>?;
            _matchedPayment = res['matched_payment_request'] as Map<String, dynamic>?;
            _detectedFileType = res['detected_file_type'] as String?;
            if (res['batch'] != null) {
              _currentBatch = SwiftBatchModel.fromJson(res['batch'] as Map<String, dynamic>);
              _isMatchingUnlocked = _currentBatch!.status == 'REVIEWED_CONFIRMED' || _currentBatch!.status == 'RECONCILED';
            }
            if (res['raw_text'] != null && (res['raw_text'] as String).isNotEmpty) {
              _rawSwiftTextController.text = res['raw_text'] as String;
            }
            if (_matchedPayment != null && _matchedPayment!['payment_id'] != null) {
              _selectedPaymentIdForReconcile = _matchedPayment!['payment_id'] as int;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.swiftExtractSuccessSnack(filename, _detectedFileType ?? l10n.swiftDocumentDefaultType),
              ),
              backgroundColor: AppTheme.emerald,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.swiftExtractErrorSnack(res['error']?.toString() ?? ''),
              ),
              backgroundColor: AppTheme.crimson,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.swiftExtractErrorSnack(e.toString())),
            backgroundColor: AppTheme.crimson,
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
        SnackBar(
          content: Text(l10n.swiftEmptyInputErrorSnack),
          backgroundColor: AppTheme.orange,
        ),
      );
      return;
    }

    setState(() => _isExtracting = true);
    try {
      final res = await ref.read(paymentRequestsProvider.notifier).smartExtractSwift(
        rawText: text,
        targetPaymentId: targetPaymentId,
      );

      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _extractedSwift = res['parsed_swift'] as Map<String, dynamic>?;
            _matchedPayment = res['matched_payment_request'] as Map<String, dynamic>?;
            if (res['batch'] != null) {
              _currentBatch = SwiftBatchModel.fromJson(res['batch'] as Map<String, dynamic>);
              _isMatchingUnlocked = _currentBatch!.status == 'REVIEWED_CONFIRMED' || _currentBatch!.status == 'RECONCILED';
            }
            if (_matchedPayment != null && _matchedPayment!['payment_id'] != null) {
              _selectedPaymentIdForReconcile = _matchedPayment!['payment_id'] as int;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.swiftParseSuccessSnack),
              backgroundColor: AppTheme.emerald,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.swiftParseErrorSnack(res['error']?.toString() ?? ''),
              ),
              backgroundColor: AppTheme.crimson,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.swiftConnectionErrorSnack(e.toString())),
            backgroundColor: AppTheme.crimson,
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

    final swiftRef = _extractedSwift!['transaction_reference'] ?? 'SWIFT-${DateTime.now().millisecondsSinceEpoch}';
    final rawDate = _extractedSwift!['value_date'] ?? DateTime.now().toString().substring(0, 10);
    final amt = (_extractedSwift!['amount'] as num?)?.toDouble() ?? pay.requestedAmount;
    final curr = _extractedSwift!['currency'] ?? pay.currencyCode;
    final swiftCode = _extractedSwift!['beneficiary_bank_swift'] ?? pay.swiftCode;
    final iban = _extractedSwift!['beneficiary_account_or_iban'] ?? pay.ibanAccountNo;

    setState(() => _isSmartReconciling = true);
    try {
      PaymentRequestModel? updated;
      if (_currentBatch != null) {
        updated = await ref.read(paymentRequestsProvider.notifier).reconcileReviewedSwiftBatch(
          batchId: _currentBatch!.batchId,
          paymentId: pay.paymentId,
          notes: storedText.swiftScreenSubtitle,
        );
      } else {
        updated = await ref.read(paymentRequestsProvider.notifier).smartReconcileSwift(
          paymentId: pay.paymentId,
          rawText: _rawSwiftTextController.text.trim(),
          swiftReferenceNo: swiftRef,
          swiftReceiptDate: rawDate.toString().substring(0, 10),
          swiftTransferredAmount: amt,
          swiftTransferredCurrency: curr,
          swiftCode: swiftCode,
          ibanAccountNo: iban,
          swiftReconciliationNotes: l10n.swiftScreenSubtitle,
          autoExecute: true,
        );
      }

      ref.read(importFilesProvider.notifier).fetchImportFiles();

      if (mounted && updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.swiftReconcileSuccessSnack(swiftRef, updated.paymentCode),
            ),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.swiftReconcileErrorSnack(e.toString())),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSmartReconciling = false);
    }
  }

  void _showSwiftReconciliationDialog(PaymentRequestModel pay) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final swiftRefController = TextEditingController(text: pay.swiftReferenceNo ?? '');
    final transferredAmountController = TextEditingController(
      text: pay.swiftTransferredAmount != null
          ? pay.swiftTransferredAmount!.toStringAsFixed(2)
          : pay.requestedAmount.toStringAsFixed(2),
    );
    final currencyController = TextEditingController(
      text: pay.swiftTransferredCurrency ?? pay.currencyCode,
    );
    final notesController = TextEditingController(text: pay.swiftReconciliationNotes ?? '');

    DateTime receiptDate;
    if (pay.swiftReceiptDate != null && pay.swiftReceiptDate!.isNotEmpty) {
      receiptDate = DateTime.tryParse(pay.swiftReceiptDate!) ?? DateTime.now();
    } else {
      receiptDate = DateTime.now();
    }

    DateTime requestDate;
    if (pay.requestDate.isNotEmpty) {
      requestDate = DateTime.tryParse(pay.requestDate) ?? DateTime.now();
    } else {
      requestDate = DateTime.now();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final transferredAmt = double.tryParse(transferredAmountController.text.trim()) ?? 0.0;
            final variance = transferredAmt - pay.requestedAmount;
            final processingDays = receiptDate.difference(requestDate).inDays;
            final safeDays = processingDays < 0 ? 0 : processingDays;

            Color varianceColor;
            IconData varianceIcon;
            String varianceText;

            if (transferredAmt <= 0) {
              varianceColor = Colors.grey;
              varianceIcon = Icons.hourglass_empty;
              varianceText = l10n.swiftWaitingAmountEntry;
            } else if (variance.abs() < 0.001) {
              varianceColor = AppTheme.emerald;
              varianceIcon = Icons.check_circle;
              varianceText = l10n.swiftBadgeMatchedFull;
            } else if (variance < 0) {
              varianceColor = AppTheme.crimson;
              varianceIcon = Icons.arrow_downward;
              varianceText = l10n.swiftBadgeDeficit(variance.abs().toStringAsFixed(2), pay.currencyCode);
            } else {
              varianceColor = AppTheme.orange;
              varianceIcon = Icons.arrow_upward;
              varianceText = l10n.swiftBadgeSurplus(variance.toStringAsFixed(2), pay.currencyCode);
            }

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
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary of Payment Request
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text('${l10n.swiftRequestTitleLabel} ${pay.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    if (pay.importFileCode != null)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () => CopyHelper.copy(context, pay.importFileCode!),
                                        child: Tooltip(
                                          message: l10n.swiftCopyFieldTooltip,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: AppTheme.cobalt, borderRadius: BorderRadius.circular(4)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.copy_rounded, color: Colors.white, size: 12),
                                                const SizedBox(width: 4),
                                                Text(pay.importFileCode!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(child: Text('${l10n.swiftBeneficiaryLabel} ${pay.beneficiaryName ?? pay.supplierName}', style: const TextStyle(fontSize: 12))),
                                    Expanded(child: Text('${l10n.swiftBankLabel} ${pay.bankName ?? "-"} (${pay.swiftCode ?? "-"})', style: const TextStyle(fontSize: 12))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(child: Text('${l10n.swiftRequestDateLabel}: ${pay.requestDate.isNotEmpty ? pay.requestDate : "-"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.charcoal))),
                                    Expanded(child: Text('${l10n.swiftRequestedAmountLabel}: ${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Quick Smart AI Extract Button inside Dialog
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('${l10n.swiftExtractorHeader}:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.description, size: 14),
                                  label: Text(l10n.swiftSampleMT103Chip, style: const TextStyle(fontSize: 11)),
                                  onPressed: () async {
                                    final res = await ref.read(paymentRequestsProvider.notifier).smartExtractSwift(
                                      rawText: kSampleSwiftMT103,
                                      targetPaymentId: pay.paymentId,
                                    );
                                    if (res['success'] == true && res['parsed_swift'] != null) {
                                      final p = res['parsed_swift'] as Map<String, dynamic>;
                                      setDialogState(() {
                                        if (p['transaction_reference'] != null) swiftRefController.text = p['transaction_reference'];
                                        if (p['amount'] != null) transferredAmountController.text = p['amount'].toString();
                                        if (p['currency'] != null) currencyController.text = p['currency'];
                                        if (p['value_date'] != null) {
                                          receiptDate = DateTime.tryParse(p['value_date']) ?? receiptDate;
                                        }
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade700,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.paste, color: Colors.white, size: 14),
                                  label: Text(l10n.swiftPasteAndExtractChip, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  onPressed: () async {
                                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                                    if (data != null && data.text != null && data.text!.isNotEmpty) {
                                      final res = await ref.read(paymentRequestsProvider.notifier).smartExtractSwift(
                                        rawText: data.text!,
                                        targetPaymentId: pay.paymentId,
                                      );
                                      if (res['success'] == true && res['parsed_swift'] != null) {
                                        final p = res['parsed_swift'] as Map<String, dynamic>;
                                        setDialogState(() {
                                          if (p['transaction_reference'] != null) swiftRefController.text = p['transaction_reference'];
                                          if (p['amount'] != null) transferredAmountController.text = p['amount'].toString();
                                          if (p['currency'] != null) currencyController.text = p['currency'];
                                          if (p['value_date'] != null) {
                                            receiptDate = DateTime.tryParse(p['value_date']) ?? receiptDate;
                                          }
                                        });
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.cobalt,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.upload_file, color: Colors.white, size: 14),
                                  label: Text(l10n.swiftUploadDocChip, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  onPressed: () async {
                                    final result = await FilePicker.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf', 'docx', 'doc', 'xlsx', 'xls', 'csv', 'jpg', 'jpeg', 'png', 'webp', 'bmp', 'txt'],
                                      withData: true,
                                    );
                                    if (result != null && result.files.isNotEmpty) {
                                      final f = result.files.first;
                                      if (f.bytes != null) {
                                        final res = await ref.read(paymentRequestsProvider.notifier).smartExtractSwiftFromFile(
                                          fileBytes: f.bytes!,
                                          filename: f.name,
                                          targetPaymentId: pay.paymentId,
                                        );
                                        if (res['success'] == true && res['parsed_swift'] != null) {
                                          final p = res['parsed_swift'] as Map<String, dynamic>;
                                          setDialogState(() {
                                            if (p['transaction_reference'] != null) swiftRefController.text = p['transaction_reference'];
                                            if (p['amount'] != null) transferredAmountController.text = p['amount'].toString();
                                            if (p['currency'] != null) currencyController.text = p['currency'];
                                            if (p['value_date'] != null) {
                                              receiptDate = DateTime.tryParse(p['value_date']) ?? receiptDate;
                                            }
                                          });
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Input Fields
                          Row(
                            children: [
                              // SWIFT Receipt Date
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: receiptDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setDialogState(() => receiptDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: l10n.swiftReceiptDateLabel,
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.cobalt),
                                    ),
                                    child: Text(receiptDate.toString().substring(0, 10), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // SWIFT Reference No
                              Expanded(
                                child: TextFormField(
                                  controller: swiftRefController,
                                  decoration: InputDecoration(
                                    labelText: '${l10n.swiftColSwiftRef} *',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.tag, color: AppTheme.cobalt),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      tooltip: l10n.swiftCopyFieldTooltip,
                                      onPressed: () => CopyHelper.copy(context, swiftRefController.text),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.swiftEnterSwiftRefError : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              // Transferred Amount
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: transferredAmountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: '${l10n.swiftTransferredAmountLabel} *',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.attach_money, color: AppTheme.emerald),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      tooltip: l10n.swiftCopyFieldTooltip,
                                      onPressed: () => CopyHelper.copy(context, transferredAmountController.text),
                                    ),
                                  ),
                                  onChanged: (v) => setDialogState(() {}),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return l10n.swiftEnterAmountError;
                                    final num = double.tryParse(v.trim());
                                    if (num == null || num <= 0) return l10n.swiftAmountGreaterThanZeroError;
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Currency
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: currencyController,
                                  decoration: InputDecoration(
                                    labelText: l10n.swiftCurrencyLabel,
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      tooltip: l10n.swiftCopyFieldTooltip,
                                      onPressed: () => CopyHelper.copy(context, currencyController.text),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Reconciliation Live Comparison Box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: varianceColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: varianceColor.withOpacity(0.4), width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(varianceIcon, color: varianceColor, size: 20),
                                    const SizedBox(width: 8),
                                    Text(l10n.swiftMatchingMatrixTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: varianceColor)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.swiftDaysBetweenDates(safeDays),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: safeDays <= 3 ? Colors.green.shade100 : (safeDays <= 7 ? Colors.orange.shade100 : Colors.red.shade100),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        safeDays <= 3
                                            ? l10n.swiftExecutionInstantTag(safeDays)
                                            : (safeDays <= 7 ? l10n.swiftExecutionReasonableTag(safeDays) : l10n.swiftExecutionDelayedTag(safeDays)),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: safeDays <= 3 ? Colors.green.shade800 : (safeDays <= 7 ? Colors.orange.shade900 : Colors.red.shade900),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${l10n.swiftRequestedAmountLabel}: ${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}', style: const TextStyle(fontSize: 12)),
                                    Text('${l10n.swiftTransferredAmountLabel}: ${transferredAmt.toStringAsFixed(2)} ${pay.currencyCode}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: varianceColor)),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(varianceText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: varianceColor)),
                                    if (variance != 0)
                                      Text(
                                        '${l10n.swiftVarianceLabel}: ${variance >= 0 ? "+" : ""}${variance.toStringAsFixed(2)} ${pay.currencyCode}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: varianceColor, fontSize: 13),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Auto-Sync Info Banner
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt, color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.swiftSyncShipmentNotice,
                                    style: const TextStyle(fontSize: 11, color: Colors.brown, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Notes Field
                          TextFormField(
                            controller: notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: l10n.swiftReconciliationNotesLabel,
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: l10n.swiftCopyFieldTooltip,
                                onPressed: () => CopyHelper.copy(context, notesController.text),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(l10n.swiftCancelBtn),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: Text(
                      l10n.swiftSaveAndSyncBtn,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(dialogCtx);

                      setState(() => _isProcessing = true);
                      try {
                        final updated = await ref.read(paymentRequestsProvider.notifier).reconcileSwift(
                          paymentId: pay.paymentId,
                          swiftReferenceNo: swiftRefController.text.trim(),
                          swiftReceiptDate: receiptDate.toString().substring(0, 10),
                          swiftTransferredAmount: transferredAmt,
                          swiftTransferredCurrency: currencyController.text.trim().isNotEmpty ? currencyController.text.trim() : 'USD',
                          swiftReconciliationNotes: notesController.text.trim(),
                        );

                        // Also refresh Import Files provider so swift_no is live immediately
                        ref.read(importFilesProvider.notifier).fetchImportFiles();

                        if (mounted && updated != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.swiftReconcileSuccessSnack(updated.swiftReferenceNo ?? '', updated.paymentCode),
                              ),
                              backgroundColor: AppTheme.emerald,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.swiftReconcileErrorSnack(e.toString())),
                              backgroundColor: AppTheme.crimson,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      swiftRefController.dispose();
      transferredAmountController.dispose();
      currencyController.dispose();
      notesController.dispose();
    });
  }

  void _showSwiftDetailsDialog(PaymentRequestModel pay) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.swiftDetailsDialogTitle(pay.paymentCode), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              _buildVarianceBadge(pay.swiftVarianceStatus, pay.swiftVarianceAmount, pay.currencyCode),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(pay.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal)),
                      ),
                      if (pay.importFileCode != null)
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => CopyHelper.copy(context, pay.importFileCode!),
                          child: Tooltip(
                            message: l10n.swiftCopyFieldTooltip,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppTheme.cobalt, borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(pay.importFileCode!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${l10n.swiftBeneficiaryLabel} ${pay.beneficiaryName ?? pay.supplierName}'),
                  Text('${l10n.swiftBankLabel} ${pay.bankName ?? "-"} | SWIFT: ${pay.swiftCode ?? "-"} | ${l10n.swiftAccountLabel} ${pay.ibanAccountNo ?? "-"}'),
                  const Divider(),
                  Row(
                    children: [
                      _buildStatPill(l10n.swiftRequestDateLabel, pay.requestDate.isNotEmpty ? pay.requestDate : '-', AppTheme.charcoal),
                      const SizedBox(width: 8),
                      _buildStatPill(l10n.swiftColSwiftDate, pay.swiftReceiptDate ?? l10n.swiftBadgePending, AppTheme.cobalt),
                      const SizedBox(width: 8),
                      _buildStatPill(l10n.swiftProcessingTimeLabel, pay.swiftProcessingDays != null ? l10n.swiftDaysCount(pay.swiftProcessingDays) : '-', Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatPill(l10n.swiftRequestedAmountLabel, '${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}', AppTheme.cobalt),
                      const SizedBox(width: 8),
                      _buildStatPill(l10n.swiftTransferredAmountLabel, pay.swiftTransferredAmount != null ? '${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}' : '-', AppTheme.emerald),
                      const SizedBox(width: 8),
                      _buildStatPill(l10n.swiftVarianceLabel, pay.swiftVarianceAmount != null ? '${pay.swiftVarianceAmount!.toStringAsFixed(2)} ${pay.currencyCode}' : '-', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tag, color: AppTheme.cobalt, size: 18),
                            const SizedBox(width: 6),
                            Text('${l10n.swiftColSwiftRef}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(pay.swiftReferenceNo ?? l10n.swiftStatusUnregistered, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 14)),
                                  if (pay.swiftReferenceNo != null && pay.swiftReferenceNo!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => CopyHelper.copy(context, pay.swiftReferenceNo!),
                                      child: Tooltip(
                                        message: l10n.swiftCopyFieldTooltip,
                                        child: const Icon(Icons.copy_rounded, size: 15, color: AppTheme.cobalt),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (pay.swiftReconciliationNotes != null && pay.swiftReconciliationNotes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('${l10n.swiftReconciliationNotesLabel}: ${pay.swiftReconciliationNotes}'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.swiftCloseBtn)),
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, color: AppTheme.crimson, size: 16),
              label: Text(l10n.swiftPrintSlipBtn),
              onPressed: () {
                FinancialExportService.printOrSaveSwiftSlipPdf(context: context, payment: pay);
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
              label: Text(l10n.swiftCopySummaryBtn),
              onPressed: () => _copyPaymentDossier(pay),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
              icon: const Icon(Icons.edit, color: Colors.white, size: 16),
              label: Text(l10n.swiftEditBtn, style: const TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.pop(ctx);
                _showSwiftReconciliationDialog(pay);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildVarianceBadge(String? status, double? variance, String currency) {
    final l10n = context.l10n;
    if (status == 'Matched' || (variance != null && variance.abs() < 0.001)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 14),
            const SizedBox(width: 4),
            Text(l10n.swiftBadgeMatchedFull, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      );
    } else if (status == 'Deficit' || (variance != null && variance < 0)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_downward, color: Colors.red, size: 14),
            const SizedBox(width: 4),
            Text(l10n.swiftBadgeDeficit(variance?.abs().toStringAsFixed(2) ?? '0.00', currency), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      );
    } else if (status == 'Surplus' || (variance != null && variance > 0)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_upward, color: Colors.orange, size: 14),
            const SizedBox(width: 4),
            Text(l10n.swiftBadgeSurplus(variance?.toStringAsFixed(2) ?? '0.00', currency), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
        child: Text(l10n.swiftBadgePending, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
      );
    }
  }

  Widget _buildInfoField(String label, String value, Color color, {bool isBold = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
                  Icon(Icons.copy_rounded, size: 12, color: color.withOpacity(0.7)),
                ],
              ),
            ),
          ],
        ),
      ),
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
    } else if (_matchedPayment != null && _matchedPayment!['payment_id'] != null) {
      matchedPay = paymentsList.firstWhere(
        (p) => p.paymentId == _matchedPayment!['payment_id'],
        orElse: () => paymentsList.first,
      );
    }

    if (matchedPay == null) {
      return Center(child: Text(l10n.swiftNoMatchingRecords));
    }
    final targetPay = matchedPay;

    final score = _matchedPayment?['confidence_score'] ?? 100;
    final amtInfo = _matchedPayment?['amount_matching'] as Map<String, dynamic>?;
    final isAmtMatched = amtInfo?['is_matched'] ?? true;
    final variance = (amtInfo?['variance'] as num?)?.toDouble() ?? 0.0;

    final benInfo = _matchedPayment?['beneficiary_matching'] as Map<String, dynamic>?;
    final isBenMatched = benInfo?['is_matched'] ?? true;

    final bankInfo = _matchedPayment?['bank_swift_matching'] as Map<String, dynamic>?;
    final isSwiftMatched = bankInfo?['is_matched'] ?? (matchedPay.swiftCode == null || matchedPay.swiftCode == _extractedSwift!['beneficiary_bank_swift']);
    final matchedBankType = bankInfo?['matched_bank_type'] as String?;

    final accInfo = _matchedPayment?['account_iban_matching'] as Map<String, dynamic>?;
    final isAccMatched = accInfo?['is_matched'] ?? true;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final mismatchLabel = isAr ? 'غير متطابق' : 'Mismatch';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows, color: AppTheme.emerald, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.swiftMatchingMatrixTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: score >= 80 ? Colors.green.shade100 : (score >= 50 ? Colors.orange.shade100 : Colors.red.shade100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: score >= 80 ? Colors.green : Colors.orange),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(score >= 80 ? Icons.check_circle : Icons.warning_amber, size: 13, color: score >= 80 ? Colors.green : Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    l10n.swiftConfidenceScoreTag(score),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: score >= 80 ? Colors.green.shade800 : Colors.orange.shade900,
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
            final isArLocale = Localizations.localeOf(context).languageCode == 'ar';
            final shipName = DisplayNameResolver.resolveShipmentNameByCode(p.importFileCode, shipments: allFiles, isArabic: isArLocale);
            final shipBadge = (shipName.isNotEmpty && shipName != '-') ? ' [$shipName]' : '';
            return SearchableDropdownItem<int>(
              value: p.paymentId,
              label: '${p.paymentCode}$shipBadge - ${p.supplierName} (${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}) [${p.status}]',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildCompareRow(
                '${l10n.swiftRequestedAmountLabel}:',
                '${matchedPay.requestedAmount.toStringAsFixed(2)} ${matchedPay.currencyCode}',
                '${_extractedSwift!['amount']} ${_extractedSwift!['currency']}',
                isAmtMatched,
                isAmtMatched
                    ? (variance == 0.0 ? l10n.swiftBadgeMatchedFull : l10n.swiftBadgeDeficit(variance.abs().toStringAsFixed(2), matchedPay.currencyCode))
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
                isAr ? 'سويفت المستفيد (:57A):' : 'Beneficiary SWIFT (:57A):',
                matchedPay.swiftCode ?? '-',
                _extractedSwift!['beneficiary_bank_swift'] ?? '-',
                isSwiftMatched && matchedBankType != 'SENDER_BANK',
                (isSwiftMatched && matchedBankType != 'SENDER_BANK')
                    ? l10n.swiftBadgeMatchedFull
                    : (matchedBankType == 'SENDER_BANK'
                        ? (isAr ? 'طابق بنك التحويل' : 'Matched Sender Bank')
                        : mismatchLabel),
                customBadgeBg: matchedBankType == 'SENDER_BANK' ? Colors.amber.shade50 : null,
                customBadgeBorder: matchedBankType == 'SENDER_BANK' ? Colors.amber.shade300 : null,
                customBadgeText: matchedBankType == 'SENDER_BANK' ? Colors.amber.shade900 : null,
                trailingAction: (matchedPay.swiftCode != _extractedSwift!['beneficiary_bank_swift'] &&
                        _extractedSwift!['beneficiary_bank_swift'] != null &&
                        _extractedSwift!['beneficiary_bank_swift'].toString().isNotEmpty)
                    ? InkWell(
                        onTap: () async {
                          final newSwift = _extractedSwift!['beneficiary_bank_swift'].toString();
                          try {
                            await ref.read(paymentRequestsProvider.notifier).updatePaymentRequest(
                              targetPay.paymentId,
                              {'swift_code': newSwift},
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isAr
                                      ? 'تم تحديث سويفت طلب السداد إلى $newSwift بنجاح!'
                                      : 'Payment Request SWIFT updated to $newSwift successfully!'),
                                  backgroundColor: AppTheme.emerald,
                                ),
                              );
                              _runSmartSwiftExtraction(targetPaymentId: targetPay.paymentId);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isAr ? 'فشل التحديث: $e' : 'Update failed: $e'),
                                  backgroundColor: AppTheme.crimson,
                                ),
                              );
                            }
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_fix_high, size: 13, color: AppTheme.cobalt),
                            const SizedBox(width: 4),
                            Text(
                              isAr
                                  ? 'تحديث سويفت طلب السداد إلى ${_extractedSwift!['beneficiary_bank_swift']} (انقر هنا)'
                                  : 'Update Payment SWIFT to ${_extractedSwift!['beneficiary_bank_swift']}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.cobalt,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
              if (_extractedSwift!['sender_bank_swift'] != null &&
                  _extractedSwift!['sender_bank_swift'].toString().isNotEmpty) ...[
                const Divider(height: 12),
                _buildCompareRow(
                  isAr ? 'بنك التحويل (مصر):' : 'Remitting Bank (EG):',
                  _extractedSwift!['sender_bank_name'] ?? (isAr ? 'بنك التحويل في مصر' : 'Remitting Bank in Egypt'),
                  _extractedSwift!['sender_bank_swift'],
                  true,
                  isAr ? 'البنك المنفذ' : 'Issuing Bank',
                  customBadgeBg: Colors.blue.shade50,
                  customBadgeBorder: Colors.blue.shade200,
                  customBadgeText: Colors.blue.shade800,
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
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isSmartReconciling
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.verified, color: Colors.white, size: 20),
            label: Text(
              l10n.swiftExecuteReconcileBtn,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _isSmartReconciling ? null : () => _executeSmartReconciliation(matchedPay!),
          ),
        ),
      ],
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
            SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            Expanded(
              child: InkWell(
                onTap: () => CopyHelper.copy(context, sysVal),
                child: Text(
                  sysVal,
                  style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Icon(Icons.arrow_right_alt, color: Colors.grey, size: 16),
            Expanded(
              child: InkWell(
                onTap: () => CopyHelper.copy(context, swiftVal),
                child: Text(
                  swiftVal,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMatch ? AppTheme.emerald : (customBadgeText ?? AppTheme.crimson),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: customBadgeBg ?? (isMatch ? Colors.green.shade50 : Colors.red.shade50),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: customBadgeBorder ?? (isMatch ? Colors.green.shade200 : Colors.red.shade200)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: customBadgeText ?? (isMatch ? Colors.green.shade800 : Colors.red.shade800),
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

  Widget _buildSmartSwiftSection(List<PaymentRequestModel> paymentsList) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cobalt.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cobalt.withOpacity(0.06),
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
                colors: [AppTheme.charcoal, AppTheme.cobalt.withOpacity(0.9)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.swiftExtractorHeader,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.description, size: 16),
                  label: Text(
                    l10n.swiftLoadSampleBtn,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    _rawSwiftTextController.text = kSampleSwiftMT103;
                    _runSmartSwiftExtraction();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _isSmartSectionExpanded ? l10n.swiftCollapseToolTooltip : l10n.swiftExpandToolTooltip,
                  icon: Icon(
                    _isSmartSectionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _isSmartSectionExpanded = !_isSmartSectionExpanded),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _uploadedFileName!.toLowerCase().endsWith('.pdf')
                                ? Icons.picture_as_pdf
                                : (_uploadedFileName!.toLowerCase().endsWith('.docx') || _uploadedFileName!.toLowerCase().endsWith('.doc')
                                    ? Icons.description
                                    : (_uploadedFileName!.toLowerCase().endsWith('.xlsx') || _uploadedFileName!.toLowerCase().endsWith('.xls') || _uploadedFileName!.toLowerCase().endsWith('.csv')
                                        ? Icons.table_chart
                                        : Icons.image)),
                            color: Colors.purple.shade700,
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
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade900),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _uploadedFileName!,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade800),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${l10n.swiftDocTypePrefix} ${_detectedFileType ?? l10n.swiftDocumentDefaultType} ${_uploadedFileSize != null ? "• ${l10n.swiftDocSizePrefix} ${(_uploadedFileSize! / 1024).toStringAsFixed(1)} KB" : ""}',
                                  style: TextStyle(fontSize: 11, color: Colors.purple.shade700),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purple.shade800,
                              side: BorderSide(color: Colors.purple.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.refresh, size: 14),
                            label: Text(l10n.swiftUploadFileBtn, style: const TextStyle(fontSize: 11)),
                            onPressed: () => _pickAndExtractFile(),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.purple),
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
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          decoration: InputDecoration(
                            hintText: l10n.swiftRawTextPlaceholder,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(12),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: l10n.swiftCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(context, _rawSwiftTextController.text),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isExtracting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.upload_file, color: Colors.white, size: 18),
                            label: Text(
                              l10n.swiftUploadFileBtn,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            onPressed: _isExtracting ? null : () => _pickAndExtractFile(),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cobalt,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isExtracting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.bolt, color: Colors.white, size: 18),
                            label: Text(
                              l10n.swiftExtractFromTextBtn,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: _isExtracting ? null : () => _runSmartSwiftExtraction(),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.paste, size: 14),
                                label: Text(l10n.swiftPasteAndExtractChip, style: const TextStyle(fontSize: 11)),
                                onPressed: () async {
                                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                                  if (data != null && data.text != null && data.text!.isNotEmpty) {
                                    _rawSwiftTextController.text = data.text!;
                                    _runSmartSwiftExtraction();
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                icon: const Icon(Icons.clear, size: 14, color: Colors.grey),
                                label: Text(l10n.swiftCancelBtn, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                              ),
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
                                targetPaymentId: _selectedPaymentIdForReconcile,
                              );
                          if (mounted && matchRes['success'] == true) {
                            setState(() {
                              _matchedPayment = matchRes['matched_payment_request'] as Map<String, dynamic>?;
                              if (_matchedPayment != null && _matchedPayment!['payment_id'] != null) {
                                _selectedPaymentIdForReconcile = _matchedPayment!['payment_id'] as int;
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
                        color: Colors.green.shade50.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.emerald, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_open, color: AppTheme.emerald, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'مصفوفة المطابقة المالية المعتمدة (Matching Matrix)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.charcoal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'البيانات مدققة ومؤكدة بشرياً',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildMatchingMatrixBox(paymentsList),
                        ],
                      ),
                    ),
                  ] else if (_currentBatch == null && _extractedSwift != null) ...[
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
                              color: Colors.blue.shade50.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.account_balance, color: AppTheme.cobalt, size: 18),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              l10n.swiftExtractorHeader,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: AppTheme.cobalt, borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          'Ref: ${_extractedSwift!['transaction_reference'] ?? l10n.swiftStatusUnregistered}',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                                    _buildInfoField(l10n.swiftColTransferredAmount, '${_extractedSwift!['amount']} ${_extractedSwift!['currency']}', AppTheme.emerald, isBold: true),
                                    const SizedBox(width: 8),
                                    _buildInfoField(l10n.swiftColSwiftDate, _extractedSwift!['value_date_formatted'] ?? _extractedSwift!['value_date'] ?? '-', AppTheme.charcoal),
                                    const SizedBox(width: 8),
                                    _buildInfoField(l10n.swiftChargesLabel, _extractedSwift!['charge_details'] ?? 'SHA', Colors.teal),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('${l10n.swiftExtractedReceiverPrefix.replaceAll(':', '')}: ${_extractedSwift!['beneficiary_name'] ?? "-"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(child: Text('${l10n.swiftCodeLabel.replaceAll(':', '')}: ${_extractedSwift!['beneficiary_bank_swift'] ?? "-"}', style: const TextStyle(fontSize: 11))),
                                    Expanded(child: Text('${l10n.swiftAccountLabel.replaceAll(':', '')}: ${_extractedSwift!['beneficiary_account_or_iban'] ?? "-"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('${l10n.swiftExtractedSenderPrefix.replaceAll(':', '')}: ${_extractedSwift!['ordering_customer_name'] ?? "-"} (${_extractedSwift!['ordering_account_or_iban'] ?? "-"})', style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                                if (_extractedSwift!['pi_number'] != null || _extractedSwift!['payment_details'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text('${l10n.swiftRequestTitleLabel} ${_extractedSwift!['pi_number'] ?? _extractedSwift!['payment_details']}', style: const TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.w600)),
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
                              color: Colors.green.shade50.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: _buildMatchingMatrixBox(paymentsList),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paymentsState = ref.watch(paymentRequestsProvider);
    final paymentsList = paymentsState.valueOrNull ?? [];

    // Filter payments
    final filtered = paymentsList.where((pay) {
      if (!pay.isActive) return false;
      final q = _searchController.text.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          pay.paymentCode.toLowerCase().contains(q) ||
          pay.title.toLowerCase().contains(q) ||
          pay.supplierName.toLowerCase().contains(q) ||
          (pay.importFileCode != null && pay.importFileCode!.toLowerCase().contains(q)) ||
          (pay.swiftReferenceNo != null && pay.swiftReferenceNo!.toLowerCase().contains(q));

      if (!matchQuery) return false;

      if (_selectedStatusFilter == 'PENDING') {
        return pay.swiftReferenceNo == null || pay.swiftReferenceNo!.isEmpty;
      } else if (_selectedStatusFilter == 'MATCHED') {
        return pay.swiftVarianceStatus == 'Matched';
      } else if (_selectedStatusFilter == 'DEFICIT') {
        return pay.swiftVarianceStatus == 'Deficit';
      } else if (_selectedStatusFilter == 'SURPLUS') {
        return pay.swiftVarianceStatus == 'Surplus';
      }
      return true;
    }).toList();

    // Calculate metrics
    final totalRequests = paymentsList.where((p) => p.isActive).length;
    final pendingSwift = paymentsList.where((p) => p.isActive && (p.swiftReferenceNo == null || p.swiftReferenceNo!.isEmpty)).length;
    final matchedSwift = paymentsList.where((p) => p.isActive && p.swiftVarianceStatus == 'Matched').length;
    final discrepancySwift = paymentsList.where((p) => p.isActive && (p.swiftVarianceStatus == 'Deficit' || p.swiftVarianceStatus == 'Surplus')).length;

    final reconciledItems = paymentsList.where((p) => p.isActive && p.swiftProcessingDays != null).toList();
    final avgDays = reconciledItems.isNotEmpty
        ? (reconciledItems.map((p) => p.swiftProcessingDays!).reduce((a, b) => a + b) / reconciledItems.length).toStringAsFixed(1)
        : '0.0';

    final content = SelectionArea(
      child: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Metric Cards
                  Row(
                    children: [
                      _buildKPICard(l10n.swiftTotalRequestsMetric, totalRequests.toString(), Icons.receipt_long, AppTheme.cobalt),
                      const SizedBox(width: 12),
                      _buildKPICard(l10n.swiftPendingSwiftMetric, pendingSwift.toString(), Icons.hourglass_top, Colors.orange),
                      const SizedBox(width: 12),
                      _buildKPICard(l10n.swiftMatchedSwiftMetric, matchedSwift.toString(), Icons.check_circle_outline, AppTheme.emerald),
                      const SizedBox(width: 12),
                      _buildKPICard(l10n.swiftVariancesMetric, discrepancySwift.toString(), Icons.compare_arrows, AppTheme.crimson),
                      const SizedBox(width: 12),
                      _buildKPICard(l10n.swiftAvgProcessingTimeMetric, l10n.swiftDaysCount(avgDays), Icons.speed, Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Smart AI SWIFT MT103 Extractor & Auto-Reconciler Tool
                  _buildSmartSwiftSection(paymentsList),
                  const SizedBox(height: 16),

                  // Filter & Search Toolbar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, val, child) {
                              return TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: l10n.swiftSearchPlaceholder,
                                  prefixIcon: const Icon(Icons.search, color: AppTheme.cobalt),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (val.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                                        tooltip: l10n.swiftCopyBtn,
                                        onPressed: () => CopyHelper.copy(context, _searchController.text),
                                      ),
                                    ],
                                  ),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) => setState(() {}),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Filter Chips
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip(l10n.swiftFilterAll(totalRequests), 'ALL'),
                            _buildFilterChip(l10n.swiftFilterPending(pendingSwift), 'PENDING'),
                            _buildFilterChip(l10n.swiftFilterMatched(matchedSwift), 'MATCHED'),
                            _buildFilterChip(l10n.swiftFilterVariances(discrepancySwift), 'DEFICIT'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Table of Payment Requests & SWIFTs
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.table_chart, color: AppTheme.charcoal, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.swiftTableTitle(filtered.length),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 16),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt, color: Colors.orange, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.swiftAutoSyncNotice,
                                        style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.cobalt,
                                      side: const BorderSide(color: AppTheme.cobalt),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.table_view, size: 16),
                                    label: Text(l10n.swiftExportTsvBtn, style: const TextStyle(fontSize: 12)),
                                    onPressed: filtered.isEmpty ? null : () => _exportTsv(filtered),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.emerald,
                                      side: const BorderSide(color: AppTheme.emerald),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.file_download, size: 16),
                                    label: Text(l10n.swiftExportExcelBtn, style: const TextStyle(fontSize: 12)),
                                    onPressed: filtered.isEmpty
                                        ? null
                                        : () => FinancialExportService.exportSwiftReconciliationToExcel(
                                              context: context,
                                              payments: filtered,
                                            ),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.charcoal,
                                      side: const BorderSide(color: Colors.grey),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.copy_all, size: 16),
                                    label: Text(l10n.swiftCopySummaryBtn, style: const TextStyle(fontSize: 12)),
                                    onPressed: filtered.isEmpty ? null : () => _copyFilteredSummary(filtered),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                l10n.swiftNoMatchingPayments,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                              columns: [
                                DataColumn(label: Text(l10n.swiftColActions, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.swiftColPaymentCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.swiftColBeneficiaryBank, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.swiftColRequestDate, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.swiftColSwiftDate, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.swiftColProcessingTime, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.swiftColRequestedAmount, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.swiftColTransferredAmount, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.swiftColVarianceStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.swiftColSwiftRef, style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filtered.map((pay) {
                                final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
                                final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                final isReconciled = pay.swiftReferenceNo != null && pay.swiftReferenceNo!.isNotEmpty;
                                final shipName = DisplayNameResolver.resolveShipmentNameByCode(pay.importFileCode, shipments: allFiles, isArabic: isAr);
                                final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(pay.importFileCode, shipments: allFiles, isArabic: isAr);
                                final rowSummary = '${pay.paymentCode} | $shipTitle | ${pay.beneficiaryName ?? pay.supplierName} | ${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode} | ${pay.swiftReferenceNo ?? l10n.swiftPendingSwiftBadge}';
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isReconciled ? AppTheme.cobalt : AppTheme.emerald,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                            icon: Icon(isReconciled ? Icons.edit : Icons.account_balance, color: Colors.white, size: 14),
                                            label: Text(
                                              isReconciled ? l10n.swiftEditBtn : l10n.swiftRegisterBtn,
                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () => _showSwiftReconciliationDialog(pay),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.visibility, color: AppTheme.charcoal, size: 18),
                                            tooltip: l10n.swiftDetailsBtn,
                                            onPressed: () => _showSwiftDetailsDialog(pay),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, color: AppTheme.cobalt, size: 16),
                                            tooltip: l10n.swiftCopyDossierBtn,
                                            onPressed: () => _copyPaymentDossier(pay),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      CopyableTableCell(
                                        value: '${pay.paymentCode}${pay.importFileCode != null ? " / $shipTitle" : ""}',
                                        rowSummary: rowSummary,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(pay.paymentCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                                const SizedBox(width: 4),
                                                _buildCopyBadge(pay.paymentCode, tooltip: l10n.swiftCopyBtn),
                                              ],
                                            ),
                                            if (pay.importFileCode != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      shipName,
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.charcoal.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        pay.importFileCode!,
                                                        style: TextStyle(fontSize: 9, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    _buildCopyBadge(pay.importFileCode!, tooltip: l10n.swiftCopyBtn),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      CopyableTableCell(
                                        value: '${pay.beneficiaryName ?? pay.supplierName} - ${pay.bankName ?? l10n.swiftUnspecifiedBank}',
                                        rowSummary: rowSummary,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(pay.beneficiaryName ?? pay.supplierName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                            Text(pay.bankName ?? l10n.swiftUnspecifiedBank, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      CopyableTableCell(
                                        value: pay.requestDate.isNotEmpty ? pay.requestDate : '-',
                                        rowSummary: rowSummary,
                                        child: Text(pay.requestDate.isNotEmpty ? pay.requestDate : '-'),
                                      ),
                                    ),
                                    DataCell(
                                      CopyableTableCell(
                                        value: pay.swiftReceiptDate ?? l10n.swiftPendingSwiftBadge,
                                        rowSummary: rowSummary,
                                        child: Text(
                                          pay.swiftReceiptDate ?? l10n.swiftPendingSwiftBadge,
                                          style: TextStyle(
                                            fontWeight: isReconciled ? FontWeight.bold : FontWeight.normal,
                                            color: isReconciled ? AppTheme.charcoal : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      CopyableTableCell(
                                        value: pay.swiftProcessingDays != null ? l10n.swiftDaysCount(pay.swiftProcessingDays.toString()) : l10n.swiftProcessingPending,
                                        rowSummary: rowSummary,
                                        child: pay.swiftProcessingDays != null
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: pay.swiftProcessingDays! <= 3
                                                      ? Colors.green.shade50
                                                      : (pay.swiftProcessingDays! <= 7 ? Colors.orange.shade50 : Colors.red.shade50),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: pay.swiftProcessingDays! <= 3
                                                        ? Colors.green.shade300
                                                        : (pay.swiftProcessingDays! <= 7 ? Colors.orange.shade300 : Colors.red.shade300),
                                                  ),
                                                ),
                                                child: Text(
                                                  '⚡ ${l10n.swiftDaysCount(pay.swiftProcessingDays.toString())}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: pay.swiftProcessingDays! <= 3
                                                        ? Colors.green.shade800
                                                        : (pay.swiftProcessingDays! <= 7 ? Colors.orange.shade900 : Colors.red.shade900),
                                                  ),
                                                ),
                                              )
                                            : Text(l10n.swiftProcessingPending, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      ),
                                    ),
                                    DataCell(
                                      CopyableTableCell(
                                        value: '${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}',
                                        rowSummary: rowSummary,
                                        child: Text('${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    DataCell(
                                      CopyableTableCell(
                                        value: pay.swiftTransferredAmount != null
                                            ? '${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}'
                                            : '-',
                                        rowSummary: rowSummary,
                                        child: pay.swiftTransferredAmount != null
                                            ? Text(
                                                '${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                              )
                                            : const Text('-', style: TextStyle(color: Colors.grey)),
                                      ),
                                    ),
                                    DataCell(
                                      CopyableTableCell(
                                        value: '${pay.swiftVarianceStatus ?? "-"} ${pay.swiftVarianceAmount != null ? pay.swiftVarianceAmount!.toStringAsFixed(2) : ""}',
                                        rowSummary: rowSummary,
                                        child: _buildVarianceBadge(pay.swiftVarianceStatus, pay.swiftVarianceAmount, pay.currencyCode),
                                      ),
                                    ),
                                    DataCell(
                                      CopyableTableCell(
                                        value: pay.swiftReferenceNo ?? l10n.swiftUnregistered,
                                        rowSummary: rowSummary,
                                        child: pay.swiftReferenceNo != null && pay.swiftReferenceNo!.isNotEmpty
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)),
                                                    child: Text(pay.swiftReferenceNo!, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 11)),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  _buildCopyBadge(pay.swiftReferenceNo!, tooltip: l10n.swiftCopyBtn),
                                                ],
                                              )
                                            : Text(l10n.swiftUnregistered, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );

    if (widget.isEmbedded) {
      return Container(
        color: Colors.grey.shade100,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppTheme.charcoal,
        title: Row(
          children: [
            const Icon(Icons.account_balance, color: AppTheme.cobalt),
            const SizedBox(width: 10),
            Text(
              l10n.swiftScreenTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.swiftRefreshBtn,
            onPressed: () {
              ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
              ref.read(importFilesProvider.notifier).fetchImportFiles();
            },
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppTheme.charcoal)),
      selected: isSelected,
      selectedColor: AppTheme.cobalt,
      backgroundColor: Colors.grey.shade100,
      onSelected: (selected) {
        if (selected) setState(() => _selectedStatusFilter = value);
      },
    );
  }

  Widget _buildCopyBadge(String text, {String? tooltip}) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => CopyHelper.copy(context, text),
      child: Tooltip(
        message: tooltip ?? context.l10n.swiftCopyBtn,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withOpacity(0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
        ),
      ),
    );
  }
}
