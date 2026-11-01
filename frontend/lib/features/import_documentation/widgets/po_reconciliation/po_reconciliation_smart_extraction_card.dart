import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../idoc_ui.dart';
import 'po_reconciliation_client_extractor.dart';
import 'po_reconciliation_discrepancy_card.dart';
import 'po_reconciliation_extraction_handler.dart';
import 'po_reconciliation_localizer.dart';
import 'po_reconciliation_service.dart';

/// Card providing AI smart extraction from Commercial Invoice and Packing List text/files,
/// running 3-way reconciliation comparison, and rendering discrepancy results.
class PoReconciliationSmartExtractionCard extends ConsumerStatefulWidget {
  final int? importFileId;
  final String finalInvoiceNumber;
  final List<POReconciliationItemModel> invoiceItems;
  final List<POReconciliationItemModel> packingItems;
  final Map<String, dynamic>? extractedData;
  final ValueChanged<Map<String, dynamic>> onExtracted;
  final VoidCallback onApplyExtractedToTables;
  final DisplayDensityMode density;

  const PoReconciliationSmartExtractionCard({
    super.key,
    required this.importFileId,
    required this.finalInvoiceNumber,
    required this.invoiceItems,
    required this.packingItems,
    required this.extractedData,
    required this.onExtracted,
    required this.onApplyExtractedToTables,
    required this.density,
  });

  @override
  ConsumerState<PoReconciliationSmartExtractionCard> createState() => _PoReconciliationSmartExtractionCardState();
}

class _PoReconciliationSmartExtractionCardState extends ConsumerState<PoReconciliationSmartExtractionCard> {
  bool _showSmartExtractionTool = true;
  bool _isExtracting = false;
  final TextEditingController _invoiceTextCtrl = TextEditingController();
  final TextEditingController _packingTextCtrl = TextEditingController();
  String? _selectedInvoiceFileName;
  String? _selectedPackingFileName;
  Uint8List? _invoiceFileBytes;
  Uint8List? _packingFileBytes;

  @override
  void dispose() {
    _invoiceTextCtrl.dispose();
    _packingTextCtrl.dispose();
    super.dispose();
  }

  void _loadSampleData() {
    setState(() {
      _invoiceTextCtrl.text = PoReconciliationClientExtractor.sampleGIIndustrialInvoice.trim();
      _packingTextCtrl.text = PoReconciliationClientExtractor.sampleGIIndustrialPackingList.trim();
      _selectedInvoiceFileName = 'Commercial_Invoice_V1_2562.pdf';
      _selectedPackingFileName = 'Packing_and_Weight_List_M26_413.pdf';
      _invoiceFileBytes = null;
      _packingFileBytes = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.poRecSampleLoadedSuccess));
  }

  Future<void> _pickFile(bool isInvoice) async {
    final picked = await PoReconciliationExtractionHandler.pickDocumentFile(context);
    if (picked != null) {
      setState(() {
        if (isInvoice) {
          _selectedInvoiceFileName = picked.fileName;
          _invoiceFileBytes = picked.fileBytes;
          _invoiceTextCtrl.text = picked.text;
        } else {
          _selectedPackingFileName = picked.fileName;
          _packingFileBytes = picked.fileBytes;
          _packingTextCtrl.text = picked.text;
        }
      });
    }
  }

  Future<void> _runExtraction() async {
    setState(() => _isExtracting = true);
    final res = await PoReconciliationService.runSmartExtraction(
      context: context,
      ref: ref,
      importFileId: widget.importFileId,
      invText: _invoiceTextCtrl.text.trim(),
      plText: _packingTextCtrl.text.trim(),
      invoiceFileBytes: _invoiceFileBytes,
      packingFileBytes: _packingFileBytes,
      selectedInvoiceFileName: _selectedInvoiceFileName,
      selectedPackingFileName: _selectedPackingFileName,
      invoiceItems: widget.invoiceItems,
      packingItems: widget.packingItems,
      finalInvoiceNumber: widget.finalInvoiceNumber,
    );
    if (mounted) {
      setState(() => _isExtracting = false);
      if (res != null) {
        widget.onExtracted(res);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Card(
      elevation: 3,
      color: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.cobalt.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;
                final titleBlock = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.poRecExtractorTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.poRecExtractorSubtitle,
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (kDebugMode)
                      IdocUi.fit(AppButton(
                        label: l.poRecLoadSampleDemoButton,
                        icon: Icons.dataset_linked,
                        variant: AppButtonVariant.success,
                        size: AppButtonSize.small,
                        onPressed: _loadSampleData,
                      )),
                    IconButton(
                      icon: Icon(
                        _showSmartExtractionTool ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                      tooltip: _showSmartExtractionTool ? l.poRecHideTool : l.poRecShowTool,
                      onPressed: () => setState(() => _showSmartExtractionTool = !_showSmartExtractionTool),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 10),
                      actionButtons,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                );
              },
            ),
            if (_showSmartExtractionTool) ...[
              const Divider(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 750;
                  final invoiceSide = Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      l.poRecExtractorTabInvoice,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.textPrimaryOf(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IdocUi.fit(AppButton(
                              label: _selectedInvoiceFileName != null ? l.poRecChangeFile : l.poRecUploadFile,
                              icon: Icons.upload_file,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              onPressed: () => _pickFile(true),
                            )),
                          ],
                        ),
                        if (_selectedInvoiceFileName != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.severityBackgroundOf(context, AppSeverity.info),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file, size: 14, color: AppTheme.cobalt),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _selectedInvoiceFileName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _invoiceTextCtrl,
                          maxLines: 8,
                          style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.textPrimaryOf(context)),
                          decoration: InputDecoration(
                            hintText: l.poRecPasteInvoiceHint,
                            filled: true,
                            fillColor: AppTheme.surfaceOf(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: AppTheme.borderOf(context)),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  );

                  final packingSide = Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, color: AppTheme.emerald, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      l.poRecExtractorTabPacking,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.textPrimaryOf(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IdocUi.fit(AppButton(
                              label: _selectedPackingFileName != null ? l.poRecChangeFile : l.poRecUploadFile,
                              icon: Icons.upload_file,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              onPressed: () => _pickFile(false),
                            )),
                          ],
                        ),
                        if (_selectedPackingFileName != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.severityBackgroundOf(context, AppSeverity.info),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file, size: 14, color: AppTheme.cobalt),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _selectedPackingFileName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _packingTextCtrl,
                          maxLines: 8,
                          style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.textPrimaryOf(context)),
                          decoration: InputDecoration(
                            hintText: l.poRecPastePackingHint,
                            filled: true,
                            fillColor: AppTheme.surfaceOf(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: AppTheme.borderOf(context)),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        invoiceSide,
                        const SizedBox(height: 12),
                        packingSide,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: invoiceSide),
                      const SizedBox(width: 16),
                      Expanded(child: packingSide),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: IdocUi.fit(AppButton(
                  label: _isExtracting ? l.poRecExtractingProgress : l.poRecExecuteSmartExtractionButton,
                  icon: Icons.compare_arrows_rounded,
                  variant: AppButtonVariant.primary,
                  isLoading: _isExtracting,
                  onPressed: _isExtracting ? null : _runExtraction,
                )),
              ),
            ],
            if (widget.extractedData != null) ...[
              const SizedBox(height: 20),
              PoReconciliationDiscrepancyCard(
                extractedData: widget.extractedData!,
                density: widget.density,
                onApplyExtractedToTables: widget.onApplyExtractedToTables,
                getLocalizedCheckField: PoReconciliationLocalizer.getLocalizedCheckField,
                getLocalizedCheckMessage: PoReconciliationLocalizer.getLocalizedCheckMessage,
                getLocalizedSessionStatus: PoReconciliationLocalizer.getLocalizedSessionStatus,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
