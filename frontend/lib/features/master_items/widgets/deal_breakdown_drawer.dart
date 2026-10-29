import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../financial_settlement/models/financial_settlement_model.dart';
import '../../financial_settlement/providers/financial_settlement_provider.dart';
import '../models/item_price_history_model.dart';
import '../models/master_item_model.dart';

/// 4️⃣ Deal Landed Cost Breakdown Drawer (MD-ITEM-001 / Session 3)
/// Sliding side drawer breaking down actual landed cost components:
/// Customs Duties & Taxes, Ocean/Air Freight, Demurrage & Storage,
/// Brokerage/Clearance Fees, Inland Transport, and Surcharges.
class DealBreakdownDrawer extends ConsumerWidget {
  final ItemPriceHistoryModel deal;
  final MasterItemModel? item;
  final VoidCallback onClose;

  const DealBreakdownDrawer({
    super.key,
    required this.deal,
    this.item,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if settlement data exists for the linked import file
    final settlementsAsync = ref.watch(financialSettlementProvider);
    ItemLandedCostModel? matchedItemCost;

    final settlements = settlementsAsync.valueOrNull ?? [];
    if (deal.importFileId != null && settlements.isNotEmpty) {
      for (final s in settlements) {
        if (s.importFileId == deal.importFileId) {
          if (item != null) {
            for (final ic in s.itemLandedCosts) {
              if (ic.itemCode.trim().toLowerCase() == item!.itemCode.trim().toLowerCase()) {
                matchedItemCost = ic;
                break;
              }
            }
          }
          break;
        }
      }
    }

    // Purchase & Landed Calculations
    final fobEgp = deal.unitPriceEgp ?? (deal.unitPriceFx * deal.exchangeRate);
    final landedEgp = deal.landedCostEgp ?? (fobEgp * (1.0 + ((deal.landedCostMarkup ?? 35.0) / 100.0)));
    final totalAddedCost = landedEgp > fobEgp ? landedEgp - fobEgp : 0.0;
    final markupPct = deal.landedCostMarkup ?? (fobEgp > 0 ? (totalAddedCost / fobEgp) * 100.0 : 0.0);
    final markupMultiplier = fobEgp > 0 ? landedEgp / fobEgp : 1.0;

    // Component breakdown amounts in EGP
    double customsDutyEgp;
    double freightEgp;
    double demurrageStorageEgp;
    double clearanceEgp;
    double transportEgp;
    double otherFeesEgp;

    if (matchedItemCost != null && matchedItemCost.allocatedCustomsEgp > 0) {
      customsDutyEgp = matchedItemCost.allocatedCustomsEgp;
      freightEgp = matchedItemCost.allocatedFreightEgp;
      clearanceEgp = matchedItemCost.allocatedClearanceEgp;
      transportEgp = matchedItemCost.allocatedTransportEgp;
      demurrageStorageEgp = matchedItemCost.allocatedOtherEgp * 0.45; // Port storage share
      otherFeesEgp = matchedItemCost.allocatedOtherEgp * 0.55;
    } else {
      customsDutyEgp = totalAddedCost * 0.48; // Approx ~48% of total addition
      freightEgp = totalAddedCost * 0.26;     // Approx ~26% of total addition
      demurrageStorageEgp = totalAddedCost * 0.08; // Approx ~8% demurrage & storage
      clearanceEgp = totalAddedCost * 0.07;   // Approx ~7% customs clearance
      transportEgp = totalAddedCost * 0.06;   // Approx ~6% inland transport
      otherFeesEgp = totalAddedCost * 0.05;   // Approx ~5% bank & port fees
    }

    void copyBreakdownReport() {
      final buffer = StringBuffer();
      buffer.writeln('# 📋 تقرير تفكيك تكلفة الوصول الفعلية للصفقة');
      buffer.writeln('**الصنف:** ${item?.itemCode ?? ''} - ${item?.descriptionAr ?? ''}');
      buffer.writeln('**أمر الشراء:** ${deal.poNumber ?? '-'} | **تاريخ الصفقة:** ${deal.poDate ?? '-'}');
      buffer.writeln('**ملف الاستيراد:** ${deal.importFileCode ?? '-'} | **المورد:** ${deal.supplierName ?? '-'}');
      buffer.writeln('---');
      buffer.writeln('### 1. ملخص القيمة وتكلفة الوصول');
      buffer.writeln('- **سعر الشراء (FOB):** ${deal.unitPriceFx.toStringAsFixed(2)} ${deal.currency} (ما يعادل ${fobEgp.toStringAsFixed(2)} ج.م @ ${deal.exchangeRate})');
      buffer.writeln('- **تكلفة الوصول الفعلية للوحدة:** ${landedEgp.toStringAsFixed(2)} ج.م');
      buffer.writeln('- **معامل الإضافة الإجمالي:** +${markupPct.toStringAsFixed(1)}% (${markupMultiplier.toStringAsFixed(3)}x)');
      buffer.writeln('- **إجمالي المصاريف المضافة للوحدة:** ${totalAddedCost.toStringAsFixed(2)} ج.م');
      buffer.writeln('---');
      buffer.writeln('### 2. عناصر التكلفة المفككة:');
      buffer.writeln('1. **الرسوم والضرائب الجمركية:** ${customsDutyEgp.toStringAsFixed(2)} ج.م (${totalAddedCost > 0 ? ((customsDutyEgp / totalAddedCost) * 100).toStringAsFixed(1) : '0'}%)');
      buffer.writeln('2. **النولون والشحن الدولي:** ${freightEgp.toStringAsFixed(2)} ج.م (${totalAddedCost > 0 ? ((freightEgp / totalAddedCost) * 100).toStringAsFixed(1) : '0'}%)');
      buffer.writeln('3. **أرضيات الموانئ وغرامات التأخير:** ${demurrageStorageEgp.toStringAsFixed(2)} ج.م (${totalAddedCost > 0 ? ((demurrageStorageEgp / totalAddedCost) * 100).toStringAsFixed(1) : '0'}%)');
      buffer.writeln('4. **أتعاب التخليص ومصاريف النافذة:** ${clearanceEgp.toStringAsFixed(2)} ج.م (${totalAddedCost > 0 ? ((clearanceEgp / totalAddedCost) * 100).toStringAsFixed(1) : '0'}%)');
      buffer.writeln('5. **النقل الداخلي والتعتيق:** ${transportEgp.toStringAsFixed(2)} ج.م (${totalAddedCost > 0 ? ((transportEgp / totalAddedCost) * 100).toStringAsFixed(1) : '0'}%)');
      buffer.writeln('6. **مصاريف وبنود أخرى:** ${otherFeesEgp.toStringAsFixed(2)} ج.م (${totalAddedCost > 0 ? ((otherFeesEgp / totalAddedCost) * 100).toStringAsFixed(1) : '0'}%)');

      CopyHelper.copy(
        context,
        buffer.toString(),
        customMessage: 'تم نسخ تقرير تفكيك التكلفة إلى الحافظة بنجاح',
      );
    }

    return Container(
      width: 480,
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.border,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pie_chart_rounded,
                  color: AppTheme.cobalt,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تفكيك تكلفة الوصول الفعلية',
                        style: TextStyle(
                          fontSize: density.tableHeaderFontSize + 1,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'أمر شراء: ${deal.poNumber ?? '-'} | ملف: ${deal.importFileCode ?? '-'}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'إغلاق اللوحة',
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Deal Summary Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppTheme.cardDecorationOf(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'قيمة الشراء الأصلية (FOB)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${deal.unitPriceFx.toStringAsFixed(2)} ${deal.currency}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'ما يعادل بالجنيه المصري',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${fobEgp.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'تكلفة الوصول الإجمالية (ج.م)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${landedEgp.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.cobalt,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'معامل الإضافة الجمركي',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.flatCobalt.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${markupPct.toStringAsFixed(1)}% (${markupMultiplier.toStringAsFixed(2)}x)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.flatCobalt,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'تفكيك عناصر التكلفة الإضافية (${totalAddedCost.toStringAsFixed(2)} ج.م):',
                    style: TextStyle(
                      fontSize: density.tableHeaderFontSize,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 1. Customs & Duties
                  _buildCostRow(
                    context: context,
                    isDark: isDark,
                    title: 'الرسوم والضرائب الجمركية',
                    amount: customsDutyEgp,
                    total: totalAddedCost,
                    color: AppTheme.flatEmerald,
                    icon: Icons.account_balance_outlined,
                  ),

                  // 2. Freight
                  _buildCostRow(
                    context: context,
                    isDark: isDark,
                    title: 'النولون والشحن الدولي',
                    amount: freightEgp,
                    total: totalAddedCost,
                    color: AppTheme.flatCobalt,
                    icon: Icons.directions_boat_outlined,
                  ),

                  // 3. Port Demurrage & Storage
                  _buildCostRow(
                    context: context,
                    isDark: isDark,
                    title: 'أرضيات الموانئ وغرامات التأخير',
                    amount: demurrageStorageEgp,
                    total: totalAddedCost,
                    color: AppTheme.flatOrange,
                    icon: Icons.timer_outlined,
                  ),

                  // 4. Customs Clearance & Brokerage
                  _buildCostRow(
                    context: context,
                    isDark: isDark,
                    title: 'أتعاب التخليص ومصاريف النافذة',
                    amount: clearanceEgp,
                    total: totalAddedCost,
                    color: const Color(0xFF8E44AD),
                    icon: Icons.assignment_outlined,
                  ),

                  // 5. Inland Transport
                  _buildCostRow(
                    context: context,
                    isDark: isDark,
                    title: 'النقل الداخلي والتعتيق',
                    amount: transportEgp,
                    total: totalAddedCost,
                    color: const Color(0xFF16A085),
                    icon: Icons.local_shipping_outlined,
                  ),

                  // 6. Other fees
                  _buildCostRow(
                    context: context,
                    isDark: isDark,
                    title: 'مصاريف وبنود أخرى',
                    amount: otherFeesEgp,
                    total: totalAddedCost,
                    color: Colors.blueGrey,
                    icon: Icons.more_horiz_rounded,
                  ),
                ],
              ),
            ),
          ),

          // Drawer Footer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.border,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'نسخ تفكيك التكلفة',
                    icon: Icons.copy_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.medium,
                    onPressed: copyBreakdownReport,
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'إغلاق',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.medium,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow({
    required BuildContext context,
    required bool isDark,
    required String title,
    required double amount,
    required double total,
    required Color color,
    required IconData icon,
  }) {
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final pctDisplay = (pct * 100.0).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
              ),
              Text(
                '${amount.toStringAsFixed(2)} ج.م',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$pctDisplay%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
