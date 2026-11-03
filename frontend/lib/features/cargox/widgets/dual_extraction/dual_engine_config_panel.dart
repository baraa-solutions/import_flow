import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/document_export/grouping_selector.dart';
import '../../../../core/widgets/document_export/packaging_detail_toggle.dart';
import '../../models/export_configs.dart';

/// Side-by-side Dual Engine configuration panel for Invoice and Packing List
class DualEngineConfigPanel extends StatelessWidget {
  final InvoiceExportConfig invoiceConfig;
  final PackingListExportConfig plConfig;
  final ValueChanged<InvoiceExportConfig> onInvoiceConfigChanged;
  final ValueChanged<PackingListExportConfig> onPlConfigChanged;

  const DualEngineConfigPanel({
    super.key,
    required this.invoiceConfig,
    required this.plConfig,
    required this.onInvoiceConfigChanged,
    required this.onPlConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Invoice Engine ────────────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.cobalt.withValues(alpha: 0.03),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.dualExtractionCommercialInvoice,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                          Text(
                            isAr ? 'الفاتورة الجمركية المستقلة' : 'Independent Customs Invoice',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                PackagingDetailToggle(
                  packaging: invoiceConfig.packaging,
                  detail: invoiceConfig.detail,
                  onPackagingChanged: (v) => onInvoiceConfigChanged(invoiceConfig.copyWith(packaging: v)),
                  onDetailChanged: (v) => onInvoiceConfigChanged(invoiceConfig.copyWith(detail: v)),
                  activeColor: AppTheme.cobalt,
                ),
                const SizedBox(height: 12),
                GroupingSelector<InvoiceGroupingMode>(
                  title: isAr ? '٣. أسلوب تجميع بنود الفاتورة:' : '3. Invoice Line Grouping:',
                  value: invoiceConfig.grouping,
                  options: InvoiceGroupingMode.values
                      .map((m) => GroupingOption(
                            value: m,
                            label: isAr ? m.labelAr : m.labelEn,
                            description: isAr ? m.descAr : m.descEn,
                          ))
                      .toList(),
                  onChanged: (v) => onInvoiceConfigChanged(invoiceConfig.copyWith(grouping: v)),
                  activeColor: AppTheme.cobalt,
                ),
                // CGX-CUSTOMS-GUARD banner
                if (invoiceConfig.grouping == InvoiceGroupingMode.byHsCode &&
                    invoiceConfig.detail == ContentDetailMode.consolidated) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.orange),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: AppTheme.orange, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isAr
                                ? 'حماية جمركية تلقائية: إذا وُجد نفس رمز التعريفة بأسعار مختلفة، يُفعّل التقسيم تلقائياً لضمان صحة الإقرار الجمركي المصري.'
                                : 'Auto customs guard: if the same HS code has different prices, lines are split automatically for Egyptian Customs compliance.',
                            style: const TextStyle(fontSize: 10, color: AppTheme.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // ── Packing List Engine ───────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.emerald.withValues(alpha: 0.03),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: AppTheme.emerald, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.dualExtractionPackingList,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.emerald)),
                          Text(
                            isAr ? 'قائمة التعبئة المستقلة' : 'Independent Packing List',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                PackagingDetailToggle(
                  packaging: plConfig.packaging,
                  detail: plConfig.detail,
                  onPackagingChanged: (v) => onPlConfigChanged(plConfig.copyWith(packaging: v)),
                  onDetailChanged: (v) => onPlConfigChanged(plConfig.copyWith(detail: v)),
                  activeColor: AppTheme.emerald,
                ),
                const SizedBox(height: 12),
                GroupingSelector<PackingListStructure>(
                  title: isAr ? '٣. هيكل التعبئة والتغليف:' : '3. Package & Carton Structure:',
                  value: plConfig.structure,
                  options: PackingListStructure.values
                      .map((s) => GroupingOption(
                            value: s,
                            label: isAr ? s.labelAr : s.labelEn,
                            description: isAr ? s.descAr : s.descEn,
                          ))
                      .toList(),
                  onChanged: (v) => onPlConfigChanged(plConfig.copyWith(structure: v)),
                  activeColor: AppTheme.emerald,
                ),
                const SizedBox(height: 8),
                AnimatedOpacity(
                  opacity: plConfig.isPalletToggleAllowed ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: SwitchListTile(
                    value: plConfig.effectiveIncludePalletDetails,
                    onChanged: plConfig.isPalletToggleAllowed
                        ? (v) => onPlConfigChanged(plConfig.copyWith(includePalletDetails: v))
                        : null,
                    title: Text(l.dualExtractionIncludePallets, style: const TextStyle(fontSize: 11)),
                    activeThumbColor: AppTheme.emerald,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
