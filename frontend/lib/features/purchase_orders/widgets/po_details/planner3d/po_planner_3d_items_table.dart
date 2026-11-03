import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/container_requirement_engine.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../po_table_cells.dart';

class PoPlanner3dItemsTable extends StatefulWidget {
  final ContainerPackingResult res;

  const PoPlanner3dItemsTable({
    super.key,
    required this.res,
  });

  @override
  State<PoPlanner3dItemsTable> createState() => _PoPlanner3dItemsTableState();
}

class _PoPlanner3dItemsTableState extends State<PoPlanner3dItemsTable> {
  bool _showDetailedCoordinates = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final res = widget.res;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _showDetailedCoordinates
                  ? l.poDetailedPlacementCoordinatesPkgs(res.placedItems.length)
                  : l.poGroupedItemsItemsTotalPkgs(res.groupedItems.length, res.placedItems.length),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            AppButton(
              label: _showDetailedCoordinates ? l.poGroupByItems : l.poDetailedCoordinates,
              icon: _showDetailedCoordinates ? Icons.table_chart_outlined : Icons.format_list_numbered,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => setState(() => _showDetailedCoordinates = !_showDetailedCoordinates),
            ),
          ],
        ),
        children: [
          if (!_showDetailedCoordinates)
            Table(
              border: TableBorder.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
              ),
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
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        '#',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    PoHeaderCell(l.poItemCode, fontSize: 11),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.poPkgType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.poDimsCm,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.qtyCol,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.poGrossWt2,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.poCBM2,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.poStack,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                ...res.groupedItems.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final g = entry.value;
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          '$idx',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          g.itemCodeOrDesc,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          g.packageType,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          '${g.length.toStringAsFixed(0)} × ${g.width.toStringAsFixed(0)} × ${g.height.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${g.count}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cobalt,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          '${g.totalWeight.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          '${g.volumeM3.toStringAsFixed(3)} m³',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.orange,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          g.isStackable ? l.poYes : l.poFloor,
                          style: TextStyle(
                            fontSize: 11,
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
              border: TableBorder.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
              ),
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
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        '#',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    PoHeaderCell(l.thPackageCode, fontSize: 11),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.thDimensions,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.thWeight,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.thCoordinates,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.thStacking,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                ...res.placedItems.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          '$idx',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          item.item.description ?? item.item.itemId,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          '${item.length.toStringAsFixed(0)} × ${item.width.toStringAsFixed(0)} × ${item.height.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          item.item.weight.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          'X: ${item.x.toStringAsFixed(0)} | Y: ${item.y.toStringAsFixed(0)} | Z: ${item.z.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          item.item.isStackable ? l.poYes : l.poFloor,
                          style: TextStyle(
                            fontSize: 11,
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
    );
  }
}
