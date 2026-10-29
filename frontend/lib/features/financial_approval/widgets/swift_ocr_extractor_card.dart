import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/financial_approval_model.dart';
import 'financial_ui.dart';
import 'swift_extraction_review_widget.dart';

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
                      isAutoFillMode
                          ? l10n.swiftExtractorTitle
                          : l10n.swiftExtractorHeader,
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onLoadSample != null) ...[
                    FinancialUi.fit(AppButton(
                      label: l10n.swiftLoadSampleBtn,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.description,
                      onPressed: onLoadSample,
                    )),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    tooltip: isSmartSectionExpanded
                        ? l10n.swiftCollapseToolTooltip
                        : l10n.swiftExpandToolTooltip,
                    icon: Icon(
                      isSmartSectionExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.white,
                    ),
                    onPressed: onToggleExpanded,
                  ),
                ],
              ),
            ),

            if (isSmartSectionExpanded)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Uploaded File Info Banner (if any)
                    if (uploadedFileName != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.cobaltLight.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.cobalt.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file,
                                color: AppTheme.cobalt, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        l10n.swiftExtractedDocLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppTheme.cobalt,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          uploadedFileName!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.charcoal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${l10n.swiftDocTypePrefix} ${detectedFileType ?? l10n.swiftDocumentDefaultType} ${uploadedFileSize != null ? "• ${l10n.swiftDocSizePrefix} ${(uploadedFileSize! / 1024).toStringAsFixed(1)} KB" : ""}',
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
                              onPressed: onPickAndExtractFile,
                            )),
                            if (onClearUploadedFile != null) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: AppTheme.wcagCobalt),
                                tooltip: l10n.swiftCloseBtn,
                                onPressed: onClearUploadedFile,
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Text Area + Action Buttons
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 650;
                        final textArea = TextField(
                          controller: rawSwiftTextController,
                          maxLines: 5,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.charcoal,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.swiftRawTextPlaceholder,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.darkElevatedSurface
                                : AppTheme.charcoalSurface,
                            contentPadding: const EdgeInsets.all(12),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: l10n.swiftCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(
                                context,
                                rawSwiftTextController.text,
                              ),
                            ),
                          ),
                        );

                        final actionButtons = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FinancialUi.fit(AppButton(
                              label: l10n.swiftUploadFileBtn,
                              variant: AppButtonVariant.primary,
                              icon: Icons.upload_file,
                              isLoading: isExtracting,
                              onPressed: isExtracting ? null : onPickAndExtractFile,
                            )),
                            const SizedBox(height: 8),
                            FinancialUi.fit(AppButton(
                              label: l10n.swiftExtractFromTextBtn,
                              variant: AppButtonVariant.primary,
                              icon: Icons.bolt,
                              isLoading: isExtracting,
                              onPressed: isExtracting ? null : onExtractFromText,
                            )),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                FinancialUi.fit(AppButton(
                                  label: l10n.swiftPasteAndExtractChip,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  icon: Icons.paste,
                                  onPressed: () async {
                                    final data = await Clipboard.getData(
                                        Clipboard.kTextPlain);
                                    if (data != null &&
                                        data.text != null &&
                                        data.text!.isNotEmpty) {
                                      rawSwiftTextController.text = data.text!;
                                      if (onPasteAndExtract != null) {
                                        onPasteAndExtract!();
                                      } else {
                                        onExtractFromText();
                                      }
                                    }
                                  },
                                )),
                                if (onReset != null)
                                  FinancialUi.fit(AppButton(
                                    label: l10n.swiftCancelBtn,
                                    variant: AppButtonVariant.secondary,
                                    size: AppButtonSize.small,
                                    icon: Icons.clear,
                                    onPressed: onReset,
                                  )),
                              ],
                            ),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              textArea,
                              const SizedBox(height: 10),
                              actionButtons,
                            ],
                          );
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: textArea),
                              const SizedBox(width: 14),
                              SizedBox(width: 220, child: actionButtons),
                            ],
                          );
                        }
                      },
                    ),

                    // Auto-fill extracted badges (if present in auto-fill mode)
                    if (isAutoFillMode && autoFillSummary != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkCardBackground
                              : AppTheme.emeraldLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.emerald.withValues(alpha: 0.4)
                                : AppTheme.emeraldBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppTheme.emerald, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    '${l10n.requestedAmountLabel}: ${autoFillSummary!['amount']} ${autoFillSummary!['currency']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.charcoal,
                                    ),
                                  ),
                                  Text(
                                    '${l10n.beneficiarySupplierLabel}: ${autoFillSummary!['beneficiary_name'] ?? "-"}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.charcoal,
                                    ),
                                  ),
                                  Text(
                                    '${l10n.paymentCodeCol}: ${autoFillSummary!['transaction_reference'] ?? "-"}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.charcoal,
                                    ),
                                  ),
                                  Text(
                                    '${l10n.swiftCodeLabel}: ${autoFillSummary!['beneficiary_bank_swift'] ?? "-"}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.charcoal,
                                    ),
                                  ),
                                  Text(
                                    '${l10n.ibanAccountLabel}: ${autoFillSummary!['beneficiary_account_or_iban'] ?? "-"}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.cobaltLight.withValues(alpha: 0.6),
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
                                            'Ref: ${extractedSwift!['transaction_reference'] ?? l10n.swiftStatusUnregistered}',
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
                                        label: l10n.swiftColTransferredAmount,
                                        value:
                                            '${extractedSwift!['amount']} ${extractedSwift!['currency']}',
                                        color: AppTheme.emerald,
                                        isBold: true,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildInfoField(
                                        label: l10n.swiftColSwiftDate,
                                        value: extractedSwift![
                                                'value_date_formatted'] ??
                                            extractedSwift!['value_date'] ??
                                            '-',
                                        color: AppTheme.charcoal,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildInfoField(
                                        label: l10n.swiftChargesLabel,
                                        value:
                                            extractedSwift!['charge_details'] ??
                                                'SHA',
                                        color: AppTheme.emerald,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${l10n.swiftExtractedReceiverPrefix.replaceAll(':', '')}: ${extractedSwift!['beneficiary_name'] ?? "-"}',
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
                                          '${l10n.swiftCodeLabel.replaceAll(':', '')}: ${extractedSwift!['beneficiary_bank_swift'] ?? "-"}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${l10n.swiftAccountLabel.replaceAll(':', '')}: ${extractedSwift!['beneficiary_account_or_iban'] ?? "-"}',
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
                                    '${l10n.swiftExtractedSenderPrefix.replaceAll(':', '')}: ${extractedSwift!['ordering_customer_name'] ?? "-"} (${extractedSwift!['ordering_account_or_iban'] ?? "-"})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textStrong,
                                    ),
                                  ),
                                  if (extractedSwift!['pi_number'] != null ||
                                      extractedSwift!['payment_details'] !=
                                          null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${l10n.swiftRequestTitleLabel} ${extractedSwift!['pi_number'] ?? extractedSwift!['payment_details']}',
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
                          if (matchingMatrixChild != null) ...[
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 6,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldLight
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: AppTheme.emeraldBorder),
                                ),
                                child: matchingMatrixChild!,
                              ),
                            ),
                          ],
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

  Widget _buildInfoField({
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.cloudWhite),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            const SizedBox(height: 2),
            CopyableText(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
