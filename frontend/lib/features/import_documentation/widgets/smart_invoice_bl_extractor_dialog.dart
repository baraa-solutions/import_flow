import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/helpers/file_picker_helper.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';

class SmartInvoiceBLExtractorDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final int initialTabIndex;

  const SmartInvoiceBLExtractorDialog({
    super.key,
    this.initialImportFileId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<SmartInvoiceBLExtractorDialog> createState() =>
      _SmartInvoiceBLExtractorDialogState();
}

class _SmartInvoiceBLExtractorDialogState
    extends ConsumerState<SmartInvoiceBLExtractorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Dio _dio = ref.read(dioProvider);
  late final Dio _uploadDio = ref.read(uploadDioProvider);

  // Tab 1: Invoice state
  final TextEditingController _invoiceTextCtrl = TextEditingController();
  PlatformFile? _pickedInvoiceFile;
  bool _isExtractingInvoice = false;
  bool _isApplyingInvoice = false;
  Map<String, dynamic>? _extractedInvoice;
  List<dynamic> _invoiceItems = [];
  int? _selectedImportFileId;

  // Tab 2: B/L state
  final TextEditingController _blTextCtrl = TextEditingController();
  PlatformFile? _pickedBLFile;
  bool _isExtractingBL = false;
  bool _isApplyingBL = false;
  Map<String, dynamic>? _extractedBL;
  List<dynamic> _blContainers = [];

  // Tab 3: Cross-Check state
  bool _isAuditing = false;
  Map<String, dynamic>? _auditResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _selectedImportFileId = widget.initialImportFileId;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoiceTextCtrl.dispose();
    _blTextCtrl.dispose();
    super.dispose();
  }

  // ─── Pick Files ────────────────────────────────────────────────────────────

  Future<void> _pickInvoiceFile() async {
    final l = context.l10n;
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'docx', 'doc', 'txt'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _pickedInvoiceFile = FilePickerHelper.withBytes(res.files.first);
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l.smartExtractorPickFileError(e), isError: true);
      }
    }
  }

  Future<void> _pickBLFile() async {
    final l = context.l10n;
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'docx', 'doc', 'txt'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _pickedBLFile = FilePickerHelper.withBytes(res.files.first);
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l.smartExtractorPickFileError(e), isError: true);
      }
    }
  }

  // ─── Extract Actions ───────────────────────────────────────────────────────

  Future<void> _extractInvoice() async {
    final l = context.l10n;
    final text = _invoiceTextCtrl.text.trim();
    if (text.isEmpty && _pickedInvoiceFile == null) {
      _showSnackBar(l.smartExtractorRequireInvoiceInput, isError: true);
      return;
    }

    setState(() => _isExtractingInvoice = true);
    try {
      final url = '${ApiConstants.smartDocumentUpload}/extract/commercial-invoice';
      Response resp;
      if (_pickedInvoiceFile != null && _pickedInvoiceFile!.bytes != null) {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            _pickedInvoiceFile!.bytes!,
            filename: _pickedInvoiceFile!.name,
          ),
          if (text.isNotEmpty) 'raw_text': text,
        });
        resp = await _uploadDio.post(url, data: formData);
      } else {
        final formData = FormData.fromMap({'raw_text': text});
        resp = await _uploadDio.post(url, data: formData);
      }

      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _extractedInvoice = data['extracted_fields'] as Map<String, dynamic>?;
          _invoiceItems = (data['items'] as List<dynamic>?) ?? [];
        });
        if (mounted) {
          _showSnackBar(l.smartExtractorInvoiceExtractedSuccess);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l.smartExtractorExtractInvoiceError(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExtractingInvoice = false);
      }
    }
  }

  Future<void> _extractBL() async {
    final l = context.l10n;
    final text = _blTextCtrl.text.trim();
    if (text.isEmpty && _pickedBLFile == null) {
      _showSnackBar(l.smartExtractorRequireBlInput, isError: true);
      return;
    }

    setState(() => _isExtractingBL = true);
    try {
      final url = '${ApiConstants.smartDocumentUpload}/extract/bill-of-lading';
      Response resp;
      if (_pickedBLFile != null && _pickedBLFile!.bytes != null) {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            _pickedBLFile!.bytes!,
            filename: _pickedBLFile!.name,
          ),
          if (text.isNotEmpty) 'raw_text': text,
        });
        resp = await _uploadDio.post(url, data: formData);
      } else {
        final formData = FormData.fromMap({'raw_text': text});
        resp = await _uploadDio.post(url, data: formData);
      }

      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _extractedBL = data['extracted_fields'] as Map<String, dynamic>?;
          _blContainers = (data['containers'] as List<dynamic>?) ?? [];
        });
        if (mounted) {
          _showSnackBar(l.smartExtractorBlExtractedSuccess);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l.smartExtractorExtractBlError(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExtractingBL = false);
      }
    }
  }

  // ─── Cross-Audit ───────────────────────────────────────────────────────────

  Future<void> _runCrossAudit() async {
    final l = context.l10n;
    if (_extractedInvoice == null || _extractedBL == null) {
      _showSnackBar(l.smartExtractorRequireBothDocsForAudit, isError: true);
      return;
    }

    setState(() => _isAuditing = true);
    try {
      final url = '${ApiConstants.smartDocumentUpload}/cross-check/invoice-vs-bl';
      final payload = {
        'invoice_data': _extractedInvoice,
        'bl_data': _extractedBL,
        'weight_tolerance_pct': 3.0,
      };
      final resp = await _dio.post(url, data: payload);
      if (resp.statusCode == 200 && resp.data != null) {
        setState(() {
          _auditResult = resp.data as Map<String, dynamic>;
        });
        if (mounted) {
          _showSnackBar(l.smartExtractorAuditSuccess);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l.smartExtractorAuditError(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isAuditing = false);
      }
    }
  }

  // ─── Apply Services ────────────────────────────────────────────────────────

  Future<void> _applyInvoiceToImportFile() async {
    final l = context.l10n;
    if (_extractedInvoice == null) return;
    if (_selectedImportFileId == null) {
      _showSnackBar(l.smartExtractorSelectFileWarning, isError: true);
      return;
    }

    setState(() => _isApplyingInvoice = true);
    try {
      final url = '${ApiConstants.smartDocumentUpload}/apply/commercial-invoice';
      final resp = await _dio.post(url, data: {
        'import_file_id': _selectedImportFileId,
        'invoice_data': _extractedInvoice,
      });
      if (resp.statusCode == 200) {
        ref.invalidate(importFilesProvider);
        if (mounted) {
          _showSnackBar(l.smartExtractorInvoiceAppliedSuccess);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l.smartExtractorApplyInvoiceError(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isApplyingInvoice = false);
      }
    }
  }

  Future<void> _applyBLToShipping() async {
    final l = context.l10n;
    if (_extractedBL == null) return;
    if (_selectedImportFileId == null) {
      _showSnackBar(l.smartExtractorSelectFileWarning, isError: true);
      return;
    }

    setState(() => _isApplyingBL = true);
    try {
      final url = '${ApiConstants.smartDocumentUpload}/apply/bill-of-lading';
      final resp = await _dio.post(url, data: {
        'import_file_id': _selectedImportFileId,
        'bl_data': _extractedBL,
      });
      if (resp.statusCode == 200) {
        ref.invalidate(importFilesProvider);
        if (mounted) {
          _showSnackBar(l.smartExtractorBlAppliedSuccess);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l.smartExtractorApplyBlError(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isApplyingBL = false);
      }
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? AppTheme.crimson : AppTheme.emerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Build UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 1120,
          height: 760,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTabsBar(),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInvoiceTab(),
                    _buildBLTab(),
                    _buildCrossCheckTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l = context.l10n;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.cobaltLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.smartExtractorDialogTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                l.smartExtractorDialogSubtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l.invoiceBlMatcherCloseButton,
        ),
      ],
    );
  }

  Widget _buildTabsBar() {
    final l = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.charcoal,
        indicator: BoxDecoration(
          color: AppTheme.cobalt,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(
            icon: const Icon(Icons.receipt_long_outlined),
            text: l.smartExtractorTabInvoice,
          ),
          Tab(
            icon: const Icon(Icons.directions_boat_outlined),
            text: l.smartExtractorTabBl,
          ),
          Tab(
            icon: const Icon(Icons.rule_folder_outlined),
            text: l.smartExtractorTabAudit,
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: Invoice Extractor ──────────────────────────────────────────────

  Widget _buildInvoiceTab() {
    final l = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputCard(
            title: l.smartExtractorInvoiceCardTitle,
            hint: l.smartExtractorInvoiceCardHint,
            textController: _invoiceTextCtrl,
            pickedFile: _pickedInvoiceFile,
            onPickFile: _pickInvoiceFile,
            onClearFile: () => setState(() => _pickedInvoiceFile = null),
            onExtract: _extractInvoice,
            isLoading: _isExtractingInvoice,
            extractButtonLabel: l.smartExtractorExtractInvoiceButton,
          ),
          const SizedBox(height: 16),
          if (_extractedInvoice != null) ...[
            _buildInvoiceSummaryCards(),
            const SizedBox(height: 16),
            _buildInvoiceItemsTable(),
            const SizedBox(height: 16),
            _buildInvoiceApplySection(),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceSummaryCards() {
    final l = context.l10n;
    final inv = _extractedInvoice ?? {};
    final currency = (inv['currency'] ?? 'USD').toString();
    return Card(
      elevation: 0,
      color: AppTheme.cobaltLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.cobaltBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.smartExtractorExtractedInvoiceTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l.smartExtractorCurrency(currency),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _buildFieldChip(l.smartExtractorFieldInvoiceNo, '${inv['invoice_number'] ?? '-'}'),
                _buildFieldChip(l.smartExtractorFieldInvoiceDate, '${inv['invoice_date'] ?? '-'}'),
                _buildFieldChip(l.smartExtractorFieldAcidNo, '${inv['acid_number'] ?? '-'}', isHighlight: true),
                _buildFieldChip(l.smartExtractorFieldImporterTaxId, '${inv['importer_tax_id'] ?? '-'}'),
                _buildFieldChip(l.smartExtractorFieldSupplier, '${inv['supplier_name'] ?? '-'}'),
                _buildFieldChip(l.smartExtractorFieldImporter, '${inv['importer_name'] ?? '-'}'),
                _buildFieldChip(l.smartExtractorFieldIncoterms, '${inv['incoterms'] ?? '-'}'),
                _buildFieldChip(l.smartExtractorFieldTotalAmount, '${inv['invoice_value'] ?? 0} $currency', isHighlight: true),
                _buildFieldChip(l.smartExtractorFieldTotalGrossWeight, '${inv['total_gross_weight_kg'] ?? '-'} KG'),
                _buildFieldChip(l.smartExtractorFieldPorts, 'POL: ${inv['loading_port'] ?? '-'} | POD: ${inv['discharge_port'] ?? '-'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemsTable() {
    final l = context.l10n;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart_outlined, color: AppTheme.charcoal, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.smartExtractorItemsTableTitle(_invoiceItems.length),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_invoiceItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text(l.smartExtractorNoItemsFound)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columnSpacing: 18,
                    columns: [
                      const DataColumn(label: Text('#')),
                      DataColumn(label: Text(l.smartExtractorColItemDescription)),
                      DataColumn(label: Text(l.smartExtractorColQuantity)),
                      DataColumn(label: Text(l.smartExtractorColUnit)),
                      DataColumn(label: Text(l.smartExtractorColUnitPrice)),
                      DataColumn(label: Text(l.smartExtractorColTotalPrice)),
                    ],
                    rows: List.generate(_invoiceItems.length, (idx) {
                      final itm = _invoiceItems[idx] as Map<String, dynamic>;
                      final idxStr = '${idx + 1}';
                      final desc = '${itm['description'] ?? '-'}';
                      final qty = '${itm['quantity'] ?? 0}';
                      final uom = '${itm['unit_of_measure'] ?? 'PCS'}';
                      final uPrice = '${itm['unit_price'] ?? 0}';
                      final tPrice = '${itm['total_price'] ?? 0}';
                      final rowSummary = '$idxStr\t$desc\t$qty\t$uom\t$uPrice\t$tPrice';

                      return DataRow(cells: [
                        DataCell(
                          CopyableTableCell(
                            value: idxStr,
                            rowSummary: rowSummary,
                            child: Text(idxStr),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: desc,
                            rowSummary: rowSummary,
                            child: SizedBox(
                              width: 250,
                              child: Text(desc, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: qty,
                            rowSummary: rowSummary,
                            child: Text(qty),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: uom,
                            rowSummary: rowSummary,
                            child: Text(uom),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: uPrice,
                            rowSummary: rowSummary,
                            child: Text(uPrice),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: tPrice,
                            rowSummary: rowSummary,
                            child: Text(tPrice, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]);
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceApplySection() {
    final l = context.l10n;
    final importFilesAsync = ref.watch(importFilesProvider);
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.link, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Text(l.smartExtractorApplySectionTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Expanded(
              child: importFilesAsync.when(
                data: (files) {
                  return SearchableDropdownField<int>(
                    labelText: l.smartExtractorSelectFileLabel,
                    hintText: l.smartExtractorSearchFileHint,
                    items: files
                        .map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.companyName}',
                            ))
                        .toList(),
                    value: _selectedImportFileId,
                    onChanged: (val) => setState(() => _selectedImportFileId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(l.smartExtractorFetchFilesError(e)),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isApplyingInvoice ? null : _applyInvoiceToImportFile,
              icon: _isApplyingInvoice
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(l.smartExtractorApplyInvoiceButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: B/L & AWB Extractor ───────────────────────────────────────────

  Widget _buildBLTab() {
    final l = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputCard(
            title: l.smartExtractorBlCardTitle,
            hint: l.smartExtractorBlCardHint,
            textController: _blTextCtrl,
            pickedFile: _pickedBLFile,
            onPickFile: _pickBLFile,
            onClearFile: () => setState(() => _pickedBLFile = null),
            onExtract: _extractBL,
            isLoading: _isExtractingBL,
            extractButtonLabel: l.smartExtractorExtractBlButton,
          ),
          const SizedBox(height: 16),
          if (_extractedBL != null) ...[
            _buildBLSummaryCards(),
            const SizedBox(height: 16),
            _buildBLContainersTable(),
            const SizedBox(height: 16),
            _buildBLApplySection(),
          ],
        ],
      ),
    );
  }

  Widget _buildBLSummaryCards() {
    final l = context.l10n;
    final bl = _extractedBL ?? {};
    final isAir = bl['bl_type'] == 'AIR_WAYBILL';
    return Card(
      elevation: 0,
      color: isAir ? AppTheme.orangeLight : AppTheme.emeraldLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isAir ? AppTheme.orange : AppTheme.emeraldBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isAir ? Icons.airplanemode_active : Icons.directions_boat,
                    color: isAir ? AppTheme.orange : AppTheme.emerald, size: 22),
                const SizedBox(width: 8),
                Text(
                  isAir ? l.smartExtractorAirWaybillTitle : l.smartExtractorOceanBlTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bl['freight_payment_term'] == 'FREIGHT_PREPAID' ? AppTheme.cobalt : AppTheme.orange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bl['freight_payment_term'] == 'FREIGHT_PREPAID' ? l.smartExtractorPaymentPrepaid : l.smartExtractorPaymentCollect,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _buildFieldChip(l.smartExtractorFieldBlNo, '${bl['bl_number'] ?? '-'}', isHighlight: true),
                _buildFieldChip(l.smartExtractorFieldAcidNo, '${bl['acid_number'] ?? '-'}', isHighlight: true),
                _buildFieldChip(l.smartExtractorFieldCarrier, '${bl['carrier_name'] ?? '-'}'),
                _buildFieldChip(
                  isAir ? l.smartExtractorFieldFlightNo : l.smartExtractorFieldVesselVoyage,
                  isAir ? '${bl['flight_number'] ?? '-'}' : '${bl['vessel_name'] ?? '-'} / ${bl['voyage_number'] ?? '-'}',
                ),
                _buildFieldChip(l.smartExtractorFieldPol, '${bl['loading_port'] ?? '-'}'),
                _buildFieldChip(l.smartExtractorFieldPod, '${bl['discharge_port'] ?? '-'}'),
                _buildFieldChip(l.smartExtractorFieldTotalGrossWeight, '${bl['total_gross_weight_kg'] ?? '-'} KG', isHighlight: true),
                _buildFieldChip(l.smartExtractorFieldTotalCbm, '${bl['total_cbm'] ?? '-'} CBM'),
                _buildFieldChip(l.smartExtractorFieldPackagesCount, '${bl['total_packages_count'] ?? '-'} (${bl['package_type'] ?? 'Pkgs'})'),
                _buildFieldChip(l.smartExtractorFieldShipper, '${bl['shipper'] ?? '-'}'),
                _buildFieldChip(l.smartExtractorFieldConsignee, '${bl['consignee'] ?? '-'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBLContainersTable() {
    final l = context.l10n;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_in_ar_outlined, color: AppTheme.charcoal, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.smartExtractorContainersTableTitle(_blContainers.length),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_blContainers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text(l.smartExtractorNoContainersFound)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columnSpacing: 24,
                    columns: [
                      const DataColumn(label: Text('#')),
                      DataColumn(label: Text(l.smartExtractorColContainerNo)),
                      DataColumn(label: Text(l.smartExtractorColSealNo)),
                      DataColumn(label: Text(l.smartExtractorColContainerType)),
                      DataColumn(label: Text(l.smartExtractorColGrossWeightKg)),
                    ],
                    rows: List.generate(_blContainers.length, (idx) {
                      final c = _blContainers[idx] as Map<String, dynamic>;
                      final idxStr = '${idx + 1}';
                      final cNo = '${c['container_no'] ?? '-'}';
                      final sealNo = '${c['seal_no'] ?? '-'}';
                      final cType = '${c['container_type'] ?? '40HC'}';
                      final gw = '${c['gross_weight_kg'] ?? '-'}';
                      final rowSummary = '$idxStr\t$cNo\t$sealNo\t$cType\t$gw';

                      return DataRow(cells: [
                        DataCell(
                          CopyableTableCell(
                            value: idxStr,
                            rowSummary: rowSummary,
                            child: Text(idxStr),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: cNo,
                            rowSummary: rowSummary,
                            child: Text(cNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: sealNo,
                            rowSummary: rowSummary,
                            child: Text(sealNo),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: cType,
                            rowSummary: rowSummary,
                            child: Text(cType),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: gw,
                            rowSummary: rowSummary,
                            child: Text(gw),
                          ),
                        ),
                      ]);
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBLApplySection() {
    final l = context.l10n;
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.directions_boat, color: AppTheme.emerald),
            const SizedBox(width: 8),
            Text(l.smartExtractorApplyBlSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isApplyingBL ? null : _applyBLToShipping,
              icon: _isApplyingBL
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_alt),
              label: Text(l.smartExtractorApplyBlButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 3: Cross-Check Audit Radar ────────────────────────────────────────

  Widget _buildCrossCheckTab() {
    final l = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: AppTheme.orangeLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.orange),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.security, color: AppTheme.orange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.smartExtractorAuditCardTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                        ),
                        Text(
                          l.smartExtractorAuditCardSubtitle,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isAuditing ? null : _runCrossAudit,
                    icon: _isAuditing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(l.smartExtractorRunAuditButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_auditResult != null) ...[
            _buildAuditScorecard(),
            const SizedBox(height: 16),
            _buildAuditMatrixTable(),
            const SizedBox(height: 16),
            _buildCorrectionNoticeCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditScorecard() {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final res = _auditResult ?? {};
    final score = (res['compliance_score'] as num?)?.toDouble() ?? 0.0;
    final verdict = res['verdict'] as String? ?? 'COMPLIANT';
    final verdictAr = res['verdict_ar'] as String? ?? '';
    final criticals = (res['critical_errors'] as List<dynamic>?) ?? [];
    final warnings = (res['warnings'] as List<dynamic>?) ?? [];

    Color badgeColor = AppTheme.emerald;
    String verdictDisplay = l.smartExtractorAuditCompliant;
    if (verdict == 'CRITICAL_MISMATCH') {
      badgeColor = AppTheme.crimson;
      verdictDisplay = l.smartExtractorAuditCriticalMismatch;
    } else if (verdict == 'WARNINGS_DETECTED') {
      badgeColor = AppTheme.orange;
      verdictDisplay = l.smartExtractorAuditWarningsDetected;
    }

    if (isArabic && verdictAr.isNotEmpty) {
      verdictDisplay = verdictAr;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.smartExtractorMatchRatio(score),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    verdictDisplay,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: badgeColor),
                  ),
                ),
              ],
            ),
            if (criticals.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.crimsonLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: criticals
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel, color: AppTheme.crimson, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(c.toString(), style: const TextStyle(fontSize: 12, color: AppTheme.crimson))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.orangeLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: warnings
                      .map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(w.toString(), style: const TextStyle(fontSize: 12, color: AppTheme.charcoal))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuditMatrixTable() {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final matrix = ((_auditResult?['audit_matrix']) as List<dynamic>?) ?? [];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.smartExtractorAuditMatrixTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                  columnSpacing: 14,
                  columns: [
                    DataColumn(label: Text(l.smartExtractorColCheckItem)),
                    DataColumn(label: Text(l.smartExtractorColInvoiceValue)),
                    DataColumn(label: Text(l.smartExtractorColBlValue)),
                    DataColumn(label: Text(l.smartExtractorColStatus)),
                    DataColumn(label: Text(l.smartExtractorColDetailsGuidance)),
                  ],
                  rows: matrix.map((m) {
                    final item = m as Map<String, dynamic>;
                    final status = item['status'] ?? 'PASS';
                    Color statusColor = AppTheme.emerald;
                    IconData statusIcon = Icons.check_circle;
                    String statusLabel = l.smartExtractorAuditPass;

                    if (status == 'CRITICAL') {
                      statusColor = AppTheme.crimson;
                      statusIcon = Icons.cancel;
                      statusLabel = l.smartExtractorAuditCritical;
                    } else if (status == 'WARNING') {
                      statusColor = AppTheme.orange;
                      statusIcon = Icons.warning;
                      statusLabel = l.smartExtractorAuditWarning;
                    }

                    final checkTitle = isArabic
                        ? (item['title_ar'] ?? item['title_en'] ?? item['check_code'] ?? '')
                        : (item['title_en'] ?? item['title_ar'] ?? item['check_code'] ?? '');
                    final invVal = '${item['invoice_value'] ?? '-'}';
                    final blVal = '${item['bl_value'] ?? '-'}';
                    final details = isArabic
                        ? '${item['details_ar'] ?? item['details_en'] ?? '-'}'
                        : '${item['details_en'] ?? item['details_ar'] ?? '-'}';

                    final rowSummary = '$checkTitle\t$invVal\t$blVal\t$statusLabel\t$details';

                    return DataRow(cells: [
                      DataCell(
                        CopyableTableCell(
                          value: checkTitle,
                          rowSummary: rowSummary,
                          child: Text(checkTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: invVal,
                          rowSummary: rowSummary,
                          child: Text(invVal),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: blVal,
                          rowSummary: rowSummary,
                          child: Text(blVal),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: statusLabel,
                          rowSummary: rowSummary,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 16),
                              const SizedBox(width: 4),
                              Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: details,
                          rowSummary: rowSummary,
                          child: SizedBox(
                            width: 280,
                            child: Text(details, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectionNoticeCard() {
    final l = context.l10n;
    final noticeEn = (_auditResult?['correction_notice_en'] ?? '').toString();
    final noticeAr = (_auditResult?['correction_notice_ar'] ?? '').toString();

    return Card(
      elevation: 0,
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined, color: AppTheme.charcoal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.smartExtractorNoticeCardTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    l.smartExtractorNoticeCardSubtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                CopyHelper.copy(
                  context,
                  noticeEn,
                  customMessage: l.smartExtractorNoticeEnCopied,
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l.smartExtractorCopyEnglishNoticeButton),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                CopyHelper.copy(
                  context,
                  noticeAr,
                  customMessage: l.smartExtractorNoticeArCopied,
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l.smartExtractorCopyArabicNoticeButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.charcoal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared Components ─────────────────────────────────────────────────────

  Widget _buildInputCard({
    required String title,
    required String hint,
    required TextEditingController textController,
    required PlatformFile? pickedFile,
    required VoidCallback onPickFile,
    required VoidCallback onClearFile,
    required VoidCallback onExtract,
    required bool isLoading,
    required String extractButtonLabel,
  }) {
    final l = context.l10n;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(pickedFile != null ? pickedFile.name : l.smartExtractorPickFileButton),
                ),
                if (pickedFile != null) ...[
                  IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.crimson, size: 20),
                    onPressed: onClearFile,
                  ),
                ],
                ElevatedButton.icon(
                  onPressed: isLoading ? null : onExtract,
                  icon: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(extractButtonLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldChip(String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.amber.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isHighlight ? Colors.amber.shade400 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.0, color: Colors.grey)),
          const SizedBox(height: 2),
          CopyableText(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: AppTheme.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
