import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class POLineItemHeader extends StatelessWidget {
  final bool isEdit;
  final bool isArabic;

  const POLineItemHeader({
    super.key,
    required this.isEdit,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.cobaltLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isEdit ? Icons.edit_note_rounded : Icons.playlist_add_rounded,
            color: AppTheme.cobalt,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? l.poLineItemDialogTitleEdit : l.poLineItemDialogTitleAdd,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
              Text(
                l.poLineItemCatalogAutoFillHint,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
          tooltip: isArabic ? 'إغلاق' : 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
