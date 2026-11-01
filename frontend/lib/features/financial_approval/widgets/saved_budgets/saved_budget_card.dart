import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/financial_approval_model.dart';
import '../../services/financial_export_service.dart';
import '../financial_ui.dart';
import 'saved_budget_card_metrics.dart';

class SavedBudgetCard extends StatelessWidget {
  final ImportBudgetModel budget;
  final bool isDark;
  final void Function(ImportBudgetModel) onEditBudget;
  final void Function(ImportBudgetModel)? onCloneBudget;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;

  const SavedBudgetCard({
    super.key,
    required this.budget,
    required this.isDark,
    required this.onEditBudget,
    this.onCloneBudget,
    required this.onViewDetails,
    required this.onDelete,
    required this.onWhatsApp,
    required this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = budget.budgetStatus.toLowerCase().contains('approved');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isApproved
              ? (isDark ? AppTheme.wcagEmerald : AppTheme.emeraldBorder)
              : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBar(context, isApproved),
          SavedBudgetCardMetrics(budget: budget, isDark: isDark),
          _buildActionFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, bool isApproved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isApproved
            ? (isDark
                ? AppTheme.wcagEmerald.withValues(alpha: 0.35)
                : AppTheme.emeraldLight.withValues(alpha: 0.5))
            : (isDark
                ? AppTheme.wcagOrange.withValues(alpha: 0.35)
                : AppTheme.orangeLight.withValues(alpha: 0.5)),
        borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(9), topEnd: Radius.circular(9)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 850;
          final codeSection = InkWell(
            onTap: () => CopyHelper.copy(context, budget.budgetCode,
                customMessage: context.l10n.budgetCodeCopied(budget.budgetCode)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.white, size: 14),
                  const SizedBox(width: 6),
                  CopyableText(budget.budgetCode,
                      style: const TextStyle(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      showIcon: false),
                  const SizedBox(width: 4),
                  Icon(Icons.copy, color: AppTheme.white.withValues(alpha: 0.7), size: 11),
                ],
              ),
            ),
          );

          final fileSection = (budget.importFileCode != null || budget.importFileId != null)
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                  ),
                  child: CopyableText(
                    budget.importFileCode ?? 'IMP-${budget.importFileId}',
                    style: const TextStyle(
                        color: AppTheme.cobalt,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                    showIcon: false,
                  ),
                )
              : null;

          final actionsSection = RowActionsPill(
            onView: onViewDetails,
            onEdit: () => onEditBudget(budget),
            onClone: onCloneBudget != null ? () => onCloneBudget!(budget) : null,
            onPrint: () => FinancialExportService.printOrSaveBudgetPdf(budget: budget),
            onDelete: onDelete,
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.start,
                    children: [
                      actionsSection,
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          codeSection,
                          if (fileSection != null) fileSection,
                          FinancialStatusChip(status: budget.budgetStatus),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                CopyableText(
                  budget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                  showIcon: false,
                ),
              ],
            );
          }

          return Row(
            children: [
              actionsSection,
              const SizedBox(width: 10),
              codeSection,
              if (fileSection != null) ...[
                const SizedBox(width: 10),
                fileSection,
              ],
              const SizedBox(width: 10),
              Expanded(
                child: CopyableText(
                  budget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  showIcon: false,
                ),
              ),
              const SizedBox(width: 10),
              FinancialStatusChip(status: budget.budgetStatus),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInputBackground : AppTheme.charcoalSurface,
        border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite)),
        borderRadius: const BorderRadiusDirectional.only(
            bottomStart: Radius.circular(9), bottomEnd: Radius.circular(9)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FinancialUi.fit(AppButton(
            label: context.l10n.viewDetails,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            icon: Icons.visibility_outlined,
            onPressed: onViewDetails,
          )),
          if (onCloneBudget != null)
            FinancialUi.fit(AppButton(
              label: context.l10n.cloneBudgetTooltip,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              icon: Icons.copy_rounded,
              onPressed: () => onCloneBudget!(budget),
            )),
          FinancialUi.fit(AppButton(
            label: context.l10n.editInForm,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            icon: Icons.edit_outlined,
            onPressed: () => onEditBudget(budget),
          )),
          FinancialUi.fit(AppButton(
            label: context.l10n.printSavePdfBtn,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            icon: Icons.print_outlined,
            onPressed: () => FinancialExportService.printOrSaveBudgetPdf(budget: budget),
          )),
          FinancialUi.fit(AppButton(
            label: context.l10n.downloadExcelBtn,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            icon: Icons.table_chart,
            onPressed: () async {
              final path = await FinancialExportService.exportBudgetToExcel(context: context, budget: budget);
              if (path != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  AppTheme.snackBar(
                    context,
                    context.l10n.excelSavedSuccess(path),
                    severity: AppSeverity.success,
                  ),
                );
              }
            },
          )),
          FinancialUi.fit(AppButton(
            label: context.l10n.whatsappShareBtn,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            icon: Icons.chat,
            onPressed: onWhatsApp,
          )),
          FinancialUi.fit(AppButton(
            label: context.l10n.emailShareBtn,
            variant: AppButtonVariant.warning,
            size: AppButtonSize.small,
            icon: Icons.email_outlined,
            onPressed: onEmail,
          )),
          FinancialUi.fit(AppButton(
            label: context.l10n.copySummaryBtn,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            icon: Icons.copy,
            onPressed: () {
              final text = FinancialExportService.generateBudgetWhatsAppText(budget);
              CopyHelper.copy(context, text, customMessage: context.l10n.budgetSummaryCopied);
            },
          )),
        ],
      ),
    );
  }
}
