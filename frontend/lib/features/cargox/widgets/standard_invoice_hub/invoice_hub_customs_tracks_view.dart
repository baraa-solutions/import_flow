import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/cargox_model.dart';
import '../../providers/cargox_provider.dart';
import '../dual_extraction_modal.dart';
import 'customs_track_card.dart';

/// Customs Tracks tab:
/// Displays independent customs tracks, their live preview stats,
/// provides invoice & packing list PDF preview/printing,
/// and enables Excel export of commercial invoices and packing lists.
class InvoiceHubCustomsTracksView extends ConsumerStatefulWidget {
  final ImportFileModel? selectedImportFile;
  final List<CustomsInvoiceTrackModel> customsTracks;
  final VoidCallback onOpenExtractionDialog;
  final ValueChanged<List<CustomsInvoiceTrackModel>> onTracksUpdated;

  const InvoiceHubCustomsTracksView({
    super.key,
    required this.selectedImportFile,
    required this.customsTracks,
    required this.onOpenExtractionDialog,
    required this.onTracksUpdated,
  });

  @override
  ConsumerState<InvoiceHubCustomsTracksView> createState() => _InvoiceHubCustomsTracksViewState();
}

class _InvoiceHubCustomsTracksViewState extends ConsumerState<InvoiceHubCustomsTracksView> {
  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final file = widget.selectedImportFile;
    final tracks = widget.customsTracks;

    if (file == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(Icons.account_balance_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              isAr ? 'يرجى اختيار ملف استيراد لعرض مساراته الجمركية' : 'Please select an import file to view its customs tracks',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (tracks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              isAr ? 'لا توجد مسارات جمركية معتمدة حتى الآن لهذا الملف' : 'No approved customs tracks exist for this file yet',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'يمكنك اعتماد فاتورة جمركية مستقلة عبر محرك استخلاص CargoX بالضغط على تحميل النموذج القياسي ثم اختيار اعتماد كمسار جمركي مستقل.'
                  : 'You can approve an independent customs invoice via CargoX extraction engine by clicking Download Template and adopting it as a track.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: isAr ? 'فتح محرك الاستخلاص والاعتماد' : 'Open Extraction Engine',
              icon: Icons.hub_outlined,
              variant: AppButtonVariant.success,
              onPressed: widget.onOpenExtractionDialog,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isAr ? 'المسارات الجمركية المعتمدة للشحنة (${tracks.length}):' : 'Approved Customs Tracks (${tracks.length}):',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
            Row(
              children: [
                AppButton(
                  label: isAr ? 'استخلاص مسار جديد' : 'Extract New Track',
                  icon: Icons.add,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: widget.onOpenExtractionDialog,
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: isAr ? 'استخلاص مزدوج' : 'Dual Extraction',
                  icon: Icons.file_copy_outlined,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: _showDualExtractionModal,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final track in tracks)
          CustomsTrackCard(
            track: track,
            importFileId: widget.selectedImportFile?.importFileId,
            onTracksUpdated: widget.onTracksUpdated,
            onDownloadExcel: _downloadTrackExcelFile,
            onDownloadPackingList: _downloadTrackPackingListFile,
            onDelete: _showTrackDeleteConfirmDialog,
          ),
      ],
    );
  }

  void _showDualExtractionModal() {
    if (widget.selectedImportFile == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DualExtractionModal(
        importFileId: widget.selectedImportFile!.importFileId,
        importFileCode: widget.selectedImportFile!.importFileCode,
        onTrackCreated: () async {
          final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
          final tracks = await notifier.fetchCustomsTracks(widget.selectedImportFile!.importFileId);
          widget.onTracksUpdated(tracks);
        },
      ),
    );
  }

  Future<void> _downloadTrackExcelFile(CustomsInvoiceTrackModel track) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      await FileSaveHelper.exportWithPickerAndFetch(
        context: context,
        stageName: 'CargoX Blockchain & ACI Hub',
        importFileNameOrCode: 'Customs Invoice (${track.trackCode})',
        extension: 'xlsx',
        customDialogTitle: isAr ? 'حفظ ملف الفاتورة الجمركية' : 'Save Customs Invoice Excel',
        fetchBytes: () => notifier.downloadTrackExcel(track.trackId),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.errorPrefix}: $e'), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _downloadTrackPackingListFile(CustomsInvoiceTrackModel track) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      await FileSaveHelper.exportWithPickerAndFetch(
        context: context,
        stageName: 'CargoX Blockchain & ACI Hub',
        importFileNameOrCode: 'Customs Packing List (${track.trackCode})',
        extension: 'xlsx',
        customDialogTitle: isAr ? 'حفظ ملف قائمة التعبئة الجمركية' : 'Save Customs Packing List Excel',
        fetchBytes: () => notifier.downloadTrackPackingListExcel(track.trackId),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.errorPrefix}: $e'), backgroundColor: AppTheme.crimson),
      );
    }
  }

  void _showTrackDeleteConfirmDialog(CustomsInvoiceTrackModel track) {
    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 28),
              const SizedBox(width: 8),
              Text(context.l10n.customsTrackDeleteDialogTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(context.l10n.customsTrackDeleteDialogMessage(track.trackCode)),
          actions: [
            AppButton(
              label: context.l10n.cancel,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            AppButton(
              label: context.l10n.delete,
              variant: AppButtonVariant.danger,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final l10n = context.l10n;
                final nav = Navigator.of(ctx);
                try {
                  final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
                  await notifier.deleteCustomsTrack(track.trackId);
                  if (widget.selectedImportFile != null) {
                    final updated = await notifier.fetchCustomsTracks(widget.selectedImportFile!.importFileId);
                    widget.onTracksUpdated(updated);
                  }
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.customsTrackDeleteSuccessToast(track.trackCode)), backgroundColor: AppTheme.emerald),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: AppTheme.crimson),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
