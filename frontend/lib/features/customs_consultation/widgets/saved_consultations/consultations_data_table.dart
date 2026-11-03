import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_consultation_model.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../services/customs_consultation_pdf_service.dart';
import '../consultation_status_badges.dart';

class ConsultationsDataTable extends StatelessWidget {
  final List<CustomsConsultationModel> sessions;
  final List<ImportFileModel> importFiles;
  final bool isDark;
  final bool isArabic;
  final void Function(BuildContext, CustomsConsultationModel) onViewDetails;
  final void Function(CustomsConsultationModel) onEdit;
  final void Function(CustomsConsultationModel) onClone;
  final void Function(CustomsConsultationModel) onDeleteOrRestore;

  const ConsultationsDataTable({
    super.key,
    required this.sessions,
    required this.importFiles,
    required this.isDark,
    required this.isArabic,
    required this.onViewDetails,
    required this.onEdit,
    required this.onClone,
    required this.onDeleteOrRestore,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final egpLabel = context.l10n.financialSettlementCurrencyEgp;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
      child: Card(
        elevation: 2,
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 76,
            horizontalMargin: 16,
            columnSpacing: 20,
            dividerThickness: 0.5,
            headingRowColor: WidgetStateProperty.all(
              isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
            ),
            headingTextStyle: const TextStyle(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
            columns: [
              DataColumn(
                label: SizedBox(
                  width: 190,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.orange),
                      const SizedBox(width: 4),
                      Text(
                        l.actionsCol,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataColumn(label: Text('📋 ${l.studyCodeCol}')),
              DataColumn(label: Text('📁 ${l.linkImportFile}')),
              DataColumn(label: Text('📝 ${l.titleField}')),
              DataColumn(label: Text('🧑‍💼 ${l.customsBrokerLabel}')),
              DataColumn(label: Text('💰 ${l.customsDutyCol}')),
              DataColumn(label: Text('📊 ${l.customsInspectionReadiness}')),
              DataColumn(label: Text('🔖 ${l.statusCol}')),
            ],
            rows: sessions.asMap().entries.map((entry) {
              final idx = entry.key;
              final session = entry.value;
              final isEven = idx.isEven;
              final rowColor = isDark
                  ? (isEven ? AppTheme.darkCardBackground : AppTheme.darkElevatedSurface)
                  : (isEven ? AppTheme.white : AppTheme.charcoalSurface);
              final readinessPct = session.readinessPercentage;
              final hasBlocking = session.hasBlockingIssues || session.blockingIssuesCount > 0;
              final rawFileCode = session.importFileCode ?? (session.importFileId != null ? 'IMP-${session.importFileId}' : '—');
              final shipmentTitle = (rawFileCode != '—')
                  ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
                  : '—';
              final fileDisplay = (shipmentTitle != '—' && shipmentTitle != rawFileCode)
                  ? '$shipmentTitle ($rawFileCode)'
                  : shipmentTitle;
              final rowSummary =
                  '${session.consultationCode} | $fileDisplay | ${session.title} | ${session.brokerName} | ${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel | ${readinessPct.toStringAsFixed(0)}% | ${session.overallStatus}';

              return DataRow(
                color: WidgetStateProperty.all(rowColor),
                onSelectChanged: (_) => onViewDetails(context, session),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RowActionsPill(
                          onView: () => onViewDetails(context, session),
                          onEdit: () => onEdit(session),
                          onClone: () => onClone(session),
                          cloneTooltip: l.cloneConsultationTooltip,
                          onPrint: () {
                            Printing.layoutPdf(
                              onLayout: (format) => CustomsConsultationPdfService.generateConsultationPdf(session),
                              name: 'Customs_Consultation_${session.consultationCode}',
                            );
                          },
                          onDelete: () => onDeleteOrRestore(session),
                          deleteTooltip: session.isActive == false ? l.restoreDeletedTooltip : l.deleteStudyTooltip,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                          tooltip: l.copyTooltip,
                          onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.customsTaxCopyRowSuccess),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: session.consultationCode,
                      rowSummary: rowSummary,
                      child: InkWell(
                        onTap: () => onViewDetails(context, session),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            session.consultationCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: fileDisplay,
                      rowSummary: rowSummary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            shipmentTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: isDark ? AppTheme.darkTextPrimary : null,
                            ),
                          ),
                          if (rawFileCode != '—' && rawFileCode != shipmentTitle) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                rawFileCode,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.cobalt,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: session.title,
                      rowSummary: rowSummary,
                      child: SizedBox(
                        width: 180,
                        child: Text(
                          session.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: '${session.brokerName}${session.brokerContactPerson != null ? " (${session.brokerContactPerson})" : ""}',
                      rowSummary: rowSummary,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.brokerName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextPrimary : null,
                            ),
                          ),
                          if (session.brokerContactPerson != null)
                            Text(
                              session.brokerContactPerson!,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: '${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel',
                      rowSummary: rowSummary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.crimson.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: '${readinessPct.toStringAsFixed(0)}%',
                      rowSummary: rowSummary,
                      child: SizedBox(
                        width: 145,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${readinessPct.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? AppTheme.orange : AppTheme.crimson),
                                  ),
                                ),
                                if (hasBlocking)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.crimson.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      l.blockingIssuesBadge(session.blockingIssuesCount),
                                      style: const TextStyle(color: AppTheme.crimson, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (readinessPct / 100).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: isDark ? AppTheme.charcoal : AppTheme.cloudWhite,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? AppTheme.orange : AppTheme.crimson),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l.approvedDocsCountBadge(session.approvedDocumentsCount, session.totalDocumentsCount),
                              style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    CopyableTableCell(
                      value: session.overallStatus,
                      rowSummary: rowSummary,
                      child: ConsultationStatusBadge(status: session.overallStatus),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
