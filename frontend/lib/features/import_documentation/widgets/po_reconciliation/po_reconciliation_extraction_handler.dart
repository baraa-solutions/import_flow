import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/helpers/file_picker_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/import_documentation_model.dart';
import '../../models/po_reconciliation_session_model.dart';

class PoReconciliationPickedFileResult {
  final String fileName;
  final Uint8List? fileBytes;
  final String text;

  const PoReconciliationPickedFileResult({
    required this.fileName,
    required this.fileBytes,
    required this.text,
  });
}

class PoReconciliationAppliedData {
  final String? finalInvoiceNumber;
  final String? finalPackingListNumber;
  final List<POReconciliationItemModel>? invoiceItems;
  final List<POReconciliationItemModel>? packingItems;

  const PoReconciliationAppliedData({
    this.finalInvoiceNumber,
    this.finalPackingListNumber,
    this.invoiceItems,
    this.packingItems,
  });
}

/// Helper for extraction sample loading, file picking, and data extraction application.
class PoReconciliationExtractionHandler {
  static Future<PoReconciliationPickedFileResult?> pickDocumentFile(BuildContext context) async {
    final l = context.l10n;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'tif', 'tiff', 'txt', 'csv', 'xlsx', 'docx', 'doc', 'xls'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileBytes = FilePickerHelper.getBytes(file);
        final text = (FilePickerHelper.isPlainTextFile(file.name) ? FilePickerHelper.tryDecodeText(fileBytes) : null) ??
            l.poRecExtractedDigitalFileNotice(file.name);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecFileSelected(file.name, (file.size / 1024).toStringAsFixed(1))));
        }
        return PoReconciliationPickedFileResult(
          fileName: file.name,
          fileBytes: fileBytes,
          text: text,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecFilePickFailed(e.toString()), severity: AppSeverity.info));
      }
    }
    return null;
  }

  static PoReconciliationAppliedData applyExtractedData({
    required Map<String, dynamic> extractedData,
    required String currentInvoiceNumber,
  }) {
    final invData = extractedData['extracted_invoice_data'] as Map<String, dynamic>?;
    final plData = extractedData['extracted_packing_data'] as Map<String, dynamic>?;
    final rawRecInv = extractedData['reconciled_invoice_items'] as List<dynamic>?;
    final rawRecPl = extractedData['reconciled_packing_items'] as List<dynamic>?;

    String? invNum;
    String? plNum;
    if (invData != null && invData['invoice_number'] != null) {
      invNum = invData['invoice_number'].toString();
    }
    if (plData != null) {
      plNum = plData['packing_list_number']?.toString() ?? 'PL-${invNum ?? currentInvoiceNumber}';
    }
    final invItems = (rawRecInv != null && rawRecInv.isNotEmpty)
        ? rawRecInv.map((j) => POReconciliationItemModel.fromJson(j as Map<String, dynamic>)).toList()
        : null;
    final plItems = (rawRecPl != null && rawRecPl.isNotEmpty)
        ? rawRecPl.map((j) => POReconciliationItemModel.fromJson(j as Map<String, dynamic>)).toList()
        : null;

    return PoReconciliationAppliedData(
      finalInvoiceNumber: invNum,
      finalPackingListNumber: plNum,
      invoiceItems: invItems,
      packingItems: plItems,
    );
  }

  static Map<String, dynamic> buildExtractedDataFromSession(POReconciliationSessionModel session, {bool isDraft = false}) {
    return {
      'overall_status': isDraft ? 'DRAFT' : session.overallStatus,
      'is_safe_for_certification': isDraft ? false : session.isSafeForCertification,
      'critical_discrepancies_count': session.criticalDiscrepanciesCount,
      'warning_discrepancies_count': session.warningDiscrepanciesCount,
      'header_discrepancies': session.headerDiscrepancies,
      'reconciled_invoice_items': session.reconciledInvoiceItems,
      'reconciled_packing_items': session.reconciledPackingItems,
      'extracted_invoice_data': session.extractedInvoiceData,
      'extracted_packing_data': session.extractedPackingData,
    };
  }

  static List<POReconciliationItemModel> parseSessionItems(List<dynamic>? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.map((j) => POReconciliationItemModel.fromJson(j as Map<String, dynamic>)).toList();
  }
}
