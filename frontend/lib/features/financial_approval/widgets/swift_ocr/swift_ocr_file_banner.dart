import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../financial_ui.dart';

class SwiftOcrFileBanner extends StatelessWidget {
  final String uploadedFileName;
  final String? detectedFileType;
  final int? uploadedFileSize;
  final VoidCallback onPickAndExtractFile;
  final VoidCallback? onClearUploadedFile;

  const SwiftOcrFileBanner({
    super.key,
    required this.uploadedFileName,
    this.detectedFileType,
    this.uploadedFileSize,
    required this.onPickAndExtractFile,
    this.onClearUploadedFile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cobaltLight.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.cobalt.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: AppTheme.cobalt, size: 22),
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
                        uploadedFileName,
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
              icon: const Icon(Icons.close, size: 16, color: AppTheme.wcagCobalt),
              tooltip: l10n.swiftCloseBtn,
              onPressed: onClearUploadedFile,
            ),
          ],
        ],
      ),
    );
  }
}
