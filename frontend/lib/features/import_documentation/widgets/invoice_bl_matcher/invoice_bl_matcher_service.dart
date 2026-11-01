import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/helpers/file_picker_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/invoice_bl_match_session_model.dart';
import '../../providers/docs_customs_approval_provider.dart';
import '../../providers/import_documentation_provider.dart';
import '../idoc_feedback.dart';
import '../idoc_ui.dart';
import 'invoice_bl_matcher_actions_bar.dart';
import 'invoice_bl_matcher_controllers.dart';

/// Data class holding the result of file picking for Commercial Invoice, Packing List, or B/L.
class InvoiceBlFileSelectionResult {
  final List<PlatformFile> resolvedFiles;
  final String displayName;
  final Uint8List? fileBytes;
  final String? decodedText;

  const InvoiceBlFileSelectionResult({
    required this.resolvedFiles,
    required this.displayName,
    required this.fileBytes,
    required this.decodedText,
  });
}

/// Network, file-picking, and session state transformation service for Screen 22: Invoice vs B/L Matcher.
class InvoiceBlMatcherService {
  static void _addFiles(FormData fd, String field, List<PlatformFile> files) {
    for (final f in files) {
      final b = f.bytes;
      if (b != null) {
        fd.files.add(MapEntry(field, MultipartFile.fromBytes(b, filename: f.name)));
      }
    }
  }

  /// Runs the cross-document matching API call against either multi-part file uploads or raw text payloads.
  static Future<Map<String, dynamic>> runCrossMatching({
    required Dio dio,
    required Dio uploadDio,
    CancelToken? cancelToken,
    required int? activeFileId,
    required InvoiceBlMatcherControllers ctrls,
  }) async {
    final hasInvoiceFile = ctrls.invoiceFiles.isNotEmpty || ctrls.invoiceFileBytes != null;
    final hasBlFile = ctrls.blFiles.isNotEmpty || ctrls.blFileBytes != null;
    final hasPackingFile = ctrls.packingFiles.isNotEmpty || ctrls.packingFileBytes != null;

    final invText = ctrls.invoiceTextCtrl.text.trim();
    final blTxt = ctrls.blTextCtrl.text.trim();
    final plText = ctrls.packingTextCtrl.text.trim();

    Response response;

    if (hasInvoiceFile || hasBlFile || hasPackingFile) {
      final formData = FormData();
      if (activeFileId != null) {
        formData.fields.add(MapEntry('import_file_id', activeFileId.toString()));
      }

      if (ctrls.invoiceFiles.isNotEmpty) {
        _addFiles(formData, 'invoice_files', ctrls.invoiceFiles);
      } else if (ctrls.invoiceFileBytes != null) {
        formData.files.add(MapEntry(
          'invoice_file',
          MultipartFile.fromBytes(ctrls.invoiceFileBytes!, filename: ctrls.invoiceFileName ?? 'invoice.pdf'),
        ));
      } else if (invText.isNotEmpty && !invText.startsWith('[')) {
        formData.fields.add(MapEntry('invoice_text', invText));
      }

      if (ctrls.packingFiles.isNotEmpty) {
        _addFiles(formData, 'packing_list_files', ctrls.packingFiles);
      } else if (ctrls.packingFileBytes != null) {
        formData.files.add(MapEntry(
          'packing_list_file',
          MultipartFile.fromBytes(ctrls.packingFileBytes!, filename: ctrls.packingFileName ?? 'packing_list.pdf'),
        ));
      } else if (plText.isNotEmpty && !plText.startsWith('[')) {
        formData.fields.add(MapEntry('packing_list_text', plText));
      }

      if (ctrls.blFiles.isNotEmpty) {
        _addFiles(formData, 'bl_files', ctrls.blFiles);
      } else if (ctrls.blFileBytes != null) {
        formData.files.add(MapEntry(
          'bl_file',
          MultipartFile.fromBytes(ctrls.blFileBytes!, filename: ctrls.blFileName ?? 'bl.pdf'),
        ));
      } else if (blTxt.isNotEmpty && !blTxt.startsWith('[')) {
        formData.fields.add(MapEntry('bl_text', blTxt));
      }

      response = await uploadDio.post(
        '${ApiConstants.baseUrl}/import-documentation/invoice-bl/extract-files-and-match',
        data: formData,
        cancelToken: cancelToken,
      );
    } else {
      response = await dio.post(
        '${ApiConstants.baseUrl}/import-documentation/invoice-bl/extract-and-match',
        data: {
          'import_file_id': activeFileId,
          'invoice_raw_text': ctrls.invoiceTextCtrl.text,
          'bl_raw_text': ctrls.blTextCtrl.text,
          'packing_list_raw_text': ctrls.packingTextCtrl.text,
        },
        cancelToken: cancelToken,
      );
    }

    if (response.statusCode == 200) {
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;
    }
    throw Exception('Server returned ${response.statusCode}: ${response.data}');
  }

  /// Picks and decodes files for invoice, packing list, or B/L.
  static Future<InvoiceBlFileSelectionResult?> pickDocFiles(
    BuildContext context,
    String docType,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'tif', 'tiff', 'txt', 'csv', 'doc', 'docx', 'xlsx', 'xls'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final resolved = FilePickerHelper.resolveFilesWithBytes(result.files);
        final file = resolved.isNotEmpty ? resolved.first : result.files.first;
        final count = resolved.length;
        final fileBytes = file.bytes ?? FilePickerHelper.getBytes(file);
        final decodedText = FilePickerHelper.isPlainTextFile(file.name) && count == 1
            ? FilePickerHelper.tryDecodeText(fileBytes)
            : null;
        final displayName = count == 1 ? file.name : '${file.name} (+$count)';

        return InvoiceBlFileSelectionResult(
          resolvedFiles: resolved,
          displayName: displayName,
          fileBytes: fileBytes,
          decodedText: decodedText,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.invoiceBlMatcherFileReadError(e), severity: AppSeverity.danger),
        );
      }
    }
    return null;
  }

  /// Saves session either as draft or final approved session, handling justification dialog and provider invalidation.
  static Future<InvoiceBLMatchSessionModel?> executeSaveSession({
    required BuildContext context,
    required WidgetRef ref,
    required int? activeFileId,
    required bool isDraft,
    required Map<String, dynamic>? matchResult,
  }) async {
    if (activeFileId == null) {
      showIdocMessage(context, context.l10n.invoiceBlMatcherSelectFileFirstWarning, color: AppTheme.crimson);
      return null;
    }

    String? justification;
    final criticalCount = (matchResult?['critical_discrepancies_count'] as num?)?.toInt() ?? 0;
    final needsJustification = !isDraft &&
        matchResult != null &&
        (matchResult['is_safe_for_certification'] == false || criticalCount > 0);
    if (needsJustification) {
      justification = await InvoiceBlMatcherDialogHelper.askCertifyJustification(context);
      if (justification == null) return null;
    }
    if (!context.mounted) return null;

    try {
      final payload = InvoiceBLMatchSessionModel.toCreateJson(
        importFileId: activeFileId,
        isDraft: isDraft,
        matchResult: matchResult,
        notes: justification,
      );

      final created = await ref.read(invoiceBLMatchSessionsProvider.notifier).createSession(payload);
      ref.invalidate(importFilesProvider);
      ref.invalidate(docsCustomsApprovalProvider);
      ref.invalidate(centralArchiveProvider);
      ref.invalidate(legalComplianceFamilyProvider);

      if (context.mounted) {
        final l = context.l10n;
        showIdocMessage(
          context,
          isDraft ? l.idocADraftSaved(created.sessionCode) : l.idocASessionApproved(created.sessionCode),
          color: isDraft ? AppTheme.cobalt : AppTheme.emerald,
        );
      }
      return created;
    } catch (e) {
      if (context.mounted) {
        showIdocError(
          context,
          e,
          title: isDraft ? context.l10n.idocADraftSaveFailed : context.l10n.idocAFinalApprovalFailed,
        );
      }
      return null;
    }
  }

  /// Prompts for confirmation and deletes draft session.
  static Future<bool> confirmAndDeleteSession(
    BuildContext context,
    WidgetRef ref,
    InvoiceBLMatchSessionModel session,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: Text(context.l10n.idocAConfirmDraftDeletion),
          content: Text(context.l10n.idocAAreYouSureYouWantTo(session.sessionCode)),
          actions: [
            IdocUi.fit(AppButton(
              label: context.l10n.cancel,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx, false),
            )),
            IdocUi.fit(AppButton(
              label: context.l10n.delete,
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(ctx, true),
            )),
          ],
        ),
      ),
    );
    if (confirm != true) return false;

    try {
      await ref.read(invoiceBLMatchSessionsProvider.notifier).deleteSession(session.sessionId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.idocADraftDeletedSuccessfully, severity: AppSeverity.success),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        showIdocError(context, e, title: context.l10n.idocADeleteSessionFailed);
      }
      return false;
    }
  }

  /// Rebuilds match result map from an existing saved session model.
  static Map<String, dynamic> buildMatchResultFromSession(InvoiceBLMatchSessionModel session) {
    return {
      'import_file_id': session.importFileId,
      'match_score_percentage': session.matchScore,
      'is_safe_for_certification': session.isSafeForCertification,
      'critical_discrepancies_count': session.criticalDiscrepanciesCount,
      'warning_discrepancies_count': session.warningDiscrepanciesCount,
      'comparison_matrix': session.comparisonMatrix,
      'invoice_data': session.invoiceData,
      'bl_data': session.blData,
      'packing_list_data': session.packingListData,
      'overall_status': session.isDraft ? 'DRAFT_SAVED' : 'CERTIFIED_SAVED',
    };
  }

  /// Clones session data for a new editable draft session.
  static Map<String, dynamic> cloneSessionToMatchResult(InvoiceBLMatchSessionModel session) {
    return {
      'import_file_id': session.importFileId,
      'match_score_percentage': session.matchScore,
      'is_safe_for_certification': session.isSafeForCertification,
      'critical_discrepancies_count': session.criticalDiscrepanciesCount,
      'warning_discrepancies_count': session.warningDiscrepanciesCount,
      'comparison_matrix': session.comparisonMatrix != null
          ? List<Map<String, dynamic>>.from(
              session.comparisonMatrix!.map((e) => Map<String, dynamic>.from(e)),
            )
          : <Map<String, dynamic>>[],
      'invoice_data': session.invoiceData != null ? Map<String, dynamic>.from(session.invoiceData!) : <String, dynamic>{},
      'bl_data': session.blData != null ? Map<String, dynamic>.from(session.blData!) : <String, dynamic>{},
      'packing_list_data': session.packingListData != null
          ? Map<String, dynamic>.from(session.packingListData!)
          : <String, dynamic>{},
      'overall_status': 'DRAFT_SAVED',
    };
  }
}
