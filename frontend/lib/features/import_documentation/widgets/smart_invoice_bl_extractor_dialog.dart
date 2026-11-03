import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../cargo_shipping/providers/cargo_shipping_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../providers/import_documentation_provider.dart'
    show invalidateImportDocDependentsW;
import 'smart_extractor/smart_extractor_bl_card.dart';
import 'smart_extractor/smart_extractor_header.dart';
import 'smart_extractor/smart_extractor_invoice_card.dart';
import 'smart_extractor/smart_extractor_match_table.dart';
import 'smart_extractor/smart_extractor_service.dart';

/// Intelligent Commercial Invoice & Bill of Lading Extractor Dialog.
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

  // Tab 1: Commercial Invoice
  final TextEditingController _invoiceTextCtrl = TextEditingController();
  PlatformFile? _pickedInvoiceFile;
  bool _isExtractingInvoice = false;
  bool _isApplyingInvoice = false;
  Map<String, dynamic>? _extractedInvoice;
  List<dynamic> _invoiceItems = [];
  int? _selectedImportFileId;

  // Tab 2: Bill of Lading
  final TextEditingController _blTextCtrl = TextEditingController();
  PlatformFile? _pickedBLFile;
  bool _isExtractingBL = false;
  bool _isApplyingBL = false;
  Map<String, dynamic>? _extractedBL;
  List<dynamic> _blContainers = [];

  // Tab 3: Cross-Audit Radar
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

  Future<void> _pickFile({required bool isInvoice}) async {
    final l = context.l10n;
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'docx', 'doc', 'txt'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          final file = FilePickerHelper.withBytes(res.files.first);
          if (isInvoice) {
            _pickedInvoiceFile = file;
          } else {
            _pickedBLFile = file;
          }
        });
      }
    } catch (e) {
      if (mounted) _showSnackBar(l.smartExtractorPickFileError(e), isError: true);
    }
  }

  Future<void> _extractInvoice() async {
    final l = context.l10n;
    final text = _invoiceTextCtrl.text.trim();
    if (text.isEmpty && _pickedInvoiceFile == null) {
      _showSnackBar(l.smartExtractorRequireInvoiceInput, isError: true);
      return;
    }
    setState(() => _isExtractingInvoice = true);
    try {
      final data = await SmartExtractorService.extractCommercialInvoice(
        uploadDio: _uploadDio,
        file: _pickedInvoiceFile,
        rawText: text,
      );
      if (data != null && mounted) {
        setState(() {
          _extractedInvoice = data['extracted_fields'] as Map<String, dynamic>?;
          _invoiceItems = (data['items'] as List<dynamic>?) ?? [];
        });
        _showSnackBar(l.smartExtractorInvoiceExtractedSuccess);
      }
    } catch (e) {
      _showError(e, l.smartExtractorExtractInvoiceError);
    } finally {
      if (mounted) setState(() => _isExtractingInvoice = false);
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
      final data = await SmartExtractorService.extractBillOfLading(
        uploadDio: _uploadDio,
        file: _pickedBLFile,
        rawText: text,
      );
      if (data != null && mounted) {
        setState(() {
          _extractedBL = data['extracted_fields'] as Map<String, dynamic>?;
          _blContainers = (data['containers'] as List<dynamic>?) ?? [];
        });
        _showSnackBar(l.smartExtractorBlExtractedSuccess);
      }
    } catch (e) {
      _showError(e, l.smartExtractorExtractBlError);
    } finally {
      if (mounted) setState(() => _isExtractingBL = false);
    }
  }

  Future<void> _runCrossAudit() async {
    final l = context.l10n;
    if (_extractedInvoice == null || _extractedBL == null) {
      _showSnackBar(l.smartExtractorRequireBothDocsForAudit, isError: true);
      return;
    }
    setState(() => _isAuditing = true);
    try {
      final data = await SmartExtractorService.crossCheckInvoiceVsBL(
        dio: _dio,
        invoiceData: _extractedInvoice!,
        blData: _extractedBL!,
      );
      if (data != null && mounted) {
        setState(() => _auditResult = data);
        _showSnackBar(l.smartExtractorAuditSuccess);
      }
    } catch (e) {
      _showError(e, l.smartExtractorAuditError);
    } finally {
      if (mounted) setState(() => _isAuditing = false);
    }
  }

  Future<void> _applyInvoiceToImportFile() async {
    final l = context.l10n;
    if (_extractedInvoice == null) return;
    if (_selectedImportFileId == null) {
      _showSnackBar(l.smartExtractorSelectFileWarning, isError: true);
      return;
    }
    setState(() => _isApplyingInvoice = true);
    try {
      final ok = await SmartExtractorService.applyCommercialInvoice(
        dio: _dio,
        importFileId: _selectedImportFileId!,
        invoiceData: _extractedInvoice!,
      );
      if (ok && mounted) {
        ref.invalidate(importFilesProvider);
        ref.invalidate(purchaseOrdersProvider);
        invalidateImportDocDependentsW(ref);
        _showSnackBar(l.smartExtractorInvoiceAppliedSuccess);
      }
    } catch (e) {
      _showError(e, l.smartExtractorApplyInvoiceError);
    } finally {
      if (mounted) setState(() => _isApplyingInvoice = false);
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
      final res = await SmartExtractorService.applyBillOfLading(
        dio: _dio,
        importFileId: _selectedImportFileId!,
        blData: _extractedBL!,
      );
      if (res['applied'] == true && mounted) {
        ref.invalidate(importFilesProvider);
        ref.invalidate(cargoShippingProvider);
        invalidateImportDocDependentsW(ref);
        _showSnackBar(l.smartExtractorBlAppliedSuccess);
      } else if (mounted) {
        final msg = res['message']?.toString() ?? '';
        _showSnackBar(
          l.smartExtractorApplyBlError(msg.isNotEmpty ? msg : l.idocABlNotApplied),
          isError: true,
        );
      }
    } catch (e) {
      _showError(e, l.smartExtractorApplyBlError);
    } finally {
      if (mounted) setState(() => _isApplyingBL = false);
    }
  }

  void _showError(dynamic e, String Function(dynamic) errBuilder) {
    if (mounted) {
      _showSnackBar(errBuilder(ApiErrorText.of(context.l10n, e)), isError: true);
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
              SmartExtractorHeader(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: 16),
              SmartExtractorTabBar(controller: _tabController),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SmartExtractorInvoiceCard(
                      textController: _invoiceTextCtrl,
                      pickedFile: _pickedInvoiceFile,
                      onPickFile: () => _pickFile(isInvoice: true),
                      onClearFile: () => setState(() => _pickedInvoiceFile = null),
                      onExtract: _extractInvoice,
                      isExtracting: _isExtractingInvoice,
                      extractedInvoice: _extractedInvoice,
                      invoiceItems: _invoiceItems,
                      selectedImportFileId: _selectedImportFileId,
                      onFileChanged: (val) => setState(() => _selectedImportFileId = val),
                      onApply: _applyInvoiceToImportFile,
                      isApplying: _isApplyingInvoice,
                    ),
                    SmartExtractorBLCard(
                      textController: _blTextCtrl,
                      pickedFile: _pickedBLFile,
                      onPickFile: () => _pickFile(isInvoice: false),
                      onClearFile: () => setState(() => _pickedBLFile = null),
                      onExtract: _extractBL,
                      isExtracting: _isExtractingBL,
                      extractedBL: _extractedBL,
                      blContainers: _blContainers,
                      onApply: _applyBLToShipping,
                      isApplying: _isApplyingBL,
                    ),
                    SmartExtractorMatchTable(
                      isAuditing: _isAuditing,
                      onRunAudit: _runCrossAudit,
                      auditResult: _auditResult,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
