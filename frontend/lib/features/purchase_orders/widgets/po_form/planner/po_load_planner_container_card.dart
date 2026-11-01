import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/container_requirement_engine.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../../../core/widgets/container_load_plan_painter.dart';
import '../../../utils/po_packing_matcher.dart';

class PoLoadPlannerContainerCard extends StatelessWidget {
  final int index;
  final ContainerPackingResult res;
  final String viewProjection;
  final bool showDetailedCoordinates;
  final bool isArabic;
  final VoidCallback onToggleDetailedCoordinates;

  const PoLoadPlannerContainerCard({
    super.key,
    required this.index,
    required this.res,
    required this.viewProjection,
    required this.showDetailedCoordinates,
    required this.isArabic,
    required this.onToggleDetailedCoordinates,
  });

  @override
  Widget build(BuildContext context) {
    if (res.containerCode == 'FAILED') {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.crimsonLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.crimsonBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                res.failureReason ?? context.l10n.packingFailureTitle,
                style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final spacePct = (res.totalVolume / res.spec.internalVolumeCbm * 100);
    final weightPct = (res.totalWeight / res.spec.maxPayloadKg * 100);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    context.l10n.containerCardHeader(
                      index + 1,
                      res.spec.code,
                      res.placedItems.length,
                      spacePct.toStringAsFixed(1),
                      weightPct.toStringAsFixed(1),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.internalDimensionsLabel(
                      res.spec.internalLength.toStringAsFixed(0),
                      res.spec.internalWidth.toStringAsFixed(0),
                      res.spec.internalHeight.toStringAsFixed(0),
                    ),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (viewProjection == 'both') ...[
              // Side View
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                ),
              ),
              const SizedBox(height: 10),
              // Top View
              Container(
                height: 155,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                ),
              ),
            ] else ...[
              Container(
                height: 360,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: ContainerLoadPlanPainter(plan: res, isTopView: viewProjection == 'top'),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Placed Items Details Table
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      showDetailedCoordinates
                          ? (isArabic
                              ? '📐 تفاصيل الرص الإحداثي (${res.placedItems.length} طرد)'
                              : '📐 Coordinate Stacking Details (${res.placedItems.length} pkgs)')
                          : (isArabic
                              ? '📊 الأصناف المرصوصة مجمعة (${res.groupedItems.length} صنف | إجمالي ${res.placedItems.length} طرد)'
                              : '📊 Grouped Items (${res.groupedItems.length} items | total ${res.placedItems.length} pkgs)'),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    AppButton(
                      label: showDetailedCoordinates
                          ? (isArabic ? 'عرض مجمع حسب الأصناف' : 'Grouped View')
                          : (isArabic ? 'عرض تفصيلي بالإحداثيات' : 'Coordinate View'),
                      icon: showDetailedCoordinates ? Icons.table_chart_outlined : Icons.format_list_numbered,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: onToggleDetailedCoordinates,
                    ),
                  ],
                ),
                children: [
                  if (!showDetailedCoordinates)
                    Table(
                      border: TableBorder.all(color: AppTheme.cloudWhite),
                      columnWidths: const {
                        0: FlexColumnWidth(0.6),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.6),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(1.8),
                        6: FlexColumnWidth(1.2),
                        7: FlexColumnWidth(1.2),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: AppTheme.cloudWhite),
                          children: [
                            const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الصنف' : 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'نوع الطرد' : 'Package Type', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الأبعاد (سم)' : 'Dimensions (cm)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'العدد' : 'Qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'إجمالي الوزن' : 'Total Weight', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الحجم' : 'Volume', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الرص' : 'Stacking', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          ],
                        ),
                        ...res.groupedItems.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final g = entry.value;
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(6), child: Text(g.itemCodeOrDesc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(g.packageType, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${g.length.toStringAsFixed(0)} × ${g.width.toStringAsFixed(0)} × ${g.height.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${g.count}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt), textAlign: TextAlign.center),
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${PoPackingMatcher.formatWeight(g.totalWeight)} kg', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${g.volumeM3.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  g.isStackable
                                      ? (isArabic ? '📦 نعم' : '📦 Yes')
                                      : (isArabic ? '🚫 أرضي' : '🚫 Floor'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: g.isStackable ? AppTheme.emerald : AppTheme.crimson,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    )
                  else
                    Table(
                      border: TableBorder.all(color: AppTheme.cloudWhite),
                      columnWidths: const {
                        0: FlexColumnWidth(0.8),
                        1: FlexColumnWidth(2.2),
                        2: FlexColumnWidth(1.8),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(2.0),
                        5: FlexColumnWidth(1.2),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: AppTheme.cloudWhite),
                          children: [
                            const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thPackageCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thDimensions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thCoordinates, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thStacking, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          ],
                        ),
                        ...res.placedItems.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final item = entry.value;
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(6), child: Text(item.item.description ?? item.item.itemId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.length.toStringAsFixed(0)} × ${item.width.toStringAsFixed(0)} × ${item.height.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(6), child: Text(PoPackingMatcher.formatWeight(item.item.weight), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(6), child: Text('X: ${item.x.toStringAsFixed(0)} | Y: ${item.y.toStringAsFixed(0)} | Z: ${item.z.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'), textAlign: TextAlign.center)),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  item.item.isStackable
                                      ? (isArabic ? '📦 نعم' : '📦 Yes')
                                      : (isArabic ? '🚫 أرضي' : '🚫 Floor'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: item.item.isStackable ? AppTheme.emerald : AppTheme.crimson,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
