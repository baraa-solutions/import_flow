import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Banner shown when actively editing an existing customs consultation record.
class ConsultationCalcEditBanner extends StatelessWidget {
  final String? editingConsultationCode;
  final VoidCallback onSave;
  final VoidCallback onSaveAsNewCopy;
  final VoidCallback onCancel;
  final bool isSaving;

  const ConsultationCalcEditBanner({
    super.key,
    required this.editingConsultationCode,
    required this.onSave,
    required this.onSaveAsNewCopy,
    required this.onCancel,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.orangeLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.orange, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppTheme.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        l.activeEditModeBannerTitle(editingConsultationCode ?? ''),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.wcagOrange,
                        ),
                      ),
                      if (editingConsultationCode != null)
                        Tooltip(
                          message: l.copyTooltip,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => CopyHelper.copy(
                                context, editingConsultationCode!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.orangeLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.orange),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    editingConsultationCode!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppTheme.wcagOrange,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy,
                                      size: 12, color: AppTheme.wcagOrange),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.activeEditModeBannerSub,
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.charcoal),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppButton(
              label: l.saveConsultationChanges,
              icon: Icons.save_as_rounded,
              variant: AppButtonVariant.warning,
              size: AppButtonSize.small,
              onPressed: isSaving ? null : onSave,
            ),
            const SizedBox(width: 8),
            AppButton(
              label: l.saveAsNewCopy,
              icon: Icons.copy_rounded,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: onSaveAsNewCopy,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textMuted),
              tooltip: l.cancelEditTooltip,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}
