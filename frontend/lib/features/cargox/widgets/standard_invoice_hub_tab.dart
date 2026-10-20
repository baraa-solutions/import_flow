import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/adaptive_tab_scaffold.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/cargox_model.dart';
import '../providers/cargox_provider.dart';
import '../services/cargox_pdf_service.dart';
import 'dual_extraction_modal.dart';
import 'package:printing/printing.dart';
import 'package:dio/dio.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../services/cargox_export_service.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
String _formatDateTime(DateTime dt) {
  final str = dt.toIso8601String();
  if (str.length >= 16) {
    return str.substring(0, 16).replaceAll('T', ' ');
  }
  return str;
}

String _extractErrorMessage(dynamic err) {
  if (err is DioException && err.response?.data != null) {
    final data = err.response!.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
  }
  return err.toString();
}

class StandardInvoiceHubTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const StandardInvoiceHubTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<StandardInvoiceHubTab> createState() => _StandardInvoiceHubTabState();
}

class _StandardInvoiceHubTabState extends ConsumerState<StandardInvoiceHubTab> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _subTabController;

  ImportFileModel? _selectedImportFile;
  StandardInvoiceSessionModel? _existingSession;
  StandardInvoicePayloadModel? _supplierData;
  StandardInvoiceComparisonResponseModel? _comparisonResult;
  List<CustomsInvoiceTrackModel> _customsTracks = [];

  bool _isLoading = false;
  final bool _isDownloading = false;
  bool _isParsing = false;
  bool _isSaving = false;

  String _selectedStatus = 'UNDER_REVIEW';
  final TextEditingController _overrideReasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 5, vsync: this);
    Future.microtask(() {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(standardInvoiceSessionsProvider.notifier).fetchSessions();
      if (widget.initialImportFileId != null) {
        _loadInitialFile(widget.initialImportFileId!);
      }
    });
  }

  @override
  void dispose() {
    _subTabController.dispose();
    _overrideReasonController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialFile(int fileId) async {
    final filesAsync = ref.read(importFilesProvider);
    filesAsync.whenData((files) {
      final match = files.where((f) => f.importFileId == fileId).firstOrNull;
      if (match != null) {
        _onSelectImportFile(match);
      }
    });
  }

  Future<void> _onSelectImportFile(ImportFileModel file) async {
    setState(() {
      _selectedImportFile = file;
      _existingSession = null;
      _supplierData = null;
      _comparisonResult = null;
      _customsTracks = [];
      _overrideReasonController.clear();
      _notesController.clear();
      _isLoading = true;
    });

    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final session = await notifier.fetchSessionByFile(file.importFileId);
      final tracks = await notifier.fetchCustomsTracks(file.importFileId);
      if (mounted) {
        setState(() {
          _existingSession = session;
          _customsTracks = tracks;
          if (session != null) {
            _selectedStatus = session.status;
            _overrideReasonController.text = session.discrepancyOverrideReason ?? '';
            _notesController.text = session.notes ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDownloadTemplate() async {
    if (_selectedImportFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.standardInvoiceSelectFileFirstError), backgroundColor: Colors.red),
      );
      return;
    }
    await _showExtractionOptionsDialog();
  }

  Future<void> _showExtractionOptionsDialog() async {
    final file = _selectedImportFile!;
    String selectedMode = 'all_consolidated';
    String selectedGrouping = 'by_hs_code';
    bool isExtracting = false;
    bool isDownloading = false;
    bool isSavingCustomsTrack = false;
    ExtractionResponseModel? previewResponse;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 950,
              constraints: const BoxConstraints(maxHeight: 780),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.hub_outlined, color: Color(0xFF27AE60), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.cargoxExtractEngineTitle,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الملف: ${file.primaryNameWithCode} — ${file.supplierName} (ACID: ${file.acidNumber ?? "N/A"})',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Content Scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'اختر مسار الاستخلاص المطلوب لملف الإكسل:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50)),
                          ),
                          const SizedBox(height: 12),

                          // 4 Options Grid/Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildModeOptionCard(
                                  title: context.l10n.cargoxModeConsolidatedTitle,
                                  subtitle: context.l10n.cargoxModeConsolidatedSubtitle,
                                  icon: Icons.compress,
                                  color: const Color(0xFF27AE60),
                                  isSelected: selectedMode == 'all_consolidated',
                                  onTap: () {
                                    setDialogState(() {
                                      selectedMode = 'all_consolidated';
                                      selectedGrouping = 'by_hs_code';
                                      previewResponse = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModeOptionCard(
                                  title: context.l10n.cargoxModeDetailedTitle,
                                  subtitle: context.l10n.cargoxModeDetailedSubtitle,
                                  icon: Icons.list_alt,
                                  color: const Color(0xFF3498DB),
                                  isSelected: selectedMode == 'all_detailed',
                                  onTap: () {
                                    setDialogState(() {
                                      selectedMode = 'all_detailed';
                                      selectedGrouping = 'flat';
                                      previewResponse = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModeOptionCard(
                                  title: context.l10n.cargoxModePerInvoiceConsolidatedTitle,
                                  subtitle: context.l10n.cargoxModePerInvoiceConsolidatedSubtitle,
                                  icon: Icons.folder_zip_outlined,
                                  color: const Color(0xFFE67E22),
                                  isSelected: selectedMode == 'per_invoice_consolidated',
                                  onTap: () {
                                    setDialogState(() {
                                      selectedMode = 'per_invoice_consolidated';
                                      selectedGrouping = 'by_hs_code';
                                      previewResponse = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModeOptionCard(
                                  title: context.l10n.cargoxModePerInvoiceDetailedTitle,
                                  subtitle: context.l10n.cargoxModePerInvoiceDetailedSubtitle,
                                  icon: Icons.inventory_2_outlined,
                                  color: const Color(0xFF9B59B6),
                                  isSelected: selectedMode == 'per_invoice_detailed',
                                  onTap: () {
                                    setDialogState(() {
                                      selectedMode = 'per_invoice_detailed';
                                      selectedGrouping = 'flat';
                                      previewResponse = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Preview Button & Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: isExtracting
                                    ? null
                                    : () async {
                                        setDialogState(() => isExtracting = true);
                                        try {
                                          final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
                                          final res = await notifier.extractMultiMode(
                                            file.importFileId,
                                            mode: selectedMode,
                                            groupingMode: selectedGrouping,
                                          );
                                          setDialogState(() {
                                            previewResponse = res;
                                            isExtracting = false;
                                          });
                                        } catch (e) {
                                          setDialogState(() => isExtracting = false);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(context.l10n.cargoxExtractionError(_extractErrorMessage(e))), backgroundColor: Colors.red),
                                          );
                                        }
                                      },
                                icon: isExtracting
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.remove_red_eye, size: 18),
                                label: Text(context.l10n.cargoxLiveItemsPreviewBtn),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C3E50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              if (previewResponse != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'عدد الفواتير: ${previewResponse!.invoicesCount} | عدد الأسطر: ${previewResponse!.totalLineItems}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF27AE60)),
                                  ),
                                ),
                            ],
                          ),

                          if (previewResponse != null) ...[
                            const SizedBox(height: 14),
                            _buildPreviewResultArea(previewResponse!),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 24),

                  // Dialog Bottom Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(context.l10n.cancel),
                      ),
                      const SizedBox(width: 12),

                      // Save as Customs Track Button
                      OutlinedButton.icon(
                        onPressed: isSavingCustomsTrack
                            ? null
                            : () async {
                                setDialogState(() => isSavingCustomsTrack = true);
                                try {
                                  final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
                                  final track = await notifier.createCustomsTrack({
                                    'import_file_id': file.importFileId,
                                    'extraction_mode': selectedMode,
                                    'grouping_mode': selectedGrouping,
                                    'notes': 'Customs track approved from the extraction screen',
                                  });
                                  final tracks = await notifier.fetchCustomsTracks(file.importFileId);
                                  setDialogState(() => isSavingCustomsTrack = false);
                                  if (!context.mounted) return;
                                  setState(() {
                                    _customsTracks = tracks;
                                  });
                                  Navigator.of(ctx).pop();
                                  _subTabController.animateTo(4);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم اعتماد وحفظ المسار الجمركي: ${track.trackCode} وتحديث تبويب المسارات الجمركية'),
                                      backgroundColor: const Color(0xFF27AE60),
                                    ),
                                  );
                                } catch (e) {
                                  setDialogState(() => isSavingCustomsTrack = false);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('خطأ أثناء حفظ المسار الجمركي: ${_extractErrorMessage(e)}'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                        icon: isSavingCustomsTrack
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.gavel, size: 18),
                        label: const Text('اعتماد كمسار جمركي مستقل'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE67E22),
                          side: const BorderSide(color: Color(0xFFE67E22)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Download Button
                      ElevatedButton.icon(
                        onPressed: isDownloading
                            ? null
                            : () async {
                                final isZip = selectedMode.startsWith('per_invoice_');
                                const stage = 'CargoX Blockchain & ACI Hub';
                                final fileCode = '${file.companyName} (${file.importFileCode})';
                                final ext = isZip ? 'zip' : 'xlsx';
                                final title = isZip ? 'حفظ أرشيف فواتير CargoX ZIP' : 'حفظ فاتورة CargoX القياسية Excel';

                                setDialogState(() => isDownloading = true);
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
                                      mode: selectedMode,
                                      groupingMode: selectedGrouping,
                                    ),
                                  );

                                  setDialogState(() => isDownloading = false);
                                  if (saved != null && ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                  }
                                } catch (e) {
                                  setDialogState(() => isDownloading = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${context.l10n.errorPrefix}: ${_extractErrorMessage(e)}'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },

                        icon: isDownloading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download, size: 18),
                        label: Text(selectedMode.startsWith('per_invoice_') ? context.l10n.cargoxDownloadZipBtn : context.l10n.cargoxExportExcelBtn),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? color : const Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewResultArea(ExtractionResponseModel response) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F7),
              borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(10), topEnd: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const Row(
              children: [
                Icon(Icons.table_chart, size: 16, color: Color(0xFF2C3E50)),
                SizedBox(width: 8),
                Text(
                  'تفاصيل البنود المستخلصة والأوزان (Live Preview):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2C3E50)),
                ),
              ],
            ),
          ),
          for (final result in response.results) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3498DB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'فاتورة: ${result.invoiceNumber ?? "Default"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2980B9)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'إجمالي القيمة: ${result.payload.subtotal.toStringAsFixed(2)} ${result.payload.currencyCode}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF27AE60)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'القائم: ${result.payload.grossWeight.toStringAsFixed(1)} ${result.payload.weightUnit} | الصافي: ${result.payload.netWeight.toStringAsFixed(1)} ${result.payload.weightUnit}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 30,
                      dataRowMaxHeight: 36,
                      columnSpacing: 16,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9F9)),
                      columns: [
                        const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(context.l10n.hsCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(context.l10n.standardInvoiceManufacturer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(context.l10n.colDescription, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(context.l10n.colQuantity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(context.l10n.colUnitPrice, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(context.l10n.colTotalAmount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(context.l10n.colGrossWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(context.l10n.standardInvoiceWeightNet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                      rows: result.payload.items.map((item) {
                        final rowSummary = '${item.index}. ${item.hsCode} | ${item.description} | ${item.quantity} ${item.qtyUnit} @ ${item.unitPrice.toStringAsFixed(4)} = ${item.totalAmount.toStringAsFixed(2)} | Gross: ${item.grossWeightKg} | Net: ${item.netWeightKg}';
                        return DataRow(
                          cells: [
                            DataCell(CopyableTableCell(value: '${item.index}', rowSummary: rowSummary, child: Text('${item.index}', style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: item.hsCode, rowSummary: rowSummary, child: LtrText(item.hsCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                            DataCell(CopyableTableCell(value: item.manufacturer ?? '—', rowSummary: rowSummary, child: Text(item.manufacturer ?? '—', style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: item.description, rowSummary: rowSummary, child: Text(item.description, style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: '${item.quantity} ${item.qtyUnit}', rowSummary: rowSummary, child: Text('${item.quantity} ${item.qtyUnit}', style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: item.unitPrice.toStringAsFixed(4), rowSummary: rowSummary, child: Text(item.unitPrice.toStringAsFixed(4), style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: item.totalAmount.toStringAsFixed(2), rowSummary: rowSummary, child: Text(item.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27AE60), fontSize: 11)))),
                            DataCell(CopyableTableCell(value: '${item.grossWeightKg} ${result.payload.weightUnit}', rowSummary: rowSummary, child: Text('${item.grossWeightKg} ${result.payload.weightUnit}', style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: '${item.netWeightKg} ${result.payload.weightUnit}', rowSummary: rowSummary, child: Text('${item.netWeightKg} ${result.payload.weightUnit}', style: const TextStyle(fontSize: 11)))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handlePickAndParseExcel() async {
    if (_selectedImportFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.standardInvoiceSelectFileFirstError), backgroundColor: Colors.red),
      );
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isParsing = true);
      try {
        final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
        final parsed = await notifier.parseExcelFile(file.bytes!, file.name);

        if (!mounted) return;
        setState(() {
          _supplierData = parsed;
          _isParsing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.standardInvoiceExtractedSuccess(parsed.invoiceNumber ?? parsed.invoiceType, parsed.items.length)),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );

        // Auto trigger comparison
        await _handleRunComparison();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isParsing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.errorPrefix}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRunComparison() async {
    if (_selectedImportFile == null || _supplierData == null) return;

    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final comp = await notifier.compareInvoice(_selectedImportFile!.importFileId, _supplierData!);

      if (!mounted) return;
      setState(() {
        _comparisonResult = comp;
      });

      _subTabController.animateTo(1); // Switch to comparison tab
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.errorPrefix}: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSaveSession({bool isDraft = false}) async {
    if (_selectedImportFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.standardInvoiceSelectFileFirstError), backgroundColor: Colors.red),
      );
      return;
    }

    final saveStatus = isDraft ? 'DRAFT' : _selectedStatus;
    final hasIssues = (_comparisonResult?.hasDiscrepancies ?? false) || (_comparisonResult?.hasCriticalMismatch ?? false);
    if (!isDraft && saveStatus == 'APPROVED' && hasIssues) {
      if (_overrideReasonController.text.trim().isEmpty) {
        _formKey.currentState?.validate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.standardInvoiceMustProvideOverrideJustification),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final payload = {
        'import_file_id': _selectedImportFile!.importFileId,
        'import_file_code': _selectedImportFile!.importFileCode,
        'acid_number': _supplierData?.acidNumber ?? _selectedImportFile!.acidNumber,
        'invoice_number': _supplierData?.invoiceNumber ?? 'INV-${_selectedImportFile!.importFileCode}',
        'invoice_date': _supplierData?.invoiceDate,
        'invoice_type': _supplierData?.invoiceType ?? 'Commercial Invoice',
        'purchase_order_number': _supplierData?.purchaseOrderNumber,
        'exporter_name': _supplierData?.sellerName ?? _selectedImportFile!.supplierName,
        'exporter_tax_id': _supplierData?.sellerTaxId,
        'exporter_country_code': _supplierData?.sellerCountryCode,
        'importer_name': _supplierData?.buyerName ?? _selectedImportFile!.companyName,
        'importer_tax_id': _supplierData?.buyerTaxId,
        'currency_code': _supplierData?.currencyCode ?? 'EUR',
        'incoterm': _supplierData?.incoterm ?? _selectedImportFile!.incotermCode,
        'pol_code': _supplierData?.originPort,
        'pod_code': _supplierData?.destinationPort,
        'gross_weight_kg': _supplierData?.grossWeight ?? 0.0,
        'net_weight_kg': _supplierData?.netWeight ?? 0.0,
        'weight_unit': _supplierData?.weightUnit ?? 'KGM',
        'subtotal_amount': _supplierData?.subtotal ?? 0.0,
        'freight_cost': _supplierData?.freightCost ?? 0.0,
        'insurance_cost': _supplierData?.insuranceCost ?? 0.0,
        'other_costs': _supplierData?.otherCosts ?? 0.0,
        'total_amount': _supplierData?.totalAmount ?? 0.0,
        'line_items_count': _supplierData?.items.length ?? 0,
        'has_discrepancies': _comparisonResult?.hasDiscrepancies ?? false,
        'has_critical_mismatch': _comparisonResult?.hasCriticalMismatch ?? false,
        'discrepancy_override_reason': _overrideReasonController.text.trim(),
        'status': saveStatus,
        'notes': _notesController.text.trim(),
      };

      final saved = await notifier.saveOrUpsertSession(payload);
      if (!mounted) return;
      setState(() {
        _existingSession = saved;
        if (isDraft) {
          _selectedStatus = 'DRAFT';
        }
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDraft
                ? 'تم حفظ مسودة جلسة مراجعة الفاتورة بنجاح (${saved.sessionCode})'
                : context.l10n.standardInvoiceSessionSavedSuccess(saved.sessionCode),
          ),
          backgroundColor: isDraft ? AppTheme.cobalt : const Color(0xFF27AE60),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.errorPrefix}: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    CopyHelper.copy(
      context,
      text,
      customMessage: context.l10n.standardInvoiceCopiedToClipboard(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(importFilesProvider);
    final sessionsAsync = ref.watch(standardInvoiceSessionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderSection(),
                if (_isLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                _buildFileSelector(filesAsync),
                if (_existingSession != null) ...[
                  const SizedBox(height: 12),
                  _buildPreExistingStudyAlertBanner(),
                ],
                const SizedBox(height: 20),
                _buildActionToolsBar(),
                const SizedBox(height: 20),
                _buildAdaptiveTabs(sessionsAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.table_chart, color: Color(0xFF27AE60), size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.standardInvoiceHubTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.standardInvoiceHubDesc,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (_existingSession != null)
            _buildStatusBadge(_existingSession!.status),
        ],
      ),
    );
  }

  Widget _buildFileSelector(AsyncValue<List<ImportFileModel>> filesAsync) {
    return filesAsync.when(
      data: (files) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBDC3C7).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SearchableDropdownField<int>(
                  labelText: context.l10n.standardInvoiceFileSelectorLabel,
                  hintText: context.l10n.standardInvoiceFileSelectorHint,
                  value: _selectedImportFile?.importFileId,
                  items: files
                      .map((f) => SearchableDropdownItem<int>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} — ${f.supplierName} (${f.companyName}) [ACID: ${f.acidNumber ?? "N/A"}]',
                            searchValue: '${f.primaryNameWithCode} ${f.supplierName} ${f.companyName} ${f.acidNumber ?? ""}',
                          ))
                      .toList(),
                  onChanged: (fileId) {
                    if (fileId != null) {
                      final match = files.where((f) => f.importFileId == fileId).firstOrNull;
                      if (match != null) _onSelectImportFile(match);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(importFilesProvider.notifier).fetchImportFiles();
                  ref.read(standardInvoiceSessionsProvider.notifier).fetchSessions();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.l10n.refresh),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('${context.l10n.standardInvoiceFetchError} $e', style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildPreExistingStudyAlertBanner() {
    final s = _existingSession!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF39C12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFD68910), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.standardInvoiceExistingSessionTitle(s.sessionCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7D6608)),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.standardInvoiceExistingSessionSubtitle(
                    _formatDateTime(s.updatedAt),
                    s.status,
                    s.totalAmount.toStringAsFixed(2),
                    s.currencyCode,
                    s.lineItemsCount,
                  ),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7D6608)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.standardInvoiceSessionLoadedToast(s.sessionCode))),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD68910),
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.standardInvoiceViewSessionBtn),
          ),
        ],
      ),
    );
  }

  Widget _buildActionToolsBar() {
    return Row(
      children: [
        Expanded(
          child: _buildToolActionCard(
            title: context.l10n.standardInvoiceTool1Title,
            subtitle: context.l10n.standardInvoiceTool1Subtitle,
            icon: Icons.download_for_offline,
            color: const Color(0xFF27AE60),
            buttonLabel: context.l10n.standardInvoiceTool1Btn,
            isLoading: _isDownloading,
            onTap: _handleDownloadTemplate,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildToolActionCard(
            title: context.l10n.standardInvoiceTool2Title,
            subtitle: context.l10n.standardInvoiceTool2Subtitle,
            icon: Icons.upload_file,
            color: const Color(0xFF3498DB),
            buttonLabel: context.l10n.standardInvoiceTool2Btn,
            isLoading: _isParsing,
            onTap: _handlePickAndParseExcel,
          ),
        ),
      ],
    );
  }

  Widget _buildToolActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonLabel,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50))),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onTap,
              icon: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(icon, size: 18),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveTabs(AsyncValue<List<StandardInvoiceSessionModel>> sessionsAsync) {
    final l10n = context.l10n;

    return AdaptiveTabScaffold(
      controller: _subTabController,
      accentColor: const Color(0xFF27AE60),
      tabs: [
        AdaptiveTabItem(
          icon: Icons.visibility,
          label: l10n.standardInvoiceTabExtracted,
          content: _buildExtractedDataTab(),
        ),
        AdaptiveTabItem(
          icon: Icons.compare_arrows,
          label: l10n.standardInvoiceTabComparison,
          content: _buildComparisonMatrixTab(),
        ),
        AdaptiveTabItem(
          icon: Icons.gavel,
          label: l10n.standardInvoiceTabGovernance,
          content: _buildApprovalAndGovernanceTab(),
        ),
        AdaptiveTabItem(
          icon: Icons.history,
          label: l10n.standardInvoiceTabRegistry,
          content: _buildSessionsRegistryTab(sessionsAsync),
        ),
        AdaptiveTabItem(
          icon: Icons.account_balance,
          label: l10n.standardInvoiceTabCustomsTracks,
          badge: _customsTracks.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_customsTracks.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              : null,
          content: _buildCustomsTracksTab(),
        ),
      ],
    );
  }

  Widget _buildCustomsTracksTab() {
    if (_selectedImportFile == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(Icons.account_balance_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('يرجى اختيار ملف استيراد لعرض مساراته الجمركية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (_customsTracks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('لا توجد مسارات جمركية معتمدة حتى الآن لهذا الملف', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'يمكنك اعتماد فاتورة جمركية مستقلة عبر محرك استخلاص CargoX بالضغط على "تحميل النموذج القياسي Excel" ثم اختيار "اعتماد كمسار جمركي مستقل".',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showExtractionOptionsDialog,
              icon: const Icon(Icons.hub_outlined, size: 18),
              label: const Text('فتح محرك الاستخلاص والاعتماد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
              ),
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
              'المسارات الجمركية المعتمدة للشحنة (${_customsTracks.length}):',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            ElevatedButton.icon(
              onPressed: _showExtractionOptionsDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('استخلاص مسار جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                if (_selectedImportFile == null) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => DualExtractionModal(
                    importFileId: _selectedImportFile!.importFileId,
                    importFileCode: _selectedImportFile!.importFileCode,
                    onTrackCreated: () async {
                      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
                      final tracks = await notifier.fetchCustomsTracks(_selectedImportFile!.importFileId);
                      if (mounted) setState(() => _customsTracks = tracks);
                    },
                  ),
                );
              },
              icon: const Icon(Icons.file_copy_outlined, size: 16),
              label: const Text('استخلاص مزدوج ✨'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final track in _customsTracks) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27AE60).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.gavel, color: Color(0xFF27AE60), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.trackCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2C3E50)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تاريخ الاعتماد: ${_formatDateTime(track.createdAt)} | النمط: ${track.extractionMode}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        track.status,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF27AE60)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildTrackStatCard(
                        'إجمالي القيمة الجمركية',
                        '${track.customsTotalAmount.toStringAsFixed(2)} USD',
                        Icons.attach_money,
                        const Color(0xFF27AE60),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTrackStatCard(
                        'إجمالي الوزن القائم',
                        '${track.customsGrossWeight.toStringAsFixed(1)} كجم',
                        Icons.scale,
                        const Color(0xFF3498DB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTrackStatCard(
                        'إجمالي الوزن الصافي',
                        '${track.customsNetWeight.toStringAsFixed(1)} كجم',
                        Icons.monitor_weight_outlined,
                        const Color(0xFFE67E22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTrackStatCard(
                        'عدد بنود التعريفة',
                        '${track.lineItemsCount} بند',
                        Icons.format_list_numbered,
                        const Color(0xFF9B59B6),
                      ),
                    ),
                  ],
                ),
                if (track.notes != null && track.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'ملاحظات: ${track.notes}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Track Actions Bar
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // 1. View Details Modal Button
                    ElevatedButton.icon(
                      onPressed: () => _showTrackDetailsDialog(track),
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                      label: const Text('مشاهدة وتفاصيل البنود'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),

                    // 2. PDF Preview & Print Button
                    ElevatedButton.icon(
                      onPressed: () => _showTrackPdfPreviewDialog(track),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('معاينة وطباعة PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),

                    // 3. Export Invoice Excel Button
                    OutlinedButton.icon(
                      onPressed: () => _downloadTrackExcelFile(track),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('إكسل الفاتورة (.xlsx)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF27AE60),
                        side: const BorderSide(color: Color(0xFF27AE60)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    // 4. Export Packing List Excel Button
                    OutlinedButton.icon(
                      onPressed: () => _downloadTrackPackingListFile(track),
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text('إكسل قائمة التعبئة (.xlsx)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3498DB),
                        side: const BorderSide(color: Color(0xFF3498DB)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    // 5. Edit Track Button
                    OutlinedButton.icon(
                      onPressed: () => _showTrackEditDialog(track),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('تعديل'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE67E22),
                        side: const BorderSide(color: Color(0xFFE67E22)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    // 6. Delete Track Button
                    IconButton(
                      onPressed: () => _showTrackDeleteConfirmDialog(track),
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFC0392B), size: 20),
                      tooltip: 'حذف المسار الجمركي',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFC0392B).withValues(alpha: 0.08),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _downloadTrackExcelFile(CustomsInvoiceTrackModel track) async {
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      await FileSaveHelper.exportWithPickerAndFetch(
        context: context,
        stageName: 'CargoX Blockchain & ACI Hub',
        importFileNameOrCode: 'Customs Invoice (${track.trackCode})',
        extension: 'xlsx',
        customDialogTitle: 'حفظ ملف الفاتورة الجمركية Excel',
        fetchBytes: () => notifier.downloadTrackExcel(track.trackId),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء تحميل إكسل الفاتورة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadTrackPackingListFile(CustomsInvoiceTrackModel track) async {
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      await FileSaveHelper.exportWithPickerAndFetch(
        context: context,
        stageName: 'CargoX Blockchain & ACI Hub',
        importFileNameOrCode: 'Customs Packing List (${track.trackCode})',
        extension: 'xlsx',
        customDialogTitle: 'حفظ ملف قائمة التعبئة الجمركية Excel',
        fetchBytes: () => notifier.downloadTrackPackingListExcel(track.trackId),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء تحميل إكسل قائمة التعبئة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showTrackDetailsDialog(CustomsInvoiceTrackModel track) {
    Map<String, dynamic> invData = {};
    if (track.customsInvoiceData is Map) {
      invData = Map<String, dynamic>.from(track.customsInvoiceData as Map);
    } else if (track.customsInvoiceData is List && (track.customsInvoiceData as List).isNotEmpty) {
      invData = Map<String, dynamic>.from((track.customsInvoiceData as List).first as Map);
    }

    final payload = invData.isNotEmpty ? StandardInvoicePayloadModel.fromJson(invData) : null;
    final packData = (track.customsPackingListData is Map) ? Map<String, dynamic>.from(track.customsPackingListData as Map) : <String, dynamic>{};
    final packItems = (packData['items'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 1000,
            constraints: const BoxConstraints(maxHeight: 750),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, color: Color(0xFF27AE60), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تفاصيل المسار الجمركي: ${track.trackCode}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                            ),
                            Text(
                              'الحالة: ${track.status} | النمط: ${track.extractionMode} | إجمالي القيمة: ${track.customsTotalAmount.toStringAsFixed(2)} USD',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF4F6F7), borderRadius: BorderRadius.circular(8)),
                  child: const TabBar(
                    labelColor: Color(0xFF2C3E50),
                    indicatorColor: Color(0xFF27AE60),
                    indicatorWeight: 3,
                    tabs: [
                      Tab(icon: Icon(Icons.receipt), text: 'الفاتورة التجارية الجمركية (Commercial Invoice)'),
                      Tab(icon: Icon(Icons.inventory_2), text: 'قائمة التعبئة الجمركية (Customs Packing List)'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Invoice Table
                      payload != null && payload.items.isNotEmpty
                          ? SingleChildScrollView(
                              child: DataTable(
                                headingRowHeight: 34,
                                dataRowMinHeight: 32,
                                dataRowMaxHeight: 40,
                                columnSpacing: 14,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9F9)),
                                columns: const [
                                  DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('HS Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('المصنع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('الوصف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('السعر المرجح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('القائم (كجم)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('الصافي (كجم)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                ],
                                rows: payload.items.map((i) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text('${i.index}', style: const TextStyle(fontSize: 11))),
                                      DataCell(LtrText(i.hsCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                      DataCell(Text(i.manufacturer ?? '', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(i.description, style: const TextStyle(fontSize: 11))),
                                      DataCell(Text('${i.quantity} ${i.qtyUnit}', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(i.unitPrice.toStringAsFixed(4), style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(i.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF27AE60)))),
                                      DataCell(Text(i.grossWeightKg.toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(i.netWeightKg.toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            )
                          : const Center(child: Text('لا توجد بنود مفصلة بالفاتورة')),

                      // Tab 2: Packing List Table
                      packItems.isNotEmpty
                          ? SingleChildScrollView(
                              child: DataTable(
                                headingRowHeight: 34,
                                dataRowMinHeight: 32,
                                dataRowMaxHeight: 40,
                                columnSpacing: 14,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9F9)),
                                columns: const [
                                  DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('رقم الطرد / البالتة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('HS Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('المصنع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('بيان الصنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('الوزن الصافي (كجم)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('الوزن القائم (كجم)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                ],
                                rows: packItems.map((i) {
                                  final idx = packItems.indexOf(i) + 1;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text('$idx', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(i['package_no']?.toString() ?? 'PKG $idx', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                      DataCell(Text(i['hs_code']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                      DataCell(Text(i['manufacturer']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(i['description']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text('${i["quantity"] ?? 0} ${i["qty_unit"] ?? "PCS"}', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text((i['net_weight_kg'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0', style: const TextStyle(fontSize: 11))),
                                      DataCell(Text((i['gross_weight_kg'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0', style: const TextStyle(fontSize: 11))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            )
                          : const Center(child: Text('لا توجد بيانات لقائمة التعبئة')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إغلاق')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTrackPdfPreviewDialog(CustomsInvoiceTrackModel track) {
    Map<String, dynamic> invData = {};
    if (track.customsInvoiceData is Map) {
      invData = Map<String, dynamic>.from(track.customsInvoiceData as Map);
    } else if (track.customsInvoiceData is List && (track.customsInvoiceData as List).isNotEmpty) {
      invData = Map<String, dynamic>.from((track.customsInvoiceData as List).first as Map);
    }

    final payload = invData.isNotEmpty ? StandardInvoicePayloadModel.fromJson(invData) : StandardInvoicePayloadModel();
    final packData = (track.customsPackingListData is Map) ? Map<String, dynamic>.from(track.customsPackingListData as Map) : <String, dynamic>{};

    bool isInvoiceMode = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 900,
              height: 750,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.picture_as_pdf, color: Color(0xFF27AE60), size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'معاينة وطباعة مستندات المسار الجمركي: ${track.trackCode}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                          ),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text(context.l10n.standardInvoiceTabTitle),
                        selected: isInvoiceMode,
                        selectedColor: const Color(0xFF27AE60).withValues(alpha: 0.2),
                        onSelected: (val) => setModalState(() => isInvoiceMode = true),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: Text(context.l10n.standardInvoicePackingListTitle),
                        selected: !isInvoiceMode,
                        selectedColor: const Color(0xFF3498DB).withValues(alpha: 0.2),
                        onSelected: (val) => setModalState(() => isInvoiceMode = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PdfPreview(
                      build: (format) => isInvoiceMode
                          ? CargoXPdfService.generateCustomsInvoicePdf(track: track, payload: payload)
                          : CargoXPdfService.generateCustomsPackingListPdf(track: track, packingListData: packData),
                      allowPrinting: true,
                      allowSharing: true,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      pdfFileName: isInvoiceMode
                          ? 'Customs_Invoice_${track.trackCode}.pdf'
                          : 'Customs_Packing_List_${track.trackCode}.pdf',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTrackEditDialog(CustomsInvoiceTrackModel track) {
    String selectedStatus = track.status;
    final notesCtrl = TextEditingController(text: track.notes ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SelectionArea(
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit, color: Color(0xFFE67E22)),
                  const SizedBox(width: 8),
                  Text(context.l10n.customsTrackEditDialogTitle(track.trackCode), style: const TextStyle(fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.customsTrackCustomsStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        DropdownMenuItem(value: 'DRAFT', child: Text(context.l10n.standardInvoiceStatusDraft)),
                        DropdownMenuItem(value: 'APPROVED', child: Text(context.l10n.standardInvoiceStatusApproved)),
                        DropdownMenuItem(value: 'SEALED', child: Text(context.l10n.customsTrackStatusSealed)),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedStatus = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(context.l10n.customsTrackNotesAndDeclaration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: context.l10n.customsTrackNotesHint,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.cancel)),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final l10n = context.l10n;
                          final nav = Navigator.of(ctx);
                          setModalState(() => isSaving = true);
                          try {
                            final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
                            await notifier.updateCustomsTrack(track.trackId, {
                              'status': selectedStatus,
                              'notes': notesCtrl.text.trim(),
                            });
                            if (_selectedImportFile != null) {
                              final updated = await notifier.fetchCustomsTracks(_selectedImportFile!.importFileId);
                              if (mounted) setState(() => _customsTracks = updated);
                            }
                            if (!mounted) return;
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(content: Text(l10n.customsTrackUpdateSuccessToast), backgroundColor: const Color(0xFF27AE60)),
                            );
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text(l10n.cargoxSaveTrackError(e)), backgroundColor: Colors.red),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white),
                  child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(context.l10n.customsTrackSaveBtn),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTrackDeleteConfirmDialog(CustomsInvoiceTrackModel track) {
    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B), size: 28),
              const SizedBox(width: 8),
              Text(context.l10n.customsTrackDeleteDialogTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(context.l10n.customsTrackDeleteDialogMessage(track.trackCode)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.cancel)),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final l10n = context.l10n;
                final nav = Navigator.of(ctx);
                try {
                  final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
                  await notifier.deleteCustomsTrack(track.trackId);
                  if (!mounted) return;
                  if (_selectedImportFile != null) {
                    final updated = await notifier.fetchCustomsTracks(_selectedImportFile!.importFileId);
                    if (!mounted) return;
                    setState(() => _customsTracks = updated);
                  }
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.customsTrackDeleteSuccessToast(track.trackCode)), backgroundColor: const Color(0xFF27AE60)),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B), foregroundColor: Colors.white),
              child: Text(context.l10n.delete),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTrackStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildExtractedDataTab() {
    if (_supplierData == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.file_copy_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(context.l10n.standardInvoiceNoExtractedData, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(context.l10n.standardInvoiceNoExtractedDataSub, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    final p = _supplierData!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.standardInvoiceDetailsHeader(p.invoiceNumber ?? p.invoiceType, p.invoiceDate ?? 'N/A'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
              Chip(
                label: Text('${p.totalAmount.toStringAsFixed(2)} ${p.currencyCode}'),
                backgroundColor: const Color(0xFF27AE60).withValues(alpha: 0.15),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInfoCard(context.l10n.standardInvoiceSellerCardTitle, [
                  context.l10n.sellerCompanyLabel(p.sellerName ?? 'N/A'),
                  context.l10n.sellerTaxIdLabel(p.sellerTaxId ?? 'N/A'),
                  'City Code (UN/LOCODE): ${p.sellerCityCode ?? 'N/A'}',
                  context.l10n.sellerCountryLabel(p.sellerCountryCode ?? 'N/A'),
                  context.l10n.sellerAddressLabel(p.sellerAddress ?? 'N/A'),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(context.l10n.standardInvoiceBuyerCardTitle, [
                  context.l10n.buyerCompanyLabel(p.buyerName ?? 'N/A'),
                  context.l10n.buyerTaxIdLabel(p.buyerTaxId ?? 'N/A'),
                  context.l10n.buyerAcidNumberLabel(p.acidNumber ?? 'N/A'),
                  context.l10n.buyerIncotermAndCurrencyLabel(p.incoterm ?? 'N/A', p.currencyCode),
                  'Origin Port (POL): ${p.originPort ?? 'N/A'}',
                  'Destination Port (POD): ${p.destinationPort ?? 'N/A'}',
                ]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(context.l10n.standardInvoiceExtractedItemsHeader, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildItemsTable(p.items),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<String> lines) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2C3E50))),
          const SizedBox(height: 8),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(l, style: const TextStyle(fontSize: 12)),
              )),
        ],
      ),
    );
  }

  Widget _buildItemsTable(List<StandardInvoiceLineItemModel> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF34495E)),
        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        columns: [
          const DataColumn(label: Text('#')),
          DataColumn(label: Text(context.l10n.colProductCode)),
          DataColumn(label: Text(context.l10n.colHsCode)),
          DataColumn(label: Text(context.l10n.colDescription)),
          DataColumn(label: Text(context.l10n.colQuantity)),
          DataColumn(label: Text(context.l10n.colUnit)),
          DataColumn(label: Text(context.l10n.colUnitPrice)),
          DataColumn(label: Text(context.l10n.colTotalAmount)),
          DataColumn(label: Text(context.l10n.colGrossWeight)),
          DataColumn(label: Text(context.l10n.fieldNetWeight)),
          DataColumn(label: Text(context.l10n.weightUnitFieldLabel)),
        ],
        rows: items.map((item) {
          final rowSummary = '${item.index}. ${item.productCode ?? ""} | ${item.hsCode} | ${item.description} | ${item.quantity} ${item.qtyUnit} @ ${item.unitPrice.toStringAsFixed(2)} = ${item.totalAmount.toStringAsFixed(2)} | Gross: ${item.grossWeightKg} | Net: ${item.netWeightKg} ${item.weightUnit}';
          return DataRow(
            cells: [
              DataCell(CopyableTableCell(value: '${item.index}', rowSummary: rowSummary, child: Text('${item.index}'))),
              DataCell(CopyableTableCell(value: item.productCode ?? '—', rowSummary: rowSummary, child: Text(item.productCode ?? '—'))),
              DataCell(CopyableTableCell(value: item.hsCode, rowSummary: rowSummary, child: LtrText(item.hsCode, style: const TextStyle(fontWeight: FontWeight.bold)))),
              DataCell(CopyableTableCell(value: item.description, rowSummary: rowSummary, child: Text(item.description))),
              DataCell(CopyableTableCell(value: '${item.quantity}', rowSummary: rowSummary, child: Text('${item.quantity}'))),
              DataCell(CopyableTableCell(value: item.qtyUnit, rowSummary: rowSummary, child: Text(item.qtyUnit))),
              DataCell(CopyableTableCell(value: item.unitPrice.toStringAsFixed(2), rowSummary: rowSummary, child: Text(item.unitPrice.toStringAsFixed(2)))),
              DataCell(CopyableTableCell(value: item.totalAmount.toStringAsFixed(2), rowSummary: rowSummary, child: Text(item.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27AE60))))),
              DataCell(CopyableTableCell(value: '${item.grossWeightKg}', rowSummary: rowSummary, child: Text('${item.grossWeightKg}'))),
              DataCell(CopyableTableCell(value: '${item.netWeightKg}', rowSummary: rowSummary, child: Text('${item.netWeightKg}'))),
              DataCell(CopyableTableCell(value: item.weightUnit, rowSummary: rowSummary, child: Text(item.weightUnit))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComparisonMatrixTab() {
    if (_comparisonResult == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(Icons.compare_arrows, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(context.l10n.standardInvoiceNoComparisonData, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(context.l10n.standardInvoiceNoComparisonDataSub, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    final c = _comparisonResult!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComparisonStatsBanner(c),
          const SizedBox(height: 20),
          Text(context.l10n.standardInvoiceCompHeadersSection, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildComparisonTable(c.headerComparisons),
          const SizedBox(height: 20),
          Text(context.l10n.standardInvoiceCompFinancialsSection, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildComparisonTable(c.financialComparisons),
          const SizedBox(height: 20),
          Text(context.l10n.standardInvoiceCompItemsSection, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildLineItemsComparisonTable(c.lineItemComparisons),
          if (c.hasDiscrepancies) ...[
            const SizedBox(height: 24),
            _buildRectificationNoticeSection(c),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonStatsBanner(StandardInvoiceComparisonResponseModel c) {
    Color bg = const Color(0xFFE8F8F5);
    Color border = const Color(0xFF27AE60);
    IconData icon = Icons.check_circle;
    String title = context.l10n.standardInvoiceMatch100Banner;

    if (c.hasCriticalMismatch) {
      bg = const Color(0xFFFDEDEC);
      border = const Color(0xFFC0392B);
      icon = Icons.cancel;
      title = context.l10n.standardInvoiceCriticalMismatchBanner(c.criticalMismatchesCount);
    } else if (c.hasDiscrepancies) {
      bg = const Color(0xFFFEF9E7);
      border = const Color(0xFFF39C12);
      icon = Icons.warning;
      title = context.l10n.standardInvoiceDiscrepanciesBanner(c.totalDiscrepanciesCount);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: border, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: border)),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(List<StandardInvoiceComparisonRowModel> rows) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF2C3E50)),
        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        columns: [
          DataColumn(label: Text(context.l10n.standardInvoiceColComparedField)),
          DataColumn(label: Text(context.l10n.standardInvoiceColSystemValue)),
          DataColumn(label: Text(context.l10n.standardInvoiceColSupplierValue)),
          DataColumn(label: Text(context.l10n.standardInvoiceColMatchStatus)),
          DataColumn(label: Text(context.l10n.standardInvoiceColDiffAndNotes)),
        ],
        rows: rows.map((r) {
          final label = isAr ? r.fieldLabelAr : r.fieldLabelEn;
          final rowSummary = '$label | System: ${r.systemValue ?? "—"} | Supplier: ${r.supplierValue ?? "—"} | Status: ${r.status} | Diff: ${r.difference ?? r.notes ?? "—"}';
          return DataRow(
            cells: [
              DataCell(CopyableTableCell(value: label, rowSummary: rowSummary, child: Text(label))),
              DataCell(CopyableTableCell(value: r.systemValue ?? '—', rowSummary: rowSummary, child: Text(r.systemValue ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)))),
              DataCell(CopyableTableCell(value: r.supplierValue ?? '—', rowSummary: rowSummary, child: Text(r.supplierValue ?? '—'))),
              DataCell(_buildStatusBadge(r.status)),
              DataCell(CopyableTableCell(
                value: r.difference ?? r.notes ?? '—',
                rowSummary: rowSummary,
                child: Text(
                  r.difference ?? r.notes ?? '—',
                  style: TextStyle(color: r.status == 'MATCH' ? Colors.grey : Colors.red),
                ),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineItemsComparisonTable(List<StandardInvoiceLineComparisonRowModel> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF2C3E50)),
        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        columns: [
          const DataColumn(label: Text('#')),
          DataColumn(label: Text(context.l10n.colProductCode)),
          DataColumn(label: Text(context.l10n.standardInvoiceColHsSystem)),
          DataColumn(label: Text(context.l10n.standardInvoiceColHsSupplier)),
          DataColumn(label: Text(context.l10n.standardInvoiceColQtySystem)),
          DataColumn(label: Text(context.l10n.standardInvoiceColQtySupplier)),
          DataColumn(label: Text(context.l10n.standardInvoiceColPriceSystem)),
          DataColumn(label: Text(context.l10n.standardInvoiceColPriceSupplier)),
          DataColumn(label: Text(context.l10n.standardInvoiceColMatchStatus)),
          DataColumn(label: Text(context.l10n.standardInvoiceColDiffAndNotes)),
        ],
        rows: rows.map((r) {
          final rowSummary = '${r.index}. ${r.productCode} | HS Sys: ${r.hsCodeSystem ?? "—"} / Supp: ${r.hsCodeSupplier ?? "—"} | Qty Sys: ${r.qtySystem} / Supp: ${r.qtySupplier} | Price Sys: ${r.unitPriceSystem.toStringAsFixed(2)} / Supp: ${r.unitPriceSupplier.toStringAsFixed(2)} | Status: ${r.status} | Notes: ${r.notes ?? "—"}';
          return DataRow(
            cells: [
              DataCell(CopyableTableCell(value: '${r.index}', rowSummary: rowSummary, child: Text('${r.index}'))),
              DataCell(CopyableTableCell(value: r.productCode, rowSummary: rowSummary, child: Text(r.productCode))),
              DataCell(CopyableTableCell(value: r.hsCodeSystem ?? '—', rowSummary: rowSummary, child: Text(r.hsCodeSystem ?? '—'))),
              DataCell(CopyableTableCell(value: r.hsCodeSupplier ?? '—', rowSummary: rowSummary, child: Text(r.hsCodeSupplier ?? '—'))),
              DataCell(CopyableTableCell(value: '${r.qtySystem}', rowSummary: rowSummary, child: Text('${r.qtySystem}'))),
              DataCell(CopyableTableCell(value: '${r.qtySupplier}', rowSummary: rowSummary, child: Text('${r.qtySupplier}'))),
              DataCell(CopyableTableCell(value: r.unitPriceSystem.toStringAsFixed(2), rowSummary: rowSummary, child: Text(r.unitPriceSystem.toStringAsFixed(2)))),
              DataCell(CopyableTableCell(value: r.unitPriceSupplier.toStringAsFixed(2), rowSummary: rowSummary, child: Text(r.unitPriceSupplier.toStringAsFixed(2)))),
              DataCell(_buildStatusBadge(r.status)),
              DataCell(CopyableTableCell(value: r.notes ?? '—', rowSummary: rowSummary, child: Text(r.notes ?? '—'))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRectificationNoticeSection(StandardInvoiceComparisonResponseModel c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.standardInvoiceRectificationSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          if (c.rectificationNoticeEn != null)
            ListTile(
              title: Text(context.l10n.standardInvoiceRectificationEnTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(c.rectificationNoticeEn!, maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: ElevatedButton.icon(
                onPressed: () => _copyToClipboard(c.rectificationNoticeEn!, context.l10n.standardInvoiceRectificationEnTitle),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(context.l10n.copy),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3498DB), foregroundColor: Colors.white),
              ),
            ),
          const Divider(),
          if (c.rectificationNoticeAr != null)
            ListTile(
              title: Text(context.l10n.standardInvoiceRectificationArTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(c.rectificationNoticeAr!, maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: ElevatedButton.icon(
                onPressed: () => _copyToClipboard(c.rectificationNoticeAr!, context.l10n.standardInvoiceRectificationArTitle),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(context.l10n.copy),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApprovalAndGovernanceTab() {
    final hasIssues = (_comparisonResult?.hasDiscrepancies ?? false) || (_comparisonResult?.hasCriticalMismatch ?? false);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.standardInvoiceGovernanceTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusRadio('DRAFT', context.l10n.standardInvoiceStatusDraft, Colors.grey),
              const SizedBox(width: 12),
              _buildStatusRadio('UNDER_REVIEW', context.l10n.standardInvoiceStatusUnderReview, const Color(0xFFF39C12)),
              const SizedBox(width: 12),
              _buildStatusRadio('APPROVED', context.l10n.standardInvoiceStatusApproved, const Color(0xFF27AE60)),
              const SizedBox(width: 12),
              _buildStatusRadio('REJECTED_NEEDS_MODIFICATION', context.l10n.standardInvoiceStatusRejected, const Color(0xFFC0392B)),
            ],
          ),
          const SizedBox(height: 20),
          if (_selectedStatus == 'APPROVED' && hasIssues) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFFDEDEC), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.standardInvoiceOverrideWarningBanner,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            TextFormField(
              controller: _overrideReasonController,
              decoration: InputDecoration(
                labelText: context.l10n.standardInvoiceOverrideReasonLabel,
                hintText: context.l10n.standardInvoiceOverrideReasonHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.gavel, color: Colors.red),
              ),
              maxLines: 3,
              validator: (v) {
                if (_selectedStatus == 'APPROVED' && hasIssues && (v == null || v.trim().isEmpty)) {
                  return context.l10n.standardInvoiceOverrideRequiredError;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: context.l10n.standardInvoiceInternalNotesLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note_alt),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _handleSaveSession(isDraft: true),
                  icon: const Icon(Icons.save_outlined, size: 18, color: AppTheme.cobalt),
                  label: const Text(
                    'حفظ مؤقت للجلسة (Save Draft)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.cobalt),
                    foregroundColor: AppTheme.cobalt,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _handleSaveSession(isDraft: false),
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(context.l10n.standardInvoiceSaveSessionBtn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRadio(String value, String label, Color color) {
    final isSelected = _selectedStatus == value;
    return InkWell(
      onTap: () => setState(() => _selectedStatus = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedStatus,
              onChanged: (v) => setState(() => _selectedStatus = v!),
              activeColor: color,
            ),
            Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? color : Colors.black87, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsRegistryTab(AsyncValue<List<StandardInvoiceSessionModel>> sessionsAsync) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.standardInvoiceRegistrySearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => ref.read(standardInvoiceSessionsProvider.notifier).fetchSessions(search: v, status: _filterStatus),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _filterStatus,
                items: [
                  DropdownMenuItem(value: 'All', child: Text(context.l10n.standardInvoiceFilterAll)),
                  DropdownMenuItem(value: 'APPROVED', child: Text(context.l10n.standardInvoiceStatusApproved)),
                  DropdownMenuItem(value: 'UNDER_REVIEW', child: Text(context.l10n.standardInvoiceStatusUnderReview)),
                  DropdownMenuItem(value: 'REJECTED_NEEDS_MODIFICATION', child: Text(context.l10n.standardInvoiceStatusRejected)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _filterStatus = v);
                    ref.read(standardInvoiceSessionsProvider.notifier).fetchSessions(search: _searchController.text, status: v);
                  }
                },
              ),
              const SizedBox(width: 12),
              // 4 Linked Output Export Actions
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.table_view_outlined, size: 16, color: AppTheme.cobalt),
                label: Text(context.l10n.standardInvoiceSessionsExportTsvBtn, style: const TextStyle(fontSize: 11.5, color: AppTheme.cobalt)),
                onPressed: () async {
                  final sessions = sessionsAsync.valueOrNull ?? [];
                  if (sessions.isEmpty) return;
                  await CargoXExportService.saveSessionsTsvToFile(context: context, sessions: sessions, shipments: importFiles);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.cargoxCopiedTsvSuccess)),
                  );
                },
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.file_present_outlined, size: 16, color: AppTheme.emerald),
                label: Text(context.l10n.standardInvoiceSessionsExportExcelBtn, style: const TextStyle(fontSize: 11.5, color: AppTheme.emerald)),
                onPressed: () async {
                  final sessions = sessionsAsync.valueOrNull ?? [];
                  if (sessions.isEmpty) return;
                  await CargoXExportService.saveSessionsCsvToFile(context: context, sessions: sessions, shipments: importFiles);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.cargoxCopiedExcelSuccess)),
                  );
                },
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.purple),
                label: Text(context.l10n.standardInvoiceSessionsPrintPdfBtn, style: const TextStyle(fontSize: 11.5, color: Colors.purple)),
                onPressed: () async {
                  final sessions = sessionsAsync.valueOrNull ?? [];
                  if (sessions.isEmpty) return;
                  await CargoXExportService.printOrSaveSessionsPdf(context: context, sessions: sessions, shipments: importFiles);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.cargoxExportPdfDialogTitle)),
                  );
                },
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.copy_all_outlined, size: 16, color: AppTheme.charcoal),
                label: Text(context.l10n.standardInvoiceSessionsCopyDossierBtn, style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal)),
                onPressed: () {
                  final sessions = sessionsAsync.valueOrNull ?? [];
                  if (sessions.isEmpty) return;
                  CargoXExportService.copySessionsDossier(context: context, sessions: sessions, shipments: importFiles);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          sessionsAsync.when(
            data: (sessions) {
              if (sessions.isEmpty) {
                return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(context.l10n.standardInvoiceNoSessionsFound)));
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF2C3E50)),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  columns: [
                    DataColumn(label: Text(context.l10n.standardInvoiceColSessionCode)),
                    DataColumn(label: Text(context.l10n.standardInvoiceColFileCode)),
                    DataColumn(label: Text(context.l10n.standardInvoiceColAcid)),
                    DataColumn(label: Text(context.l10n.standardInvoiceColInvoiceNum)),
                    DataColumn(label: Text(context.l10n.standardInvoiceColSupplier)),
                    DataColumn(label: Text(context.l10n.standardInvoiceColTotal)),
                    DataColumn(label: Text(context.l10n.standardInvoiceColItemsCount)),
                    DataColumn(label: Text(context.l10n.standardInvoiceColStatus)),
                    DataColumn(label: Text(context.l10n.standardInvoiceColUpdatedAt)),
                  ],
                  rows: sessions.map((s) {
                    final resolvedTitle = DisplayNameResolver.resolveShipmentTitleByCode(
                      s.importFileCode,
                      shipments: importFiles,
                      isArabic: isAr,
                    );
                    final rowSummary = '${s.sessionCode} | File: $resolvedTitle (${s.importFileCode}) | ACID: ${s.acidNumber ?? "—"} | Inv: ${s.invoiceNumber ?? "—"} | Supp: ${s.exporterName ?? "—"} | Total: ${s.totalAmount.toStringAsFixed(2)} ${s.currencyCode} | Items: ${s.lineItemsCount} | Status: ${s.status} | Updated: ${_formatDateTime(s.updatedAt)}';
                    return DataRow(
                      cells: [
                        DataCell(CopyableTableCell(value: s.sessionCode, rowSummary: rowSummary, child: Text(s.sessionCode, style: const TextStyle(fontWeight: FontWeight.bold)))),
                        DataCell(
                          CopyableTableCell(
                            value: resolvedTitle.isNotEmpty ? '$resolvedTitle (${s.importFileCode})' : s.importFileCode,
                            rowSummary: rowSummary,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (resolvedTitle.isNotEmpty && resolvedTitle != s.importFileCode)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      resolvedTitle,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.charcoal),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: LtrText(
                                        s.importFileCode,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => CopyHelper.copy(
                                        context,
                                        s.importFileCode,
                                        customMessage: '${context.l10n.standardInvoiceColFileCode}: ${s.importFileCode}',
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2.0),
                                        child: Icon(Icons.copy_rounded, size: 10, color: AppTheme.cobalt),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(CopyableTableCell(value: s.acidNumber ?? '—', rowSummary: rowSummary, child: Text(s.acidNumber ?? '—'))),
                        DataCell(CopyableTableCell(value: s.invoiceNumber ?? '—', rowSummary: rowSummary, child: Text(s.invoiceNumber ?? '—'))),
                        DataCell(CopyableTableCell(value: s.exporterName ?? '—', rowSummary: rowSummary, child: Text(s.exporterName ?? '—'))),
                        DataCell(CopyableTableCell(value: '${s.totalAmount.toStringAsFixed(2)} ${s.currencyCode}', rowSummary: rowSummary, child: Text('${s.totalAmount.toStringAsFixed(2)} ${s.currencyCode}', style: const TextStyle(color: Color(0xFF27AE60), fontWeight: FontWeight.bold)))),
                        DataCell(CopyableTableCell(value: '${s.lineItemsCount}', rowSummary: rowSummary, child: Text('${s.lineItemsCount}'))),
                        DataCell(_buildStatusBadge(s.status)),
                        DataCell(CopyableTableCell(value: _formatDateTime(s.updatedAt), rowSummary: rowSummary, child: Text(_formatDateTime(s.updatedAt)))),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('${context.l10n.errorPrefix}: $e', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    String label = status;

    switch (status) {
      case 'APPROVED':
      case 'MATCH':
        color = const Color(0xFF27AE60);
        label = status == 'MATCH' ? 'مطابق' : 'معتمد';
        break;
      case 'WARNING':
      case 'UNDER_REVIEW':
        color = const Color(0xFFF39C12);
        label = status == 'WARNING' ? 'فرق طفيف' : 'قيد المراجعة';
        break;
      case 'CRITICAL_MISMATCH':
      case 'REJECTED_NEEDS_MODIFICATION':
        color = const Color(0xFFC0392B);
        label = status == 'CRITICAL_MISMATCH' ? 'فرق حرج' : 'مرفوض للتعديل';
        break;
      case 'DRAFT':
        color = Colors.blueGrey;
        label = 'مسودة';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
