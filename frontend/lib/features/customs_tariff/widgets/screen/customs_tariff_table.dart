import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_tariff_model.dart';
import 'customs_tariff_export_helper.dart';

class CustomsTariffTable extends StatelessWidget {
  final List<CustomsTariffModel> tariffs;
  final ValueChanged<CustomsTariffModel> onViewDetails;
  final ValueChanged<CustomsTariffModel> onEdit;
  final ValueChanged<CustomsTariffModel> onPrint;
  final ValueChanged<CustomsTariffModel> onToggleActive;

  const CustomsTariffTable({
    super.key,
    required this.tariffs,
    required this.onViewDetails,
    required this.onEdit,
    required this.onPrint,
    required this.onToggleActive,
  });

  static Color getCategoryColor(String? category) {
    switch (category) {
      case 'ELECTRONICS':
      case 'Electronics':
        return AppTheme.cobalt;
      case 'AUTOMOTIVE':
      case 'AUTOMOTIVE_SPARE_PARTS':
      case 'Automotive':
      case 'Automotive Parts':
        return AppTheme.orange;
      case 'PHARMACEUTICALS':
      case 'Pharmaceuticals':
        return AppTheme.emerald;
      case 'FOOD_AGRICULTURAL':
      case 'Agriculture & Food':
        return const Color(0xFF27AE60);
      case 'Luxury Goods':
        return AppTheme.crimson;
      case 'Home Appliances':
        return const Color(0xFF8E44AD);
      default:
        return Colors.grey.shade700;
    }
  }

  static Widget _rateBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  static Widget _reqIcon(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: active ? AppTheme.cobalt.withValues(alpha: 0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? AppTheme.cobalt.withValues(alpha: 0.4) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: active ? AppTheme.cobalt : Colors.grey.shade400,
        ),
      ),
    );
  }

  static Widget _cell({
    required Widget child,
    String? value,
    String? rowSummary,
  }) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    );
    if (value != null) {
      content = CopyableTableCell(
        value: value,
        rowSummary: rowSummary,
        child: content,
      );
    }
    return TableRowInkWell(
      onTap: () {},
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 1180 ? 1180.0 : constraints.maxWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderOf(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FixedColumnWidth(210),
                      1: FixedColumnWidth(140),
                      2: FlexColumnWidth(3),
                      3: FixedColumnWidth(140),
                      4: FixedColumnWidth(180),
                      5: FixedColumnWidth(140),
                      6: FixedColumnWidth(90),
                    },
                    children: [
                      // Header Row
                      TableRow(
                        decoration: const BoxDecoration(color: AppTheme.charcoal),
                        children: [
                          l10n.tariffActionsCol,
                          l10n.tariffHsCodeCol,
                          l10n.tariffDescAndAuthorityCol,
                          l10n.tariffCategoryCol,
                          l10n.tariffTaxRatesBreakdownCol,
                          l10n.tariffRequirementsCol,
                          l10n.tariffStatusCol,
                        ]
                            .map((h) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Text(
                                    h,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),

                      // Data Rows
                      ...tariffs.asMap().entries.map((entry) {
                        final tariff = entry.value;
                        final isEven = entry.key % 2 == 0;
                        final catColor = getCategoryColor(tariff.customsCategory);
                        final rowSummary = CustomsTariffExportHelper.buildTariffRowSummary(l10n, tariff);

                        final reqsList = <String>[];
                        if (tariff.requiresAcid) reqsList.add('ACID');
                        if (tariff.requiresCoo) reqsList.add('COO');
                        if (tariff.requiresInspection) reqsList.add('INSP');
                        final reqsStr = reqsList.join(', ');

                        final taxRatesStr = [
                          'Duty: ${tariff.customsDutyRate}%',
                          'VAT: ${tariff.vatRate}%',
                          if (tariff.scheduleTaxRate > 0) 'Sched: ${tariff.scheduleTaxRate}%',
                          if (tariff.developmentFeeRate > 0) 'Dev: ${tariff.developmentFeeRate}%',
                        ].join(', ');

                        return TableRow(
                          decoration: BoxDecoration(
                            color: isEven
                                ? AppTheme.surfaceOf(context)
                                : (isDark ? AppTheme.darkCardBackground : Colors.grey.shade50),
                          ),
                          children: [
                            // Actions
                            _cell(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
                                    tooltip: l10n.tariffCopySummaryBtn,
                                    onPressed: () => CustomsTariffExportHelper.copySingleTariffSummary(context, tariff),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  RowActionsPill(
                                    onView: () => onViewDetails(tariff),
                                    onEdit: () => onEdit(tariff),
                                    onPrint: () => onPrint(tariff),
                                    onDelete: () => onToggleActive(tariff),
                                    deleteTooltip: tariff.isActive ? l10n.deactivateTariffTooltip : l10n.activateTariffTooltip,
                                  ),
                                ],
                              ),
                            ),

                            // HS Code Badge
                            _cell(
                              value: tariff.hsCode,
                              rowSummary: rowSummary,
                              child: InkWell(
                                onTap: () => onViewDetails(tariff),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tariff.hsCode,
                                        style: const TextStyle(
                                          color: AppTheme.cobalt,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => CopyHelper.copy(context, tariff.hsCode),
                                        child: const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Description & Regulatory Authority
                            _cell(
                              value: '${tariff.hsDescription}${tariff.regulatoryAuthority != null ? " - ${tariff.regulatoryAuthority}" : ""}',
                              rowSummary: rowSummary,
                              child: InkWell(
                                onTap: () => onViewDetails(tariff),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tariff.hsDescription,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.charcoal,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (tariff.regulatoryAuthority != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          l10n.govAuthorityPrefix(tariff.regulatoryAuthority!),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Category
                            _cell(
                              value: tariff.categoryLabel(l10n) ?? '—',
                              rowSummary: rowSummary,
                              child: tariff.customsCategory != null
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: catColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        tariff.categoryLabel(l10n) ?? tariff.customsCategory!,
                                        style: TextStyle(
                                          color: catColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    )
                                  : const Text('—', style: TextStyle(color: Colors.grey)),
                            ),

                            // Tax Rates Breakdown
                            _cell(
                              value: taxRatesStr,
                              rowSummary: rowSummary,
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _rateBadge(l10n.rateDutyBadge('${tariff.customsDutyRate}%'), AppTheme.cobalt),
                                  _rateBadge(l10n.rateVatBadge('${tariff.vatRate}%'), AppTheme.emerald),
                                  if (tariff.scheduleTaxRate > 0)
                                    _rateBadge(l10n.rateSchedBadge('${tariff.scheduleTaxRate}%'), AppTheme.crimson),
                                  if (tariff.developmentFeeRate > 0)
                                    _rateBadge(l10n.rateDevBadge('${tariff.developmentFeeRate}%'), AppTheme.orange),
                                ],
                              ),
                            ),

                            // Requirements (COO, Inspection, ACID)
                            _cell(
                              value: reqsStr.isNotEmpty ? reqsStr : '—',
                              rowSummary: rowSummary,
                              child: Row(
                                children: [
                                  _reqIcon('ACID', tariff.requiresAcid),
                                  const SizedBox(width: 4),
                                  _reqIcon('COO', tariff.requiresCoo),
                                  const SizedBox(width: 4),
                                  _reqIcon('INSP', tariff.requiresInspection),
                                ],
                              ),
                            ),

                            // Status
                            _cell(
                              value: tariff.isActive ? l10n.statusActive : l10n.statusInactive,
                              rowSummary: rowSummary,
                              child: AppStatusBadge(
                                label: tariff.isActive ? l10n.statusActive : l10n.statusInactive,
                                severity: tariff.isActive ? AppSeverity.success : AppSeverity.danger,
                                size: AppStatusBadgeSize.small,
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
