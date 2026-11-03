import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/import_files_provider.dart';

/// Helper methods for exporting and importing Import Files data (Excel, PDF, TSV).
class ImportFilesExportHelper {
  static String getPriorityLabel(String priority, AppLocalizations l) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return l.priorityCritical;
      case 'high':
        return l.priorityHigh;
      case 'medium':
        return l.priorityMedium;
      case 'low':
        return l.priorityLow;
      default:
        return priority;
    }
  }

  static String getStatusLabel(String status, AppLocalizations l) {
    switch (status.toLowerCase()) {
      case 'open':
        return l.statusOpen;
      case 'closed':
        return l.statusClosed;
      case 'in progress':
      case 'inprogress':
        return l.statusInProgress;
      case 'draft':
        return l.filterStatusDraft;
      default:
        return status;
    }
  }

  static void copyTableAsTsv(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
    final files = ref.read(paginatedImportFilesProvider).items;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic ? 'لا توجد شحنات للنسخ' : 'No import files to copy',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      isArabic ? 'رقم ملف الشحنة' : 'File Number',
      isArabic ? 'الشركة المستوردة' : 'Importing Company',
      isArabic ? 'أمر الشراء / الفاتورة' : 'PO / PI',
      isArabic ? 'المورد الأجنبي' : 'Supplier',
      isArabic ? 'طريقة الشحن / الشرط' : 'Transport / Incoterm',
      isArabic ? 'الأولوية' : 'Priority',
      isArabic ? 'تاريخ الوصول المتوقع' : 'Target ETA',
      isArabic ? 'المرحلة الحالية' : 'Current Stage',
      isArabic ? 'نسبة الإنجاز' : 'Progress %',
      isArabic ? 'الإجراء التالي' : 'Next Action',
      isArabic ? 'المسؤول' : 'Owner',
      isArabic ? 'الحالة' : 'Status',
    ];

    final rows = files.map((f) {
      final priorityText = getPriorityLabel(f.priority, l);
      final statusText = getStatusLabel(f.status, l);
      final resolvedStage = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isArabic);
      final resolvedAction = f.displayNextAction(context.l10n);
      final fileDisplay = f.customFileNumber ?? f.importFileCode;
      final poDisplay = (f.poNumber != null && f.poNumber!.isNotEmpty) ? f.poNumber! : '-';
      final piDisplay = (f.piNumber != null && f.piNumber!.isNotEmpty) ? f.piNumber! : '-';
      return [
        fileDisplay,
        f.companyName,
        'PO: $poDisplay | PI: $piDisplay',
        f.supplierName,
        '${f.shipmentMode} (${f.incotermCode})',
        priorityText,
        f.requiredEta ?? '-',
        resolvedStage,
        '${f.progressPercent.toInt()}%',
        resolvedAction,
        f.owner,
        statusText,
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: isArabic ? 'تم نسخ بيانات الشحنات كجدول بنجاح' : 'Import files table copied to clipboard',
    );
  }

  static Future<void> exportToExcel(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
    final files = ref.read(paginatedImportFilesProvider).items;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic ? 'لا توجد شحنات للتصدير' : 'No import files to export',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      isArabic ? 'رقم ملف الشحنة' : 'File Number',
      isArabic ? 'الشركة المستوردة' : 'Importing Company',
      isArabic ? 'أمر الشراء / الفاتورة' : 'PO / PI',
      isArabic ? 'المورد الأجنبي' : 'Supplier',
      isArabic ? 'طريقة الشحن / الشرط' : 'Transport / Incoterm',
      isArabic ? 'الأولوية' : 'Priority',
      isArabic ? 'تاريخ الوصول المتوقع' : 'Target ETA',
      isArabic ? 'المرحلة الحالية' : 'Current Stage',
      isArabic ? 'نسبة الإنجاز' : 'Progress %',
      isArabic ? 'الإجراء التالي' : 'Next Action',
      isArabic ? 'المسؤول' : 'Owner',
      isArabic ? 'الحالة' : 'Status',
    ];

    final rows = files.map((f) {
      final priorityText = getPriorityLabel(f.priority, l);
      final statusText = getStatusLabel(f.status, l);
      final resolvedStage = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isArabic);
      final resolvedAction = f.displayNextAction(context.l10n);
      final fileDisplay = f.customFileNumber ?? f.importFileCode;
      final poDisplay = (f.poNumber != null && f.poNumber!.isNotEmpty) ? f.poNumber! : '-';
      final piDisplay = (f.piNumber != null && f.piNumber!.isNotEmpty) ? f.piNumber! : '-';
      return [
        fileDisplay,
        f.companyName,
        'PO: $poDisplay | PI: $piDisplay',
        f.supplierName,
        '${f.shipmentMode} (${f.incotermCode})',
        priorityText,
        f.requiredEta ?? '-',
        resolvedStage,
        '${f.progressPercent.toInt()}%',
        resolvedAction,
        f.owner,
        statusText,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isArabic ? 'ملفات الشحنات الاستيرادية' : 'Import Files',
      importFileNameOrCode: 'Import_Files_Registry',
    );
  }

  static Future<void> exportToPdf(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
    final files = ref.read(paginatedImportFilesProvider).items;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic ? 'لا توجد شحنات للتصدير' : 'No import files to export',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      isArabic ? 'رقم الملف' : 'File No',
      isArabic ? 'الشركة' : 'Company',
      isArabic ? 'أمر الشراء' : 'PO/PI',
      isArabic ? 'المورد' : 'Supplier',
      isArabic ? 'الشحن/الشرط' : 'Mode/Inco',
      isArabic ? 'المرحلة' : 'Stage',
      isArabic ? 'الإنجاز' : 'Progress',
      isArabic ? 'الحالة' : 'Status',
    ];

    final rows = files.map((f) {
      final statusText = getStatusLabel(f.status, l);
      final resolvedStage = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isArabic);
      final fileDisplay = f.customFileNumber ?? f.importFileCode;
      final poDisplay = (f.poNumber != null && f.poNumber!.isNotEmpty) ? f.poNumber! : '-';
      return [
        fileDisplay,
        f.companyName,
        poDisplay,
        f.supplierName,
        '${f.shipmentMode} (${f.incotermCode})',
        resolvedStage,
        '${f.progressPercent.toInt()}%',
        statusText,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isArabic ? 'ملفات الشحنات الاستيرادية' : 'Import Files',
      importFileNameOrCode: 'Import_Files_Registry',
      headerContext: TableExportHeaderContext(
        title: isArabic ? 'سجل ملفات الشحنات الاستيرادية' : 'Import Files Master Registry',
        subtitle: 'Sorour Logistics ERP',
        metadata: {
          isArabic ? 'إجمالي الملفات' : 'Total Files': '${files.length}',
          isArabic ? 'تاريخ التقرير' : 'Report Date': DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  static Future<void> importFromExcel(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              'Could not read file bytes',
              severity: AppSeverity.danger,
            ),
          );
        }
        return;
      }

      final dio = ref.read(uploadDioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
      });

      final response = await dio.post(
        '/import-files/import-excel',
        data: formData,
      );

      if (!context.mounted) return;
      final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
      final message = response.data['message'] ?? (isArabic ? 'تم استيراد البيانات بنجاح' : 'Import successful');
      final List errors = response.data['errors'] ?? [];

      ref.read(paginatedImportFilesProvider.notifier).fetchPage(1);

      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          errors.isEmpty ? message : '$message (${errors.length} errors)',
          severity: errors.isEmpty ? AppSeverity.success : AppSeverity.warning,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'Error: $e',
          severity: AppSeverity.danger,
        ),
      );
    }
  }
}
