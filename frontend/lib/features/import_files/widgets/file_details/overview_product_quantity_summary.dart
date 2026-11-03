// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../models/import_file_model.dart';
import 'overview_hs_code_summary_section.dart';

/// 📦 Product & Quantity Summary section for Overview Tab
class OverviewProductQuantitySummary extends ConsumerWidget {
  final ImportFileModel file;
  final List<PurchaseOrderModel> linkedPOs;
  final bool isAr;
  final bool isDark;

  const OverviewProductQuantitySummary({
    super.key,
    required this.file,
    required this.linkedPOs,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItems = <({
      String description,
      String hsCode,
      double quantity,
      String uom,
      double unitPrice,
      String currency,
      String poNumber,
    })>[];

    for (final po in linkedPOs) {
      if (po.items.isNotEmpty) {
        for (final item in po.items) {
          String resolvedHs = item.hsCode?.trim() ?? '';
          if (resolvedHs.isEmpty && po.packingListItems.isNotEmpty) {
            for (final pl in po.packingListItems) {
              if (pl.hsCode.trim().isNotEmpty) {
                resolvedHs = pl.hsCode.trim();
                break;
              }
            }
          }
          if (resolvedHs.isEmpty && file.hsCode != null) {
            resolvedHs = file.hsCode!.trim();
          }
          allItems.add((
            description: item.itemDescription.trim().isNotEmpty
                ? item.itemDescription.trim()
                : (isAr ? 'منتج غير محدد' : 'Unnamed Product'),
            hsCode: resolvedHs,
            quantity: item.quantity,
            uom: item.unitOfMeasure,
            unitPrice: item.unitPrice,
            currency: po.currencyCode ?? 'USD',
            poNumber: po.poNumber,
          ));
        }
      } else if (po.packingListItems.isNotEmpty) {
        for (final pl in po.packingListItems) {
          allItems.add((
            description: pl.mainDescription?.trim().isNotEmpty == true
                ? pl.mainDescription!.trim()
                : (pl.description?.trim().isNotEmpty == true
                    ? pl.description!.trim()
                    : (isAr ? 'منتج غير محدد' : 'Unnamed Product')),
            hsCode: pl.hsCode.trim(),
            quantity: pl.qtyPcs > 0 ? pl.qtyPcs : pl.qtyPkg,
            uom: pl.packageType.trim().isNotEmpty ? pl.packageType.trim() : 'CTN',
            unitPrice: 0.0,
            currency: po.currencyCode ?? 'USD',
            poNumber: po.poNumber,
          ));
        }
      }
    }

    if (allItems.isEmpty && file.packingListsData.isNotEmpty) {
      for (final pl in file.packingListsData) {
        allItems.add((
          description: file.productCategory ?? (isAr ? 'قائمة تعبئة (${pl.plNo})' : 'Packing List (${pl.plNo})'),
          hsCode: file.hsCode ?? '',
          quantity: pl.totalPackages.toDouble(),
          uom: 'PKG',
          unitPrice: 0.0,
          currency: 'USD',
          poNumber: file.poNumber ?? file.importFileCode,
        ));
      }
    }

    if (allItems.isEmpty) return const SizedBox.shrink();

    final distinctHsCodes = <String>{};
    for (final item in allItems) {
      if (item.hsCode.isNotEmpty) distinctHsCodes.add(item.hsCode);
    }
    final hsCodes = distinctHsCodes.toList()..sort();

    const headerStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 11,
    );

    Widget buildTable(List<dynamic> items) {
      return Table(
        border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
        columnWidths: const {
          0: FlexColumnWidth(3.0),
          1: FlexColumnWidth(1.4),
          2: FlexColumnWidth(1.0),
          3: FlexColumnWidth(1.0),
          4: FlexColumnWidth(1.2),
          5: FlexColumnWidth(1.4),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal),
            children: [
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'المنتج / البيان' : 'Product / Description', style: headerStyle)),
              const Padding(padding: EdgeInsets.all(7), child: Text('HS Code', style: headerStyle)),
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'الكمية' : 'Qty', style: headerStyle)),
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'الوحدة' : 'UOM', style: headerStyle)),
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'سعر الوحدة' : 'Unit Price', style: headerStyle)),
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'أمر التوريد' : 'PO No.', style: headerStyle)),
            ],
          ),
          ...items.map((rawItem) {
            final item = rawItem as ({
              String description,
              String hsCode,
              double quantity,
              String uom,
              double unitPrice,
              String currency,
              String poNumber,
            });
            final evenRow = items.indexOf(rawItem).isEven;
            return TableRow(
              decoration: BoxDecoration(
                color: evenRow
                    ? (isDark ? AppTheme.darkSurface : null)
                    : (isDark ? AppTheme.darkCardBackground : Colors.grey.shade50),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(
                    item.description,
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: item.hsCode.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: isDark ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                          ),
                          child: LtrText(
                            item.hsCode,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                            ),
                          ),
                        )
                      : Text('—', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(
                    item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(2),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(item.uom, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(
                    item.unitPrice > 0 ? '${item.currency} ${item.unitPrice.toStringAsFixed(2)}' : '—',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.green.shade300 : Colors.green.shade700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: LtrText(
                    item.poNumber,
                    style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextMuted : Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface.withValues(alpha: 0.5) : AppTheme.emerald.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.emerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: isDark ? Colors.green.shade300 : AppTheme.emerald, size: 18),
              const SizedBox(width: 8),
              Text(
                isAr ? '📦 ملخص المنتجات والكميات' : '📦 Product & Quantity Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.green.shade900 : AppTheme.emerald).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? Colors.green.shade700 : AppTheme.emerald.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${allItems.length} ${isAr ? 'بند' : 'items'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.green.shade300 : AppTheme.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hsCodes.length > 1) ...[
            DefaultTabController(
              length: hsCodes.length + 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                    child: TabBar(
                      isScrollable: true,
                      indicatorColor: AppTheme.emerald,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(
                          child: Text(
                            isAr ? 'الكل (${allItems.length})' : 'All (${allItems.length})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...hsCodes.map((hs) {
                          final count = allItems.where((i) => i.hsCode == hs).length;
                          return Tab(
                            child: Text(
                              '$hs ($count)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: (allItems.length.clamp(1, 8) * 36.0) + 40,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(child: buildTable(allItems)),
                        ...hsCodes.map((hs) {
                          final filtered = allItems.where((i) => i.hsCode == hs).toList();
                          return SingleChildScrollView(child: buildTable(filtered));
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            buildTable(allItems),
          ],
          OverviewHsCodeSummarySection(
            hsCodes: hsCodes,
            allItems: allItems,
            countryOfOrigin: linkedPOs.firstOrNull?.countryOfOrigin,
            isDark: isDark,
            isAr: isAr,
          ),
        ],
      ),
    );
  }
}
