import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/financial_approval_model.dart';

class DuplicateBudgetDialog extends StatelessWidget {
  final ImportBudgetModel existingBudget;
  final VoidCallback onCancelSelection;
  final VoidCallback onReviewSyncLiveCosts;
  final VoidCallback onViewAndPrintBudget;

  const DuplicateBudgetDialog({
    super.key,
    required this.existingBudget,
    required this.onCancelSelection,
    required this.onReviewSyncLiveCosts,
    required this.onViewAndPrintBudget,
  });

  static Future<void> show(
    BuildContext context, {
    required ImportBudgetModel existingBudget,
    required VoidCallback onCancelSelection,
    required VoidCallback onReviewSyncLiveCosts,
    required VoidCallback onViewAndPrintBudget,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DuplicateBudgetDialog(
        existingBudget: existingBudget,
        onCancelSelection: onCancelSelection,
        onReviewSyncLiveCosts: onReviewSyncLiveCosts,
        onViewAndPrintBudget: onViewAndPrintBudget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: AlertDialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.duplicateBudgetTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        l.duplicateBudgetMessage(existingBudget.budgetCode, existingBudget.title),
        style: TextStyle(
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        AppButton(
          label: l.cancelSelection,
          variant: AppButtonVariant.secondary,
          onPressed: () {
            Navigator.pop(context);
            onCancelSelection();
          },
        ),
        AppButton(
          label: l.faReviewSyncBudgetLiveCosts,
          variant: AppButtonVariant.primary,
          icon: Icons.sync,
          onPressed: () {
            Navigator.pop(context);
            onReviewSyncLiveCosts();
          },
        ),
        AppButton(
          label: l.viewAndPrintBudget,
          variant: AppButtonVariant.success,
          icon: Icons.print,
          onPressed: () {
            Navigator.pop(context);
            onViewAndPrintBudget();
          },
        ),
      ],
    ),
    );
  }
}
