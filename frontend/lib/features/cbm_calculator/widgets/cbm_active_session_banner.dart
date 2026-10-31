import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class CbmActiveSessionBanner extends StatelessWidget {
  final String activeSessionCode;
  final String? activeSessionTitle;
  final VoidCallback onSaveChanges;
  final VoidCallback onNewBlankSession;

  const CbmActiveSessionBanner({
    super.key,
    required this.activeSessionCode,
    required this.activeSessionTitle,
    required this.onSaveChanges,
    required this.onNewBlankSession,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.orangeLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.wcagOrange, width: 1.5),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_note, color: AppTheme.wcagOrange, size: 24),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l.activeEditSessionBanner}: [$activeSessionCode] - ${activeSessionTitle ?? ""}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.wcagOrange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.activeEditSessionHint,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.wcagOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: '${l.saveChangesInSession} [$activeSessionCode]',
                icon: Icons.check,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: onSaveChanges,
              ),
              const SizedBox(width: 8),
              AppButton(
                label: l.newBlankSession,
                icon: Icons.add,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: onNewBlankSession,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
