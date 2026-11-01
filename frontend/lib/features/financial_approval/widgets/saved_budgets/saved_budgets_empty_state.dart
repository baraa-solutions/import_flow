import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

class SavedBudgetsEmptyState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onSwitchToForm;

  const SavedBudgetsEmptyState({
    super.key,
    required this.isDark,
    required this.onSwitchToForm,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 56,
            color: isDark ? AppTheme.darkBorder : AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            l.noMatchingBudgets,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textStrong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.noBudgetsPlaceholderMessage,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: l.approveNewBudgetNow,
            variant: AppButtonVariant.success,
            icon: Icons.add,
            onPressed: onSwitchToForm,
          ),
        ],
      ),
    );
  }
}
