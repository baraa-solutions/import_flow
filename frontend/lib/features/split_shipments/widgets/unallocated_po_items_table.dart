import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../split_shipments_provider.dart';

/// Table displaying purchase order items and their remaining unallocated quantities.
class UnallocatedPoItemsTable extends StatelessWidget {
  final List<UnallocatedPoItem> items;
  final ValueChanged<UnallocatedPoItem> onAllocate;

  const UnallocatedPoItemsTable({
    super.key,
    required this.items,
    required this.onAllocate,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text(
          'جميع بنود أوامر الشراء موزعة ومخصصة بالكامل للبوالص',
          style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold),
        ),
      );
    }

    return LayoutBuilder(
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
                DataColumn(label: Text('أمر الشراء', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('رمز الصنف', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('اسم البند', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الكمية المطلوبة', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('المخصص سابقاً', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('المتبقي للتجزئة', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الإجراء', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: items.map((item) {
                final rem = item.remainingQuantity;
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.poNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14, color: AppTheme.textSecondary),
                            tooltip: 'نسخ رقم أمر الشراء',
                            onPressed: () => CopyHelper.copy(context, item.poNumber),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(item.itemSku, style: const TextStyle(color: AppTheme.cobalt))),
                    DataCell(Text(item.itemName)),
                    DataCell(Text(item.totalQuantity.toStringAsFixed(0))),
                    DataCell(Text(item.allocatedQuantity.toStringAsFixed(0))),
                    DataCell(
                      Text(
                        rem.toStringAsFixed(0),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rem > 0 ? AppTheme.orange : AppTheme.emerald,
                        ),
                      ),
                    ),
                    DataCell(
                      AppButton(
                        label: 'تخصيص لبوليصة',
                        icon: Icons.call_split,
                        variant: AppButtonVariant.primary,
                        onPressed: rem > 0 ? () => onAllocate(item) : null,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
