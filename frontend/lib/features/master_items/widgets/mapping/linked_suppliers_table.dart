import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/states/app_empty_state.dart';
import '../../../../core/widgets/states/app_loading_state.dart';
import '../../models/item_supplier_catalog_model.dart';

/// Table displaying linked overseas suppliers for a master item
class LinkedSuppliersTable extends StatelessWidget {
  final AsyncValue<List<ItemSupplierCatalogModel>> linkedSuppliersAsync;

  const LinkedSuppliersTable({
    super.key,
    required this.linkedSuppliersAsync,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return linkedSuppliersAsync.when(
      loading: () => const AppLoadingState.section(),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.crimson.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'خطأ أثناء تحميل الموردين المرتبطين: $err',
          style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
        ),
      ),
      data: (catalogs) {
        if (catalogs.isEmpty) {
          return const AppEmptyState(
            message: 'لا يوجد موردون مسجلون لهذا الصنف حالياً',
            subtitle: 'قم بالنقر على "ربط مورد جديد" لإضافة كود المورد وعرض السعر المعتمد.',
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.6),
              1: FlexColumnWidth(2.2),
              2: FlexColumnWidth(2.0),
              3: FlexColumnWidth(1.4),
              4: FlexColumnWidth(1.4),
              5: FlexColumnWidth(1.8),
            },
            border: TableBorder(
              horizontalInside: BorderSide(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      'المورد الأجنبي',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      'كود الصنف عند المورد (Part #)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      'آخر سعر شراء معتمد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      'شرط الشحن (Incoterm)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      'مدة التوريد (أيام)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      'المورد المفضل',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              ...catalogs.map((cat) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        cat.supplierName ?? 'مورد #${cat.supplierId}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        cat.supplierItemCode ?? '—',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        cat.lastConfirmedPrice != null
                            ? '${cat.lastConfirmedPrice!.toStringAsFixed(2)} ${cat.lastConfirmedCurrency}'
                            : '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emerald,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        cat.preferredIncoterm ?? '—',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        cat.leadTimeDays != null ? '${cat.leadTimeDays} يوم' : '—',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: cat.isPreferredSupplier
                          ? const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                  SizedBox(width: 4),
                                  Text('المفضل', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                                ],
                              ),
                            )
                          : const Text('—', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
