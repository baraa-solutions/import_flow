import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/import_documentation_model.dart';
import '../../providers/docs_customs_approval_provider.dart';
import '../../providers/import_documentation_provider.dart';
import '../../services/coo_export_service.dart';
import '../visual_draft_coo_sheet.dart';

class CooReviewService {
  static Future<Map<String, dynamic>> fetchDraftTemplate(
    WidgetRef ref,
    int fileId, {
    String? certType,
  }) async {
    return await ref.read(cooReviewsProvider.notifier).fetchCooDraftTemplate(
          fileId,
          certType: certType,
        );
  }

  static Future<Map<String, dynamic>> extractFromRawText(
    WidgetRef ref, {
    required String rawText,
    required String certType,
    int? importFileId,
  }) async {
    final docTypeKey = certType.contains('China')
        ? 'CHINA_COO'
        : (certType.contains('EUR') ? 'EUR1' : 'STANDARD_COO');
    return await ref.read(cooReviewsProvider.notifier).extractCertificate(
          docTypeKey,
          rawText,
          importFileId: importFileId,
        );
  }

  static Future<Map<String, dynamic>> runComparison(
    WidgetRef ref, {
    required int fileId,
    required String certType,
    required Map<String, String> draftFields,
  }) async {
    return await ref.read(cooReviewsProvider.notifier).compareCOO(
          fileId,
          certType,
          draftFields,
        );
  }

  static Future<void> saveReview(
    WidgetRef ref,
    Map<String, dynamic> payload,
  ) async {
    await ref.read(cooReviewsProvider.notifier).saveCOOReview(payload);
    ref.invalidate(importFilesProvider);
    ref.invalidate(docsCustomsApprovalProvider);
    await ref.read(cooReviewsProvider.notifier).fetchCOOReviews();
  }

  static Future<void> deleteReview(
    WidgetRef ref,
    int reviewId,
  ) async {
    await ref.read(cooReviewsProvider.notifier).deleteCOOReview(reviewId);
    ref.invalidate(importFilesProvider);
  }

  static void exportMatrixPdf({
    required BuildContext context,
    required Map<String, dynamic>? activeDraftTemplate,
    required String certType,
    required String? activeAcidNumber,
    required String? activeExemptionNotes,
  }) {
    if (activeDraftTemplate != null) {
      if (showCooExportBlockedIfAny(
        context,
        CooExportService.missingExportField(activeDraftTemplate, activeAcidNumber),
      )) {
        return;
      }
      CooExportService.printOrSavePdf(
        templateData: activeDraftTemplate,
        certificateType: certType,
        acidNumber: activeAcidNumber ?? '',
        exemptionNotes: activeExemptionNotes,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cooExportingPdfReportSnackbar,
          severity: AppSeverity.info,
        ),
      );
    }
  }

  static void exportMatrixExcel({
    required BuildContext context,
    required Map<String, dynamic>? activeDraftTemplate,
    required String certType,
    required String? activeAcidNumber,
  }) {
    if (activeDraftTemplate != null) {
      if (showCooExportBlockedIfAny(
        context,
        CooExportService.missingExportField(activeDraftTemplate, activeAcidNumber),
      )) {
        return;
      }
      final csv = CooExportService.exportCOOCsv(
        templateData: activeDraftTemplate,
        certificateType: certType,
        acidNumber: activeAcidNumber ?? '',
      );
      CopyHelper.copy(context, csv, customMessage: context.l10n.cooExcelCopiedSnackbar);
    }
  }

  static Future<void> exportRegistryRowPdf({
    required BuildContext context,
    required WidgetRef ref,
    required CertificateOfOriginReviewModel review,
  }) async {
    final expName = review.draftInputData?['exporter_name'] ??
        review.draftInputData?['box_1_exporter'] ??
        '—';
    final tData = {
      'certificate_number': review.certificateNumber,
      'box_1_exporter': expName,
      'box_2_consignee': review.draftInputData?['importer_name'] ??
          review.draftInputData?['box_2_consignee'] ??
          '—',
      'country_of_origin': review.draftInputData?['country_of_origin'] ?? '—',
      'box_4_country_of_destination': review.draftInputData?['destination_country'] ??
          review.draftInputData?['box_4_country_of_destination'] ??
          '—',
      'box_10_invoice_number_and_date': review.draftInputData?['invoice_number'] ??
          review.draftInputData?['box_10_invoice_number_and_date'] ??
          '—',
    };
    final rowFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final rowAcid = rowFiles
            .where((f) => f.importFileId == review.importFileId)
            .firstOrNull
            ?.acidNumber ??
        '';
    if (showCooExportBlockedIfAny(
      context,
      CooExportService.missingExportField(tData, rowAcid),
    )) {
      return;
    }
    await CooExportService.printOrSavePdf(
      templateData: tData,
      certificateType: review.certificateType,
      acidNumber: rowAcid,
    );
  }
}
