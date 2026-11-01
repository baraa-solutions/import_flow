import 'package:flutter/material.dart';
import '../../../../../core/helpers/table_copy_helper.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/table_export_service.dart';
import '../../../models/import_documentation_model.dart';

class DraftBlRegistryExportHelper {
  const DraftBlRegistryExportHelper._();

  static List<String> _getHeaders(AppLocalizations l) => [
        l.idocASessionTypeAlt,
        l.draftBlRegistryColSessionId,
        l.draftBlRegistryColBlNumber,
        l.draftBlRegistryColShippingLine,
        l.draftBlRegistryColVesselVoyage,
        l.draftBlRegistryColStage,
        l.draftBlRegistryColImporterApproval,
        l.draftBlRegistryColBrokerApproval,
        l.draftBlRegistryColStatus,
      ];

  static List<List<dynamic>> _getRows(AppLocalizations l, List<DraftBLReviewModel> reviews) {
    return reviews.map((r) {
      final blNumber = (r.draftExtractedData?['draft_bl_number'] ??
              r.draftExtractedData?['bl_number'] ??
              r.systemDataSnapshot?['draft_bl_number'] ??
              r.draftBlNumber)
          .toString();
      final vesselVoyage = '${r.vesselName ?? "-"} / ${r.voyageNumber ?? "-"}';
      final importerApproval = r.importerApprovalStatus == 'Approved' ? l.approved : r.importerApprovalStatus;
      final brokerApproval = r.brokerApprovalStatus == 'Approved' ? l.approved : r.brokerApprovalStatus;
      final statusLabel = r.status == 'Final Approved' || r.status == 'Approved' ? l.approved : r.status;
      return [
        r.isDraft ? l.idocADraft : l.idocACertified,
        '#${r.blReviewId}',
        blNumber,
        r.shippingLine ?? '-',
        vesselVoyage,
        r.stage,
        importerApproval,
        brokerApproval,
        statusLabel,
      ];
    }).toList();
  }

  static Future<void> exportToExcel(BuildContext context, List<DraftBLReviewModel> reviews) async {
    final l = context.l10n;
    final headers = _getHeaders(l);
    final rows = _getRows(l, reviews);

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocADraftBLRegistry,
      importFileNameOrCode: 'Draft_BL_Registry',
    );
  }

  static Future<void> exportToPdf(BuildContext context, List<DraftBLReviewModel> reviews) async {
    final l = context.l10n;
    final headers = _getHeaders(l);
    final rows = _getRows(l, reviews);

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocADraftBLRegistry,
      importFileNameOrCode: 'Draft_BL_Registry',
    );
  }

  static void copyAsTsv(BuildContext context, List<DraftBLReviewModel> reviews) {
    final l = context.l10n;
    final headers = _getHeaders(l);
    final rows = _getRows(l, reviews);

    TableCopyHelper.copyTable(context, headers, rows);
  }
}
