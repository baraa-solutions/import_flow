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

class ConsultationsMobileList extends StatelessWidget {
  final List<CustomsConsultationModel> sessions;
  final List<ImportFileModel> importFiles;
  final bool isDark;
  final bool isArabic;
  final void Function(BuildContext, CustomsConsultationModel) onViewDetails;
  final void Function(CustomsConsultationModel) onEdit;
  final void Function(CustomsConsultationModel) onClone;
  final void Function(CustomsConsultationModel) onDeleteOrRestore;

  const ConsultationsMobileList({
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

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 24),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final rawFileCode = session.importFileCode ?? (session.importFileId != null ? 'IMP-${session.importFileId}' : '—');
        final shipmentTitle = (rawFileCode != '—')
            ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
            : '—';
        final fileDisplay = (shipmentTitle != '—' && shipmentTitle != rawFileCode)
            ? '$shipmentTitle ($rawFileCode)'
            : shipmentTitle;
        final readinessPct = session.readinessPercentage;
        final hasBlocking = session.hasBlockingIssues || session.blockingIssuesCount > 0;
        final rowSummary =
            '${session.consultationCode} | $fileDisplay | ${session.title} | ${session.brokerName} | ${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel | ${readinessPct.toStringAsFixed(0)}% | ${session.overallStatus}';

        return Card(
          elevation: 2,
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onViewDetails(context, session),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          session.consultationCode,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      ConsultationStatusBadge(status: session.overallStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (rawFileCode != '—')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_outlined, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            const SizedBox(width: 4),
                            Text(
                              fileDisplay,
                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            ),
                          ],
                        ),
                      if (session.brokerName.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            const SizedBox(width: 4),
                            Text(
                              session.brokerName,
                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (session.estimatedDutiesEgp > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.crimson.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 11),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${readinessPct.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? AppTheme.orange : AppTheme.crimson),
                            ),
                          ),
                          if (hasBlocking) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.crimson.withValues(alpha: 0.12),
                              ),
                              child: Text(
                                l.blockingIssuesBadge(session.blockingIssuesCount),
                                style: const TextStyle(color: AppTheme.crimson, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (readinessPct / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark ? AppTheme.charcoal : AppTheme.cloudWhite,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? AppTheme.orange : AppTheme.crimson),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                        tooltip: l.copyTooltip,
                        onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.customsTaxCopyRowSuccess),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
