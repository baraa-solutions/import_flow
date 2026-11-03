import 'package:flutter/material.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../models/customs_declaration_assessment.dart';
import '../../services/customs_declaration46_calculator.dart';
import '../form46_variance_bar.dart';
import '../idoc_ui_b.dart';
import 'registry_item.dart';

class Declaration46RegistryTable extends StatelessWidget {
  final List<DeclarationRegistryItem> items;
  final bool isDark;
  final ValueChanged<CustomsDeclarationAssessment> onCloneDeclaration;
  final void Function(CustomsDeclarationAssessment assessment) onShowAssessment;

  const Declaration46RegistryTable({
    super.key,
    required this.items,
    required this.isDark,
    required this.onCloneDeclaration,
    required this.onShowAssessment,
  });

  Widget _figureText(BuildContext context, double? value, Color color, {required bool bold, required String miss}) {
    if (value == null) return IdocBMissingMark(label: miss);
    return LtrText(
      '${IdocBFormat.money(value)} ${context.l10n.egpCurrency}',
      textAlign: TextAlign.end,
      style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.w600,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _varianceBadge(BuildContext context, DeclarationRegistryItem item, AppLocalizations l, bool isDark) {
    final vr = item.varianceResult;
    final pct = vr.diffPercentage;

    if (pct == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkInputBackground : AppTheme.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          l.customsDeclVariancePending,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textMutedOf(context),
          ),
        ),
      );
    }

    final color = Form46VarianceBar.severityColor(vr.severity);
    final sign = pct >= 0 ? '+' : '';
    final pctText = '$sign${pct.toStringAsFixed(1)}%';
    final reason = item.dutyVarianceReason;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            vr.severity == Form46VarianceSeverity.compliant
                ? Icons.check_circle_outline
                : (vr.severity == Form46VarianceSeverity.moderate
                    ? Icons.change_circle_outlined
                    : Icons.warning_amber_rounded),
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          LtrText(
            pctText,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (reason != null && reason.trim().isNotEmpty) {
      badge = Tooltip(
        message: '${l.form46VarianceReasonLabel}: $reason',
        child: badge,
      );
    }

    return badge;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final miss = l.idocBMissing;

    return Container(
      width: double.infinity,
      decoration: AppTheme.cardDecorationOf(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkInputBackground : AppTheme.surfaceAlt),
          columns: [
            DataColumn(
              label: Text(
                l.customsDeclColActions,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
            DataColumn(
              label: Text(
                l.customsDeclColDeclarationNo,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
            DataColumn(
              label: Text(
                l.customsDeclColFileNumber,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
            DataColumn(
              label: Text(
                l.customsDeclColSupplier,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
            DataColumn(
              label: Text(
                l.customsDeclColRegistrationDate,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
            DataColumn(
              label: Text(
                l.ccDecOfficeLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
            DataColumn(
              label: Text(
                l.customsDeclChannelLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
            DataColumn(
              label: Text(
                l.customsDeclColDeclarationStatus,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                l.customsDeclColTariffEstimate,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
            DataColumn(
              label: Text(
                l.customsDeclColVariance,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
          ],
          rows: items.map((item) {
            final vr = item.varianceResult;
            final pctText = vr.diffPercentage != null
                ? '${vr.diffPercentage! >= 0 ? '+' : ''}${vr.diffPercentage!.toStringAsFixed(1)}%'
                : l.customsDeclVariancePending;
            final rowSummary = '${item.declarationNo}\t${item.importFileCode}\t${item.supplierName}\t${item.declarationDate}\t${item.customsOffice}\t${item.channel}\t${item.status}\t${item.estimatedDutyTotal.fixedOrMissing(2, miss)}\t$pctText';

            return DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.estimate != null)
                        IconButton(
                          key: Key('viewAssessmentBtn_${item.declarationNo}'),
                          icon: const Icon(Icons.analytics_outlined, color: AppTheme.cobalt, size: 18),
                          tooltip: l.customsDeclViewAssessmentTooltip,
                          onPressed: () => onShowAssessment(item.estimate!),
                        ),
                      IconButton(
                        key: Key('copyRegistryRowBtn_${item.declarationNo}'),
                        icon: Icon(Icons.copy, size: 16, color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt),
                        tooltip: l.copyRegistryRowSuccess,
                        onPressed: () {
                          final headers = [
                            l.customsDeclColDeclarationNo,
                            l.customsDeclColFileNumber,
                            l.customsDeclColSupplier,
                            l.customsDeclColRegistrationDate,
                            l.ccDecOfficeLabel,
                            l.customsDeclChannelLabel,
                            l.customsDeclColDeclarationStatus,
                            l.customsDeclColTariffEstimate,
                            l.customsDeclColVariance,
                          ];
                          final values = [
                            item.declarationNo,
                            item.importFileCode,
                            item.supplierName,
                            item.declarationDate,
                            item.customsOffice,
                            item.channel,
                            item.status,
                            item.estimatedDutyTotal.fixedOrMissing(2, miss),
                            pctText,
                          ];
                          TableCopyHelper.copyRow(context, values, headers: headers);
                        },
                      ),
                      if (item.estimate != null)
                        IconButton(
                          key: Key('cloneRegistryRowBtn_${item.declarationNo}'),
                          icon: Icon(Icons.copy_all, size: 18, color: isDark ? AppTheme.emerald : AppTheme.flatEmerald),
                          tooltip: l.cloneCustomsDeclRowTooltip,
                          onPressed: () => onCloneDeclaration(item.estimate!),
                        ),
                    ],
                  ),
                ),
                DataCell(
                  CopyableTableCell(
                    value: item.declarationNo,
                    rowSummary: rowSummary,
                    child: Text(
                      item.declarationNo,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  CopyableTableCell(
                    value: item.importFileCode,
                    rowSummary: rowSummary,
                    child: Text(
                      item.importFileCode,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                ),
                DataCell(
                  CopyableTableCell(
                    value: item.supplierName,
                    rowSummary: rowSummary,
                    child: Text(
                      item.supplierName,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                ),
                DataCell(
                  CopyableTableCell(
                    value: item.declarationDate,
                    rowSummary: rowSummary,
                    child: Text(
                      item.declarationDate,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                ),
                DataCell(
                  CopyableTableCell(
                    value: item.customsOffice,
                    rowSummary: rowSummary,
                    child: Text(
                      item.customsOffice,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                ),
                DataCell(
                  CopyableTableCell(
                    value: item.channel,
                    rowSummary: rowSummary,
                    child: Builder(
                      builder: (context) {
                        final ch = CcUi.channelStyle(l, item.channel);
                        return IdocBStatusChip(
                          label: ch.label,
                          severity: ch.severity,
                          icon: ch.icon,
                        );
                      },
                    ),
                  ),
                ),
                DataCell(
                  CopyableTableCell(
                    value: item.status,
                    rowSummary: rowSummary,
                    child: Builder(
                      builder: (context) {
                        final st = CcUi.statusStyle(l, item.status);
                        return IdocBStatusChip(
                          label: st.label,
                          severity: st.severity,
                        );
                      },
                    ),
                  ),
                ),
                DataCell(
                  CopyableTableCell(
                    value: item.estimatedDutyTotal.fixedOrMissing(2, miss),
                    rowSummary: rowSummary,
                    child: _figureText(context, item.estimatedDutyTotal, AppTheme.crimson, bold: true, miss: miss),
                  ),
                ),
                DataCell(
                  CopyableTableCell(
                    value: pctText,
                    rowSummary: rowSummary,
                    child: _varianceBadge(context, item, l, isDark),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
