import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../suppliers/models/supplier_model.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../providers/import_documentation_provider.dart';

class NafezaAcidService {
  static Future<void> saveMtsResultAsAcidSession({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, dynamic>? parsedData,
    required int? selectedImportFileId,
    required String rawText,
    required bool isDraft,
    required void Function(bool) onSavingStateChanged,
  }) async {
    final l = context.l10n;
    if (parsedData == null) return;
    if (selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.selectImportFileFirst, severity: AppSeverity.danger),
      );
      return;
    }

    onSavingStateChanged(true);
    try {
      final acidNum = parsedData['acid_number']?.toString().trim() ?? '';
      final payload = {
        'import_file_id': selectedImportFileId,
        'importer_name': parsedData['importer_name']?.toString().trim() ?? '',
        'importer_tax_id': parsedData['importer_tax_id']?.toString().trim() ?? '',
        'importer_address': parsedData['importer_address']?.toString().trim() ?? '',
        'exporter_name': parsedData['exporter_name']?.toString().trim() ?? '',
        'exporter_reg_type': parsedData['exporter_reg_type']?.toString().trim() ?? 'Company Registration Number',
        'exporter_reg_id': parsedData['exporter_reg_id']?.toString().trim() ?? '',
        'exporter_country': parsedData['exporter_country']?.toString().trim() ?? '',
        'exporter_country_code': parsedData['exporter_country_code']?.toString().trim() ?? '',
        'exporter_address': parsedData['exporter_address']?.toString().trim() ?? '',
        'exporter_phone': parsedData['exporter_phone']?.toString().trim() ?? '',
        'cargox_id': parsedData['cargox_id']?.toString().trim() ?? '',
        'proforma_invoice_no': parsedData['proforma_invoice_no']?.toString().trim() ?? '',
        'proforma_invoice_date': parsedData['proforma_invoice_date']?.toString().trim() ?? '',
        if (parsedData['invoice_date'] != null && parsedData['invoice_date'].toString().trim().isNotEmpty)
          'invoice_date': parsedData['invoice_date'].toString().trim(),
        'invoice_type': parsedData['invoice_type']?.toString().trim() ?? 'Proforma Invoice',
        'pol_name': parsedData['pol_name']?.toString().trim() ?? '',
        'pod_name': parsedData['pod_name']?.toString().trim() ?? '',
        'requested_date': parsedData['requested_date']?.toString().trim() ?? '',
        if (parsedData['generated_date'] != null && parsedData['generated_date'].toString().trim().isNotEmpty)
          'generated_date': parsedData['generated_date'].toString().trim(),
        if (parsedData['expiry_date'] != null && parsedData['expiry_date'].toString().trim().isNotEmpty)
          'expiry_date': parsedData['expiry_date'].toString().trim(),
        'acid_number': acidNum.isNotEmpty ? acidNum : 'PENDING',
        'raw_nafeza_text': rawText.trim(),
        'status': isDraft ? 'DRAFT' : (acidNum.isNotEmpty ? 'Issued' : 'Pending Issue'),
      };

      final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
      final existing = sessions.where((s) => s.importFileId == selectedImportFileId && s.isActive).firstOrNull;

      if (existing != null) {
        await ref.read(acidSessionsProvider.notifier).updateAcidSession(existing.acidId, payload);
      } else {
        await ref.read(acidSessionsProvider.notifier).createAcidSession(payload);
      }

      await ref.read(importFilesProvider.notifier).fetchImportFiles();
      await ref.read(acidTrackerProvider.notifier).fetchAcidTracker();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, isDraft ? l.acidRequestSavedSuccess : l.acidCertifiedSuccess, severity: isDraft ? AppSeverity.info : AppSeverity.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorDetailsDialog(context, title: isDraft ? l.errorSavingDraft : l.errorSavingAcid, error: e);
      }
    } finally {
      onSavingStateChanged(false);
    }
  }

  static Future<void> codeSupplierFromMts({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, dynamic>? parsedData,
  }) async {
    final l = context.l10n;
    if (parsedData == null) return;
    final expName = parsedData['exporter_name']?.toString().trim() ?? '';
    if (expName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.foreignSupplierNotInData, severity: AppSeverity.danger),
      );
      return;
    }

    try {
      final existingSuppliers = ref.read(suppliersProvider).valueOrNull ?? [];
      final existing = existingSuppliers.where((s) =>
          s.companyName.toLowerCase() == expName.toLowerCase() ||
          s.foreignExporterId == (parsedData['exporter_reg_id']?.toString().trim() ?? '')).firstOrNull;

      final supplier = SupplierModel(
        supplierId: existing?.supplierId,
        supplierCode: existing?.supplierCode ?? 'SUP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        companyName: expName,
        supplierType: 'Manufacturer',
        registrationType: parsedData['exporter_reg_type']?.toString().trim() ?? 'Company Registration Number',
        foreignExporterId: parsedData['exporter_reg_id']?.toString().trim() ?? (existing?.foreignExporterId ?? 'EXP-SUP-001'),
        cargoxPlatformId: parsedData['cargox_id']?.toString().trim() ?? existing?.cargoxPlatformId,
        foreignExporterCountry: parsedData['exporter_country']?.toString().trim() ?? (existing?.foreignExporterCountry ?? 'China'),
        foreignExporterCountryCode: parsedData['exporter_country_code']?.toString().trim() ?? (existing?.foreignExporterCountryCode ?? 'CN'),
        address: parsedData['exporter_address']?.toString().trim() ?? (existing?.address ?? 'No.16 Kangsheng Road, Changshu, China'),
        phone: parsedData['exporter_phone']?.toString().trim() ?? existing?.phone,
        isActive: true,
      );

      String? err;
      if (existing != null && existing.supplierId != null) {
        err = await ref.read(suppliersProvider.notifier).updateSupplier(existing.supplierId!, supplier);
      } else {
        err = await ref.read(suppliersProvider.notifier).createSupplier(supplier);
      }

      if (err != null) {
        if (context.mounted) showErrorDetailsDialog(context, title: l.errorCodingSupplier, error: err);
        return;
      }

      await ref.read(suppliersProvider.notifier).fetchSuppliers();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.supplierCodedSuccess(expName), severity: AppSeverity.success),
        );
      }
    } catch (e) {
      if (context.mounted) showErrorDetailsDialog(context, title: l.errorCodingSupplier, error: e);
    }
  }

  static Future<void> exportAcidRegistryToExcel(BuildContext context, List<dynamic> list, List<dynamic> importFiles) async {
    final l = context.l10n;
    final headers = [
      l.acidNumberCol,
      l.importFile,
      l.foreignExporterCol,
      l.importerCompanyCol,
      l.issueDateCol,
      l.expiryDateCol,
      l.validityStatusCol,
    ];
    final rows = list.map((s) {
      final dateStr = s.generatedDate ?? s.requestedDate ?? '-';
      final expStr = s.expiryDate ?? '-';
      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
      final statusLabel = isIssued ? l.issuedAndValidStatus : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
      return [
        s.acidNumber.isNotEmpty ? s.acidNumber : '-',
        fileLabel,
        s.exporterName,
        s.importerName,
        dateStr,
        expStr,
        statusLabel,
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocBAcidRegistryStage,
      importFileNameOrCode: 'ACID_Registry',
    );
  }

  static Future<void> exportAcidRegistryToPdf(BuildContext context, List<dynamic> list, List<dynamic> importFiles) async {
    final l = context.l10n;
    final headers = [
      l.acidNumberCol,
      l.importFile,
      l.foreignExporterCol,
      l.importerCompanyCol,
      l.issueDateCol,
      l.expiryDateCol,
      l.validityStatusCol,
    ];
    final rows = list.map((s) {
      final dateStr = s.generatedDate ?? s.requestedDate ?? '-';
      final expStr = s.expiryDate ?? '-';
      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
      final statusLabel = isIssued ? l.issuedAndValidStatus : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
      return [
        s.acidNumber.isNotEmpty ? s.acidNumber : '-',
        fileLabel,
        s.exporterName,
        s.importerName,
        dateStr,
        expStr,
        statusLabel,
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocBAcidRegistryStage,
      importFileNameOrCode: 'ACID_Registry',
    );
  }

  static void copyAcidRegistryAsTsv(BuildContext context, List<dynamic> list, List<dynamic> importFiles) {
    final l = context.l10n;
    final headers = [
      l.acidNumberCol,
      l.importFile,
      l.foreignExporterCol,
      l.importerCompanyCol,
      l.issueDateCol,
      l.expiryDateCol,
      l.validityStatusCol,
    ];
    final rows = list.map((s) {
      final dateStr = s.generatedDate ?? s.requestedDate ?? '-';
      final expStr = s.expiryDate ?? '-';
      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
      final statusLabel = isIssued ? l.issuedAndValidStatus : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
      return [
        s.acidNumber.isNotEmpty ? s.acidNumber : '-',
        fileLabel,
        s.exporterName,
        s.importerName,
        dateStr,
        expStr,
        statusLabel,
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }
}
