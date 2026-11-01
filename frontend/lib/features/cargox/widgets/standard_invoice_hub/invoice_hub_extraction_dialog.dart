import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/cargox_model.dart';
import '../../providers/cargox_provider.dart';
import 'invoice_hub_extraction_modes_grid.dart';
import 'invoice_hub_formatters.dart';
import 'invoice_hub_preview_result_card.dart';

/// Modal dialog providing multi-mode extraction of CargoX invoices,
/// live preview of parsed items and weight consolidation,
/// direct adoption into a customs track, and Excel/ZIP downloads.
class InvoiceHubExtractionDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final ValueChanged<CustomsInvoiceTrackModel> onCustomsTrackCreated;

  const InvoiceHubExtractionDialog({
    super.key,
    required this.file,
    required this.onCustomsTrackCreated,
  });

  static Future<void> show({
    required BuildContext context,
    required ImportFileModel file,
    required ValueChanged<CustomsInvoiceTrackModel> onCustomsTrackCreated,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => InvoiceHubExtractionDialog(
        file: file,
        onCustomsTrackCreated: onCustomsTrackCreated,
      ),
    );
  }

  @override
  ConsumerState<InvoiceHubExtractionDialog> createState() => _InvoiceHubExtractionDialogState();
}

class _InvoiceHubExtractionDialogState extends ConsumerState<InvoiceHubExtractionDialog> {
  String _selectedMode = 'all_consolidated';
  String _selectedGrouping = 'by_hs_code';
  bool _isExtracting = false;
  bool _isDownloading = false;
  bool _isSavingCustomsTrack = false;
  ExtractionResponseModel? _previewResponse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final file = widget.file;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 950,
          constraints: const BoxConstraints(maxHeight: 780),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hub_outlined, color: AppTheme.emerald, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.cargoxExtractEngineTitle,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.cargoxExtractFileSubtitle(
                            file.primaryNameWithCode,
                            file.supplierName,
                            file.acidNumber ?? "N/A",
                          ),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.cargoxChooseExtractionPathPrompt,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                      ),
                      const SizedBox(height: 12),
                      InvoiceHubExtractionModesGrid(
                        selectedMode: _selectedMode,
                        onSelectMode: (mode, grouping) {
                          setState(() {
                            _selectedMode = mode;
                            _selectedGrouping = grouping;
                            _previewResponse = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppButton(
                            label: l10n.cargoxLiveItemsPreviewBtn,
                            icon: Icons.remove_red_eye,
                            variant: AppButtonVariant.primary,
                            isLoading: _isExtracting,
                            onPressed: _isExtracting ? null : _handleExtractPreview,
                          ),
                          if (_previewResponse != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.cargoxInvoicesCountAndLines(_previewResponse!.invoicesCount, _previewResponse!.totalLineItems),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.emerald),
                              ),
                            ),
                        ],
                      ),
                      if (_previewResponse != null) ...[
                        const SizedBox(height: 14),
                        InvoiceHubPreviewResultCard(response: _previewResponse!),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: l10n.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: isAr ? 'اعتماد كمسار جمركي مستقل' : 'Adopt as Customs Track',
                    icon: Icons.gavel,
                    variant: AppButtonVariant.warning,
                    isLoading: _isSavingCustomsTrack,
                    onPressed: _isSavingCustomsTrack ? null : _handleAdoptCustomsTrack,
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: _selectedMode.startsWith('per_invoice_') ? l10n.cargoxDownloadZipBtn : l10n.cargoxExportExcelBtn,
                    icon: Icons.download,
                    variant: AppButtonVariant.success,
                    isLoading: _isDownloading,
                    onPressed: _isDownloading ? null : _handleDownloadExtractionFile,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExtractPreview() async {
    setState(() => _isExtracting = true);
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final res = await notifier.extractMultiMode(
        widget.file.importFileId,
        mode: _selectedMode,
        groupingMode: _selectedGrouping,
      );
      if (!mounted) return;
      setState(() {
        _previewResponse = res;
        _isExtracting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.cargoxExtractionError(extractInvoiceHubErrorMessage(e))),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  Future<void> _handleAdoptCustomsTrack() async {
    setState(() => _isSavingCustomsTrack = true);
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final track = await notifier.createCustomsTrack({
        'import_file_id': widget.file.importFileId,
        'extraction_mode': _selectedMode,
        'grouping_mode': _selectedGrouping,
        'notes': 'Customs track approved from the extraction screen',
      });
      if (!mounted) return;
      setState(() => _isSavingCustomsTrack = false);
      widget.onCustomsTrackCreated(track);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.cargoxAdoptCustomsTrackSuccess(track.trackCode)),
          backgroundColor: AppTheme.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingCustomsTrack = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.cargoxSaveTrackError(extractInvoiceHubErrorMessage(e))),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  Future<void> _handleDownloadExtractionFile() async {
    final file = widget.file;
    final isZip = _selectedMode.startsWith('per_invoice_');
    const stage = 'CargoX Blockchain & ACI Hub';
    final fileCode = '${file.companyName} (${file.importFileCode})';
    final ext = isZip ? 'zip' : 'xlsx';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final title = isZip
        ? (isAr ? 'حفظ أرشيف فواتير CargoX المضغوط' : 'Save CargoX Invoices ZIP Archive')
        : (isAr ? 'حفظ فاتورة CargoX القياسية' : 'Save CargoX Standard Invoice Excel');

    setState(() => _isDownloading = true);
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);

      final saved = await FileSaveHelper.exportWithPickerAndFetch(
        context: context,
        stageName: stage,
        importFileNameOrCode: fileCode,
        extension: ext,
        customDialogTitle: title,
        fetchBytes: () => notifier.downloadMultiInvoiceZip(
          file.importFileId,
          mode: _selectedMode,
          groupingMode: _selectedGrouping,
        ),
      );

      if (!mounted) return;
      setState(() => _isDownloading = false);
      if (saved != null) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.errorPrefix}: ${extractInvoiceHubErrorMessage(e)}'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }
}
