import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../shipping_scenarios/models/shipping_scenario_model.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/freight_booking_model.dart';
import '../providers/freight_booking_provider.dart';
import '../services/booking_charge_builder.dart';
import 'booking_form/booking_form_actions_bar.dart';
import 'booking_form/booking_form_charges_tab.dart';
import 'booking_form/booking_form_controller.dart';
import 'booking_form/booking_form_details_tab.dart';
import 'booking_form/booking_form_header.dart';
import 'freight_booking_prompts.dart';
import 'freight_booking_ui.dart';

// The charge-building API lives in the service; re-exported for existing callers.
export '../services/booking_charge_builder.dart'
    show FbkQuoteState, buildChargesFromQuote, collectApplicableCurrencies, hasMixedCurrencies;

/// Create / edit a freight booking coordinator dialog.
class FreightBookingFormDialog extends ConsumerStatefulWidget {
  final ShipmentBookingModel? bookingToEdit;
  final bool isClone;
  const FreightBookingFormDialog({super.key, this.bookingToEdit, this.isClone = false});

  static List<BookingChargeModel> buildCharges(FbkQuoteState s) => buildChargesFromQuote(s);
  static Set<String> collectCurrencies(FbkQuoteState s) => collectApplicableCurrencies(s);
  static bool checkMixedCurrencies(FbkQuoteState s) => hasMixedCurrencies(s);

  @override
  ConsumerState<FreightBookingFormDialog> createState() => _FreightBookingFormDialogState();
}

class _FreightBookingFormDialogState extends ConsumerState<FreightBookingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = BookingFormController();
  int _tab = 0;
  bool _isSaving = false;

  bool get _isEdit => widget.bookingToEdit != null && !widget.isClone;
  FbkQuoteState get _currentQuoteState => _ctrl.currentQuoteState;

  @override
  void initState() {
    super.initState();
    _ctrl.init(widget.bookingToEdit, widget.isClone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _rebuildChargesFromQuoteBreakdown() {
    final result = BookingChargeBuilder.build(_currentQuoteState, containers: _ctrl.containers);
    _ctrl.charges = result.charges;
    _ctrl.has40ftMismatch = result.has40ftMismatch;
    _ctrl.has20ftMismatch = result.has20ftMismatch;
  }

  double get _computedCurrentExecutedFreight {
    final charges = buildChargesFromQuote(_currentQuoteState);
    return charges.fold<double>(0.0, (sum, c) => sum + c.total);
  }

  String? _getQuoteMismatchError(BuildContext context) =>
      _ctrl.getQuoteMismatchError(AppLocalizations.of(context));

  void _applyScenarioQuote(ShippingEvaluationModel session, ShippingScenarioItemModel item) {
    setState(() {
      _ctrl.applyScenarioQuote(session, item);
      _rebuildChargesFromQuoteBreakdown();
    });
    final l = AppLocalizations.of(context);
    FbkUi.snack(context, l.freightBookingQuoteAppliedSuccess(item.providerName, item.vesselName), severity: AppSeverity.success);
  }

  Future<void> _submitWithContainerValidation(ContainerRecommendationResult? rec) async {
    final l = AppLocalizations.of(context);
    if (hasMixedCurrencies(_currentQuoteState)) {
      if (_tab != 1) setState(() => _tab = 1);
      FbkUi.snack(context, l.fbkMixedCurrencyError, severity: AppSeverity.danger);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      if (_tab != 0) setState(() => _tab = 0);
      return;
    }
    setState(() => _rebuildChargesFromQuoteBreakdown());
    if (_ctrl.hasQuoteMismatch) {
      if (_tab != 0) setState(() => _tab = 0);
      FbkUi.snack(context, _getQuoteMismatchError(context)!, severity: AppSeverity.danger);
      return;
    }

    if (rec != null) {
      final assignedTotal = _ctrl.containers.fold(0, (sum, c) => sum + c.quantity);
      final assignedType = _ctrl.containers.isNotEmpty ? _ctrl.containers.first.containerType : 'N/A';
      final isMismatch = (assignedTotal != rec.requiredContainersCount) ||
          (_ctrl.containers.length == 1 && assignedType != rec.recommendedContainerCode);

      if (isMismatch && (_ctrl.containerMismatchReason == null || _ctrl.containerMismatchReason!.trim().isEmpty)) {
        final shouldProceed = await FbkPrompts.confirmMismatch(
          context,
          '$assignedTotal x $assignedType',
          '${rec.requiredContainersCount} x ${rec.recommendedContainerCode}',
        );
        if (!shouldProceed || !mounted) return;
        final reason = await FbkPrompts.askMismatchReason(context);
        if (reason == null) return;
        setState(() => _ctrl.containerMismatchReason = reason);
      }
    }

    _doSave();
  }

  Future<void> _doSave() async {
    setState(() => _rebuildChargesFromQuoteBreakdown());
    if (_ctrl.hasQuoteMismatch) {
      if (_tab != 0) setState(() => _tab = 0);
      FbkUi.snack(context, _getQuoteMismatchError(context)!, severity: AppSeverity.danger);
      return;
    }

    setState(() => _isSaving = true);
    final l = AppLocalizations.of(context);
    try {
      final payload = _ctrl.buildPayload(bookingToEdit: widget.bookingToEdit);
      if (!_isEdit) {
        await ref.read(freightBookingProvider.notifier).createBooking(payload);
      } else {
        await ref.read(freightBookingProvider.notifier).updateBooking(widget.bookingToEdit!.bookingId, payload);
      }
      ref.invalidate(lifecycleBoardSummaryProvider);
      ref.invalidate(liveLogisticsTrackingProvider);
      ref.invalidate(importFilesProvider);
      ref.invalidate(smartTasksProvider);
      if (mounted) {
        FbkUi.snack(context, l.freightBookingSaveSuccess, severity: AppSeverity.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        if (errStr.contains('يوجد بالفعل حجز شحن') || errStr.contains('مسجل لهذا الملف')) {
          final existing = (ref.read(freightBookingProvider).valueOrNull ?? [])
              .where((b) => b.importFileId == _ctrl.selectedImportFileId && b.isActive)
              .firstOrNull;
          if (existing != null) {
            await _handleDuplicate(existing);
            return;
          }
        }
        FbkUi.snack(context, '${l.error}: ${ApiErrorText.of(l, e)}', severity: AppSeverity.danger);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDuplicate(ShipmentBookingModel existing) async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final cur = files.where((f) => f.importFileId == existing.importFileId).firstOrNull;
    final label = cur != null ? '${cur.primaryNameWithCode} (${cur.companyName})' : 'IMP-${existing.importFileId}';
    final switchToEdit = await FbkPrompts.duplicateBooking(context, existing: existing, fileLabel: label);
    if (!mounted) return;
    if (!switchToEdit) {
      setState(() => _ctrl.selectedImportFileId = null);
      return;
    }
    final nav = Navigator.of(context);
    nav.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!nav.context.mounted) return;
      showDialog(context: nav.context, barrierDismissible: false, builder: (c) => FreightBookingFormDialog(bookingToEdit: existing));
    });
  }

  void _onImportFileSelected(int? val, List<ShippingEvaluationModel> shippingSessions) {
    if (val == null) {
      setState(() => _ctrl.selectedImportFileId = null);
      return;
    }
    final existing = (ref.read(freightBookingProvider).valueOrNull ?? [])
        .where((b) => b.importFileId == val && b.isActive && (!_isEdit || b.bookingId != widget.bookingToEdit!.bookingId))
        .firstOrNull;
    if (existing != null) {
      _handleDuplicate(existing);
      return;
    }
    setState(() {
      _ctrl.selectedImportFileId = val;
      final matched = shippingSessions.where((s) => s.importFileId == val).toList();
      if (matched.isNotEmpty && matched.first.items.isNotEmpty) {
        final rec = matched.first.items.firstWhere((i) => i.isRecommended, orElse: () => matched.first.items.first);
        _applyScenarioQuote(matched.first, rec);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final partners = ref.watch(allPartnersProvider).valueOrNull ?? ref.watch(partnersProvider).valueOrNull ?? [];
    final ports = ref.watch(transportLocationsProvider).valueOrNull ?? [];
    final shippingSessions = ref.watch(shippingScenariosProvider).sessions;
    final poList = ref.watch(purchaseOrdersProvider).purchaseOrders;

    final shippingLines = partners.where((p) => p.partnerType.contains('Shipping Line') || p.partnerType.contains('Carrier') || p.partnerType.contains('Bank') || p.partnerType.contains('Freight')).toList();
    final freightForwarders = partners.where((p) => p.partnerType.contains('Forwarder') || p.partnerType.contains('Logistics') || p.partnerType.contains('Freight')).toList();
    final matchingSessions = _ctrl.selectedImportFileId != null
        ? shippingSessions.where((s) => s.importFileId == _ctrl.selectedImportFileId).toList()
        : <ShippingEvaluationModel>[];

    final activeContainerRec = BookingFormController.calculateCargoMetrics(
      selectedImportFileId: _ctrl.selectedImportFileId,
      importFiles: importFiles,
      poList: poList,
      isStackable: true,
    );

    final l = AppLocalizations.of(context);
    final isEdit = _isEdit;

    return SelectionArea(
      child: CcStageDialogShell(
        title: isEdit ? l.freightBookingEditDialogTitle(widget.bookingToEdit!.bookingCode) : l.freightBookingNewDialogTitle,
        icon: Icons.directions_boat,
        maxWidth: 980,
        isSubmitting: _isSaving,
        confirmKey: const Key('fbkFormSaveBtn'),
        confirmLabel: isEdit ? l.freightBookingBtnUpdate : l.freightBookingBtnSaveConfirm,
        confirmIcon: Icons.check,
        onConfirm: () => _submitWithContainerValidation(activeContainerRec),
        headerActions: BookingFormHeader.buildHeaderActions(context, isEdit: isEdit, bookingToEdit: widget.bookingToEdit),
        footerLeading: BookingFormActionsBar(
          isEdit: isEdit,
          isSaving: _isSaving,
          onLiveReload: () {
            ref.read(freightBookingProvider.notifier).refresh();
            ref.read(importFilesProvider.notifier).fetchImportFiles();
          },
          onClearNew: () {
            _formKey.currentState?.reset();
            setState(() => _ctrl.reset());
          },
          onSaveDraft: () {
            if (!_isEdit) _ctrl.status = 'Draft';
            _submitWithContainerValidation(activeContainerRec);
          },
        ),
        body: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BookingFormStepSwitcher(selectedIndex: _tab, onSelected: (i) => setState(() => _tab = i)),
              const SizedBox(height: 14),
              Offstage(
                offstage: _tab != 0,
                child: BookingFormDetailsTab(
                  ctrl: _ctrl,
                  importFiles: importFiles,
                  shippingLines: shippingLines,
                  freightForwarders: freightForwarders,
                  ports: ports,
                  matchingSessions: matchingSessions,
                  quoteMismatchError: _getQuoteMismatchError(context),
                  cargoMetricsMissing: _ctrl.selectedImportFileId != null && activeContainerRec == null,
                  onImportFileChanged: (val) => _onImportFileSelected(val, shippingSessions),
                  onApplyScenarioQuote: _applyScenarioQuote,
                  onShippingLineChanged: (name, id) => setState(() { _ctrl.shippingLineName = name; _ctrl.shippingLineId = id; }),
                  onFreightForwarderChanged: (name, id) => setState(() { _ctrl.freightForwarderName = name; _ctrl.freightForwarderId = id; }),
                  onPolChanged: (name, id) => setState(() { _ctrl.pol.text = name; _ctrl.polLocationId = id; }),
                  onPodChanged: (name, id) => setState(() { _ctrl.pod.text = name; _ctrl.podLocationId = id; }),
                  onEtdChanged: (d) => setState(() => _ctrl.etd = d),
                  onEtaChanged: (d) => setState(() => _ctrl.eta = d),
                  onAtdChanged: (d) => setState(() => _ctrl.atd = d),
                  onClearAtd: () => setState(() => _ctrl.atd = null),
                  onExpectedWhDaysChanged: (_) => setState(() {}),
                  onStatusChanged: (v) => setState(() => _ctrl.status = v),
                  onContainerTypeChanged: (val) => setState(() { _ctrl.updateContainerType(val); _rebuildChargesFromQuoteBreakdown(); }),
                  onContainerQtyChanged: (q) => setState(() { _ctrl.updateContainerQty(q); _rebuildChargesFromQuoteBreakdown(); }),
                ),
              ),
              Offstage(
                offstage: _tab != 1,
                child: BookingFormChargesTab(
                  quoteData: _ctrl.quoteData,
                  quoteRevision: _ctrl.quoteRevision,
                  computedCurrentExecutedFreight: _computedCurrentExecutedFreight,
                  onQuoteChanged: () => setState(() => _rebuildChargesFromQuoteBreakdown()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
