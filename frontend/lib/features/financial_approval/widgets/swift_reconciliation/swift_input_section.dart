import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../financial_ui.dart';

class SwiftInputSection extends StatelessWidget {
  final TextEditingController rawSwiftTextController;
  final String? uploadedFileName;
  final String? detectedFileType;
  final int? uploadedFileSize;
  final bool isExtracting;
  final VoidCallback onPickAndExtractFile;
  final VoidCallback onRunSmartSwiftExtraction;
  final VoidCallback onClear;
  final VoidCallback onDismissUploadedFile;

  const SwiftInputSection({
    super.key,
    required this.rawSwiftTextController,
    required this.uploadedFileName,
    required this.detectedFileType,
    required this.uploadedFileSize,
    required this.isExtracting,
    required this.onPickAndExtractFile,
    required this.onRunSmartSwiftExtraction,
    required this.onClear,
    required this.onDismissUploadedFile,
  });

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) return Icons.description;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.csv')) return Icons.table_chart;
    return Icons.image;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (uploadedFileName != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cobaltLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cobaltBorder),
            ),
            child: Row(
              children: [
                Icon(
                  _fileIcon(uploadedFileName!),
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
                              uploadedFileName!,
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
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppTheme.wcagCobalt),
                  tooltip: l10n.swiftCloseBtn,
                  onPressed: onDismissUploadedFile,
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: rawSwiftTextController,
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
                      rawSwiftTextController.text,
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
                  isLoading: isExtracting,
                  onPressed: isExtracting ? null : onPickAndExtractFile,
                )),
                const SizedBox(height: 8),
                FinancialUi.fit(AppButton(
                  label: l10n.swiftExtractFromTextBtn,
                  variant: AppButtonVariant.primary,
                  icon: Icons.bolt,
                  isLoading: isExtracting,
                  onPressed: isExtracting ? null : onRunSmartSwiftExtraction,
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
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data != null && data.text != null && data.text!.isNotEmpty) {
                          rawSwiftTextController.text = data.text!;
                          onRunSmartSwiftExtraction();
                        }
                      },
                    )),
                    const SizedBox(width: 4),
                    FinancialUi.fit(AppButton(
                      label: l10n.swiftCancelBtn,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.clear,
                      onPressed: onClear,
                    )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
