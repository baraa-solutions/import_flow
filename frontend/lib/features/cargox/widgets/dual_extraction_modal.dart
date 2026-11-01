import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/cargox_model.dart';
import '../models/export_configs.dart';
import '../providers/cargox_provider.dart';
import 'dual_extraction/dual_engine_config_panel.dart';
import 'dual_extraction/dual_extraction_header.dart';
import 'dual_extraction/dual_preview_summary_panel.dart';
import 'dual_extraction/pallets_management_panel.dart';

/// CGX-004: واجهة الاستخلاص المزدوج — فاتورة + باكينج ليست مستقلان (Task K Independent Dimensions)
class DualExtractionModal extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;
  final VoidCallback onTrackCreated;

  const DualExtractionModal({
    super.key,
    required this.importFileId,
    required this.importFileCode,
    required this.onTrackCreated,
  });

  @override
  ConsumerState<DualExtractionModal> createState() => _DualExtractionModalState();
}

class _DualExtractionModalState extends ConsumerState<DualExtractionModal> {
  // ── Document Export Configurations (Task K Independent Dimensions) ────────
  InvoiceExportConfig _invoiceConfig = const InvoiceExportConfig();
  PackingListExportConfig _plConfig = const PackingListExportConfig();

  // ── Pallets ───────────────────────────────────────────────────────────────
  final List<PalletInputModel> _pallets = [];

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;
  DualExtractionResponseModel? _previewResult;

  Map<String, dynamic> _buildRequest() {
    final Map<String, dynamic> req = {
      'invoice_mode': _invoiceConfig.toApiInvoiceMode(),
      'invoice_grouping': _invoiceConfig.toApiInvoiceGrouping(),
      'packing_list_mode': _plConfig.toApiPackingListMode(),
      'packing_list_structure': _plConfig.toApiPackingListStructure(),
      'include_pallets': _plConfig.effectiveIncludePalletDetails,
    };
    if (_plConfig.effectiveIncludePalletDetails && _pallets.isNotEmpty) {
      req['pallet_details'] = _pallets.map((p) => p.toJson()).toList();
    }
    return req;
  }

  Future<void> _preview() async {
    setState(() { _isLoading = true; _errorMessage = null; _previewResult = null; });
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final result = await notifier.extractDualMode(widget.importFileId, _buildRequest());
      setState(() { _previewResult = result; });
    } catch (e) {
      setState(() { _errorMessage = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _saveAsTrack() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final payload = {
        'import_file_id': widget.importFileId,
        ..._buildRequest(),
      };
      await notifier.createDualCustomsTrack(payload);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onTrackCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.dualExtractionTrackCreatedSuccess,
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      setState(() { _errorMessage = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _downloadZip() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final bytes = await notifier.generateDualZip(widget.importFileId, _buildRequest());
      if (mounted) {
        await FileSaveHelper.saveBytes(
          context: context,
          bytes: bytes,
          defaultFileName: 'CargoX_Dual_${widget.importFileCode}.zip',
          dialogTitle: context.l10n.dualExtractionDownloadZip,
          allowedExtensions: ['zip'],
        );
      }
    } catch (e) {
      setState(() { _errorMessage = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _copySummary(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final r = _previewResult;
    if (r == null) return;
    final buffer = StringBuffer();
    if (isAr) {
      buffer.writeln('=== ملخص الاستخلاص المزدوج للوثائق ===');
      buffer.writeln('كود الملف: ${widget.importFileCode}');
      buffer.writeln('نمط الفاتورة: ${r.invoiceMode} (${r.invoiceGrouping})');
      buffer.writeln('الفاتورة التجارية: ${r.invoiceInvoicesCount} فاتورة، إجمالي ${r.invoiceTotalLineItems} بند');
      buffer.writeln('نمط قائمة التعبئة: ${r.packingListMode} (${r.packingListStructure})');
      buffer.writeln('قائمة التعبئة: ${r.packingListCount} ملف، إجمالي ${r.packingListTotalItems} بند');
    } else {
      buffer.writeln('=== Dual Document Extraction Summary ===');
      buffer.writeln('File Code: ${widget.importFileCode}');
      buffer.writeln('Invoice Mode: ${r.invoiceMode} (${r.invoiceGrouping})');
      buffer.writeln('Commercial Invoice: ${r.invoiceInvoicesCount} invoices, ${r.invoiceTotalLineItems} items');
      buffer.writeln('Packing List Mode: ${r.packingListMode} (${r.packingListStructure})');
      buffer.writeln('Packing List: ${r.packingListCount} files, ${r.packingListTotalItems} items');
    }
    CopyHelper.copy(context, buffer.toString(), customMessage: l.dualExtractionSummaryCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      backgroundColor: AppTheme.isDark(context) ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 700),
          child: Column(
            children: [
              DualExtractionHeader(
                importFileCode: widget.importFileCode,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      DualEngineConfigPanel(
                        invoiceConfig: _invoiceConfig,
                        plConfig: _plConfig,
                        onInvoiceConfigChanged: (c) => setState(() => _invoiceConfig = c),
                        onPlConfigChanged: (c) => setState(() => _plConfig = c),
                      ),
                      if (_plConfig.effectiveIncludePalletDetails) ...[
                        const SizedBox(height: 16),
                        PalletsManagementPanel(
                          pallets: _pallets,
                          onPalletAdded: (pallet) => setState(() => _pallets.add(pallet)),
                          onPalletRemoved: (idx) => setState(() => _pallets.removeAt(idx)),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        DualExtractionErrorBanner(errorMessage: _errorMessage!),
                      ],
                      if (_previewResult != null) ...[
                        const SizedBox(height: 12),
                        DualPreviewSummaryPanel(
                          previewResult: _previewResult!,
                          onCopySummary: () => _copySummary(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _buildFooter(l, isAr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l, bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(16),
          bottomEnd: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _preview,
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(l.dualExtractionPreviewResults, style: const TextStyle(fontSize: 11)),
          ),
          const Spacer(),
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _downloadZip,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: Text(l.dualExtractionDownloadZip, style: const TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.cobalt),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isLoading ? null : _saveAsTrack,
            icon: _isLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(l.dualExtractionAdoptCustomsTrack, style: const TextStyle(fontSize: 11)),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.charcoal),
          ),
        ],
      ),
    );
  }
}
