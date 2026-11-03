import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';
import 'hs_code_agreements_tab.dart';
import 'hs_code_history_tab.dart';
import 'hs_code_quick_calculator_tab.dart';
import 'hs_code_regulatory_tab.dart';
import 'hs_code_tax_rates_tab.dart';

class HsCodeDetailedExplorer extends ConsumerWidget {
  final CustomsTariffModel tariff;
  final TabController tabController;

  const HsCodeDetailedExplorer({
    super.key,
    required this.tariff,
    required this.tabController,
  });

  void _copyTariffSummary(BuildContext context, WidgetRef ref, CustomsTariffModel tariff) async {
    final l = context.l10n;
    final ags = await ref.read(customsTariffProvider.notifier).fetchAgreements(tariff.hsCode);
    final text = MasterDataExportService.generateTariffWhatsAppText(tariff, ags);
    if (context.mounted) {
      CopyHelper.copy(context, text, customMessage: l.hsExplorerCopySummarySuccess);
    }
  }

  void _exportPdf(BuildContext context, WidgetRef ref, CustomsTariffModel tariff) async {
    final ags = await ref.read(customsTariffProvider.notifier).fetchAgreements(tariff.hsCode);
    await MasterDataExportService.printOrSaveTariffPdf(tariff, ags);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.charcoal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => CopyHelper.copy(context, tariff.hsCode, customMessage: l.hsExplorerCopySummarySuccess),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tariff.hsCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: l.hsExplorerCopyHsCodeTooltip,
                          child: const Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tariff.hsDescription,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (tariff.customsCategory != null) ...[
                            Text(
                              l.hsCategoryPrefix(tariff.categoryLabel(l) ?? tariff.customsCategory!),
                              style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            '${l.hsEffectiveFromPrefix(tariff.effectiveFrom.toIso8601String().split('T').first)} ${tariff.effectiveTo != null ? l.hsEffectiveToPrefix(tariff.effectiveTo!.toIso8601String().split('T').first) : l.hsEffectiveActiveRecord}',
                            style: const TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _copyTariffSummary(context, ref, tariff),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_all_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          l.hsExplorerCopySummaryBtn,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _exportPdf(context, ref, tariff),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emerald),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          l.hsExplorerExportPdfBtn,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => tabController.animateTo(3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_edu, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          l.hsDiffHistoryAction,
                          style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (tariff.hasMultiplePhases)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه زمني: هذا البند له ${tariff.totalVersions} مراحل تاريخية بتعريفات واشتراطات مختلفة. يمكنك مراجعة كافة المراحل والاشتراطات بالضغط على تبويب "تاريخ التحديثات".',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => tabController.animateTo(3),
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('عرض المراحل', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Adaptive Tab Navigation
          Expanded(
            child: AdaptiveTabScaffold(
              controller: tabController,
              tabs: [
                AdaptiveTabItem(
                  icon: Icons.calculate_outlined,
                  label: l.hsTabTaxRates,
                  content: HsCodeTaxRatesTab(tariff: tariff),
                ),
                AdaptiveTabItem(
                  icon: Icons.public_outlined,
                  label: l.hsTabAgreements,
                  content: HsCodeAgreementsTab(tariff: tariff),
                ),
                AdaptiveTabItem(
                  icon: Icons.account_balance_outlined,
                  label: l.hsTabRegulatory,
                  content: HsCodeRegulatoryTab(tariff: tariff),
                ),
                AdaptiveTabItem(
                  icon: Icons.history_edu_outlined,
                  label: l.hsTabHistory,
                  content: HsCodeHistoryTab(tariff: tariff),
                ),
                AdaptiveTabItem(
                  icon: Icons.point_of_sale_outlined,
                  label: l.hsTabQuickCalculator,
                  content: HsCodeQuickCalculatorTab(tariff: tariff),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
