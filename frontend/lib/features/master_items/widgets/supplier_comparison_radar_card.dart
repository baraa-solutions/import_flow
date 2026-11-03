import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../models/item_supplier_catalog_model.dart';
import '../models/master_item_model.dart';
import '../providers/master_items_provider.dart';
import 'item_supplier_mapping_dialog.dart';

/// 3️⃣ Supplier Comparison Radar Card (MD-ITEM-001 / Session 3)
/// Cross-supplier multi-quote comparison for the same item:
/// Quoted Price, Variance from Best Price, Incoterms, Lead Time, and MOQ.
class SupplierComparisonRadarCard extends ConsumerWidget {
  final MasterItemModel item;

  const SupplierComparisonRadarCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suppliersAsync = ref.watch(itemSuppliersProvider(item.itemId));

    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.border,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 20,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.cobalt,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مقارنة أسعار الموردين وعروض الشراء المعتمدة',
                    style: TextStyle(
                      fontSize: density.tableHeaderFontSize + 1,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'ربط مورد جديد',
                  icon: Icons.person_add_alt_1_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ItemSupplierMappingDialog(item: item),
                    );
                  },
                ),
              ],
            ),
          ),

          // Content Area
          suppliersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppLoadingState(message: 'جاري تحميل عروض وموردي الصنف...'),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(
                  'تعذر تحميل قائمة الموردين: $err',
                  style: const TextStyle(color: AppTheme.crimson),
                ),
              ),
            ),
            data: (suppliers) {
              if (suppliers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.store_mall_directory_outlined,
                          size: 44,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.black26,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'لا يوجد موردون مسجلون لهذا الصنف في الدليل حتى الآن',
                          style: TextStyle(
                            fontSize: density.tableCellPrimaryFontSize,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'إضافة أول مورد للصنف',
                          icon: Icons.add_link_rounded,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => ItemSupplierMappingDialog(item: item),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Determine best price among suppliers with confirmed price
              final pricedSuppliers = suppliers
                  .where((s) => s.lastConfirmedPrice != null && s.lastConfirmedPrice! > 0)
                  .toList();

              double bestPrice = double.infinity;
              double highestPrice = 0.0;
              for (final s in pricedSuppliers) {
                final p = s.lastConfirmedPrice!;
                if (p < bestPrice) bestPrice = p;
                if (p > highestPrice) highestPrice = p;
              }

              final savingsPct = highestPrice > 0 && bestPrice < double.infinity
                  ? ((highestPrice - bestPrice) / highestPrice) * 100.0
                  : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Suppliers Table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 880),
                      child: DataTable(
                        headingRowHeight: 38,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 50,
                        horizontalMargin: 16,
                        columnSpacing: 18,
                        headingRowColor: WidgetStateProperty.all(
                          isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        ),
                        columns: const [
                          DataColumn(label: Text('#', style: _colHeaderStyle)),
                          DataColumn(label: Text('المورد', style: _colHeaderStyle)),
                          DataColumn(label: Text('كود الصنف لديه', style: _colHeaderStyle)),
                          DataColumn(numeric: true, label: Text('آخر سعر معتمد', style: _colHeaderStyle)),
                          DataColumn(numeric: true, label: Text('الفارق عن الأفضل', style: _colHeaderStyle)),
                          DataColumn(label: Text('شرط التسليم', style: _colHeaderStyle)),
                          DataColumn(numeric: true, label: Text('مدة التوريد', style: _colHeaderStyle)),
                          DataColumn(numeric: true, label: Text('الحد الأدنى للطلب', style: _colHeaderStyle)),
                          DataColumn(label: Text('الحالة', style: _colHeaderStyle)),
                        ],
                        rows: suppliers.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final s = entry.value;
                          final price = s.lastConfirmedPrice;
                          final isBestPrice = price != null && price == bestPrice && pricedSuppliers.length > 1;

                          double? variance;
                          if (price != null && bestPrice < double.infinity && bestPrice > 0) {
                            variance = ((price - bestPrice) / bestPrice) * 100.0;
                          }

                          return DataRow(
                            cells: [
                              // #
                              DataCell(Text(
                                idx.toString(),
                                style: TextStyle(
                                  fontSize: density.tableCellSecondaryFontSize,
                                  color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                                ),
                              )),

                              // Supplier Name
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    s.supplierName ?? 'مورد #${s.supplierId}',
                                    style: TextStyle(
                                      fontSize: density.tableCellPrimaryFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                  ),
                                  if (s.isPreferredSupplier) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.flatCobalt.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'مفضل',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.flatCobalt,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              )),

                              // Supplier Part Code
                              DataCell(Text(
                                s.supplierItemCode ?? '-',
                                style: TextStyle(
                                  fontSize: density.tableCellPrimaryFontSize,
                                  fontFamily: 'monospace',
                                ),
                              )),

                              // Last Confirmed Price
                              DataCell(Text(
                                price != null
                                    ? '${price.toStringAsFixed(2)} ${s.lastConfirmedCurrency}'
                                    : 'غير مسجل',
                                style: TextStyle(
                                  fontSize: density.tableCellPrimaryFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: isBestPrice
                                      ? AppTheme.flatEmerald
                                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                              )),

                              // Variance from Best Price
                              DataCell(
                                isBestPrice
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.flatEmerald.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'أفضل سعر',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.flatEmerald,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        variance != null
                                            ? '+${variance.toStringAsFixed(1)}%'
                                            : '-',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: variance != null && variance > 10.0
                                              ? AppTheme.flatCrimson
                                              : Colors.black54,
                                        ),
                                      ),
                              ),

                              // Incoterm
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  s.preferredIncoterm ?? 'FOB',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )),

                              // Lead Time Days
                              DataCell(Text(
                                s.leadTimeDays != null ? '${s.leadTimeDays} يوم' : '-',
                                style: TextStyle(
                                  fontSize: density.tableCellPrimaryFontSize,
                                ),
                              )),

                              // Min Order Qty
                              DataCell(Text(
                                s.minOrderQtyFormatted,
                                style: TextStyle(
                                  fontSize: density.tableCellPrimaryFontSize,
                                  fontFamily: 'monospace',
                                ),
                              )),

                              // Active Status
                              DataCell(
                                Icon(
                                  s.isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                                  size: 16,
                                  color: s.isActive ? AppTheme.flatEmerald : AppTheme.flatCrimson,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Bottom Comparison Analysis Banner
                  if (pricedSuppliers.length > 1 && savingsPct > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.flatEmerald.withValues(alpha: 0.08),
                        border: Border(
                          top: BorderSide(
                            color: AppTheme.flatEmerald.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: AppTheme.flatEmerald,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تحليل وفورات التوريد: الشراء من المورد صاحب أفضل سعر يوفر حتى ${savingsPct.toStringAsFixed(1)}% مقارنة بأعلى عرض معتمد.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.flatEmerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

extension on ItemSupplierCatalogModel {
  String get minOrderQtyFormatted {
    if (minOrderQty == null) return '-';
    if (minOrderQty == minOrderQty!.truncateToDouble()) {
      return minOrderQty!.toInt().toString();
    }
    return minOrderQty!.toStringAsFixed(1);
  }
}

const TextStyle _colHeaderStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 12,
  fontFamily: 'Cairo',
);
