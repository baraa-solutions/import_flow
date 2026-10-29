import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_card_container.dart';
import 'report_copy_badge.dart';

/// Basic information details card for the Comprehensive Report.
class ReportBasicInfoCard extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;

  const ReportBasicInfoCard({
    super.key,
    required this.file,
    this.dossier,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final effectiveCompanyName = file.companyName.isNotEmpty
        ? file.companyName
        : (dossier?.companyName.isNotEmpty == true
            ? dossier!.companyName
            : 'SCAS For Construction And Finishing');
    final effectiveSupplierName = file.supplierName.isNotEmpty
        ? file.supplierName
        : (dossier?.supplierName.isNotEmpty == true ? dossier!.supplierName : '—');

    return ReportCardContainer(
      title: l.compReportSecBasicInfo,
      icon: Icons.info_outline,
      iconColor: AppTheme.cobalt,
      child: Column(
        children: [
          buildInfoRow(context, l.compReportColFileCode, file.importFileCode, showCopyBadge: true),
          buildInfoRow(context, l.compReportColCustomsFileNo, file.customFileNumber ?? '—',
              showCopyBadge: file.customFileNumber != null && file.customFileNumber!.isNotEmpty),
          buildInfoRow(context, l.compReportColImportCompany, effectiveCompanyName),
          buildInfoRow(context, l.compReportColSupplier, effectiveSupplierName),
          buildInfoRow(context, l.compReportColBroker, file.brokerName ?? '—'),
          buildInfoRow(context, l.compReportColPoNumber, file.poNumber ?? '—',
              showCopyBadge: file.poNumber != null && file.poNumber!.isNotEmpty),
          buildInfoRow(context, l.compReportColPiNumber, file.piNumber ?? '—',
              showCopyBadge: file.piNumber != null && file.piNumber!.isNotEmpty),
          buildInfoRow(context, l.compReportColShipmentMode, file.shipmentMode),
          buildInfoRow(context, l.compReportColIncoterm, file.incotermCode),
          buildInfoRow(context, l.compReportColCategory, file.shipmentCategory),
          buildInfoRow(context, l.compReportColScenario, file.selectedScenario ?? '—'),
          buildInfoRow(context, l.compReportColRequiredEta, file.requiredEta ?? '—'),
          buildInfoRow(context, l.compReportColOwner, file.owner),
          buildInfoRow(context, l.compReportColCreatedAt, file.createdAt.split('T').first),
          buildInfoRow(context, l.compReportColUpdatedAt, file.updatedAt.split('T').first),
        ],
      ),
    );
  }

  static Widget buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool showCopyBadge = false,
  }) {
    final l = context.l10n;
    final hasVal = value != '—' && value.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(color: Colors.grey)),
          Expanded(
            child: hasVal
                ? (showCopyBadge
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ReportCopyBadge(textToCopy: value),
                      )
                    : CopyableTableCell(
                        value: value,
                        rowSummary: '$label: $value',
                        customMessage: l.compReportCopyValueTooltip(label),
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal,
                          ),
                        ),
                      ))
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
