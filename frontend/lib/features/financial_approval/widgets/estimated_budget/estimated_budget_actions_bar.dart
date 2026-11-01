import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../../core/localization/app_localizations.dart';
import '../financial_ui.dart';

class EstimatedBudgetActionsBar extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onRefresh;
  final VoidCallback onReset;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onSaveAndApprove;
  final VoidCallback onExportExcel;
  final VoidCallback onPrintPdf;

  const EstimatedBudgetActionsBar({
    super.key,
    required this.isEditing,
    required this.isSaving,
    required this.onRefresh,
    required this.onReset,
    required this.onSaveDraft,
    required this.onSaveAndApprove,
    required this.onExportExcel,
    required this.onPrintPdf,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 1. Live Refresh
            FinancialUi.fit(AppButton(
              label: l.refresh,
              variant: AppButtonVariant.secondary,
              icon: Icons.refresh,
              onPressed: onRefresh,
            )),

            // 2. Clear Form & Start New
            FinancialUi.fit(AppButton(
              label: l.reset,
              variant: AppButtonVariant.secondary,
              icon: Icons.cleaning_services_outlined,
              onPressed: onReset,
            )),

            // 3. Save Draft & Continue Later
            FinancialUi.fit(AppButton(
              label: isEditing ? l.saveBudgetChanges : l.saveDraft,
              variant: AppButtonVariant.primary,
              icon: Icons.save_outlined,
              onPressed: isSaving ? null : onSaveDraft,
            )),

            // 4. Final Approval
            FinancialUi.fit(AppButton(
              label: isEditing
                  ? l.saveAndApproveBudget
                  : l.approveAndCertifyBudget,
              variant: AppButtonVariant.success,
              icon: Icons.verified,
              isLoading: isSaving,
              onPressed: isSaving ? null : onSaveAndApprove,
            )),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FinancialUi.fit(AppButton(
              label: l.exportExcel,
              variant: AppButtonVariant.secondary,
              icon: Icons.table_chart,
              onPressed: onExportExcel,
            )),
            FinancialUi.fit(AppButton(
              label: l.print,
              variant: AppButtonVariant.primary,
              icon: Icons.print,
              onPressed: onPrintPdf,
            )),
          ],
        ),
      ],
    );
  }
}
