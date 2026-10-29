import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_error.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';
import '../services/financial_export_service.dart';
import 'async_action_button.dart';
import 'budget_email_share_dialog.dart';
import 'budget_whatsapp_share_dialog.dart';
import 'financial_ui.dart';

class BudgetDetailsDialog extends ConsumerStatefulWidget {
  final ImportBudgetModel budget;
  final BudgetPrefillModel? prefill;
  final VoidCallback? onEditBudget;

  const BudgetDetailsDialog({
    super.key,
    required this.budget,
    this.prefill,
    this.onEditBudget,
  });

  static Future<void> show(
    BuildContext context, {
    required ImportBudgetModel budget,
    BudgetPrefillModel? prefill,
    VoidCallback? onEditBudget,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => BudgetDetailsDialog(
        budget: budget,
        prefill: prefill,
        onEditBudget: onEditBudget,
      ),
    );
  }

  @override
  ConsumerState<BudgetDetailsDialog> createState() =>
      _BudgetDetailsDialogState();
}

class _BudgetDetailsDialogState extends ConsumerState<BudgetDetailsDialog> {
  Future<BudgetPrefillModel?>? _prefillFuture;

  @override
  void initState() {
    super.initState();
    if (widget.prefill != null) {
      _prefillFuture = Future.value(widget.prefill);
    } else if (widget.budget.importFileId != null) {
      _prefillFuture = _fetchPrefillOrNull(widget.budget.importFileId!);
    } else {
      _prefillFuture = Future.value(null);
    }
  }

  Future<BudgetPrefillModel?> _fetchPrefillOrNull(int fileId) async {
    try {
      return await ref
          .read(importBudgetsProvider.notifier)
          .fetchBudgetPrefill(fileId);
    } catch (_) {
      return null;
    }
  }

  Widget _buildVarianceAlertBanner({
    required BuildContext context,
    required ImportBudgetModel bgt,
    required BudgetPrefillModel prefill,
  }) {
    final diffInvoice =
        prefill.totalInvoiceAmountEgp - bgt.invoiceAmountEgp;
    final diffFreight =
        prefill.estimatedFreightCostEgp - bgt.freightCostEgp;
    final diffDuties =
        prefill.estimatedCustomsDutiesEgp - bgt.customsDutiesEgp;
    final diffClearance =
        prefill.estimatedClearanceFeesEgp - bgt.clearanceInlandEgp;

    final bool hasVariance = diffInvoice.abs() > 1.0 ||
        diffFreight.abs() > 1.0 ||
        diffDuties.abs() > 1.0 ||
        diffClearance.abs() > 1.0;

    if (!hasVariance) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalDiff = diffInvoice + diffFreight + diffDuties + diffClearance;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.orangeLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.wcagOrange, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppTheme.wcagOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.white, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.faUpstreamVarianceTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.orange,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (totalDiff > 0 ? AppTheme.crimson : AppTheme.emerald)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${totalDiff > 0 ? "+" : ""}${totalDiff.toStringAsFixed(2)} EGP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color:
                        totalDiff > 0 ? AppTheme.crimson : AppTheme.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.faUpstreamVarianceBody,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidatedTable(
      BuildContext context, ImportBudgetModel bgt) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget rowItem(String title, String foreignStr, String egpStr,
        {bool isBold = false, Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isBold ? 13 : 12,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: color ??
                      (isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.charcoal),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                foreignStr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textMuted,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                egpStr,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: isBold ? 13 : 12,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  fontFamily: 'monospace',
                  color: color ??
                      (isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.charcoal),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  l.categoryCol,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  l.currencyCol,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  l.equivalentEgpCol,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          rowItem(
            l.estimatedInvoiceValue,
            '${bgt.invoiceAmountForeign.toStringAsFixed(2)} ${bgt.invoiceCurrency}',
            '${bgt.invoiceAmountEgp.toStringAsFixed(2)} EGP',
          ),
          rowItem(
            l.estimatedFreightCost,
            '${bgt.freightCostForeign.toStringAsFixed(2)} ${bgt.freightCurrency}',
            '${bgt.freightCostEgp.toStringAsFixed(2)} EGP',
          ),
          rowItem(
            l.customsAndVatEstimate,
            '-',
            '${bgt.customsDutiesEgp.toStringAsFixed(2)} EGP',
          ),
          rowItem(
            l.clearanceAndTransportEstimate,
            '-',
            '${bgt.clearanceInlandEgp.toStringAsFixed(2)} EGP',
          ),
          const Divider(height: 14),
          rowItem(
            l.totalBudgetEgp,
            '-',
            '${bgt.totalBudgetEgp.toStringAsFixed(2)} EGP',
            isBold: true,
            color: AppTheme.cobalt,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgt = widget.budget;

    return FutureBuilder<BudgetPrefillModel?>(
      future: _prefillFuture,
      builder: (ctx, snapshot) {
        final prefill = snapshot.data ?? widget.prefill;

        return SelectionArea(
          child: AlertDialog(
          backgroundColor:
              isDark ? AppTheme.darkCardBackground : AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l.budgetDetailsTitle(bgt.budgetCode),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FinancialStatusChip(status: bgt.budgetStatus),
            ],
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bgt.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (prefill != null) ...[
                    _buildVarianceAlertBanner(
                      context: context,
                      bgt: bgt,
                      prefill: prefill,
                    ),
                  ],

                  _buildConsolidatedTable(context, bgt),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurface
                          : AppTheme.charcoalSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.cloudWhite),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.share_outlined,
                                size: 16, color: AppTheme.cobalt),
                            const SizedBox(width: 6),
                            Text(
                              l.exportAndShareOptionsTitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // 1. Print / Save PDF
                            AppButton(
                              label: l.printSavePdfBtn,
                              variant: AppButtonVariant.primary,
                              size: AppButtonSize.small,
                              icon: Icons.print,
                              onPressed: () {
                                FinancialExportService.printOrSaveBudgetPdf(
                                  budget: bgt,
                                  prefill: prefill,
                                );
                              },
                            ),
                            // 2. Export Excel
                            AppButton(
                              label: l.downloadExcelBtn,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              icon: Icons.table_chart,
                              onPressed: () async {
                                final scaffold = ScaffoldMessenger.of(context);
                                final path = await FinancialExportService
                                    .exportBudgetToExcel(
                                  context: context,
                                  budget: bgt,
                                  prefill: prefill,
                                );
                                if (path != null && mounted) {
                                  scaffold.showSnackBar(
                                    AppTheme.snackBar(context, l.excelSavedSuccess(path), severity: AppSeverity.success),
                                  );
                                }
                              },
                            ),
                            // 3. WhatsApp Sharing
                            AppButton(
                              label: l.whatsappShareBtn,
                              variant: AppButtonVariant.success,
                              size: AppButtonSize.small,
                              icon: Icons.chat,
                              onPressed: () {
                                BudgetWhatsAppShareDialog.show(
                                  context,
                                  budget: bgt,
                                  prefill: prefill,
                                );
                              },
                            ),
                            // 4. Email Sharing
                            AppButton(
                              label: l.emailShareBtn,
                              variant: AppButtonVariant.warning,
                              size: AppButtonSize.small,
                              icon: Icons.email_outlined,
                              onPressed: () {
                                BudgetEmailShareDialog.show(
                                  context,
                                  budget: bgt,
                                  prefill: prefill,
                                );
                              },
                            ),
                            // 5. Copy Summary
                            AppButton(
                              label: l.copySummaryBtn,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              icon: Icons.copy,
                              onPressed: () {
                                final text = FinancialExportService
                                    .generateBudgetWhatsAppText(
                                        bgt, prefill);
                                CopyHelper.copy(context, text);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AppButton(
              label: l.close,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
            if (widget.onEditBudget != null)
              AppButton(
                label: l.edit,
                variant: AppButtonVariant.secondary,
                icon: Icons.edit,
                onPressed: () {
                  Navigator.pop(context);
                  widget.onEditBudget!();
                },
              ),
            if (bgt.importFileId != null)
              RecalculateButton(
                entityType: 'import_budget',
                entityId: bgt.budgetId,
                sourcePage: 'BudgetDetailsDialog',
                label: l.faSyncLiveCosts,
                onSuccess: (result) {
                  Navigator.of(context).pop();
                  ref.invalidate(importBudgetsProvider);
                },
              ),
            if (bgt.budgetStatus == 'Pending Review' ||
                bgt.budgetStatus == 'Draft' ||
                bgt.budgetStatus == 'Needs Revalidation') ...[
              AsyncActionButton(
                label: l.approveAndCertifyBudget,
                variant: AppButtonVariant.success,
                onAction: () async {
                  final nav = Navigator.of(context);
                  final scaffold = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(importBudgetsProvider.notifier)
                        .approveImportBudget(bgt.budgetId);
                    nav.pop();
                  } catch (e) {
                    if (mounted) {
                      scaffold.showSnackBar(
                        AppTheme.snackBar(context, ApiError.message(e), severity: AppSeverity.danger),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
      );
      },
    );
  }
}
