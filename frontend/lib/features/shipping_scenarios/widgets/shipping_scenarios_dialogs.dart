import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/api_error_text.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/container_requirement_engine.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/shipping_scenario_model.dart';
import '../providers/shipping_scenarios_provider.dart';

class ShippingScenariosDialogs {
  ShippingScenariosDialogs._();

  static void showSaveSuccessReportDialog(BuildContext context, ShippingEvaluationModel sess) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final l = dialogCtx.l10n;
        return SelectionArea(
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.emerald, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.saveSuccessReportTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: SizedBox(
              width: 850,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.emeraldBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CopyableText('${l.studyCodeLabel} ${sess.sessionCode}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 13)),
                          const SizedBox(height: 4),
                          CopyableText('${l.studyTitleDetailLabel} ${sess.title ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          CopyableText('${l.crdLabel}: ${sess.cargoReadyDate} | ${l.pickupAddressLabel}: ${sess.pickUpAddress ?? l.unassigned}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(l.comparativeReportLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: AppTheme.cloudWhite),
                      columnWidths: const {
                        0: FlexColumnWidth(1.5),
                        1: FlexColumnWidth(1.1),
                        2: FlexColumnWidth(1.1),
                        3: FlexColumnWidth(1.1),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(1.5),
                        6: FlexColumnWidth(1.0),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.carrierLineCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.sailingDateCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.portArrivalCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.totalDaysCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.whDateCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.totalQuoteCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.recommendationCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          ],
                        ),
                        ...sess.items.map((item) {
                          return TableRow(
                            decoration: BoxDecoration(color: item.isRecommended ? AppTheme.emeraldLight.withValues(alpha: 0.5) : null),
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.providerName, style: TextStyle(fontWeight: item.isRecommended ? FontWeight.bold : FontWeight.normal, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.sailingDate, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.estimatedArrivalDate, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: CopyableText(l.avgTransitDays(item.expectedTotalDaysToWarehouse.toString()), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.expectedWarehouseArrivalDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.totalQuotationAmount != null ? '${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? ""}' : '—', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson))),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: CopyableText(
                                  item.isRecommended ? l.recommendedBadge(item.providerName) : (item.isExcludedFromAverage ? l.excludedBadge : l.normalBadge),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: item.isRecommended ? AppTheme.emerald : AppTheme.textMuted, fontSize: 10),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.cobaltLight, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, color: AppTheme.cobalt),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CopyableText(
                              '${l.recommendedLineContractLabel} ${sess.recommendedScenarioProvider ?? l.unassigned}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                            ),
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
                label: l.copySummaryBtn,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () {
                  CopyHelper.copy(
                    dialogCtx,
                    '${l.freightStudiesTitle} ${sess.sessionCode}: ${sess.title}\n${l.recommendedLineMetric}: ${sess.recommendedScenarioProvider}\n${l.avgWarehouseArrivalMetric}: ${sess.avgExpectedWarehouseArrivalDate}',
                  );
                },
              ),
              AppButton(
                label: l.saveDoneBtn,
                variant: AppButtonVariant.success,
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
        );
      },
    );
  }

  static void showContainerComparisonDialog(
    BuildContext context,
    ContainerDualRecommendationResult dualRec,
    double cbm,
    double weightKg,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final l = dialogCtx.l10n;
        return SelectionArea(
          child: AlertDialog(
            title: Text(l.containerDualMatrixTitle),
            content: SizedBox(
              width: 650,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CopyableText(
                    l.totalCbmAndWeight(cbm.toStringAsFixed(3), weightKg.toStringAsFixed(0)),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Table(
                    border: TableBorder.all(color: AppTheme.cloudWhite),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                        children: [
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.statusCol, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: const EdgeInsets.all(8), child: Text('📦 ${l.stackableOption}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald))),
                          Padding(padding: const EdgeInsets.all(8), child: Text('🚫 ${l.nonStackableOption}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange))),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.containerTypeCol)),
                          Padding(padding: const EdgeInsets.all(8), child: CopyableText(dualRec.stackableResult.recommendedContainerCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: const EdgeInsets.all(8), child: CopyableText(dualRec.nonStackableResult.recommendedContainerCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.containersRequiredCol)),
                          Padding(padding: const EdgeInsets.all(8), child: CopyableText('${dualRec.stackableResult.requiredContainersCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                          Padding(padding: const EdgeInsets.all(8), child: CopyableText('${dualRec.nonStackableResult.requiredContainersCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.spaceUtilizationLabel)),
                          Padding(padding: const EdgeInsets.all(8), child: CopyableText('${dualRec.stackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%')),
                          Padding(padding: const EdgeInsets.all(8), child: CopyableText('${dualRec.nonStackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: l.close,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
        );
      },
    );
  }

  static void showVisualLoadPlanDialog(BuildContext context, List<PurchaseOrderModel> pos, double totalCbm, double totalWeight) {
    CargoLoadPlannerDialog.showFromPurchaseOrders(
      context,
      pos: pos,
      totalCbm: totalCbm,
      totalWeight: totalWeight,
    );
  }

  static void showCloneStudyReviewDialog(
    BuildContext context,
    WidgetRef ref,
    ShippingEvaluationModel source, {
    required void Function(ShippingEvaluationModel cloned) onClonedSuccess,
  }) {
    final l = context.l10n;
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final initialName = '${source.title ?? source.sessionCode}${TableRowCloneHelper.copySuffix}';

    final copiedMap = <String, String>{
      l.shippingCarrierOptions: '${source.items.length}',
      l.crdLabel: source.cargoReadyDate,
    };
    if (source.recommendedScenarioProvider != null) {
      copiedMap[l.recommendedLineMetric] = source.recommendedScenarioProvider!;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AppLocalizationsProvider(
          locale: isArabic ? const Locale('ar') : const Locale('en'),
          child: Directionality(
            textDirection: textDir,
            child: CloneEntityReviewDialog(
              entityType: l.cloneStudyDialogTitle,
              sourceCode: source.sessionCode,
              suggestedNewCode: '${source.sessionCode}-CLONE',
              sourceTitle: initialName,
              copiedFieldsSummary: copiedMap,
              mandatorilyResetFields: [
                l.cloneFieldStudyCodeGenerated,
                l.cloneFieldImportFileReset,
                l.cloneFieldPoReset,
                l.cloneFieldSelectionReset,
              ],
              onConfirm: ({
                required String newCode,
                required String newTitle,
                required bool copyLineItems,
                required bool copyAttachments,
                String? notes,
              }) async {
                final sId = source.sessionId;
                if (sId == null) return;
                final messenger = ScaffoldMessenger.of(context);
                final cloned = await ref.read(shippingScenariosProvider.notifier).cloneSession(
                  sId,
                  newTitle: newTitle,
                  remarks: notes,
                  unlinkImportFile: true,
                  unlinkPo: true,
                  copyCarrierOptions: copyLineItems,
                );
                if (!context.mounted) return;
                if (cloned != null) {
                  onClonedSuccess(cloned);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    AppTheme.snackBar(
                      context,
                      l.cloneStudySuccess(cloned.sessionCode),
                      severity: AppSeverity.success,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    AppTheme.snackBar(
                      context,
                      ApiErrorText.of(l, ref.read(shippingScenariosProvider).error, fallback: l.operationFailed),
                      severity: AppSeverity.danger,
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
