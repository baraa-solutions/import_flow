import 'package:flutter/widgets.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../models/import_documentation_model.dart';

class CooReviewTableExporter {
  static List<String> buildHeaders(BuildContext context) {
    return [
      context.l10n.idocBSessionTypeCol,
      context.l10n.cooRegistryColCode,
      context.l10n.cooRegistryColType,
      context.l10n.cooRegistryColNumber,
      context.l10n.cooRegistryColExporter,
      context.l10n.cooRegistryColStatus,
      context.l10n.cooRegistryColDate,
    ];
  }

  static List<List<dynamic>> buildRows(BuildContext context, List<CertificateOfOriginReviewModel> reviews) {
    return reviews.map((r) {
      final expName = r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—';
      final isDraft = r.isDraft;
      final dateStr = r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt;
      return [
        isDraft ? context.l10n.idocBSessionDraftShort : context.l10n.idocBSessionCertifiedShort,
        r.cooReviewCode,
        r.certificateType,
        r.certificateNumber,
        expName,
        r.status,
        dateStr,
      ];
    }).toList();
  }

  static Future<void> exportToExcel(BuildContext context, List<CertificateOfOriginReviewModel> reviews) async {
    final headers = buildHeaders(context);
    final rows = buildRows(context, reviews);

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBCooRegistryStage,
      importFileNameOrCode: 'Draft_COO_Registry',
    );
  }

  static Future<void> exportToPdf(BuildContext context, List<CertificateOfOriginReviewModel> reviews) async {
    final headers = buildHeaders(context);
    final rows = buildRows(context, reviews);

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBCooRegistryStage,
      importFileNameOrCode: 'Draft_COO_Registry',
    );
  }

  static void copyAsTsv(BuildContext context, List<CertificateOfOriginReviewModel> reviews) {
    final headers = buildHeaders(context);
    final rows = buildRows(context, reviews);

    TableCopyHelper.copyTable(context, headers, rows);
  }
}
