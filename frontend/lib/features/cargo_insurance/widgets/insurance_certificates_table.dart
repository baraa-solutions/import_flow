import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/cargo_insurance_model.dart';
import '../services/cargo_insurance_export_service.dart';

/// Severity of a certificate status (ISSUED / DRAFT / CANCELLED ...).
AppSeverity insuranceStatusSeverity(String status) {
  switch (status) {
    case 'ISSUED':
      return AppSeverity.success;
    case 'CANCELLED':
      return AppSeverity.danger;
    case 'CLAIMED':
      return AppSeverity.info;
    default:
      return AppSeverity.warning;
  }
}

String insuranceStatusLabel(AppLocalizations l, String status) {
  switch (status) {
    case 'ISSUED':
      return l.insuranceStatusIssuedBadge;
    case 'CANCELLED':
      return l.insuranceStatusCancelledBadge;
    default:
      return l.insuranceStatusDraftBadge;
  }
}

/// The certificates registry grid: copy-able cells, severity status chips and
/// right-aligned money columns. Pure presentation: every action is a callback.
class InsuranceCertificatesTable extends StatelessWidget {
  const InsuranceCertificatesTable({
    super.key,
    required this.certificates,
    required this.importFiles,
    required this.isArabic,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onIssue,
  });

  final List<CargoInsuranceModel> certificates;
  final List<ImportFileModel> importFiles;
  final bool isArabic;
  final ValueChanged<CargoInsuranceModel> onView;
  final ValueChanged<CargoInsuranceModel> onEdit;
  final ValueChanged<CargoInsuranceModel> onDelete;
  final ValueChanged<CargoInsuranceModel> onIssue;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context));

    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 46,
          dataRowMinHeight: 54,
          dataRowMaxHeight: 64,
          horizontalMargin: 16,
          columnSpacing: 18,
          dividerThickness: 0.5,
          headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
          headingTextStyle: head,
          columns: [
            DataColumn(label: Text(l.insuranceColActions)),
            const DataColumn(label: Text('#')),
            DataColumn(label: Text(l.insuranceColCertCode)),
            DataColumn(label: Text(l.insuranceColIssueDate)),
            DataColumn(label: Text(l.insuranceColPolicyFile)),
            DataColumn(label: Text(l.insuranceColInsuredEntity)),
            DataColumn(label: Text(l.insuranceColInsuranceCo)),
            DataColumn(label: Text(l.insuranceColTransportRoute)),
            DataColumn(label: Text(l.insuranceColInsuredValue), numeric: true),
            DataColumn(label: Text(l.insuranceColCoverageClause)),
            DataColumn(label: Text(l.insuranceColGrossPremium), numeric: true),
            DataColumn(label: Text(l.insuranceColStatus)),
          ],
          rows: [
            for (var i = 0; i < certificates.length; i++) _row(context, l, i + 1, certificates[i]),
          ],
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l, int idx, CargoInsuranceModel cert) {
    final isIssued = cert.status == 'ISSUED';
    final isCancelled = cert.status == 'CANCELLED';
    final shipmentCode = cert.importFileId != null ? 'IMP-${cert.importFileId}' : null;
    final shipmentTitle = shipmentCode != null
        ? DisplayNameResolver.resolveShipmentTitleByCode(shipmentCode, shipments: importFiles, isArabic: isArabic)
        : null;
    final rowSummary = CargoInsuranceExportService.toRowSummary(cert, l, shipments: importFiles, isArabic: isArabic);
    final issueDate = cert.issuedAt?.substring(0, 10) ?? cert.createdAt.substring(0, 10);
    final secondary = TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context));

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 16, color: AppTheme.textSecondaryOf(context)),
                tooltip: l.insuranceCopyRowSummaryBtn,
                onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.insuranceCopyRowSummarySuccess),
              ),
              RowActionsPill(
                onView: () => onView(cert),
                onEdit: isIssued ? null : () => onEdit(cert),
                onPrint: () => onView(cert),
                onDelete: () => onDelete(cert),
                viewTooltip: l.insuranceViewTooltip,
                editTooltip: l.insuranceEditTooltip,
                printTooltip: l.insurancePrintTooltip,
                deleteTooltip: l.insuranceDeleteTooltip,
              ),
              if (!isIssued && !isCancelled) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.verified_rounded, color: AppTheme.emerald, size: 18),
                  tooltip: l.insuranceIssueCertificateTooltip,
                  onPressed: () => onIssue(cert),
                ),
              ],
            ],
          ),
        ),
        DataCell(CopyableTableCell(
          value: '$idx',
          rowSummary: rowSummary,
          child: Text('$idx', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        )),
        DataCell(CopyableTableCell(
          value: cert.certificateCode,
          rowSummary: rowSummary,
          child: InkWell(
            onTap: () => onView(cert),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, size: 14, color: AppTheme.cobalt),
                const SizedBox(width: 4),
                LtrText(
                  cert.certificateCode,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                ),
                const SizedBox(width: 4),
                _copyIcon(
                  context,
                  size: 12,
                  onTap: () => CopyHelper.copy(
                    context,
                    cert.certificateCode,
                    customMessage: l.insuranceCopyBadgeSuccess(l.insuranceColCertCode, cert.certificateCode),
                  ),
                ),
              ],
            ),
          ),
        )),
        DataCell(CopyableTableCell(
          value: issueDate,
          rowSummary: rowSummary,
          child: LtrText(issueDate, style: const TextStyle(fontSize: 12)),
        )),
        DataCell(CopyableTableCell(
          value: '${shipmentTitle ?? (cert.policyNumber ?? "-")} (${cert.policyNumber ?? "-"})',
          rowSummary: rowSummary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (shipmentTitle != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 2),
                  child: Text(
                    shipmentTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cert.policyNumber != null ? l.insPolicyShort(cert.policyNumber!) : '-',
                    style: shipmentTitle == null
                        ? TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.textPrimaryOf(context))
                        : secondary,
                  ),
                  if (cert.policyNumber != null && cert.policyNumber!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _copyIcon(
                      context,
                      size: 11,
                      onTap: () => CopyHelper.copy(
                        context,
                        cert.policyNumber!,
                        customMessage: l.insuranceCopyBadgeSuccess(l.insuranceColPolicyFile, cert.policyNumber!),
                      ),
                    ),
                  ],
                  if (shipmentCode != null) ...[
                    const SizedBox(width: 6),
                    AppStatusBadge(
                      label: shipmentCode,
                      severity: AppSeverity.info,
                      size: AppStatusBadgeSize.small,
                    ),
                    const SizedBox(width: 2),
                    _copyIcon(
                      context,
                      size: 11,
                      color: AppTheme.cobalt,
                      onTap: () => CopyHelper.copy(
                        context,
                        shipmentCode,
                        customMessage: l.insuranceCopyBadgeSuccess(l.insuranceFieldLinkImportFile, shipmentCode),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        )),
        DataCell(CopyableTableCell(
          value: cert.insuredEntityName,
          rowSummary: rowSummary,
          child: SizedBox(
            width: 140,
            child: Text(
              cert.insuredEntityName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        )),
        DataCell(CopyableTableCell(
          value: cert.insuranceCompanyName ?? '-',
          rowSummary: rowSummary,
          child: SizedBox(
            width: 130,
            child: Text(
              cert.insuranceCompanyName ?? '-',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
          ),
        )),
        DataCell(CopyableTableCell(
          value: '${cert.transportMode} | ${cert.portOfLoading} -> ${cert.portOfDischarge}',
          rowSummary: rowSummary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cert.transportMode == 'AIR' ? Icons.flight_takeoff_rounded : Icons.directions_boat_rounded,
                    size: 13,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  const SizedBox(width: 4),
                  Text(cert.transportMode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('${cert.portOfLoading} ➔ ${cert.portOfDischarge}', style: secondary),
            ],
          ),
        )),
        DataCell(CopyableTableCell(
          value: '${cert.insuredValue.toStringAsFixed(2)} ${cert.currency}',
          rowSummary: rowSummary,
          child: CcMoneyText(
            cert.insuredValue,
            currency: cert.currency,
            fontSize: 12,
            color: AppTheme.severityForegroundOf(context, AppSeverity.success),
            textAlign: TextAlign.end,
          ),
        )),
        DataCell(CopyableTableCell(
          value: cert.coverageClause,
          rowSummary: rowSummary,
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: LtrText(
              cert.coverageClause,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
            ),
          ),
        )),
        DataCell(CopyableTableCell(
          value: '${cert.totalPayablePremium.toStringAsFixed(2)} ${cert.currency}',
          rowSummary: rowSummary,
          child: CcMoneyText(cert.totalPayablePremium, currency: cert.currency, fontSize: 12, textAlign: TextAlign.end),
        )),
        DataCell(CopyableTableCell(
          value: cert.status,
          rowSummary: rowSummary,
          child: AppStatusBadge(
            label: insuranceStatusLabel(l, cert.status),
            severity: insuranceStatusSeverity(cert.status),
            icon: isIssued ? Icons.check_circle_outline : (isCancelled ? Icons.block : Icons.hourglass_bottom_rounded),
            size: AppStatusBadgeSize.small,
          ),
        )),
      ],
    );
  }

  Widget _copyIcon(BuildContext context, {required double size, required VoidCallback onTap, Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(Icons.copy_rounded, size: size, color: color ?? AppTheme.textSecondaryOf(context)),
      ),
    );
  }
}
