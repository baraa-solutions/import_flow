import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';

import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../external_service_providers/models/partner_model.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../freight_quotations/widgets/freight_quotations_extractor_dialog.dart';
import '../../projects/providers/projects_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/shipping_scenario_model.dart';
import 'evaluator/scenario_evaluator_actions_bar.dart';
import 'evaluator/scenario_evaluator_carrier_table.dart';
import 'evaluator/scenario_evaluator_dialogs.dart';
import 'evaluator/scenario_evaluator_header.dart';
import 'evaluator/scenario_evaluator_inputs_card.dart';
import 'shipping_quote_smart_mapper.dart';

class ShippingScenarioEvaluatorTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final VoidCallback? onSwitchToRegistry;
  final VoidCallback? onRefreshData;

  const ShippingScenarioEvaluatorTab({
    super.key,
    this.initialImportFileId,
    this.onSwitchToRegistry,
    this.onRefreshData,
  });

  @override
  ConsumerState<ShippingScenarioEvaluatorTab> createState() => ShippingScenarioEvaluatorTabState();
}

class ShippingScenarioEvaluatorTabState extends ConsumerState<ShippingScenarioEvaluatorTab> {
  final _formKey = GlobalKey<FormState>();

  // Evaluator Form State
  int? _editingSessionId;
  String? _editingSessionCode;
  int _editFormVersion = 0;
  String _title = '';
  DateTime _cargoReadyDate = DateTime.now().add(const Duration(days: 5));
  String _pickUpAddress = '';
  int _avgForm4Days = 5;
  int _avgClearanceDays = 7;
  int? _selectedImportFileId;
  int? _selectedPoId;
  int? _selectedProjectId;
  final String _sessionNotes = '';

  // Carrier Options List
  final List<ShippingScenarioItemModel> _evalItems = [];
  bool _isSaving = false;
  bool _isStackable = true;

  // Track expanded quotes in UI
  final Map<int, bool> _expandedQuotes = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
    }
  }

  void loadSessionForEditing(ShippingEvaluationModel sess, {bool showLoadedSnackbar = true}) {
    setState(() {
      _editFormVersion++;
      _editingSessionId = sess.sessionId;
      _editingSessionCode = sess.sessionCode;
      _title = sess.title ?? '';
      _cargoReadyDate = DateTime.tryParse(sess.cargoReadyDate) ?? DateTime.now();
      _pickUpAddress = sess.pickUpAddress ?? '';
      _avgForm4Days = sess.avgForm4Days;
      _avgClearanceDays = sess.avgClearanceDays;
      _selectedImportFileId = sess.importFileId;
      _selectedPoId = sess.poId;
      _selectedProjectId = sess.projectId;
      _evalItems.clear();
      _evalItems.addAll(sess.items);
      _expandedQuotes.clear();
      for (int i = 0; i < sess.items.length; i++) {
        _expandedQuotes[i] = true;
      }
    });
    if (showLoadedSnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.sessionLoadedMsg(sess.sessionCode),
          severity: AppSeverity.info,
        ),
      );
    }
  }

  Future<void> resetFormForNewStudy() async {
    if (_evalItems.isNotEmpty) {
      final confirm = await ScenarioEvaluatorDialogs.confirmResetStudy(context);
      if (!confirm) return;
    }
    setState(() {
      _editFormVersion++;
      _editingSessionId = null;
      _editingSessionCode = null;
      _title = '';
      _cargoReadyDate = DateTime.now().add(const Duration(days: 5));
      _pickUpAddress = '';
      _avgForm4Days = 5;
      _avgClearanceDays = 7;
      _selectedImportFileId = null;
      _selectedPoId = null;
      _selectedProjectId = null;
      _expandedQuotes.clear();
      _evalItems.clear();
    });
  }

  void _addNewBlankCarrierOption() {
    setState(() {
      _evalItems.add(ScenarioEvaluatorCarrierTable.createBlankOption(
        _cargoReadyDate,
        isRecommended: _evalItems.isEmpty,
      ));
      _expandedQuotes[_evalItems.length - 1] = false;
    });
  }

  void _cloneCarrierOption(int idx) {
    if (idx < 0 || idx >= _evalItems.length) return;
    final source = _evalItems[idx];
    final clonedItem = source.copyWith(isRecommended: false, isSelected: false);
    setState(() {
      _evalItems.insert(idx + 1, clonedItem);
      _expandedQuotes[idx + 1] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.carrierOptionClonedSuccess,
        severity: AppSeverity.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteCarrierOption(int idx) async {
    if (idx < 0 || idx >= _evalItems.length) return;
    final item = _evalItems[idx];
    final confirm = await ScenarioEvaluatorDialogs.confirmDeleteOption(context, item.providerName);
    if (confirm) {
      setState(() {
        _evalItems.removeAt(idx);
        _expandedQuotes.remove(idx);
      });
    }
  }

  void _handleAddExtractedQuotations(List<ExtractedQuotationOption> selectedOptions) {
    if (selectedOptions.isEmpty) return;
    final crd = _cargoReadyDate;
    final partners = ref.read(allPartnersProvider).valueOrNull ?? ref.read(partnersProvider).valueOrNull ?? [];
    final ports = ref.read(transportLocationsProvider).valueOrNull ?? [];

    setState(() {
      _editFormVersion++;
      for (int i = 0; i < selectedOptions.length; i++) {
        final opt = selectedOptions[i];
        final newItem = ShippingQuoteSmartMapper.mapExtractedOptionToScenarioItem(
          opt: opt,
          crd: crd,
          partners: partners,
          portsList: ports,
          isRecommended: _evalItems.isEmpty && i == 0,
        );
        _evalItems.add(newItem);
        _expandedQuotes[_evalItems.length - 1] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.freightQuotesAddedMsg(selectedOptions.length),
        severity: AppSeverity.success,
      ),
    );
  }

  void _handleAddSingleExtractedQuotation(ExtractedQuotationOption opt) {
    _handleAddExtractedQuotations([opt]);
  }

  void applySmartExtractedFreightQuotes(Map<String, dynamic> fields) {
    final List<dynamic> options = (fields['rate_options'] is List && (fields['rate_options'] as List).isNotEmpty)
        ? fields['rate_options'] as List
        : [fields];

    final selected = [
      for (int i = 0; i < options.length; i++)
        ExtractedQuotationOption.fromMap(Map<String, dynamic>.from(options[i] as Map), i + 1),
    ];

    _evalItems.clear();
    _expandedQuotes.clear();
    _handleAddExtractedQuotations(selected);
  }

  void _handleCancelEdit() {
    resetFormForNewStudy();
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.cancelEditModeMsg,
        severity: AppSeverity.info,
      ),
    );
  }

  Future<void> _saveEvaluationSession(BuildContext context, List<CurrencyModel> currenciesList) async {
    setState(() => _isSaving = true);
    await ScenarioEvaluatorDialogs.saveEvaluationSession(
      context: context,
      ref: ref,
      formKey: _formKey,
      currenciesList: currenciesList,
      editingSessionId: _editingSessionId,
      editingSessionCode: _editingSessionCode,
      title: _title,
      cargoReadyDate: _cargoReadyDate,
      pickUpAddress: _pickUpAddress,
      avgForm4Days: _avgForm4Days,
      avgClearanceDays: _avgClearanceDays,
      selectedImportFileId: _selectedImportFileId,
      selectedPoId: _selectedPoId,
      selectedProjectId: _selectedProjectId,
      sessionNotes: _sessionNotes,
      items: _evalItems,
      onResetForm: resetFormForNewStudy,
      onSwitchToRegistry: widget.onSwitchToRegistry,
      onOpenExisting: (match) {
        if (mounted) loadSessionForEditing(match);
      },
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final poState = ref.watch(purchaseOrdersProvider);
    final projectsState = ref.watch(projectsProvider);
    final partnersState = ref.watch(allPartnersProvider);
    final portsState = ref.watch(transportLocationsProvider);
    final currenciesAsync = ref.watch(currenciesProvider);

    final poList = poState.purchaseOrders;
    final projectsList = projectsState.valueOrNull ?? [];
    final List<PartnerModel> partnersList = partnersState.valueOrNull ?? [];
    final List<CurrencyModel> currenciesList = currenciesAsync.valueOrNull ?? [];
    final portsList = portsState.valueOrNull ?? [];

    final metrics = ScenarioEvaluatorMetrics.calculate(
      items: _evalItems,
      cargoReadyDate: _cargoReadyDate,
      avgForm4Days: _avgForm4Days,
      avgClearanceDays: _avgClearanceDays,
    );

    return SelectionArea(
      child: Form(
        key: _formKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: KeyedSubtree(
                key: ValueKey('evaluator_form_${_editingSessionId ?? "new"}_$_editFormVersion'),
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: 16, bottom: 85),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScenarioEvaluatorHeader(metrics: metrics),
                      const SizedBox(height: 16),
                      ScenarioEvaluatorInputsCard(
                        title: _title,
                        onTitleChanged: (val) => _title = val,
                        cargoReadyDate: _cargoReadyDate,
                        onCargoReadyDateChanged: (val) => setState(() => _cargoReadyDate = val),
                        selectedImportFileId: _selectedImportFileId,
                        onImportFileChanged: (val) => setState(() => _selectedImportFileId = val),
                        pickUpAddress: _pickUpAddress,
                        onPickUpAddressChanged: (val) => _pickUpAddress = val,
                        selectedPoId: _selectedPoId,
                        onPoChanged: (val) => setState(() => _selectedPoId = val),
                        selectedProjectId: _selectedProjectId,
                        onProjectChanged: (val) => setState(() => _selectedProjectId = val),
                        avgForm4Days: _avgForm4Days,
                        onAvgForm4DaysChanged: (val) => setState(() => _avgForm4Days = val),
                        avgClearanceDays: _avgClearanceDays,
                        onAvgClearanceDaysChanged: (val) => setState(() => _avgClearanceDays = val),
                        isStackable: _isStackable,
                        onStackableChanged: (val) => setState(() => _isStackable = val),
                        editingSessionId: _editingSessionId,
                        editingSessionCode: _editingSessionCode,
                        editFormVersion: _editFormVersion,
                        onCancelEdit: _handleCancelEdit,
                        poList: poList,
                        projectsList: projectsList,
                        onAddExtractedQuotations: _handleAddExtractedQuotations,
                        onAddSingleExtractedQuotation: _handleAddSingleExtractedQuotation,
                      ),
                      const SizedBox(height: 20),
                      ScenarioEvaluatorCarrierTable(
                        items: _evalItems,
                        calculatedScenarios: metrics.calculatedScenarios,
                        expandedQuotes: _expandedQuotes,
                        editingSessionId: _editingSessionId,
                        editFormVersion: _editFormVersion,
                        onAddCarrierOption: _addNewBlankCarrierOption,
                        onToggleExpanded: (idx) => setState(() => _expandedQuotes[idx] = !(_expandedQuotes[idx] ?? false)),
                        onUpdateItem: (idx, updated) => setState(() => _evalItems[idx] = updated),
                        onCloneOption: _cloneCarrierOption,
                        onDeleteOption: _deleteCarrierOption,
                        partnersList: partnersList,
                        portsList: portsList,
                        currenciesList: currenciesList,
                        onRefreshData: () => widget.onRefreshData?.call(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: ScenarioEvaluatorActionsBar(
                isSaving: _isSaving,
                isEditing: _editingSessionId != null,
                onRefresh: () => widget.onRefreshData?.call(),
                onResetForm: resetFormForNewStudy,
                onSaveDraft: () => _saveEvaluationSession(context, currenciesList),
                onSubmitStudy: () => _saveEvaluationSession(context, currenciesList),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
