import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../swift_extraction_review_widget.dart';
import 'swift_extracted_details_card.dart';
import 'swift_header_bar.dart';
import 'swift_input_section.dart';
import 'swift_matching_matrix_box.dart';
import 'swift_reconciliation_common.dart';
import 'swift_upload_service.dart';

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
  ConsumerState<SwiftUploadStepCard> createState() => _SwiftUploadStepCardState();
}

class _SwiftUploadStepCardState extends ConsumerState<SwiftUploadStepCard> {
  final TextEditingController _rawSwiftTextController = TextEditingController();

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

  void _applyExtractionResult(SwiftExtractionResult res) {
    setState(() {
      _extractedSwift = res.extractedSwift;
      _matchedPayment = res.matchedPayment;
      if (res.detectedFileType != null) _detectedFileType = res.detectedFileType;
      if (res.currentBatch != null) {
        _currentBatch = res.currentBatch;
        _isMatchingUnlocked = res.isMatchingUnlocked;
      }
      if (res.rawText != null && res.rawText!.isNotEmpty) {
        _rawSwiftTextController.text = res.rawText!;
      }
      if (res.selectedPaymentId != null) {
        _selectedPaymentIdForReconcile = res.selectedPaymentId;
      }
    });
  }

  Future<void> _pickAndExtractFile({int? targetPaymentId}) async {
    setState(() => _isExtracting = true);
    final res = await SwiftUploadService.pickAndExtractFile(
      context: context,
      ref: ref,
      l10n: context.l10n,
      targetPaymentId: targetPaymentId,
      onFilePicked: (filename, size) {
        setState(() {
          _uploadedFileName = filename;
          _uploadedFileSize = size;
        });
      },
    );
    if (mounted) {
      setState(() => _isExtracting = false);
      if (res != null) _applyExtractionResult(res);
    }
  }

  Future<void> _runSmartSwiftExtraction({int? targetPaymentId}) async {
    setState(() => _isExtracting = true);
    final res = await SwiftUploadService.runSmartSwiftExtraction(
      context: context,
      ref: ref,
      l10n: context.l10n,
      rawText: _rawSwiftTextController.text,
      targetPaymentId: targetPaymentId,
    );
    if (mounted) {
      setState(() => _isExtracting = false);
      if (res != null) _applyExtractionResult(res);
    }
  }

  Future<void> _executeSmartReconciliation(PaymentRequestModel pay) async {
    if (_extractedSwift == null) return;
    setState(() => _isSmartReconciling = true);
    await SwiftUploadService.executeSmartReconciliation(
      context: context,
      ref: ref,
      l10n: context.l10n,
      pay: pay,
      extractedSwift: _extractedSwift!,
      currentBatch: _currentBatch,
      rawText: _rawSwiftTextController.text,
      onReconciliationCompleted: () => widget.onReconciliationCompleted?.call(),
    );
    if (mounted) setState(() => _isSmartReconciling = false);
  }

  @override
  Widget build(BuildContext context) {
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
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwiftHeaderBar(
              isSmartSectionExpanded: _isSmartSectionExpanded,
              onLoadSample: () {
                _rawSwiftTextController.text = kSampleSwiftMT103;
                _runSmartSwiftExtraction();
              },
              onToggleExpanded: () => setState(
                () => _isSmartSectionExpanded = !_isSmartSectionExpanded,
              ),
            ),
            if (_isSmartSectionExpanded)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwiftInputSection(
                      rawSwiftTextController: _rawSwiftTextController,
                      uploadedFileName: _uploadedFileName,
                      detectedFileType: _detectedFileType,
                      uploadedFileSize: _uploadedFileSize,
                      isExtracting: _isExtracting,
                      onPickAndExtractFile: _pickAndExtractFile,
                      onRunSmartSwiftExtraction: _runSmartSwiftExtraction,
                      onClear: () {
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
                      onDismissUploadedFile: () {
                        setState(() {
                          _uploadedFileName = null;
                          _detectedFileType = null;
                          _uploadedFileSize = null;
                        });
                      },
                    ),
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
                                _matchedPayment =
                                    matchRes['matched_payment_request'] as Map<String, dynamic>?;
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
                                const Icon(Icons.lock_open, color: AppTheme.emerald, size: 20),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                            SwiftMatchingMatrixBox(
                              paymentsList: widget.paymentsList,
                              selectedPaymentIdForReconcile: _selectedPaymentIdForReconcile,
                              extractedSwift: _extractedSwift,
                              matchedPayment: _matchedPayment,
                              isSmartReconciling: _isSmartReconciling,
                              onPaymentSelected: (val) {
                                setState(() => _selectedPaymentIdForReconcile = val);
                                _runSmartSwiftExtraction(targetPaymentId: val);
                              },
                              onExecuteReconcile: _executeSmartReconciliation,
                            ),
                          ],
                        ),
                      ),
                    ] else if (_currentBatch == null && _extractedSwift != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: SwiftExtractedDetailsCard(extractedSwift: _extractedSwift!),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 6,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldLight.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.emeraldBorder),
                              ),
                              child: SwiftMatchingMatrixBox(
                                paymentsList: widget.paymentsList,
                                selectedPaymentIdForReconcile: _selectedPaymentIdForReconcile,
                                extractedSwift: _extractedSwift,
                                matchedPayment: _matchedPayment,
                                isSmartReconciling: _isSmartReconciling,
                                onPaymentSelected: (val) {
                                  setState(() => _selectedPaymentIdForReconcile = val);
                                  _runSmartSwiftExtraction(targetPaymentId: val);
                                },
                                onExecuteReconcile: _executeSmartReconciliation,
                              ),
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
