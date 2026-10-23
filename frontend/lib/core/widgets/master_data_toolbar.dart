import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../localization/app_localizations.dart';
import '../network/dio_client.dart';
import '../services/file_save_helper.dart';
import '../theme/app_theme.dart';
import 'buttons/app_button.dart';
import 'stage_notes_card.dart';

/// Reusable master data toolbar with Export/Import/Refresh actions.
///
/// Now uses:
/// - [AppButton] for consistent button styling
/// - [AppTheme.toolbarDecoration] for container style
/// - [dioProvider] singleton instead of `Dio()` local instance
/// - [context.l10n] for localized labels
class MasterDataToolbarWidget extends ConsumerStatefulWidget {
  final String moduleEndpoint;
  final String title;
  final VoidCallback onRefreshNeeded;
  final VoidCallback? onDownloadTemplate;
  final VoidCallback? onImportExcel;
  final VoidCallback? onExportExcel;
  final VoidCallback? onExportPdf;
  final Widget? extraTrailing;

  const MasterDataToolbarWidget({
    super.key,
    required this.moduleEndpoint,
    required this.title,
    required this.onRefreshNeeded,
    this.onDownloadTemplate,
    this.onImportExcel,
    this.onExportExcel,
    this.onExportPdf,
    this.extraTrailing,
  });

  @override
  ConsumerState<MasterDataToolbarWidget> createState() =>
      _MasterDataToolbarWidgetState();
}

class _MasterDataToolbarWidgetState
    extends ConsumerState<MasterDataToolbarWidget> {
  bool _isUploading = false;

  Future<void> _downloadFile(
      String actionEndpoint, String defaultFileName) async {
    final cleanTitle = widget.title.replaceAll(' ', '_');
    final formattedDefaultName = defaultFileName.startsWith('MasterData_')
        ? defaultFileName
        : 'MasterData_${cleanTitle}_$defaultFileName';
    final url =
        '${ApiConstants.baseUrl}/${widget.moduleEndpoint}/$actionEndpoint';
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null && response.data is List<int>) {
        if (!mounted) return;
        await FileSaveHelper.saveBytes(
          context: context,
          bytes: response.data as List<int>,
          defaultFileName: formattedDefaultName,
          dialogTitle: 'حفظ ملف بيانات ${widget.title}',
          allowedExtensions: defaultFileName.endsWith('.pdf') ? ['pdf'] : ['xlsx', 'csv'],
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.errorPrefix}: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  Future<void> _handleImportExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );


      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read file bytes'),
              backgroundColor: AppTheme.crimson,
            ),
          );
        }
        return;
      }

      setState(() => _isUploading = true);

      // Use upload Dio (multipart, no JSON content-type header)
      final dio = ref.read(uploadDioProvider);

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
      });

      final response = await dio.post(
        '/${widget.moduleEndpoint}/import-excel',
        data: formData,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      final l = context.l10n;
      final message = response.data['message'] ?? l.importSuccessful;
      final List errors = response.data['errors'] ?? [];

      _showImportResultDialog(message, errors);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.error}: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }


  void _showImportResultDialog(String message, List errors) {
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
                      color: AppTheme.crimson, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...errors.map((err) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text('• $err',
                          style: const TextStyle(fontSize: 12)),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onRefreshNeeded();
            },
            child: Text(l.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: AppTheme.toolbarDecorationOf(context),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_chart_outlined,
                  color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  l.dataActionsTitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.isDark(context) ? AppTheme.darkTextPrimary : Colors.grey.shade800),
                ),
              ),
            ],
          ),

          // Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Live Refresh
              AppButton(
                label: l.liveRefresh,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                icon: Icons.refresh,
                onPressed: widget.onRefreshNeeded,
              ),

              // Export Excel
              AppButton(
                label: l.exportExcel,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                icon: Icons.description,
                onPressed: widget.onExportExcel ??
                    () => _downloadFile(
                        'export-excel', 'MasterData_${widget.title.replaceAll(" ", "_")}_Report.xlsx'),
              ),

              // Export PDF
              AppButton(
                label: l.exportPdf,
                variant: AppButtonVariant.danger,
                size: AppButtonSize.small,
                icon: Icons.picture_as_pdf,
                onPressed: widget.onExportPdf ??
                    () => _downloadFile(
                        'export-pdf', 'MasterData_${widget.title.replaceAll(" ", "_")}_Report.pdf'),
              ),

              // Import Excel
              AppButton(
                label: _isUploading ? l.uploading : l.importExcel,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                icon: Icons.upload_file,
                isLoading: _isUploading,
                onPressed: _isUploading
                    ? null
                    : (widget.onImportExcel ?? _handleImportExcel),
              ),

              // Notes & Attachments (+)
              AppButton(
                label: l.isArabic ? 'الملاحظات (+)' : 'Notes (+)',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: Icons.rate_review_outlined,
                onPressed: () {
                  StageNotesCard.showAsDialog(
                    context,
                    screenCode: widget.moduleEndpoint,
                    title: widget.title,
                  );
                },
              ),

              if (widget.extraTrailing != null) widget.extraTrailing!,
            ],
          ),
        ],
      ),
    );
  }
}
