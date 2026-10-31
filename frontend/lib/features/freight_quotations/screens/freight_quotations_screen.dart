import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/freight_quotation_model.dart';
import '../providers/freight_quotations_provider.dart';
import '../utils/freight_quotation_mapper.dart';
import '../utils/freight_rfq_populator.dart';
import '../widgets/freight_add_quotation_dialog.dart';
import '../widgets/freight_ai_extractor_card.dart';
import '../widgets/freight_container_comparison_dialog.dart';
import '../widgets/freight_header_actions.dart';
import '../widgets/freight_matched_rfq_banner.dart';
import '../widgets/freight_metrics_header.dart';
import '../widgets/freight_quotations_extractor_dialog.dart';
import '../widgets/freight_quotations_list_card.dart';
import '../widgets/freight_rfq_setup_card.dart';

class FreightQuotationsScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final int initialTabIndex;
  const FreightQuotationsScreen({
    super.key,
    this.initialImportFileId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<FreightQuotationsScreen> createState() => _FreightQuotationsScreenState();
}

class _FreightQuotationsScreenState extends ConsumerState<FreightQuotationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _titleModifiedByUser = false;
  final _cbmController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _crdDate = DateTime.now().add(const Duration(days: 15));
  String _shippingMethod = 'Ocean FCL';
  String _polName = '', _podName = '';
  int? _selectedImportFileId, _selectedPoId, _selectedProjectId;

  FreightRFQRequestModel? _matchedExistingRFQ;
  final List<FreightQuotationItemModel> _quotations = [];
  bool _isSaving = false, _isStackable = true, _isDirty = false;

  void _setDirty([bool dirty = true]) {
    if (_isDirty != dirty && mounted) setState(() => _isDirty = dirty);
  }

  void _markDirty() {
    if (!_isDirty) _setDirty(true);
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirty);
    _cbmController.addListener(_markDirty);
    _weightController.addListener(_markDirty);
    _notesController.addListener(_markDirty);
    if (widget.initialImportFileId != null) _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() {
      if (!ref.read(freightQuotationsProvider).isLoading) {
        ref.read(freightQuotationsProvider.notifier).fetchRFQs();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles().then((_) {
          if (widget.initialImportFileId != null && mounted) {
            setState(() => _populateFromImportFile(widget.initialImportFileId!));
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(FreightQuotationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != null && widget.initialImportFileId != _selectedImportFileId) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
        _populateFromImportFile(widget.initialImportFileId!);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cbmController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateFromImportFile(int fileId) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
    final data = FreightRfqPopulator.populate(fileId: fileId, importFilesList: files, allPOs: allPOs);
    if (data == null) return;

    _titleController.text = data.title;
    _shippingMethod = data.shippingMethod;
    if (data.crdDate != null) _crdDate = data.crdDate!;
    if (data.polName.isNotEmpty) _polName = data.polName;
    if (data.podName.isNotEmpty) _podName = data.podName;
    if (data.calcCbm > 0) _cbmController.text = data.calcCbm.toStringAsFixed(2);
    if (data.calcWeight > 0) _weightController.text = data.calcWeight.toStringAsFixed(1);
    if (data.isStackable != null) _isStackable = data.isStackable!;

    final rfqs = ref.read(freightQuotationsProvider).value ?? [];
    final matching = rfqs.where((r) => r.importFileId == fileId).toList();
    if (matching.isNotEmpty) {
      _matchedExistingRFQ = matching.first;
      if (_quotations.isEmpty && _matchedExistingRFQ!.quotations.isNotEmpty) {
        _loadExistingRFQQuotations(_matchedExistingRFQ!, showSnackbar: false);
      }
    } else {
      _matchedExistingRFQ = null;
    }
  }

  void _loadExistingRFQQuotations(FreightRFQRequestModel rfq, {bool showSnackbar = true}) {
    setState(() {
      _quotations..clear()..addAll(rfq.quotations.map((q) => q.copyWith()));
    });
    if (showSnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'تم استدعاء ${rfq.quotations.length} عروض أسعار مسجلة للمقارنة والترسية',
            severity: AppSeverity.success),
      );
    }
  }

  void _onRfqLoaded(FreightRFQRequestModel rfq) {
    _loadExistingRFQQuotations(rfq);
    setState(() {
      _matchedExistingRFQ = rfq;
      _selectedImportFileId = rfq.importFileId;
      _selectedPoId = rfq.poId;
      _selectedProjectId = rfq.projectId;
      _titleController.text = rfq.title;
      _shippingMethod = rfq.shippingMethod;
      _polName = rfq.polName;
      _podName = rfq.podName;
      _cbmController.text = rfq.totalCbm.toString();
      _weightController.text = rfq.totalGrossWeightKg.toString();
      _notesController.text = rfq.notes ?? '';
      if (rfq.crdDate.isNotEmpty) _crdDate = DateTime.tryParse(rfq.crdDate) ?? _crdDate;
      _isDirty = false;
    });
  }

  Future<void> _resetRFQForm() async {
    final isArabic = context.l10n.isArabic;
    if (_quotations.isNotEmpty || _titleModifiedByUser) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: isArabic ? 'تأكيد طلب جديد' : 'Confirm New RFQ',
        message: isArabic
            ? 'هل أنت متأكد من تفريغ كافة الحقول وعروض الأسعار المضافة للبدء من جديد؟'
            : 'Are you sure you want to clear all entered data and quotations to start fresh?',
        confirmLabel: isArabic ? 'تفريغ وبدء جديد' : 'Clear & Start New',
        cancelLabel: context.l10n.cancel,
        confirmVariant: AppButtonVariant.warning,
        icon: Icons.refresh_rounded,
      );
      if (!confirmed) return;
    }
    setState(() {
      _titleController.text = 'New Freight RFQ Request';
      _titleModifiedByUser = false;
      _cbmController.text = '0.0';
      _weightController.text = '0.0';
      _notesController.clear();
      _selectedImportFileId = null;
      _selectedPoId = null;
      _selectedProjectId = null;
      _matchedExistingRFQ = null;
      _quotations.clear();
      _crdDate = DateTime.now().add(const Duration(days: 15));
      _isDirty = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, isArabic ? 'تم تفريغ الحقول وبدء طلب عرض سعر جديد' : 'Form reset for new RFQ',
            severity: AppSeverity.info, duration: const Duration(seconds: 2)),
      );
    }
  }

  void _addExtractedOptionsToQuotations(List<ExtractedQuotationOption> selectedOptions) {
    final partners = ref.read(partnersProvider).valueOrNull ?? [];
    final newQuotes = FreightQuotationMapper.mapExtractedOptions(
      selectedOptions: selectedOptions,
      partners: partners,
      defaultSailingDate: DateTime.now().add(const Duration(days: 7)),
    );
    setState(() => _quotations.addAll(newQuotes));
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, 'تمت إضافة ${selectedOptions.length} عرض/عروض أسعار بنجاح!',
          severity: AppSeverity.success),
    );
  }

  Future<void> _saveRFQ() async {
    if (!_formKey.currentState!.validate()) return;
    if (_quotations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'يرجى إضافة عرض سعر واحد على الأقل للمقارنة', severity: AppSeverity.warning),
      );
      return;
    }
    setState(() => _isSaving = true);
    final ok = await FreightRfqPopulator.saveRfq(
      context: context, ref: ref,
      title: _titleController.text.trim(),
      shippingMethod: _shippingMethod, crdDate: _crdDate,
      polName: _polName, podName: _podName,
      importFileId: _selectedImportFileId, poId: _selectedPoId, projectId: _selectedProjectId,
      totalCbm: double.tryParse(_cbmController.text.trim()) ?? 0.0,
      totalGrossWeightKg: double.tryParse(_weightController.text.trim()) ?? 0.0,
      notes: _notesController.text.trim(), quotations: _quotations, onRetry: _saveRFQ,
    );
    if (mounted) {
      if (ok) _setDirty(false);
      setState(() => _isSaving = false);
    }
  }

  void _showContainerComparisonDialog(BuildContext context) {
    final curCbm = double.tryParse(_cbmController.text.trim()) ?? 0.0;
    final curWeight = double.tryParse(_weightController.text.trim()) ?? 0.0;
    FreightContainerComparisonDialog.show(
      context,
      dualRec: ContainerRequirementEngine.calculateBoth(totalCbm: curCbm, totalWeightKg: curWeight),
      totalCbm: curCbm,
      totalWeightKg: curWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final portsList = ref.watch(transportLocationsProvider).valueOrNull ?? [];
    final rfqsState = ref.watch(freightQuotationsProvider);
    final importFilesList = ref.watch(importFilesProvider).valueOrNull ?? [];
    final lowestCost = _quotations.isNotEmpty ? _quotations.map((q) => q.totalCost).reduce((a, b) => a < b ? a : b) : 0.0;
    final fastestTransit = _quotations.isNotEmpty ? _quotations.map((q) => q.transitDays).reduce((a, b) => a < b ? a : b) : 0;
    final isArabic = context.l10n.isArabic;

    if (!_titleModifiedByUser && (_titleController.text.isEmpty || _titleController.text == 'طلب عرض سعر شحن حاويات لمعدات وآلات خط الإنتاج')) {
      _titleController.text = 'Container Freight Quotation Request for Production Line Equipment';
    }

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onDiscard: () => setState(() => _isDirty = false),
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: PageHeader(
          icon: Icons.request_quote_outlined,
          title: isArabic ? 'طلب ومقارنة عروض أسعار الشحن والترسية' : 'Freight RFQ & Quotations Comparison',
          actions: [
            FreightHeaderActions(
              rfqs: rfqsState.valueOrNull ?? [],
              onRfqLoaded: _onRfqLoaded,
              onResetForm: _resetRFQForm,
            ),
          ],
        ),
        body: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FreightMetricsHeader(
                    lowestCost: lowestCost,
                    fastestTransit: fastestTransit,
                    carrierQuotesCount: _quotations.length,
                    isSaving: _isSaving,
                    onSaveRFQ: _saveRFQ,
                  ),
                  const SizedBox(height: 18),
                  FreightAiExtractorCard(onAddQuotations: _addExtractedOptionsToQuotations),
                  const SizedBox(height: 18),
                  FreightRfqSetupCard(
                    data: FreightRfqSetupData(
                      selectedImportFileId: _selectedImportFileId,
                      onImportFileChanged: (v) => setState(() {
                        _selectedImportFileId = v;
                        if (v != null) _populateFromImportFile(v);
                      }),
                      importFilesList: importFilesList,
                      titleController: _titleController,
                      onTitleChanged: (v) => _titleModifiedByUser = true,
                      shippingMethod: _shippingMethod,
                      onShippingMethodChanged: (v) { if (v != null) setState(() => _shippingMethod = v); },
                      crdDate: _crdDate,
                      onCrdDateChanged: (d) { if (d != null) setState(() => _crdDate = d); },
                      polName: _polName,
                      onPolNameChanged: (v) { if (v != null) setState(() => _polName = v); },
                      podName: _podName,
                      onPodNameChanged: (v) { if (v != null) setState(() => _podName = v); },
                      portsList: portsList,
                      cbmController: _cbmController,
                      weightController: _weightController,
                      isStackable: _isStackable,
                      onStackableChanged: (v) => setState(() => _isStackable = v),
                      onCompareCases: () => _showContainerComparisonDialog(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_matchedExistingRFQ != null)
                    FreightMatchedRfqBanner(
                      matchedExistingRFQ: _matchedExistingRFQ!,
                      onLoadQuotes: () => _loadExistingRFQQuotations(_matchedExistingRFQ!),
                    ),
                  FreightQuotationsListCard(
                    quotations: _quotations,
                    rfqCode: _matchedExistingRFQ?.rfqCode,
                    supplierName: _titleController.text,
                    onShowExtractorDialog: () => FreightQuotationsExtractorDialog.show(context, onAddQuotations: _addExtractedOptionsToQuotations),
                    onAddQuotation: () => FreightAddQuotationDialog.show(context, ref, crdDate: _crdDate, onQuotationAdded: (q) => setState(() => _quotations.add(q))),
                    onDeleteQuotation: (index) => setState(() => _quotations.removeAt(index)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
