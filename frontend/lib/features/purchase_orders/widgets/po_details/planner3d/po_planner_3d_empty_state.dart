import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';

class PoPlanner3dEmptyState extends StatelessWidget {
  final VoidCallback? onEdit;

  const PoPlanner3dEmptyState({
    super.key,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.view_in_ar_rounded,
                  size: 48,
                  color: AppTheme.orange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.poNoPackingListOrPalletData,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.poPleaseAddPackingListOrPallet,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: l.poEditPOAddPackingList,
                icon: Icons.edit,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: () {
                  Navigator.pop(context);
                  onEdit?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
