import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../import_files/widgets/import_file_form_dialog.dart';
import '../../../core/localization/stored_text.dart';

class SmartCloneShipmentDialog extends ConsumerStatefulWidget {
  final ImportFileModel sourceFile;

  const SmartCloneShipmentDialog({
    super.key,
    required this.sourceFile,
  });

  static Future<void> show(BuildContext context, ImportFileModel sourceFile) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SmartCloneShipmentDialog(sourceFile: sourceFile),
    );
  }

  @override
  ConsumerState<SmartCloneShipmentDialog> createState() => _SmartCloneShipmentDialogState();
}

class _SmartCloneShipmentDialogState extends ConsumerState<SmartCloneShipmentDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _newCodeController;
  late final TextEditingController _newNameController;
  late final TextEditingController _newInvoiceController;
  late final TextEditingController _newFreightCostController;
  late final TextEditingController _notesController;

  bool _copyInvoices = true;
  bool _copyPackingLists = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final src = widget.sourceFile;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _newCodeController = TextEditingController(text: '${src.importFileCode}-C$timestamp');
    _newNameController = TextEditingController();
    _newInvoiceController = TextEditingController();
    _newFreightCostController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final src = widget.sourceFile;
      if (_newNameController.text.isEmpty) {
        _newNameController.text = src.notes != null && src.notes!.isNotEmpty
            ? '${src.notes!.split("\n").first} ${storedText.inqCloneNewShipmentSuffix}'
            : '${src.importFileCode} ${storedText.inqCloneNewShipmentSuffix}';
      }
      if (_notesController.text.isEmpty) {
        _notesController.text = storedText.inqCloneTemplateDefaultNote(src.importFileCode);
      }
    }
  }

  @override
  void dispose() {
    _newCodeController.dispose();
    _newNameController.dispose();
    _newInvoiceController.dispose();
    _newFreightCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleClone({bool openFullForm = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final src = widget.sourceFile;
      final payload = {
        'target_import_file_code': _newCodeController.text.trim(),
        'target_custom_file_number': null,
        'copy_invoices_data': _copyInvoices,
        'copy_packing_lists': _copyPackingLists,
        'copy_attachments': false,
        'notes': _notesController.text.trim(),
      };

      // Call clone API through notifier
      final clonedFile = await ref.read(importFilesProvider.notifier).cloneImportFile(
        src.importFileId,
        payload,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      final l = context.l10n;
      final clonedCode = clonedFile?.importFileCode ?? _newCodeController.text.trim();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.inqCloneSuccessToast(clonedCode),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (openFullForm && mounted && clonedFile != null) {
        showDialog(
          context: context,
          builder: (ctx) => ImportFileFormDialog(fileToEdit: clonedFile),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final src = widget.sourceFile;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.inqCloneDialogTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.charcoal,
                            ),
                          ),
                          Text(
                            l.inqCloneDialogSubtitle(src.importFileCode),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Confirmation & Guidance Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.inqCloneSuccessBanner(src.importFileCode),
                          style: const TextStyle(
                            color: AppTheme.emerald,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.crimson.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                    ),
                  ),
                ],

                // Main Body: 2 Columns (Copied Data Template vs New Input Form)
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Column 1: Copied Data Summary (Template Values)
                        Expanded(
                          flex: 4,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ListView(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lock_outline, size: 16, color: AppTheme.cobalt),
                                    const SizedBox(width: 6),
                                    Text(
                                      l.inqCloneCopiedDataTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.cobalt,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                _buildSummaryTile(context, l.inqSupplier, src.supplierName),
                                _buildSummaryTile(context, l.inqImporter, src.companyName),
                                _buildSummaryTile(context, l.guideHsCode, src.hsCode ?? l.unspecified),
                                _buildSummaryTile(context, l.guideProductCategory, src.productCategory ?? 'عام'),
                                _buildSummaryTile(context, l.inqIncoterm, src.incotermCode),
                                _buildSummaryTile(context, l.inqShippingMode, src.shipmentMode),
                                _buildSummaryTile(
                                  context,
                                  l.inqColRoute,
                                  '${src.portOfLoading ?? l.unspecified} → ${src.portOfDischarge ?? "الإسكندرية"}',
                                ),
                                _buildSummaryTile(
                                  context,
                                  l.inqCarrier,
                                  src.selectedScenario ?? l.unspecified,
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 16),
                                // Options Checkboxes
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(l.inqCloneCopyInvoicesLabel, style: const TextStyle(fontSize: 12)),
                                  value: _copyInvoices,
                                  activeColor: AppTheme.cobalt,
                                  onChanged: (v) => setState(() => _copyInvoices = v ?? true),
                                ),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(l.inqCloneCopyPackingListsLabel, style: const TextStyle(fontSize: 12)),
                                  value: _copyPackingLists,
                                  activeColor: AppTheme.cobalt,
                                  onChanged: (v) => setState(() => _copyPackingLists = v ?? true),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Column 2: Cleared Fields Requiring New Input
                        Expanded(
                          flex: 6,
                          child: ListView(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.edit_outlined, size: 16, color: AppTheme.charcoal),
                                  const SizedBox(width: 6),
                                  Text(
                                    l.inqCloneClearedDataTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),

                              // New Shipment Name
                              TextFormField(
                                controller: _newNameController,
                                decoration: InputDecoration(
                                  labelText: l.inqCloneNewShipmentName,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l.copy,
                                    onPressed: () => CopyHelper.copy(context, _newNameController.text),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return l.inqCloneValidationName;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // New Import File Code
                              TextFormField(
                                controller: _newCodeController,
                                decoration: InputDecoration(
                                  labelText: l.inqCloneNewFileCode,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.qr_code, size: 18),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l.copy,
                                    onPressed: () => CopyHelper.copy(context, _newCodeController.text),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return l.inqCloneValidationCode;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // New Invoice Number
                              TextFormField(
                                controller: _newInvoiceController,
                                decoration: InputDecoration(
                                  labelText: l.inqCloneNewInvoiceNumber,
                                  hintText: l.inqCloneInvoiceHint,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.receipt_outlined, size: 18),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l.copy,
                                    onPressed: () => CopyHelper.copy(context, _newInvoiceController.text),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // New Freight Cost with Last Recorded Cost Hint
                              TextFormField(
                                controller: _newFreightCostController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: l.inqCloneNewFreightCost,
                                  helperText: '${l.inqCloneLastRecordedCost}: ${src.estimatedCost.toStringAsFixed(0)} ${src.estimatedCostCurrency}',
                                  helperStyle: const TextStyle(
                                    color: AppTheme.cobalt,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.monetization_on_outlined, size: 18),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l.copy,
                                    onPressed: () => CopyHelper.copy(context, _newFreightCostController.text),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Notes
                              TextFormField(
                                controller: _notesController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: l.inqCloneNotesLabel,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l.copy,
                                    onPressed: () => CopyHelper.copy(context, _notesController.text),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(l.cancel),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(l.inqCloneOpenFormBtn),
                      onPressed: _isLoading ? null : () => _handleClone(openFullForm: true),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: Text(l.inqCloneConfirmBtn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : () => _handleClone(openFullForm: false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTile(BuildContext context, String label, String value) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
          ),
          InkWell(
            onTap: () => CopyHelper.copy(context, value),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Tooltip(
                message: l.copy,
                child: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
