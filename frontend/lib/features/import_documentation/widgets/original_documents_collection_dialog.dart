import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import 'original_documents_collection_tab.dart';

/// Modal dialog wrapper for Original Documents Collection & Courier Tracking (SH-04).
/// Allows tracking multi-courier deliveries, checking off hard-copy banking documents,
/// and certifying receipt for Egyptian Customs clearance.
class OriginalDocumentsCollectionDialog extends StatelessWidget {
  final ImportFileModel file;

  const OriginalDocumentsCollectionDialog({
    super.key,
    required this.file,
  });

  static Future<void> show(
    BuildContext context,
    ImportFileModel file,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => OriginalDocumentsCollectionDialog(file: file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final dialogWidth = (media.width * 0.95).clamp(950.0, 1550.0);
    final dialogHeight = (media.height * 0.92).clamp(650.0, 980.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.white),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withValues(alpha: 0.2), // Amber
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.markunread_mailbox_rounded,
                        color: AppTheme.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              Text(
                                context.l10n.idocAReceiptAndDocumentationOfOriginalBank,
                                style: TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.cobalt.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  file.primaryNameWithCode,
                                  style: const TextStyle(
                                    color: AppTheme.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (file.acidNumber != null && file.acidNumber!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.qr_code_2, size: 13, color: AppTheme.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ACID: ${file.acidNumber}',
                                        style: const TextStyle(
                                          color: AppTheme.orange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.idocAStage5SailingAndCargoXCourier,
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.white),
                      tooltip: context.l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Embedded Original Documents Collection Tab Content
              Expanded(
                child: OriginalDocumentsCollectionTab(
                  initialImportFileId: file.importFileId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
