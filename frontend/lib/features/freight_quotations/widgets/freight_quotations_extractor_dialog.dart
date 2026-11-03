import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import 'quotations_extractor/extracted_quotation_option_model.dart';
import 'quotations_extractor/quotations_extractor_header.dart';
import 'quotations_extractor/quotations_extractor_dropzone.dart';
import 'quotations_extractor/quotations_extractor_comparison_view.dart';
import 'quotations_extractor/quotations_extractor_actions.dart';
import 'quotations_extractor/quotations_extractor_service.dart';

export 'quotations_extractor/extracted_quotation_option_model.dart';

/// Advanced Freight Quotations Extractor Dialog supporting Text & OCR Scans,
/// Party Verification (Forwarder & Carrier in DB), and Manual Custom Fields.
class FreightQuotationsExtractorDialog extends ConsumerStatefulWidget {
  final void Function(List<ExtractedQuotationOption> selectedOptions) onAddQuotations;

  const FreightQuotationsExtractorDialog({
    super.key,
    required this.onAddQuotations,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(List<ExtractedQuotationOption> selectedOptions) onAddQuotations,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FreightQuotationsExtractorDialog(
        onAddQuotations: onAddQuotations,
      ),
    );
  }

  @override
  ConsumerState<FreightQuotationsExtractorDialog> createState() =>
      _FreightQuotationsExtractorDialogState();
}

class _FreightQuotationsExtractorDialogState
    extends ConsumerState<FreightQuotationsExtractorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();

  bool _isExtracting = false;
  String? _error;
  PlatformFile? _pickedFile;

  List<ExtractedQuotationOption> _options = [];
  Map<String, dynamic>? _primaryMetadata;
  Map<String, String> _customFields = {};
  double _confidenceScore = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _loadSampleText() {
    setState(() {
      _textController.text = QuotationsExtractorDropzone.sampleQuoteText.trim();
      _error = null;
    });
  }

  Future<void> _extractFromText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'يرجى إدخال أو لصق نص عرض السعر أولاً');
      return;
    }

    setState(() {
      _isExtracting = true;
      _error = null;
      _options = [];
      _primaryMetadata = null;
      _customFields = {};
    });

    final result = await QuotationsExtractionService.extractFromText(
      context: context,
      dio: ref.read(uploadDioProvider),
      text: text,
      isArabic: Directionality.of(context) == TextDirection.rtl,
    );

    if (mounted) {
      setState(() {
        _isExtracting = false;
        _confidenceScore = result.confidenceScore;
        _primaryMetadata = result.primaryMetadata;
        _options = result.options;
        _customFields = Map.from(result.customFields);
        _error = result.error;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'xlsx', 'xls', 'docx', 'doc', 'txt'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFile = result.files.first;
        _error = null;
      });
    }
  }

  Future<void> _extractFromFileOcr() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      setState(() => _error = 'يرجى اختيار ملف أو صورة عرض السعر أولاً');
      return;
    }

    setState(() {
      _isExtracting = true;
      _error = null;
      _options = [];
      _primaryMetadata = null;
      _customFields = {};
    });

    final result = await QuotationsExtractionService.extractFromFileOcr(
      context: context,
      dio: ref.read(uploadDioProvider),
      file: _pickedFile!,
      isArabic: Directionality.of(context) == TextDirection.rtl,
    );

    if (mounted) {
      setState(() {
        _isExtracting = false;
        _confidenceScore = result.confidenceScore;
        _primaryMetadata = result.primaryMetadata;
        _options = result.options;
        _customFields = Map.from(result.customFields);
        _error = result.error;
      });
    }
  }

  void _addSelectedAndClose() {
    final selected = _options.where((o) => o.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'يرجى تحديد عرض سعر واحد على الأقل للإضافة.',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    if (_customFields.isNotEmpty) {
      final customSummary = _customFields.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
      for (final opt in selected) {
        if (opt.notes == null || opt.notes!.isEmpty) {
          opt.notes = customSummary;
        } else if (!opt.notes!.contains(customSummary)) {
          opt.notes = '${opt.notes!} | $customSummary';
        }
      }
    }

    widget.onAddQuotations(selected);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _options.where((o) => o.isSelected).length;
    final hasResults = _options.isNotEmpty;

    final partnersAsync = ref.watch(allPartnersProvider);
    final portsAsync = ref.watch(transportLocationsProvider);
    final partners = partnersAsync.value ?? [];
    final portsList = portsAsync.value ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 880,
          constraints: const BoxConstraints(maxHeight: 840),
          child: Column(
            children: [
              QuotationsExtractorHeader(
                confidenceScore: _confidenceScore,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      QuotationsExtractorDropzone(
                        tabController: _tabController,
                        textController: _textController,
                        pickedFile: _pickedFile,
                        isExtracting: _isExtracting,
                        onLoadSampleText: _loadSampleText,
                        onClearText: () => setState(() {
                          _textController.clear();
                          _options = [];
                          _primaryMetadata = null;
                          _error = null;
                        }),
                        onPickFile: _pickFile,
                        onExtractFromText: _extractFromText,
                        onExtractFromFileOcr: _extractFromFileOcr,
                        onTextChanged: (_) => setState(() {}),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.crimson.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.crimson, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (hasResults)
                        QuotationsExtractorComparisonView(
                          options: _options,
                          primaryMetadata: _primaryMetadata,
                          customFields: _customFields,
                          partners: partners,
                          portsList: portsList,
                          onAddCustomField: () => QuotationsExtractorModals.showAddCustomFieldModal(
                            context,
                            onAdd: (k, v) => setState(() => _customFields[k] = v),
                          ),
                          onEditCustomField: (k, v) => QuotationsExtractorModals.showEditCustomFieldModal(
                            context,
                            key: k,
                            currentValue: v,
                            onSave: (newVal) => setState(() => _customFields[k] = newVal),
                          ),
                          onDeleteCustomField: (k) => setState(() => _customFields.remove(k)),
                          onRegisterPartner: () => UniversalEntityExtractorDialog.show(
                            context,
                            initialTarget: EntityTarget.partner,
                            onSaved: () => ref.invalidate(allPartnersProvider),
                          ),
                          onAddSingleQuote: (opt) {
                            widget.onAddQuotations([opt]);
                            Navigator.of(context).pop();
                          },
                          onAddAllQuotes: () {
                            for (final opt in _options) {
                              opt.isSelected = true;
                            }
                            _addSelectedAndClose();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              QuotationsExtractorFooterActions(
                selectedCount: selectedCount,
                hasResults: hasResults,
                onCancel: () => Navigator.of(context).pop(),
                onAddSelected: _addSelectedAndClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
