import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Card for uploading and extracting Draft B/L documents across multiple formats
/// (PDF, Word docx, Excel xlsx, Raw text / OCR), displaying extracted B/L number,
/// and showing safety guardrail mismatch alerts.
class DraftBlExtractorCard extends StatelessWidget {
  final bool isUploadingFile;
  final String? uploadedFileName;
  final int? uploadedFileSize;
  final String? extractionStatus;
  final List<dynamic> missingCriticalFields;
  final String? safetyWarning;
  final String blNumber;
  final TextEditingController rawTextController;
  final VoidCallback onPickAndExtractFile;
  final VoidCallback onExtractFromText;
  final ValueChanged<String>? onBlNumberChanged;

  const DraftBlExtractorCard({
    super.key,
    required this.isUploadingFile,
    this.uploadedFileName,
    this.uploadedFileSize,
    this.extractionStatus,
    this.missingCriticalFields = const [],
    this.safetyWarning,
    required this.blNumber,
    required this.rawTextController,
    required this.onPickAndExtractFile,
    required this.onExtractFromText,
    this.onBlNumberChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.borderOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isNarrow = constraints.maxWidth < 650;
                  final badges = Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildFormatBadge('PDF', AppTheme.crimson),
                      _buildFormatBadge('Word (.docx)', AppTheme.cobalt),
                      _buildFormatBadge('Excel (.xlsx)', AppTheme.emerald),
                      _buildFormatBadge('Text / OCR', AppTheme.emerald),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.document_scanner, color: AppTheme.cobalt, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.draftBlSmartExtractorTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.draftBlSmartExtractorSub,
                          style: TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context)),
                        ),
                        const SizedBox(height: 8),
                        badges,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      const Icon(Icons.document_scanner, color: AppTheme.cobalt, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.draftBlSmartExtractorTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.draftBlSmartExtractorSub,
                              style: TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context)),
                            ),
                          ],
                        ),
                      ),
                      badges,
                    ],
                  );
                },
              ),
              Divider(height: 24, color: isDark ? AppTheme.darkBorder : null),

              // File Upload Button & Status
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton(
                    label: isUploadingFile
                        ? l.draftBlExtractingFileProgress
                        : l.draftBlUploadAndExtractButton,
                    icon: Icons.upload_file,
                    variant: AppButtonVariant.primary,
                    isLoading: isUploadingFile,
                    onPressed: isUploadingFile ? null : onPickAndExtractFile,
                  ),
                  if (uploadedFileName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.severityForegroundOf(context, AppSeverity.success).withValues(alpha: 0.3)
                            : AppTheme.severityBackgroundOf(context, AppSeverity.success),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.severityForegroundOf(context, AppSeverity.success)
                              : AppTheme.emeraldBorder,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.emerald, size: 18),
                          Text(
                            l.draftBlFileExtractedSuccess(
                              uploadedFileName!,
                              ((uploadedFileSize ?? 0) / 1024).toStringAsFixed(1),
                            ),
                            style: TextStyle(
                              color: isDark ? AppTheme.emerald : AppTheme.severityForegroundOf(context, AppSeverity.success),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18, color: AppTheme.emerald),
                            tooltip: l.draftBlReuploadTooltip,
                            onPressed: onPickAndExtractFile,
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Extracted B/L quick display bar
              if (blNumber.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.35)),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          const Icon(Icons.confirmation_number_outlined, color: AppTheme.cobalt, size: 22),
                          Text(
                            l.draftBlExtractedBlNumberLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceOf(context),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  blNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => CopyHelper.copy(
                                    context,
                                    blNumber,
                                    customMessage: l.draftBlCopiedBlNumberSnackbar(blNumber),
                                  ),
                                  child: Tooltip(
                                    message: l.draftBlCopyBlNumberTooltip,
                                    child: Icon(
                                      Icons.copy,
                                      size: 16,
                                      color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onBlNumberChanged != null)
                            AppButton(
                              label: l.edit,
                              icon: Icons.edit,
                              variant: AppButtonVariant.ghost,
                              size: AppButtonSize.small,
                              onPressed: () => _showEditBlDialog(context, l),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Safety Guardrail Alert
              if (missingCriticalFields.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.draftBlSafetyAlertTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              safetyWarning ?? l.draftBlSafetyAlertSub,
                              style: const TextStyle(fontSize: 12, color: AppTheme.charcoal),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: missingCriticalFields.map((f) {
                                final label = f is Map ? (f['field_label'] ?? f['field_key']) : f.toString();
                                return Chip(
                                  label: Text(
                                    label.toString(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.white),
                                  ),
                                  backgroundColor: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (uploadedFileName != null && extractionStatus == 'EXTRACTION_COMPLETE') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emeraldBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: AppTheme.emerald, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        l.draftBlSmartExtractionComplete,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Raw Text Expansion
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                title: Text(
                  l.draftBlPasteRawTextTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                children: [
                  TextFormField(
                    controller: rawTextController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l.draftBlPasteRawTextHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton(
                      label: l.draftBlExtractFromTextButton,
                      icon: Icons.flash_on,
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.small,
                      onPressed: onExtractFromText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBlDialog(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (dCtx) {
        final editCtrl = TextEditingController(text: blNumber);
        return SelectionArea(
          child: AlertDialog(
            title: Text(l.draftBlEditBlNumberTitle),
            content: TextField(
              controller: editCtrl,
              decoration: InputDecoration(
                labelText: l.draftBlRegistryColBlNumber,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              AppButton(
                label: l.cancel,
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.pop(dCtx),
              ),
              AppButton(
                label: l.save,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  final text = editCtrl.text.trim();
                  if (text.isNotEmpty && onBlNumberChanged != null) {
                    onBlNumberChanged!(text);
                  }
                  Navigator.pop(dCtx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
