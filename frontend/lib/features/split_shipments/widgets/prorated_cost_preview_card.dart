import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../split_shipments_provider.dart';

/// Card previewing the fair prorated landed cost breakdown across split B/Ls.
class ProratedCostPreviewCard extends StatelessWidget {
  final List<SplitAllocationData> allocations;
  final VoidCallback onRecalculatePool;

  const ProratedCostPreviewCard({
    super.key,
    required this.allocations,
    required this.onRecalculatePool,
  });

  @override
  Widget build(BuildContext context) {
    if (allocations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text(
          'لا توجد بوالص شحن مجزأة مسجلة حالياً',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final totalCustoms = allocations.fold(0.0, (acc, item) => acc + item.proratedCustomsCost);
    final totalFreight = allocations.fold(0.0, (acc, item) => acc + item.proratedFreightCost);
    final totalLanded = totalCustoms + totalFreight;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart, color: AppTheme.cobalt, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'توزيع التكاليف التناسبية على البوالص المجزأة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                    ),
                  ],
                ),
                AppButton(
                  label: 'تحديث مجمع التكاليف',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.secondary,
                  onPressed: onRecalculatePool,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Allocations table
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAlt),
                      dataRowMinHeight: 46,
                      dataRowMaxHeight: 52,
                      columns: const [
                        DataColumn(label: Text('البوليصة المجزأة', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('رمز الصنف', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('الكمية المخصصة', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('نسبة التخصيص', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('جمارك تناسبية', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('نولون تناسبي', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('إجمالي التكلفة', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: allocations.map((alloc) {
                        final itemTotal = alloc.proratedCustomsCost + alloc.proratedFreightCost;
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    alloc.splitBlNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 14, color: AppTheme.textSecondary),
                                    tooltip: 'نسخ رقم البوليصة الجزئية',
                                    onPressed: () => CopyHelper.copy(context, alloc.splitBlNumber),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(alloc.itemSku)),
                            DataCell(Text('${alloc.allocatedQuantity.toStringAsFixed(0)} وحدة')),
                            DataCell(Text('${(alloc.allocationRatio * 100).toStringAsFixed(1)}%')),
                            DataCell(Text('${alloc.proratedCustomsCost.toStringAsFixed(2)} ${alloc.currency}')),
                            DataCell(Text('${alloc.proratedFreightCost.toStringAsFixed(2)} ${alloc.currency}')),
                            DataCell(
                              Text(
                                '${itemTotal.toStringAsFixed(2)} ${alloc.currency}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 32),

            // Summary Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('إجمالي الجمارك الموزعة', '${totalCustoms.toStringAsFixed(2)} جنيه'),
                    const SizedBox(width: 16),
                    _buildSummaryItem('إجمالي النولون الموزع', '${totalFreight.toStringAsFixed(2)} جنيه'),
                    const SizedBox(width: 16),
                    _buildSummaryItem('إجمالي التكلفة التناسبية', '${totalLanded.toStringAsFixed(2)} جنيه', isBold: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppTheme.cobalt : AppTheme.charcoal,
          ),
        ),
      ],
    );
  }
}
