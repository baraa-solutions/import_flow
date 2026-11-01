import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../models/import_documentation_model.dart';
import '../../models/po_reconciliation_session_model.dart';
import '../../providers/import_documentation_provider.dart';
import '../../utils/po_reconciliation_payload_builder.dart';
import 'po_reconciliation_client_extractor.dart';
import 'po_reconciliation_dialogs.dart';
import 'po_reconciliation_localizer.dart';

/// Service managing API interactions, background saves, and smart extractions
/// for PO & Packing Reconciliation.
class PoReconciliationService {
  static Future<Map<String, dynamic>?> runSmartExtraction({
    required BuildContext context,
    required WidgetRef ref,
    required int? importFileId,
    required String invText,
    required String plText,
    required Uint8List? invoiceFileBytes,
    required Uint8List? packingFileBytes,
    required String? selectedInvoiceFileName,
    required String? selectedPackingFileName,
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
    required String? finalInvoiceNumber,
  }) async {
    final l = context.l10n;
    final List<String> issues = [];
    final List<String> recs = [];

    if (importFileId == null) {
      issues.add(l.poRecIssueNoFileSelected);
      recs.add(l.poRecRecSelectFileFromList);
    }
    final hasInvoice = (invoiceFileBytes != null) || (invText.isNotEmpty && !invText.startsWith('['));
    final hasPacking = (packingFileBytes != null) || (plText.isNotEmpty && !plText.startsWith('['));
    if (!hasInvoice && !hasPacking) {
      issues.add(l.poRecIssueEmptyInputs);
      recs.add(l.poRecRecProvideInputs);
    }
    if (issues.isNotEmpty) {
      PoReconciliationDialogs.showInputValidationDialog(context, title: l.poRecInputValidationTitle, issues: issues, recommendations: recs);
      return null;
    }

    try {
      final dio = ref.read(uploadDioProvider);
      final hasBinary = invoiceFileBytes != null || packingFileBytes != null;
      final endpoint = hasBinary
          ? '${ApiConstants.baseUrl}/import-documentation/po-reconciliation/extract-files-and-compare'
          : '${ApiConstants.baseUrl}/import-documentation/po-reconciliation/extract-and-compare';

      dynamic body;
      if (hasBinary) {
        final formMap = <String, dynamic>{if (importFileId != null) 'import_file_id': importFileId.toString()};
        if (invoiceFileBytes != null) {
          formMap['invoice_file'] = MultipartFile.fromBytes(invoiceFileBytes, filename: selectedInvoiceFileName ?? 'invoice.pdf');
        } else if (invText.isNotEmpty && !invText.startsWith('[')) {
          formMap['invoice_text'] = invText;
        }
        if (packingFileBytes != null) {
          formMap['packing_file'] = MultipartFile.fromBytes(packingFileBytes, filename: selectedPackingFileName ?? 'packing_list.pdf');
        } else if (plText.isNotEmpty && !plText.startsWith('[')) {
          formMap['packing_text'] = plText;
        }
        body = FormData.fromMap(formMap);
      } else {
        body = {
          'import_file_id': importFileId,
          'invoice_raw_text': invText,
          'packing_list_raw_text': plText,
          'system_items': invoiceItems.map((i) => i.toJson()).toList(),
          'system_packing_items': packingItems.map((i) => i.toJson()).toList(),
        };
      }

      final response = await dio.post(endpoint, data: body);
      if (response.statusCode == 200 && response.data != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecServerSuccessNotice, severity: AppSeverity.success));
        }
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      final currentFile = allFiles.where((f) => f.importFileId == importFileId).firstOrNull;
      final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
      final linkedPO = allPOs.where((po) => po.importFileId == importFileId).firstOrNull;

      final fallback = PoReconciliationClientExtractor.performClientSideFallbackExtraction(
        invText: invText,
        plText: plText,
        currentFile: currentFile,
        linkedPO: linkedPO,
        finalInvoiceNumber: finalInvoiceNumber,
        invoiceItems: invoiceItems,
        packingItems: packingItems,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecFallbackSuccessNotice, severity: AppSeverity.success));
      }
      return fallback;
    }
    return null;
  }

  static Future<POReconciliationSessionModel?> saveSession({
    required BuildContext context,
    required WidgetRef ref,
    required int? activeSessionId,
    required int importFileId,
    required String finalInvoiceNumber,
    required String finalPackingListNumber,
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
    required Map<String, dynamic>? extractedData,
    required String Function(String?) formatSessionDate,
  }) async {
    final l = context.l10n;
    final totalAmount = invoiceItems.fold(0.0, (s, i) => s + (i.finalQuantity * (i.finalUnitPrice > 0 ? i.finalUnitPrice : i.unitPrice)));
    final totalPackages = packingItems.fold(0.0, (s, i) => s + i.finalPackagesCount);
    final totalGross = packingItems.fold(0.0, (s, i) => s + i.finalGrossWeightKg);
    final totalNet = packingItems.fold(0.0, (s, i) => s + i.finalNetWeightKg);
    final totalCbm = packingItems.fold(0.0, (s, i) => s + i.finalCbm);

    final sessionsList = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
    final existing = sessionsList.where((s) => s.importFileId == importFileId && s.sessionId != activeSessionId && s.isActive).firstOrNull;

    if (existing != null) {
      final isDraft = existing.overallStatus.toUpperCase() == 'DRAFT';
      final statusLabel = isDraft ? l.idocADraft3 : l.idocASavedApprovedStatus(existing.overallStatus);
      final updater = existing.certifiedBy?.isNotEmpty == true ? existing.certifiedBy! : l.idocADocumentsReviewer;
      final updatedTime = formatSessionDate(existing.updatedAt ?? existing.createdAt);
      final confirm = await PoReconciliationDialogs.showExistingSessionConfirmDialog(
        context,
        statusLabel: statusLabel,
        updater: updater,
        updatedTime: updatedTime,
        sessionCode: existing.sessionCode,
      );
      if (confirm != true || !context.mounted) return null;
      return _executeUpdate(
        context: context,
        ref: ref,
        sessionId: existing.sessionId!,
        finalInvoiceNumber: finalInvoiceNumber,
        finalPackingListNumber: finalPackingListNumber,
        totalAmount: totalAmount,
        totalPackages: totalPackages,
        totalGross: totalGross,
        totalNet: totalNet,
        totalCbm: totalCbm,
        extractedData: extractedData,
        invoiceItems: invoiceItems,
        packingItems: packingItems,
      );
    }

    if (activeSessionId != null) {
      return _executeUpdate(
        context: context,
        ref: ref,
        sessionId: activeSessionId,
        finalInvoiceNumber: finalInvoiceNumber,
        finalPackingListNumber: finalPackingListNumber,
        totalAmount: totalAmount,
        totalPackages: totalPackages,
        totalGross: totalGross,
        totalNet: totalNet,
        totalCbm: totalCbm,
        extractedData: extractedData,
        invoiceItems: invoiceItems,
        packingItems: packingItems,
      );
    }

    return _executeCreate(
      context: context,
      ref: ref,
      importFileId: importFileId,
      finalInvoiceNumber: finalInvoiceNumber,
      finalPackingListNumber: finalPackingListNumber,
      totalAmount: totalAmount,
      totalPackages: totalPackages,
      totalGross: totalGross,
      totalNet: totalNet,
      totalCbm: totalCbm,
      extractedData: extractedData,
      invoiceItems: invoiceItems,
      packingItems: packingItems,
    );
  }

  static Future<POReconciliationSessionModel?> _executeCreate({
    required BuildContext context,
    required WidgetRef ref,
    required int importFileId,
    required String finalInvoiceNumber,
    required String finalPackingListNumber,
    required double totalAmount,
    required double totalPackages,
    required double totalGross,
    required double totalNet,
    required double totalCbm,
    required Map<String, dynamic>? extractedData,
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
  }) async {
    final l = context.l10n;
    try {
      final filesList = ref.read(importFilesProvider).value ?? [];
      final currentFile = filesList.where((f) => f.importFileId == importFileId).firstOrNull;
      final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
      final linkedPO = allPOs.where((po) => po.importFileId == importFileId).firstOrNull;
      final dynamicShipper = extractedData?['extracted_invoice_data']?['shipper']?.toString().trim() ??
          extractedData?['extracted_packing_data']?['shipper']?.toString().trim() ??
          currentFile?.supplierName ??
          '';

      final model = POReconciliationSessionModel(
        importFileId: importFileId,
        finalInvoiceNumber: finalInvoiceNumber.trim(),
        finalPackingListNumber: finalPackingListNumber.trim(),
        acidNumber: extractedData?['extracted_packing_data']?['acid_number'] ??
            extractedData?['extracted_invoice_data']?['acid_number'] ??
            currentFile?.acidNumber,
        shipperName: dynamicShipper.isNotEmpty ? dynamicShipper : null,
        totalInvoiceAmount: totalAmount,
        currency: extractedData?['extracted_invoice_data']?['currency'] ??
            linkedPO?.currencyCode ??
            currentFile?.estimatedCostCurrency ??
            'USD',
        totalPackages: totalPackages,
        totalNetWeightKg: totalNet,
        totalGrossWeightKg: totalGross,
        totalCbm: totalCbm,
        overallStatus: extractedData?['overall_status'] ?? 'FULLY_MATCHED',
        isSafeForCertification: extractedData?['is_safe_for_certification'] ?? true,
        criticalDiscrepanciesCount: extractedData?['critical_discrepancies_count'] ?? 0,
        warningDiscrepanciesCount: extractedData?['warning_discrepancies_count'] ?? 0,
        headerDiscrepancies: extractedData?['header_discrepancies'] as List<dynamic>?,
        reconciledInvoiceItems: invoiceItems.map((i) => i.toJson()).toList(),
        reconciledPackingItems: packingItems.map((i) => i.toJson()).toList(),
        extractedInvoiceData: extractedData?['extracted_invoice_data'] as Map<String, dynamic>?,
        extractedPackingData: extractedData?['extracted_packing_data'] as Map<String, dynamic>?,
      );

      return await ref.read(poReconciliationSessionsProvider.notifier).createSession(model);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecSaveSessionError(ApiErrorText.of(l, e)), severity: AppSeverity.info));
      }
      return null;
    }
  }

  static Future<POReconciliationSessionModel?> _executeUpdate({
    required BuildContext context,
    required WidgetRef ref,
    required int sessionId,
    required String finalInvoiceNumber,
    required String finalPackingListNumber,
    required double totalAmount,
    required double totalPackages,
    required double totalGross,
    required double totalNet,
    required double totalCbm,
    required Map<String, dynamic>? extractedData,
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
  }) async {
    final l = context.l10n;
    try {
      final updateData = {
        'final_invoice_number': finalInvoiceNumber.trim(),
        'final_packing_list_number': finalPackingListNumber.trim(),
        'total_invoice_amount': totalAmount,
        'total_packages': totalPackages,
        'total_net_weight_kg': totalNet,
        'total_gross_weight_kg': totalGross,
        'total_cbm': totalCbm,
        'overall_status': extractedData?['overall_status'] ?? 'FULLY_MATCHED',
        'is_safe_for_certification': extractedData?['is_safe_for_certification'] ?? true,
        'critical_discrepancies_count': extractedData?['critical_discrepancies_count'] ?? 0,
        'warning_discrepancies_count': extractedData?['warning_discrepancies_count'] ?? 0,
        'header_discrepancies': extractedData?['header_discrepancies'] as List<dynamic>?,
        'reconciled_invoice_items': invoiceItems.map((i) => i.toJson()).toList(),
        'reconciled_packing_items': packingItems.map((i) => i.toJson()).toList(),
        'extracted_invoice_data': extractedData?['extracted_invoice_data'] as Map<String, dynamic>?,
        'extracted_packing_data': extractedData?['extracted_packing_data'] as Map<String, dynamic>?,
      };

      return await ref.read(poReconciliationSessionsProvider.notifier).updateSession(sessionId, updateData);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecSaveSessionError(ApiErrorText.of(l, e)), severity: AppSeverity.info));
      }
      return null;
    }
  }

  static Future<bool> submitCertification({
    required BuildContext context,
    required WidgetRef ref,
    required int importFileId,
    required String finalInvoiceNumber,
    required String finalPackingListNumber,
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
  }) async {
    final l = context.l10n;
    try {
      final payload = POReconciliationPayloadBuilder.buildPayload(
        importFileId: importFileId,
        finalInvoiceNumber: finalInvoiceNumber,
        finalPackingListNumber: finalPackingListNumber,
        invoiceItems: invoiceItems,
        packingItems: packingItems,
      );

      final result = await ref.read(poReconciliationProvider).submitPOFinalReconciliation(payload);
      ref.invalidate(importFilesProvider);
      ref.invalidate(purchaseOrdersProvider);
      invalidateImportDocDependentsW(ref);

      if (context.mounted) {
        String msg = l.poRecCertificationSuccess;
        if (result.totalFinalAmountByCurrency != null && result.totalFinalAmountByCurrency!.isNotEmpty) {
          final curBreakdown = result.totalFinalAmountByCurrency!.entries.map((e) => '${e.value.toStringAsFixed(2)} ${e.key}').join(' | ');
          msg = '$msg ($curBreakdown)';
        }
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, msg, severity: AppSeverity.info));
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecCertificationError(ApiErrorText.of(l, e)), severity: AppSeverity.info));
      }
      return false;
    }
  }

  static Future<POReconciliationSessionModel?> handleSave({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required int? selectedImportFileId,
    required int? activeSessionId,
    required String finalInvoiceNumber,
    required String finalPackingListNumber,
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
    required Map<String, dynamic>? extractedData,
    required String Function(String?) formatSessionDate,
  }) async {
    final l = context.l10n;
    if (!formKey.currentState!.validate()) return null;
    if (selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecSaveSessionSelectFileWarning, severity: AppSeverity.info));
      return null;
    }
    final saved = await saveSession(
      context: context,
      ref: ref,
      activeSessionId: activeSessionId,
      importFileId: selectedImportFileId,
      finalInvoiceNumber: finalInvoiceNumber,
      finalPackingListNumber: finalPackingListNumber,
      invoiceItems: invoiceItems,
      packingItems: packingItems,
      extractedData: extractedData,
      formatSessionDate: formatSessionDate,
    );
    if (saved != null && context.mounted) {
      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      PoReconciliationDialogs.showSaveSuccessReportDialog(
        context,
        saved,
        importFiles: importFiles,
        onPrintReport: () => PoReconciliationDialogs.showPrintReportDialog(
          context,
          saved,
          importFiles: importFiles,
          getLocalizedSessionStatus: PoReconciliationLocalizer.getLocalizedSessionStatus,
        ),
      );
    }
    return saved;
  }

  static Future<bool> handleCertification({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required int? selectedImportFileId,
    required String finalInvoiceNumber,
    required String finalPackingListNumber,
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
  }) async {
    final l = context.l10n;
    if (!formKey.currentState!.validate()) return false;
    if (selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.poRecSelectFileRequired, severity: AppSeverity.info));
      return false;
    }
    final hasInvoiceVar = invoiceItems.any((i) => (i.finalQuantity - i.initialQuantity).abs() > 0.001 || (i.finalUnitPrice - i.initialUnitPrice).abs() > 0.001);
    final hasPackingVar = packingItems.any((p) => (p.finalQuantity - p.initialQuantity).abs() > 0.001 || (p.finalGrossWeightKg - p.initialGrossWeightKg).abs() > 0.001);

    if (hasInvoiceVar || hasPackingVar) {
      final confirm = await PoReconciliationDialogs.showVarianceAlertConfirmDialog(context);
      if (confirm != true || !context.mounted) return false;
    }

    return await submitCertification(
      context: context,
      ref: ref,
      importFileId: selectedImportFileId,
      finalInvoiceNumber: finalInvoiceNumber,
      finalPackingListNumber: finalPackingListNumber,
      invoiceItems: invoiceItems,
      packingItems: packingItems,
    );
  }
}
