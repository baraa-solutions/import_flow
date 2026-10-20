import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../screens/cargox_hub_screen.dart';

/// Modal dialog wrapper for CargoX Hub & Digital Transfer (SH-03).
/// Allows reviewing, verifying, sealing, and transferring digital envelopes to Egyptian Customs.
class CargoXHubDialog extends StatelessWidget {
  final ImportFileModel file;

  const CargoXHubDialog({
    super.key,
    required this.file,
  });

  static Future<void> show(
    BuildContext context,
    ImportFileModel file,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CargoXHubDialog(file: file),
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
              color: Colors.black.withValues(alpha: 0.25),
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
                    bottom: BorderSide(color: Colors.white10),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        color: AppTheme.cobalt,
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
                              const Text(
                                'منصة النقل الرقمي CargoX واعتماد الملفات (SH-03)',
                                style: TextStyle(
                                  color: Colors.white,
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
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (file.acidNumber != null && file.acidNumber!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.qr_code_2, size: 13, color: Colors.amberAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ACID: ${file.acidNumber}',
                                        style: const TextStyle(
                                          color: Colors.amberAccent,
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
                          const Text(
                            'المرحلة الخامسة: الإبحار و CargoX — رفع ومطابقة الوثائق الرقمية والختم الإلكتروني ونقل المظروف لمصلحة الجمارك',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Embedded Hub Screen Content
              Expanded(
                child: CargoXHubScreen(
                  initialImportFileId: file.importFileId,
                  isEmbedded: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
