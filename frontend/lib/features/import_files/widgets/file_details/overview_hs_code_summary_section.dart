// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customs_tariff/models/customs_tariff_model.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../../customs_tariff/widgets/hs_code_compliance_insight_card.dart';

/// 📊 HS Code summary table and compliance insight card section
class OverviewHsCodeSummarySection extends ConsumerWidget {
  final List<String> hsCodes;
  final List<({
    String description,
    String hsCode,
    double quantity,
    String uom,
    double unitPrice,
    String currency,
    String poNumber,
  })> allItems;
  final String? countryOfOrigin;
  final bool isDark;
  final bool isAr;

  const OverviewHsCodeSummarySection({
    super.key,
    required this.hsCodes,
    required this.allItems,
    this.countryOfOrigin,
    required this.isDark,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hsCodes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          isAr
              ? '📊 ملخص بنود أوامر التوريد حسب البند الجمركي'
              : '📊 PO Line Items Summary By HS Code',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(1.6),
            1: FlexColumnWidth(1.8),
            2: FlexColumnWidth(0.9),
            3: FlexColumnWidth(1.1),
            4: FlexColumnWidth(1.3),
            5: FlexColumnWidth(1.3),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cloudWhite),
              children: [
                Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'بند التعريفة' : 'HS Code', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'أوامر التوريد' : 'Linked POs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'الأصناف' : 'Items', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'إجمالي الكمية' : 'Total Qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'إجمالي القيمة' : 'Total Value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'نسب الرسوم' : 'Duty / VAT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
            ...hsCodes.map((hs) {
              final matchingItems = allItems.where((i) => i.hsCode == hs).toList();
              final totalQty = matchingItems.fold<double>(0.0, (sum, i) => sum + i.quantity);
              final totalAmount = matchingItems.fold<double>(0.0, (sum, i) => sum + (i.quantity * i.unitPrice));
              final poNumbers = matchingItems.map((i) => i.poNumber).toSet().toList().join(', ');
              final currency = matchingItems.isNotEmpty ? matchingItems.first.currency : 'USD';
              final cleanHs = hs.trim();
              final registeredTariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];
              final tariff = registeredTariffs.cast<CustomsTariffModel?>().firstWhere(
                (t) => t != null && (t.hsCode == cleanHs || t.hsCode.replaceAll('.', '') == cleanHs.replaceAll('.', '')),
                orElse: () => null,
              );
              final dutyRate = tariff?.customsDutyRate ?? 0.0;
              final vatRate = tariff?.vatRate ?? 14.0;

              return TableRow(
                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : null),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(hs, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(poNumbers, style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('${matchingItems.length}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(totalQty % 1 == 0 ? totalQty.toInt().toString() : totalQty.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('$currency ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('$dutyRate% / $vatRate%', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                  ),
                ],
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          isAr
              ? '🛡️ شروط الاستيراد الرقابية وقواعد الإعفاء لكل بند جمركي:'
              : '🛡️ Regulatory Import Conditions & Trade Agreements per HS Code:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        ...hsCodes.map((hs) {
          final cleanHs = hs.trim();
          final registeredTariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];
          final tariff = registeredTariffs.cast<CustomsTariffModel?>().firstWhere(
            (t) => t != null && (t.hsCode == cleanHs || t.hsCode.replaceAll('.', '') == cleanHs.replaceAll('.', '')),
            orElse: () => null,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: HsCodeComplianceInsightCard(
              hsCode: hs,
              tariff: tariff,
              countryOfOrigin: countryOfOrigin,
              isDark: isDark,
              isArabic: isAr,
            ),
          );
        }),
      ],
    );
  }
}
