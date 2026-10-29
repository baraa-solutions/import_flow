import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/item_price_history_model.dart';
import '../models/item_price_trends_model.dart';

/// 2️⃣ Price History Timeline Table (MD-ITEM-001 / Session 3)
/// Timeline of 10+ historical procurement deals, landed cost in EGP,
/// and customs/logistics markup percentage with deep-dive inspection.
class PriceHistoryTimelineTable extends ConsumerStatefulWidget {
  final ItemPriceTrendsModel trends;
  final ValueChanged<ItemPriceHistoryModel>? onInspectBreakdown;

  const PriceHistoryTimelineTable({
    super.key,
    required this.trends,
    this.onInspectBreakdown,
  });

  @override
  ConsumerState<PriceHistoryTimelineTable> createState() =>
      _PriceHistoryTimelineTableState();
}

class _PriceHistoryTimelineTableState
    extends ConsumerState<PriceHistoryTimelineTable> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _copyTableAsTsv(BuildContext context) {
    final headers = [
      '#',
      'تاريخ الصفقة',
      'أمر الشراء',
      'ملف الاستيراد',
      'المورد',
      'الكمية',
      'سعر الوحدة أجنبي',
      'العملة',
      'سعر الصرف',
      'سعر الشراء (ج.م)',
      'تكلفة الوصول (ج.م)',
      'نسبة الإضافة %',
    ];

    final rows = widget.trends.history.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final h = entry.value;
      return [
        idx.toString(),
        h.poDate ?? '',
        h.poNumber ?? '',
        h.importFileCode ?? '',
        h.supplierName ?? '',
        h.quantity?.toStringAsFixed(0) ?? '',
        h.unitPriceFx.toStringAsFixed(2),
        h.currency,
        h.exchangeRate.toStringAsFixed(2),
        h.unitPriceEgp?.toStringAsFixed(2) ?? '',
        h.landedCostEgp?.toStringAsFixed(2) ?? '',
        h.landedCostMarkup != null ? '${h.landedCostMarkup!.toStringAsFixed(1)}%' : '',
      ];
    }).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }

  @override
  Widget build(BuildContext context) {
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final history = widget.trends.history;

    // Identify lowest and highest price records for visual highlights
    double minPrice = double.infinity;
    double maxPrice = -double.infinity;
    for (final h in history) {
      if (h.unitPriceFx < minPrice) minPrice = h.unitPriceFx;
      if (h.unitPriceFx > maxPrice) maxPrice = h.unitPriceFx;
    }

    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header Bar
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
                  Icons.history_edu_rounded,
                  size: 20,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.cobalt,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'سجل الصفقات التاريخية وتكلفة الوصول الفعلية',
                          style: TextStyle(
                            fontSize: density.tableHeaderFontSize + 1,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${history.length} صفقات مسجلة',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cobalt,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'نسخ جدول البيانات',
                  icon: Icons.copy_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: history.isEmpty ? null : () => _copyTableAsTsv(context),
                ),
              ],
            ),
          ),

          // Table Content Area
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.black26,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'لا توجد صفقات سابقة مسجلة لهذا الصنف حتى الآن',
                      style: TextStyle(
                        fontSize: density.tableCellPrimaryFontSize,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 1080),
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: 52,
                    horizontalMargin: 16,
                    columnSpacing: 18,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    ),
                    columns: const [
                      DataColumn(label: Text('#', style: _headerStyle)),
                      DataColumn(label: Text('تاريخ الصفقة', style: _headerStyle)),
                      DataColumn(label: Text('أمر الشراء', style: _headerStyle)),
                      DataColumn(label: Text('ملف الاستيراد', style: _headerStyle)),
                      DataColumn(label: Text('المورد', style: _headerStyle)),
                      DataColumn(numeric: true, label: Text('الكمية', style: _headerStyle)),
                      DataColumn(numeric: true, label: Text('سعر الوحدة (أجنبي)', style: _headerStyle)),
                      DataColumn(numeric: true, label: Text('سعر الصرف', style: _headerStyle)),
                      DataColumn(numeric: true, label: Text('سعر الشراء (ج.م)', style: _headerStyle)),
                      DataColumn(numeric: true, label: Text('تكلفة الوصول (ج.م)', style: _headerStyle)),
                      DataColumn(numeric: true, label: Text('نسبة الإضافة', style: _headerStyle)),
                      DataColumn(label: Text('الإجراء', style: _headerStyle)),
                    ],
                    rows: history.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final deal = entry.value;
                      final isLowest = deal.unitPriceFx == minPrice && history.length > 1;
                      final isHighest = deal.unitPriceFx == maxPrice && history.length > 1;

                      final rowBg = isLowest
                          ? (isDark ? const Color(0x1A27AE60) : const Color(0x142ECC71))
                          : isHighest
                              ? (isDark ? const Color(0x1AC0392B) : const Color(0x12E74C3C))
                              : Colors.transparent;

                      final markup = deal.landedCostMarkup;
                      Color markupColor = AppTheme.charcoal;
                      if (markup != null) {
                        if (markup <= 25.0) {
                          markupColor = AppTheme.flatEmerald;
                        } else if (markup <= 45.0) {
                          markupColor = AppTheme.flatCobalt;
                        } else {
                          markupColor = AppTheme.flatOrange;
                        }
                      }

                      return DataRow(
                        color: WidgetStateProperty.all(rowBg),
                        cells: [
                          // #
                          DataCell(Text(
                            idx.toString(),
                            style: TextStyle(
                              fontSize: density.tableCellSecondaryFontSize,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                            ),
                          )),

                          // Deal Date
                          DataCell(Text(
                            deal.poDate ?? '-',
                            style: TextStyle(
                              fontSize: density.tableCellPrimaryFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          )),

                          // PO Number
                          DataCell(
                            InkWell(
                              onTap: deal.poNumber != null
                                  ? () => CopyHelper.copy(context, deal.poNumber!)
                                  : null,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    deal.poNumber ?? '-',
                                    style: TextStyle(
                                      fontSize: density.tableCellPrimaryFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.cobalt,
                                    ),
                                  ),
                                  if (deal.poNumber != null) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 13,
                                      color: AppTheme.cobalt.withValues(alpha: 0.7),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Import File Code
                          DataCell(
                            InkWell(
                              onTap: deal.importFileCode != null
                                  ? () => CopyHelper.copy(context, deal.importFileCode!)
                                  : null,
                              child: Text(
                                deal.importFileCode ?? '-',
                                style: TextStyle(
                                  fontSize: density.tableCellPrimaryFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          // Supplier Name
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                deal.supplierName ?? '-',
                                style: TextStyle(
                                  fontSize: density.tableCellPrimaryFontSize,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),

                          // Quantity
                          DataCell(Text(
                            deal.quantity?.toStringAsFixed(0) ?? '-',
                            style: TextStyle(
                              fontSize: density.tableCellPrimaryFontSize,
                              fontFamily: 'monospace',
                            ),
                          )),

                          // Unit Price FX
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${deal.unitPriceFx.toStringAsFixed(2)} ${deal.currency}',
                                style: TextStyle(
                                  fontSize: density.tableCellPrimaryFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: isLowest
                                      ? AppTheme.flatEmerald
                                      : isHighest
                                          ? AppTheme.flatCrimson
                                          : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                              ),
                              if (isLowest) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.flatEmerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'أقل',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.flatEmerald,
                                    ),
                                  ),
                                ),
                              ] else if (isHighest) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.flatCrimson.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'أعلى',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.flatCrimson,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )),

                          // Exchange Rate
                          DataCell(Text(
                            deal.exchangeRate.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: density.tableCellPrimaryFontSize,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                            ),
                          )),

                          // Unit Price EGP
                          DataCell(Text(
                            deal.unitPriceEgp != null
                                ? '${deal.unitPriceEgp!.toStringAsFixed(2)} ج.م'
                                : '-',
                            style: TextStyle(
                              fontSize: density.tableCellPrimaryFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          )),

                          // Landed Cost EGP
                          DataCell(Text(
                            deal.landedCostEgp != null
                                ? '${deal.landedCostEgp!.toStringAsFixed(2)} ج.م'
                                : 'قيد التسوية',
                            style: TextStyle(
                              fontSize: density.tableCellPrimaryFontSize,
                              fontWeight: FontWeight.bold,
                              color: deal.landedCostEgp != null
                                  ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)
                                  : Colors.grey,
                            ),
                          )),

                          // Markup %
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: markupColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              deal.landedCostMarkup != null
                                  ? '+${deal.landedCostMarkup!.toStringAsFixed(1)}%'
                                  : '-',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: markupColor,
                              ),
                            ),
                          )),

                          // Action: Inspect Breakdown
                          DataCell(
                            IconButton(
                              icon: const Icon(
                                Icons.pie_chart_outline_rounded,
                                size: 19,
                                color: AppTheme.cobalt,
                              ),
                              tooltip: 'تفكيك تكلفة الوصول',
                              onPressed: () {
                                widget.onInspectBreakdown?.call(deal);
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 12.5,
  fontFamily: 'Cairo',
);
