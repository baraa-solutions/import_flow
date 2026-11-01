import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../budget_details_dialog.dart';
import '../budget_email_share_dialog.dart';
import '../budget_whatsapp_share_dialog.dart';

class SavedBudgetsActionsHandler {
  SavedBudgetsActionsHandler._();

  static void showBudgetDetailsDialog(
    BuildContext context, {
    required ImportBudgetModel budget,
    required void Function(ImportBudgetModel) onEditBudget,
  }) {
    BudgetDetailsDialog.show(
      context,
      budget: budget,
      onEditBudget: () => onEditBudget(budget),
    );
  }

  static void showWhatsAppShareDialog(BuildContext context, ImportBudgetModel budget) {
    BudgetWhatsAppShareDialog.show(context, budget: budget);
  }

  static void showEmailShareDialog(BuildContext context, ImportBudgetModel budget) {
    BudgetEmailShareDialog.show(context, budget: budget);
  }

  static Future<void> confirmDeleteBudget(
    BuildContext context, {
    required WidgetRef ref,
    required ImportBudgetModel budget,
  }) async {
    final l = context.l10n;

    final confirm = await AppConfirmDialog.showDelete(
      context,
      title: l.confirmDeleteBudgetTitle,
      message: l.confirmDeleteBudgetMessage(budget.budgetCode, budget.title),
      entityName: '${budget.budgetCode} - ${budget.title}',
    );

    if (confirm == true) {
      try {
        await ref
            .read(importBudgetsProvider.notifier)
            .softDeleteImportBudget(budget.budgetId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l.budgetDeletedSuccess(budget.budgetCode),
              severity: AppSeverity.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l.deleteErrorMsg(ApiError.message(e)),
              severity: AppSeverity.danger,
            ),
          );
        }
      }
    }
  }
}
