import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/system_messages/coded_item_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../idoc_ui.dart';

/// Discrepancy details card showing tolerance checks, 4-way header comparisons,
/// status explanations, override options, and extracted document metadata pills.
class PoReconciliationDiscrepancyCard extends StatelessWidget {
  final Map<String, dynamic> extractedData;
  final DisplayDensityMode density;
  final VoidCallback onApplyExtractedToTables;
  final String Function(BuildContext context, String fieldName, [String? fieldNameAr]) getLocalizedCheckField;
  final String Function(BuildContext context, String fieldName, String status, String? rawMessage) getLocalizedCheckMessage;
  final String Function(BuildContext context, String status) getLocalizedSessionStatus;

  const PoReconciliationDiscrepancyCard({
    super.key,
    required this.extractedData,
    required this.density,
    required this.onApplyExtractedToTables,
    required this.getLocalizedCheckField,
    required this.getLocalizedCheckMessage,
    required this.getLocalizedSessionStatus,
  });

  Widget _buildMatchStatusBadge(BuildContext context, String status) {
    final l = context.l10n;
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'MATCH':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.success);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.success);
        label = l.poRecMatchStatusMatched;
        break;
      case 'WARNING':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.warning);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.warning);
        label = l.poRecMatchStatusWarning;
        break;
      case 'CRITICAL':
      default:
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.danger);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.danger);
        label = l.poRecMatchStatusCritical;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildExtractedPill(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    const pillBg = AppTheme.white;
    final pillBorder = AppTheme.borderOf(context);
    final labelColor = AppTheme.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: pillBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.cobalt),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final overallStatus = extractedData['overall_status'] as String? ?? 'FULLY_MATCHED';
    final critCount = extractedData['critical_discrepancies_count'] as int? ?? 0;
    final warnCount = extractedData['warning_discrepancies_count'] as int? ?? 0;
    final headerDiscrepancies = extractedData['header_discrepancies'] as List<dynamic>? ?? [];
    final invData = extractedData['extracted_invoice_data'] as Map<String, dynamic>? ?? {};
    final plData = extractedData['extracted_packing_data'] as Map<String, dynamic>? ?? {};

    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    if (overallStatus == 'FULLY_MATCHED') {
      statusColor = AppTheme.emerald;
      statusIcon = Icons.check_circle;
      statusTitle = l.poRecStatusFullyMatchedTitle;
    } else if (overallStatus == 'ACCEPTED_WITH_WARNINGS') {
      statusColor = AppTheme.orange;
      statusIcon = Icons.warning_amber;
      statusTitle = l.poRecStatusWarningsTitle(warnCount);
    } else {
      statusColor = AppTheme.crimson;
      statusIcon = Icons.cancel;
      statusTitle = l.poRecStatusCriticalTitle(critCount);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final statusTitleRow = Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              );
              final applyButton = IdocUi.fit(AppButton(
                label: l.poRecApplyExtractedToTablesButton,
                icon: Icons.playlist_add_check,
                variant: AppButtonVariant.success,
                onPressed: onApplyExtractedToTables,
              ));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  statusTitleRow,
                  const SizedBox(height: 10),
                  applyButton,
                ],
              );
            },
          ),
          const Divider(height: 20),
          Text(
            l.poRecHeaderComplianceChecksTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: density.tableHeadingHeight,
              dataRowMinHeight: density.tableRowHeight - 4,
              dataRowMaxHeight: density.tableRowHeight + 6,
              columnSpacing: density.byDensity<double>(20, 16, 12),
              horizontalMargin: density.byDensity<double>(16, 12, 8),
              columns: [
                DataColumn(label: Text(l.poRecColCheckItem)),
                DataColumn(label: Text(context.l10n.idocAColSystemValueInvoice)),
                DataColumn(label: Text(context.l10n.idocAColSystemValuePacking)),
                DataColumn(label: Text(context.l10n.idocAColUploadedValueInvoice)),
                DataColumn(label: Text(context.l10n.idocAColUploadedValuePacking)),
                DataColumn(label: Text(l.poRecColMatchStatus)),
                DataColumn(label: Text(l.poRecColDetails)),
              ],
              rows: headerDiscrepancies.map((d) {
                final map = CodedItemText.localizeRow(d as Map, l);
                final status = map['status'] as String? ?? 'MATCH';
                final fieldName = map['field_name'] as String? ?? '';
                final fieldNameAr = map['field_name_ar'] as String? ?? '';
                final localizedFieldName = getLocalizedCheckField(context, fieldName, fieldNameAr);
                final systemVal = map['system_value']?.toString() ?? '—';
                final extractedVal = map['extracted_value']?.toString() ?? '—';
                final rawMsg = (map['message'] ?? map['details'])?.toString();
                final localizedMsg = getLocalizedCheckMessage(context, fieldName, status, rawMsg);
                final localizedStatus = getLocalizedSessionStatus(context, status);
                final rowSummary = [localizedFieldName, systemVal, extractedVal, localizedStatus, localizedMsg].join('\t');

                final sysInvVal = (map['system_invoice_value'] ?? map['system_value'] ?? '—').toString();
                final sysPlVal = (map['system_packing_value'] ?? map['system_value'] ?? '—').toString();
                final uplInvVal = (map['uploaded_invoice_value'] ?? map['extracted_value'] ?? '—').toString();
                final uplPlVal = (map['uploaded_packing_value'] ?? map['extracted_value'] ?? '—').toString();

                return DataRow(cells: [
                  DataCell(CopyableTableCell(
                    value: localizedFieldName,
                    rowSummary: rowSummary,
                    child: Text(
                      localizedFieldName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: sysInvVal,
                    rowSummary: rowSummary,
                    child: Text(
                      sysInvVal,
                      style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 12),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: sysPlVal,
                    rowSummary: rowSummary,
                    child: Text(
                      sysPlVal,
                      style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: uplInvVal,
                    rowSummary: rowSummary,
                    child: Text(
                      uplInvVal,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: uplPlVal,
                    rowSummary: rowSummary,
                    child: Text(
                      uplPlVal,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: localizedStatus,
                    rowSummary: rowSummary,
                    child: _buildMatchStatusBadge(context, status),
                  )),
                  DataCell(CopyableTableCell(
                    value: localizedMsg,
                    rowSummary: rowSummary,
                    child: Text(
                      localizedMsg,
                      style: TextStyle(
                        fontSize: 12,
                        color: status == 'MATCH'
                            ? AppTheme.severityForegroundOf(context, AppSeverity.success)
                            : AppTheme.severityForegroundOf(context, AppSeverity.danger),
                      ),
                    ),
                  )),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.poRecExtractedDocMetadataTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final pills = [
                _buildExtractedPill(
                  context,
                  label: l.poRecExtractedInvNo,
                  value: invData['invoice_number']?.toString() ?? '—',
                  icon: Icons.receipt_long,
                ),
                _buildExtractedPill(
                  context,
                  label: l.poRecExtractedInvAmount,
                  value: '${invData['total_amount'] ?? "—"} ${invData['currency'] ?? ""}',
                  icon: Icons.monetization_on,
                ),
                _buildExtractedPill(
                  context,
                  label: l.poRecExtractedAcid,
                  value: plData['acid_number']?.toString() ?? invData['acid_number']?.toString() ?? '—',
                  icon: Icons.tag,
                ),
                _buildExtractedPill(
                  context,
                  label: l.poRecExtractedPackagesWeight,
                  value:
                      '${plData['total_packages'] ?? "—"} ${l.poRecPackagesUnit} - ${plData['total_gross_weight_kg'] ?? "—"} ${l.poRecKgUnit}',
                  icon: Icons.inventory_2,
                ),
              ];

              if (constraints.maxWidth >= 750) {
                return Row(
                  children: pills
                      .map((p) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: p,
                            ),
                          ))
                      .toList(),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pills
                    .map((p) => SizedBox(
                          width: constraints.maxWidth > 400
                              ? (constraints.maxWidth - 8) / 2
                              : constraints.maxWidth,
                          child: p,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
