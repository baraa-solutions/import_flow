import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/document_export/packaging_detail_toggle.dart';
import '../../../core/widgets/document_export/grouping_selector.dart';
import '../models/cargox_model.dart';
import '../models/export_configs.dart';
import '../providers/cargox_provider.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
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
              _buildHeader(l),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildDualEnginePanel(l, isAr),
                      if (_plConfig.effectiveIncludePalletDetails) ...[ 
                        const SizedBox(height: 16),
                        _buildPalletsPanel(l, isAr),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _buildErrorBanner(),
                      ],
                      if (_previewResult != null) ...[
                        const SizedBox(height: 12),
                        _buildPreviewSummary(l, isAr),
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

  Widget _buildHeader(AppLocalizations l) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(16),
          topEnd: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.file_copy_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dualExtractionEngineTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                LtrText(
                  widget.importFileCode,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDualEnginePanel(AppLocalizations l, bool isAr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Invoice Engine ────────────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.cobalt.withValues(alpha: 0.03),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.dualExtractionCommercialInvoice,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                          Text(
                            isAr ? 'الفاتورة الجمركية المستقلة' : 'Independent Customs Invoice',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                // Dim 1 + Dim 2
                PackagingDetailToggle(
                  packaging: _invoiceConfig.packaging,
                  detail: _invoiceConfig.detail,
                  onPackagingChanged: (v) => setState(() => _invoiceConfig = _invoiceConfig.copyWith(packaging: v)),
                  onDetailChanged: (v) => setState(() => _invoiceConfig = _invoiceConfig.copyWith(detail: v)),
                  activeColor: AppTheme.cobalt,
                ),
                const SizedBox(height: 12),
                // Dim 3 — Invoice Line Grouping
                GroupingSelector<InvoiceGroupingMode>(
                  title: isAr ? '٣. أسلوب تجميع بنود الفاتورة:' : '3. Invoice Line Grouping:',
                  value: _invoiceConfig.grouping,
                  options: InvoiceGroupingMode.values
                      .map((m) => GroupingOption(
                            value: m,
                            label: isAr ? m.labelAr : m.labelEn,
                            description: isAr ? m.descAr : m.descEn,
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _invoiceConfig = _invoiceConfig.copyWith(grouping: v)),
                  activeColor: AppTheme.cobalt,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // ── Packing List Engine ───────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.emerald.withValues(alpha: 0.03),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: AppTheme.emerald, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.dualExtractionPackingList,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.emerald)),
                          Text(
                            isAr ? 'قائمة التعبئة المستقلة' : 'Independent Packing List',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                // Dim 1 + Dim 2
                PackagingDetailToggle(
                  packaging: _plConfig.packaging,
                  detail: _plConfig.detail,
                  onPackagingChanged: (v) => setState(() => _plConfig = _plConfig.copyWith(packaging: v)),
                  onDetailChanged: (v) => setState(() => _plConfig = _plConfig.copyWith(detail: v)),
                  activeColor: AppTheme.emerald,
                ),
                const SizedBox(height: 12),
                // Dim 3 — Package & Carton Structure
                GroupingSelector<PackingListStructure>(
                  title: isAr ? '٣. هيكل التعبئة والتغليف:' : '3. Package & Carton Structure:',
                  value: _plConfig.structure,
                  options: PackingListStructure.values
                      .map((s) => GroupingOption(
                            value: s,
                            label: isAr ? s.labelAr : s.labelEn,
                            description: isAr ? s.descAr : s.descEn,
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _plConfig = _plConfig.copyWith(structure: v)),
                  activeColor: AppTheme.emerald,
                ),
                const SizedBox(height: 8),
                // Dim 4 — Conditional pallet details toggle
                AnimatedOpacity(
                  opacity: _plConfig.isPalletToggleAllowed ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: SwitchListTile(
                    value: _plConfig.effectiveIncludePalletDetails,
                    onChanged: _plConfig.isPalletToggleAllowed
                        ? (v) => setState(() => _plConfig = _plConfig.copyWith(includePalletDetails: v))
                        : null,
                    title: Text(l.dualExtractionIncludePallets, style: const TextStyle(fontSize: 11)),
                    activeThumbColor: AppTheme.emerald,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPalletsPanel(AppLocalizations l, bool isAr) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF1FBF5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_module_outlined, color: AppTheme.emerald, size: 18),
              const SizedBox(width: 8),
              Text(l.dualExtractionPalletDataTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showAddPalletDialog(l, isAr),
                icon: const Icon(Icons.add, size: 14),
                label: Text(l.dualExtractionAddPalletBtn, style: const TextStyle(fontSize: 11)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          if (_pallets.isEmpty) ...[
            const SizedBox(height: 12),
            Center(child: Text(l.dualExtractionNoPallets, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          ] else ...[
            const SizedBox(height: 10),
            ..._pallets.asMap().entries.map((e) => _buildPalletTile(e.key, e.value, l, isAr)),
          ],
        ],
      ),
    );
  }

  Widget _buildPalletTile(int index, PalletInputModel pallet, AppLocalizations l, bool isAr) {
    final weightGrossLabel = isAr ? 'الوزن القائم:' : 'Gross:';
    final weightNetLabel = isAr ? 'الصافي:' : 'Net:';
    final kgLabel = isAr ? 'كجم' : 'kg';
    final itemsLabel = isAr ? 'بند' : 'items';
    final cmLabel = isAr ? 'سم' : 'cm';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_rows_outlined, size: 18, color: AppTheme.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pallet.palletNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(
                  '${pallet.palletType}  ·  ${pallet.items.length} $itemsLabel  ·  '
                  '$weightGrossLabel ${pallet.grossWeightKg} $kgLabel  ·  $weightNetLabel ${pallet.netWeightKg} $kgLabel'
                  '${pallet.dimensionsCm != null ? "  ·  ${pallet.dimensionsCm} $cmLabel" : ""}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.grey, size: 16),
            onPressed: () => CopyHelper.copy(
              context,
              '${pallet.palletNumber}: ${pallet.palletType}, ${pallet.grossWeightKg} $kgLabel',
              customMessage: l.copyTooltip,
            ),
            tooltip: l.copyTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: () => setState(() => _pallets.removeAt(index)),
            tooltip: isAr ? 'حذف البالتة' : 'Remove Pallet',
          ),
        ],
      ),
    );
  }

  void _showAddPalletDialog(AppLocalizations l, bool isAr) {
    final palletNumCtrl = TextEditingController(text: 'PLT-${(_pallets.length + 1).toString().padLeft(3, "0")}');
    final dimsCtrl = TextEditingController();
    final grossCtrl = TextEditingController();
    final netCtrl = TextEditingController();
    String palletType = 'EURO';

    final palletTypeOptions = isAr
        ? [
            ('EURO', 'بالتة أوروبية'),
            ('CHEP', 'بالتة شيب زرقاء'),
            ('CUSTOM', 'بالتة مقاس خاص'),
            ('WOODEN', 'بالتة خشبية قياسية'),
          ]
        : [
            ('EURO', 'EURO Standard'),
            ('CHEP', 'CHEP Blue Pallet'),
            ('CUSTOM', 'Custom Dimensions'),
            ('WOODEN', 'Standard Wooden'),
          ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: Text(l.dualExtractionAddPalletBtn, style: const TextStyle(fontSize: 14)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: palletNumCtrl,
                  decoration: InputDecoration(
                    labelText: isAr ? 'رقم البالتة' : 'Pallet Number',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: palletType,
                  items: palletTypeOptions
                      .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) => setInnerState(() => palletType = v ?? 'EURO'),
                  decoration: InputDecoration(
                    labelText: isAr ? 'نوع البالتة' : 'Pallet Type',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dimsCtrl,
                  decoration: InputDecoration(
                    labelText: isAr ? 'الأبعاد سم — مثال: 120×80×150' : 'Dimensions cm (e.g. 120x80x150)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: grossCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isAr ? 'الوزن القائم كجم' : 'Gross Weight (kg)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: netCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isAr ? 'الوزن الصافي كجم' : 'Net Weight (kg)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pallet = PalletInputModel(
                  palletNumber: palletNumCtrl.text.trim(),
                  palletType: palletType,
                  dimensionsCm: dimsCtrl.text.trim().isEmpty ? null : dimsCtrl.text.trim(),
                  grossWeightKg: double.tryParse(grossCtrl.text) ?? 0.0,
                  netWeightKg: double.tryParse(netCtrl.text) ?? 0.0,
                );
                setState(() => _pallets.add(pallet));
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
              child: Text(isAr ? 'إضافة' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(fontSize: 11, color: Colors.orange))),
        ],
      ),
    );
  }

  Widget _buildPreviewSummary(AppLocalizations l, bool isAr) {
    final r = _previewResult!;
    final invoiceSummary = isAr
        ? '${r.invoiceInvoicesCount} فاتورة · ${r.invoiceTotalLineItems} بند'
        : '${r.invoiceInvoicesCount} invoices · ${r.invoiceTotalLineItems} items';
    final plSummary = isAr
        ? '${r.packingListCount} ملف · ${r.packingListTotalItems} بند'
        : '${r.packingListCount} files · ${r.packingListTotalItems} items';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.dualExtractionPreviewResults,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.emerald),
                tooltip: l.dualExtractionCopySummaryTooltip,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _copySummary(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _previewChip(Icons.receipt_long, l.dualExtractionCommercialInvoice, invoiceSummary, AppTheme.cobalt),
              const SizedBox(width: 12),
              _previewChip(Icons.inventory_2_outlined, l.dualExtractionPackingList, plSummary, AppTheme.emerald),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: color)),
                  Text(value, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
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
