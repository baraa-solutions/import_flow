import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/providers/import_files_provider.dart';
import 'coo_review_controllers.dart';
import 'coo_review_dialogs.dart';
import 'coo_review_service.dart';

class CooReviewWorkflowService {
  final WidgetRef ref;
  const CooReviewWorkflowService(this.ref);

  Future<Map<String, dynamic>?> fetchAndApplyDraft({
    required int fileId,
    required CooReviewControllers controllers,
    String? overrideCertType,
  }) async {
    try {
      final res = await CooReviewService.fetchDraftTemplate(
        ref,
        fileId,
        certType: overrideCertType,
      );
      final template = res['template_data'] as Map<String, dynamic>? ?? {};
      final file = (ref.read(importFilesProvider).value ?? [])
          .where((f) => f.importFileId == fileId)
          .firstOrNull;

      final recType = res['recommended_certificate_type']?.toString();
      final retCertType =
          (res['certificate_type'] ?? template['certificate_type'] ?? recType)?.toString();
      final allowed = (res['allowed_certificate_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final resolvedCertType = overrideCertType ??
          ((retCertType != null && retCertType.isNotEmpty)
              ? retCertType
              : ((recType != null && recType.isNotEmpty) ? recType : null));

      if (template['certificate_number'] != null) {
        controllers.certNumber.text = template['certificate_number'].toString();
      }
      if (template['country_of_origin'] != null) {
        controllers.originCountry.text = template['country_of_origin'].toString();
      }
      if (template['box_1_exporter'] != null) {
        controllers.exporter.text = template['box_1_exporter'].toString();
      }
      if (template['box_2_consignee'] != null) {
        controllers.importer.text = template['box_2_consignee'].toString();
      }

      return {
        'certType': resolvedCertType,
        'recommendationAlert': res['recommendation_alert']?.toString(),
        'isManualChoiceRequired': res['is_manual_choice_required'] == true,
        'allowedCertTypes': allowed,
        'template': template,
        'acidNumber': (file?.acidNumber != null && file!.acidNumber!.isNotEmpty)
            ? file.acidNumber
            : '',
        'exemptionNotes': res['exemption_notes']?.toString(),
      };
    } catch (e) {
      debugPrint('Error fetching COO template: $e');
      return null;
    }
  }

  Future<void> generateOfficialDraft({
    required BuildContext context,
    required int? fileId,
    required String certType,
    required CooReviewControllers controllers,
    required VoidCallback onRefresh,
    required void Function(Map<String, dynamic> template, String acidNo, String exemption)
        onAutofilled,
  }) async {
    if (fileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cooSelectFileFirstForComparison,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    try {
      final res = await CooReviewService.fetchDraftTemplate(ref, fileId, certType: certType);
      if (!context.mounted) return;

      final preview = res['preview_markdown']?.toString() ?? '';
      final template = res['template_data'] as Map<String, dynamic>? ?? {};
      final exemption = res['exemption_notes']?.toString() ?? '';
      final files = ref.read(importFilesProvider).value ?? [];
      final file = files.where((f) => f.importFileId == fileId).firstOrNull;
      final acidNo = file?.acidNumber ?? '';

      CooReviewDialogs.showOfficialDraftPreviewDialog(
        context: context,
        template: template,
        certType: res['certificate_type'] ?? certType,
        acidNo: acidNo,
        exemption: exemption,
        preview: preview,
        onRefresh: onRefresh,
        onAutoFill: ({certNumber, originCountry, destCountry, exporter, importer, rawText}) {
          if (certNumber != null) controllers.certNumber.text = certNumber;
          if (originCountry != null) controllers.originCountry.text = originCountry;
          if (destCountry != null) controllers.destCountry.text = destCountry;
          if (exporter != null) controllers.exporter.text = exporter;
          if (importer != null) controllers.importer.text = importer;
          if (rawText != null) controllers.rawText.text = rawText;
          onAutofilled(template, acidNo, exemption);
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              context.l10n.cooDraftFilledSuccess,
              severity: AppSeverity.success,
            ),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cooGenerateDraftError(ApiErrorText.of(context.l10n, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  Future<void> extractFromOcrText({
    required BuildContext context,
    required int? fileId,
    required String certType,
    required CooReviewControllers controllers,
  }) async {
    final rawText = controllers.rawText.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cooPasteTextOrUploadWarning,
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    try {
      final res = await CooReviewService.extractFromRawText(
        ref,
        rawText: rawText,
        certType: certType,
        importFileId: fileId,
      );

      final extracted = res['extracted_data'] as Map<String, dynamic>? ?? {};
      final warnings = res['warnings'] as List<dynamic>? ?? [];

      controllers.certNumber.text = extracted['certificate_number']?.toString() ?? '';
      controllers.originCountry.text = extracted['country_of_origin']?.toString() ??
          extracted['origin_country']?.toString() ??
          '';
      controllers.destCountry.text =
          extracted['destination_country']?.toString() ?? 'Egypt';
      controllers.exporter.text = extracted['exporter_name']?.toString() ?? '';
      controllers.exporterRegId.text = extracted['exporter_reg_id']?.toString() ?? '';
      controllers.importer.text = extracted['importer_name']?.toString() ??
          extracted['consignee_name']?.toString() ??
          '';
      controllers.invoiceNo.text = extracted['invoice_number']?.toString() ?? '';

      if (context.mounted) {
        final snack = warnings.isNotEmpty
            ? AppTheme.snackBar(context, warnings.join('\n'), severity: AppSeverity.warning)
            : AppTheme.snackBar(context, context.l10n.cooAiExtractSuccess,
                severity: AppSeverity.success);
        ScaffoldMessenger.of(context).showSnackBar(snack);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cooExtractError(ApiErrorText.of(context.l10n, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> runComparison({
    required BuildContext context,
    required int? fileId,
    required String certType,
    required CooReviewControllers controllers,
  }) async {
    if (fileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cooSelectFileFirstForComparison,
          severity: AppSeverity.danger,
        ),
      );
      return null;
    }

    try {
      final draftFields = {
        'certificate_type': certType,
        'certificate_number': controllers.certNumber.text.trim(),
        'exporter_name': controllers.exporter.text.trim(),
        'exporter_reg_id': controllers.exporterRegId.text.trim(),
        'importer_name': controllers.importer.text.trim(),
        'country_of_origin': controllers.originCountry.text.trim(),
        'destination_country': controllers.destCountry.text.trim(),
        'invoice_number': controllers.invoiceNo.text.trim(),
      };
      return await CooReviewService.runComparison(
        ref,
        fileId: fileId,
        certType: certType,
        draftFields: draftFields,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cooComparisonError(ApiErrorText.of(context.l10n, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
      return null;
    }
  }

  Future<bool> saveReview({
    required BuildContext context,
    required int? fileId,
    required String certType,
    required Map<String, dynamic>? comparisonResult,
    required CooReviewControllers controllers,
    required bool isDraft,
  }) async {
    if (comparisonResult == null || fileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cooSelectFileFirstForComparison,
          severity: AppSeverity.warning,
        ),
      );
      return false;
    }

    final hasDisc = comparisonResult['has_discrepancies'] as bool? ?? false;
    final hasCritical = comparisonResult['has_critical_mismatch'] as bool? ?? false;
    final reason = controllers.overrideReason.text.trim();

    if (!isDraft && (hasDisc || hasCritical) && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cooMustProvideJustificationSnackbar,
          severity: AppSeverity.warning,
        ),
      );
      return false;
    }

    try {
      final snap = comparisonResult['system_snapshot_data'] as Map<String, dynamic>? ?? {};
      final draft = comparisonResult['draft_input_data'] as Map<String, dynamic>? ?? {};

      final expName = controllers.exporter.text.trim().isNotEmpty
          ? controllers.exporter.text.trim()
          : (draft['exporter_name'] ?? snap['exporter_name'] ?? 'Exporter');
      final impName = controllers.importer.text.trim().isNotEmpty
          ? controllers.importer.text.trim()
          : (draft['importer_name'] ?? snap['importer_name'] ?? 'Importer');
      final originCountry = controllers.originCountry.text.trim().isNotEmpty
          ? controllers.originCountry.text.trim()
          : (draft['country_of_origin'] ?? snap['country_of_origin'] ?? 'China');
      final destCountry = controllers.destCountry.text.trim().isNotEmpty
          ? controllers.destCountry.text.trim()
          : 'Egypt';

      final statusValue = isDraft
          ? 'Draft Generated'
          : (hasDisc
              ? (hasCritical ? 'Correction Requested' : 'Discrepancy_Accepted')
              : 'Approved');

      final payload = {
        'import_file_id': fileId,
        'certificate_type': certType,
        'certificate_number': controllers.certNumber.text.trim().isNotEmpty
            ? controllers.certNumber.text.trim()
            : 'DRAFT-COO',
        'exporter_name': expName,
        'importer_name': impName,
        'country_of_origin': originCountry,
        'destination_country': destCountry,
        'invoice_number': controllers.invoiceNo.text.trim(),
        'raw_input_text': controllers.rawText.text,
        'raw_text': controllers.rawText.text,
        'system_snapshot_data': comparisonResult['system_snapshot_data'],
        'draft_input_data': comparisonResult['draft_input_data'],
        'comparison_matrix': comparisonResult['comparison_matrix'],
        'has_discrepancies': hasDisc,
        'has_critical_mismatch': hasCritical,
        'override_reason': reason,
        'is_draft': isDraft,
        'status': statusValue,
      };

      await CooReviewService.saveReview(ref, payload);
      if (context.mounted) {
        final msg = isDraft
            ? '${context.l10n.idocBCooSavedDraft} 💾'
            : '${context.l10n.idocBCooCertified} ✅';
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, msg, severity: AppSeverity.success),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cooSaveError(ApiErrorText.of(context.l10n, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
      return false;
    }
  }
}
