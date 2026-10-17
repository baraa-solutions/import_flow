import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../localization/app_localizations.dart';
import '../network/dio_client.dart';
import '../services/file_save_helper.dart';
import '../theme/app_theme.dart';

/// Central helper for Master Data operations (Excel/PDF Export, Template Download, Excel Import)
/// designed to be seamlessly integrated with [ActionToolbar] across all Type B screens.
class MasterDataActionHelper {
  /// Downloads a file (Excel report, PDF report, or Excel template) from the backend
  /// and prompts the user to choose the save location via [FileSaveHelper.saveBytes].
  static Future<void> downloadFile({
    required BuildContext context,
    required WidgetRef ref,
    required String moduleEndpoint,
    required String actionEndpoint,
    required String defaultFileName,
    required String dialogTitle,
  }) async {
    final cleanEndpoint = moduleEndpoint.startsWith('/') ? moduleEndpoint.substring(1) : moduleEndpoint;
    final url = '${ApiConstants.baseUrl}/$cleanEndpoint/$actionEndpoint';

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null && response.data is List<int>) {
        if (!context.mounted) return;

        // Resolve standardized filename from Content-Disposition header or ensure date format
        String resolvedFileName = defaultFileName;
        final disposition = response.headers.value('content-disposition');
        if (disposition != null && disposition.contains('filename=')) {
          final match = RegExp(r'filename=["'']?([^"'';\r\n]+)["'']?').firstMatch(disposition);
          if (match != null && match.group(1) != null && match.group(1)!.trim().isNotEmpty) {
            resolvedFileName = match.group(1)!.trim();
          }
        } else {
          final now = DateTime.now();
          final dateStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          if (!resolvedFileName.contains(RegExp(r'\d{4}-\d{2}-\d{2}'))) {
            final dotIdx = resolvedFileName.lastIndexOf('.');
            if (dotIdx != -1) {
              final base = resolvedFileName.substring(0, dotIdx);
              final ext = resolvedFileName.substring(dotIdx);
              resolvedFileName = '${base}_$dateStr$ext';
            } else {
              resolvedFileName = '${resolvedFileName}_$dateStr';
            }
          }
        }

        await FileSaveHelper.saveBytes(
          context: context,
          bytes: response.data as List<int>,
          defaultFileName: resolvedFileName,
          dialogTitle: dialogTitle,
          allowedExtensions: resolvedFileName.endsWith('.pdf') ? ['pdf'] : ['xlsx', 'csv', 'xls'],
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.errorPrefix}: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  /// Handles picking and uploading an Excel file for bulk data import.
  static Future<void> importExcel({
    required BuildContext context,
    required WidgetRef ref,
    required String moduleEndpoint,
    required VoidCallback onImportSuccess,
  }) async {
    final l = context.l10n;

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
            const SnackBar(
              content: Text('Could not read file bytes'),
              backgroundColor: AppTheme.crimson,
            ),
          );
        }
        return;
      }

      final cleanEndpoint = moduleEndpoint.startsWith('/') ? moduleEndpoint.substring(1) : moduleEndpoint;
      final url = '${ApiConstants.baseUrl}/$cleanEndpoint/import-excel';

      final dio = ref.read(uploadDioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
      });

      final response = await dio.post(
        url,
        data: formData,
      );

      if (!context.mounted) return;

      final message = response.data['message'] ?? l.importSuccessful;
      final List errors = response.data['errors'] ?? [];

      _showImportResultDialog(context, message, errors, onImportSuccess);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.error}: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  static void _showImportResultDialog(
    BuildContext context,
    String message,
    List errors,
    VoidCallback onImportSuccess,
  ) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              errors.isEmpty ? Icons.check_circle : Icons.warning_amber,
              color: errors.isEmpty ? AppTheme.emerald : AppTheme.orange,
            ),
            const SizedBox(width: 8),
            Text(errors.isEmpty ? l.importSuccessful : l.importWithAlerts),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l.alertsErrors,
                  style: const TextStyle(
                    color: AppTheme.crimson,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...errors.map((err) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text('• $err', style: const TextStyle(fontSize: 12)),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onImportSuccess();
            },
            child: Text(l.ok),
          ),
        ],
      ),
    );
  }

  /// Builds standard PopupMenuItems for ActionToolbar's "More Actions" dropdown.
  static List<PopupMenuEntry<String>> buildStandardMoreActionItems({
    required BuildContext context,
    bool includeTsv = true,
  }) {
    final l = context.l10n;

    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return [
      PopupMenuItem(
        value: 'export_excel',
        child: Row(
          children: [
            const Icon(Icons.table_view_rounded, color: AppTheme.wcagEmerald, size: 16),
            const SizedBox(width: 8),
            Text(l.exportExcel, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'export_pdf',
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson, size: 16),
            const SizedBox(width: 8),
            Text(l.exportPdf, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
      if (includeTsv) ...[
        PopupMenuItem(
          value: 'copy_tsv',
          child: Row(
            children: [
              const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
              const SizedBox(width: 8),
              Text(isArabic ? 'نسخ الجدول (TSV)' : 'Copy Table (TSV)', style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ],
      const PopupMenuDivider(height: 1),
      PopupMenuItem(
        value: 'download_template',
        child: Row(
          children: [
            const Icon(Icons.file_download_outlined, color: Colors.blueGrey, size: 16),
            const SizedBox(width: 8),
            Text(isArabic ? 'تنزيل نموذج إكسل' : 'Download Template', style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'import_excel',
        child: Row(
          children: [
            const Icon(Icons.upload_file, color: Colors.blueGrey, size: 16),
            const SizedBox(width: 8),
            Text(l.importExcel, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    ];
  }
}
