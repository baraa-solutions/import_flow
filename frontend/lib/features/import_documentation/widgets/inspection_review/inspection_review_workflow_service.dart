import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/import_documentation_model.dart';
import '../../providers/import_documentation_provider.dart';
import '../../services/inspection_export_service.dart';
import 'inspection_review_controllers.dart';
import 'inspection_review_dialogs.dart';

enum InspectionExportType { tsv, excel, pdf, dossier }

class InspectionReviewWorkflowService {
  final WidgetRef ref;
  const InspectionReviewWorkflowService(this.ref);

  static void showAcidMissing(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.idocBExportBlockedAcid, severity: AppSeverity.danger),
    );
  }

  static bool blockIfAcidMissing(BuildContext context, String effectiveAcid) {
    if (effectiveAcid.isNotEmpty) return false;
    showAcidMissing(context);
    return true;
  }

  Future<Map<String, dynamic>?> fetchDraftTemplate({
    required int fileId,
    required String agency,
    required String certType,
  }) async {
    try {
      final res = await ref.read(inspectionReviewsProvider.notifier).fetchInspectionDraftTemplate(
            fileId,
            agency: agency,
            certType: certType,
          );
      final template = res['template_data'] as Map<String, dynamic>? ?? {};
      final standards = (res['applicable_standards'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      final file = files.where((f) => f.importFileId == fileId).firstOrNull;

      final acid = (file?.acidNumber != null && file!.acidNumber!.isNotEmpty)
          ? file.acidNumber!
          : (template['acid_number'] ?? '').toString();

      return {
        'template': template,
        'standards': standards,
        'acidNumber': acid,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> runComparison({
    required BuildContext context,
    required int? selectedImportFileId,
    required String inspType,
    required String inspAgency,
    required InspectionReviewControllers controllers,
  }) async {
    final l10n = context.l10n;
    if (selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.pleaseSelectFileFirstPrompt, severity: AppSeverity.danger),
      );
      return null;
    }

    try {
      final draftFields = controllers.buildDraftFields(inspType, inspAgency);
      final res = await ref.read(inspectionReviewsProvider.notifier).compareInspection(
            selectedImportFileId,
            inspType,
            inspAgency,
            draftFields,
          );
      return res;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l10n.inspectionComparisonError(ApiErrorText.of(l10n, e)), severity: AppSeverity.danger),
        );
      }
      return null;
    }
  }

  Future<bool> saveReview({
    required BuildContext context,
    required int? selectedImportFileId,
    required String inspType,
    required String inspAgency,
    required String effectiveAcid,
    required Map<String, dynamic>? comparisonResult,
    required InspectionReviewControllers controllers,
  }) async {
    final l10n = context.l10n;
    if (comparisonResult == null || selectedImportFileId == null) return false;
    if (blockIfAcidMissing(context, effectiveAcid)) return false;
    if (controllers.certNumberCtrl.text.trim().isEmpty || controllers.authorityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.idocBInspectionFieldsRequired, severity: AppSeverity.danger),
      );
      return false;
    }

    final hasDisc = comparisonResult['has_discrepancies'] as bool? ?? false;
    final hasCritical = comparisonResult['has_critical_mismatch'] as bool? ?? false;
    final reason = controllers.overrideReasonCtrl.text.trim();

    if ((hasDisc || hasCritical) && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, '⚠️ ${l10n.overrideReasonMandatoryWarning}', severity: AppSeverity.warning),
      );
      return false;
    }

    try {
      final payload = {
        'import_file_id': selectedImportFileId,
        'inspection_type': inspType,
        'inspection_agency': inspAgency,
        'certificate_number': controllers.certNumberCtrl.text.trim(),
        'regulatory_authority': controllers.authorityCtrl.text.trim(),
        'standard_specification': controllers.specCtrl.text.trim(),
        'raw_input_text': controllers.rawTextCtrl.text,
        'raw_text': controllers.rawTextCtrl.text,
        'system_snapshot_data': comparisonResult['system_snapshot_data'],
        'draft_input_data': comparisonResult['draft_input_data'],
        'comparison_matrix': comparisonResult['comparison_matrix'],
        'has_discrepancies': hasDisc,
        'has_critical_mismatch': hasCritical,
        'override_reason': reason,
        'status': hasDisc ? (hasCritical ? 'Correction Requested' : 'Discrepancy_Accepted') : 'Verified',
      };

      await ref.read(inspectionReviewsProvider.notifier).saveInspectionReview(payload);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, '✔ ${l10n.saveInspectionReviewSuccess}', severity: AppSeverity.success),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l10n.saveInspectionReviewError(ApiErrorText.of(l10n, e)), severity: AppSeverity.danger),
        );
      }
      return false;
    }
  }

  Future<void> generateOfficialDraft({
    required BuildContext context,
    required int? selectedImportFileId,
    required String inspAgency,
    required String certType,
    required VoidCallback onRefresh,
    required void Function(Map<String, dynamic> template, String acidNo, List<String> standards) onLoaded,
    required VoidCallback onApplyData,
  }) async {
    final l10n = context.l10n;
    if (selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.generateDraftSelectFileFirstPrompt, severity: AppSeverity.danger),
      );
      return;
    }

    try {
      final res = await ref.read(inspectionReviewsProvider.notifier).fetchInspectionDraftTemplate(
            selectedImportFileId,
            agency: inspAgency,
            certType: certType,
          );
      if (!context.mounted) return;

      final template = res['template_data'] as Map<String, dynamic>? ?? {};
      final standards = (res['applicable_standards'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      final file = files.where((f) => f.importFileId == selectedImportFileId).firstOrNull;
      final acidNo = file?.acidNumber ?? '';

      onLoaded(template, acidNo, standards);

      InspectionReviewDialogs.showVisualPreviewDialog(
        context: context,
        agency: inspAgency,
        certType: certType,
        acidNumber: acidNo,
        standards: standards,
        template: template,
        onRefresh: onRefresh,
        onApplyData: () {
          onApplyData();
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, '✔ ${l10n.inspectionDraftDataAppliedSuccess}', severity: AppSeverity.success),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l10n.generateDraftError(ApiErrorText.of(l10n, e)), severity: AppSeverity.danger),
        );
      }
    }
  }

  Future<void> extractFromOcrText({
    required BuildContext context,
    required int? selectedImportFileId,
    required InspectionReviewControllers controllers,
    required void Function(String agency, String type) onMetaFound,
  }) async {
    final l10n = context.l10n;
    final rawText = controllers.rawTextCtrl.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.pasteRawTextFirstPrompt, severity: AppSeverity.warning),
      );
      return;
    }

    try {
      final res = await ref.read(inspectionReviewsProvider.notifier).extractCertificate(
            'INSPECTION_VOC',
            rawText,
            importFileId: selectedImportFileId,
          );

      final extracted = res['extracted_data'] as Map<String, dynamic>? ?? {};
      final isDraft = res['is_draft_detected'] as bool? ?? false;
      final warnings = res['warnings'] as List<dynamic>? ?? [];

      controllers.applyOcrExtracted(extracted, onMetaFound);

      if (context.mounted) {
        if (warnings.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l10n.inspectionOcrWarningsAlert(warnings.join(', ')), severity: AppSeverity.warning),
          );
        } else if (isDraft) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, '⚠️ ${l10n.inspectionDraft48hWarningAlert}', severity: AppSeverity.warning),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, '✔ ${l10n.inspectionExtractionSuccess}', severity: AppSeverity.success),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l10n.inspectionComparisonError(ApiErrorText.of(l10n, e)), severity: AppSeverity.danger),
        );
      }
    }
  }

  void handleExport({
    required BuildContext context,
    required InspectionExportType type,
    required String effectiveAcid,
    required Map<String, dynamic> template,
    required String agency,
    required String certType,
    required List<String> standards,
    required List<dynamic> matrix,
    String? overrideReason,
  }) {
    if (blockIfAcidMissing(context, effectiveAcid)) return;
    switch (type) {
      case InspectionExportType.tsv:
        InspectionExportService.saveInspectionTsvToFile(
          context: context,
          templateData: template,
          agency: agency,
          certType: certType,
          acidNumber: effectiveAcid,
          standards: standards,
          comparisonMatrix: matrix,
        );
      case InspectionExportType.excel:
        InspectionExportService.saveInspectionCsvToFile(
          context: context,
          templateData: template,
          agency: agency,
          certType: certType,
          acidNumber: effectiveAcid,
          standards: standards,
          comparisonMatrix: matrix,
        );
      case InspectionExportType.pdf:
        InspectionExportService.saveInspectionPdfToFile(
          context: context,
          templateData: template,
          agency: agency,
          certType: certType,
          acidNumber: effectiveAcid,
          standards: standards,
          comparisonMatrix: matrix,
        );
      case InspectionExportType.dossier:
        InspectionExportService.copyDossierToClipboard(
          context,
          templateData: template,
          agency: agency,
          certType: certType,
          acidNumber: effectiveAcid,
          standards: standards,
          comparisonMatrix: matrix,
          overrideReason: overrideReason,
        );
    }
  }

  Future<void> downloadReviewPdf({
    required BuildContext context,
    required InspectionCertificateReviewModel review,
    required List<String> activeStandards,
  }) async {
    final rowFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final rowAcid = (rowFiles.where((f) => f.importFileId == review.importFileId).firstOrNull?.acidNumber ?? '').trim();
    if (rowAcid.isEmpty) {
      showAcidMissing(context);
      return;
    }
    final tData = {
      'certificate_number': review.certificateNumber,
      'inspection_agency': review.inspectionAgency,
      'inspection_type': review.inspectionType,
      ...?review.draftInputData,
    };
    await InspectionExportService.printOrSavePdf(
      templateData: tData,
      agency: review.inspectionAgency,
      certType: review.inspectionType,
      acidNumber: rowAcid,
      standards: activeStandards,
    );
  }
}
