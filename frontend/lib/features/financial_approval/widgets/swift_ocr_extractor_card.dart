import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/financial_approval_model.dart';
import 'swift_extraction_review_widget.dart';
import 'swift_ocr/swift_ocr_autofill_summary.dart';
import 'swift_ocr/swift_ocr_file_banner.dart';
import 'swift_ocr/swift_ocr_header.dart';
import 'swift_ocr/swift_ocr_input_section.dart';
import 'swift_ocr/swift_ocr_legacy_extracted_view.dart';

/// Smart AI SWIFT MT103 Extractor & OCR Card
///
/// Reusable enterprise card for extracting and reconciling SWIFT MT103 data
/// via OCR file uploads (PDF, DOCX, images) or raw text parsing.
class SwiftOcrExtractorCard extends StatelessWidget {
  final TextEditingController rawSwiftTextController;
  final bool isSmartSectionExpanded;
  final VoidCallback onToggleExpanded;
  final String? uploadedFileName;
  final String? detectedFileType;
  final int? uploadedFileSize;
  final VoidCallback? onClearUploadedFile;
  final bool isExtracting;
  final VoidCallback onPickAndExtractFile;
  final VoidCallback onExtractFromText;
  final VoidCallback? onPasteAndExtract;
  final VoidCallback? onLoadSample;
  final VoidCallback? onReset;

  // Batch Review & Matching Matrix Integration
  final SwiftBatchModel? currentBatch;
  final bool isMatchingUnlocked;
  final Map<String, dynamic>? extractedSwift;
  final Widget? matchingMatrixChild;
  final ValueChanged<SwiftBatchModel>? onBatchConfirmed;
  final VoidCallback? onBatchCancel;

  // Auto-fill mode (for Payment Request form)
  final bool isAutoFillMode;
  final Map<String, dynamic>? autoFillSummary;

  const SwiftOcrExtractorCard({
    super.key,
    required this.rawSwiftTextController,
    required this.isSmartSectionExpanded,
    required this.onToggleExpanded,
    this.uploadedFileName,
    this.detectedFileType,
    this.uploadedFileSize,
    this.onClearUploadedFile,
    this.isExtracting = false,
    required this.onPickAndExtractFile,
    required this.onExtractFromText,
    this.onPasteAndExtract,
    this.onLoadSample,
    this.onReset,
    this.currentBatch,
    this.isMatchingUnlocked = false,
    this.extractedSwift,
    this.matchingMatrixChild,
    this.onBatchConfirmed,
    this.onBatchCancel,
    this.isAutoFillMode = false,
    this.autoFillSummary,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? AppTheme.darkBorder
                : AppTheme.cobalt.withValues(alpha: 0.3),
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
            SwiftOcrHeader(
              isAutoFillMode: isAutoFillMode,
              isSmartSectionExpanded: isSmartSectionExpanded,
              onToggleExpanded: onToggleExpanded,
              onLoadSample: onLoadSample,
            ),

            if (isSmartSectionExpanded)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Uploaded File Info Banner (if any)
                    if (uploadedFileName != null)
                      SwiftOcrFileBanner(
                        uploadedFileName: uploadedFileName!,
                        detectedFileType: detectedFileType,
                        uploadedFileSize: uploadedFileSize,
                        onPickAndExtractFile: onPickAndExtractFile,
                        onClearUploadedFile: onClearUploadedFile,
                      ),

                    // Text Area + Action Buttons
                    SwiftOcrInputSection(
                      rawSwiftTextController: rawSwiftTextController,
                      isExtracting: isExtracting,
                      isDark: isDark,
                      onPickAndExtractFile: onPickAndExtractFile,
                      onExtractFromText: onExtractFromText,
                      onPasteAndExtract: onPasteAndExtract,
                      onReset: onReset,
                    ),

                    // Auto-fill extracted badges (if present in auto-fill mode)
                    if (isAutoFillMode && autoFillSummary != null) ...[
                      const SizedBox(height: 12),
                      SwiftOcrAutofillSummary(
                        autoFillSummary: autoFillSummary!,
                        isDark: isDark,
                      ),
                    ],

                    // 1. SWIFT Extraction Review Layer (Mandatory Human Review)
                    if (currentBatch != null) ...[
                      const SizedBox(height: 16),
                      SwiftExtractionReviewWidget(
                        initialBatch: currentBatch!,
                        onBatchConfirmed: onBatchConfirmed ?? (_) {},
                        onCancel: onBatchCancel ?? () {},
                      ),
                    ],

                    // 2. Matching Matrix Box (Only unlocked after user confirms the review)
                    if (isMatchingUnlocked &&
                        currentBatch != null &&
                        matchingMatrixChild != null) ...[
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
                                  l10n.faApprovedMatchingMatrix,
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
                                    l10n.faDataHumanVerified,
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
                            matchingMatrixChild!,
                          ],
                        ),
                      ),
                    ] else if (currentBatch == null &&
                        extractedSwift != null) ...[
                      // Legacy fallback if no batch was returned
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      SwiftOcrLegacyExtractedView(
                        extractedSwift: extractedSwift!,
                        matchingMatrixChild: matchingMatrixChild,
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
