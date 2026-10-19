import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../../audit_logs/widgets/row_history_dialog.dart';
import '../../cargo_shipping/widgets/cargo_shipping_ui.dart';
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
import 'freight_booking_cost_row.dart';
import 'freight_booking_prompts.dart';
import 'freight_booking_quote_card.dart';
import 'freight_booking_ui.dart';

// The charge-building API lives in the service; re-exported for existing callers.
export '../services/booking_charge_builder.dart'
    show FbkQuoteState, buildChargesFromQuote, collectApplicableCurrencies, hasMixedCurrencies;

/// Create / edit a freight booking. Nothing is prefilled with sample data:
/// a new booking starts empty and the required fields carry validators.
class FreightBookingFormDialog extends ConsumerStatefulWidget {
  final ShipmentBookingModel? bookingToEdit;
  final bool isClone;
  const FreightBookingFormDialog({super.key, this.bookingToEdit, this.isClone = false});

  static List<BookingChargeModel> buildCharges(FbkQuoteState s) =>
      buildChargesFromQuote(s);
  static Set<String> collectCurrencies(FbkQuoteState s) =>
      collectApplicableCurrencies(s);
  static bool checkMixedCurrencies(FbkQuoteState s) =>
      hasMixedCurrencies(s);

  @override
  ConsumerState<FreightBookingFormDialog> createState() => _FreightBookingFormDialogState();
}

class _FreightBookingFormDialogState extends ConsumerState<FreightBookingFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bookingConfirmNoController;
  late TextEditingController _polController;
  late TextEditingController _podController;
  late TextEditingController _vesselNameController;
  late TextEditingController _voyageNoController;
  late TextEditingController _releaseOrderNoController;
  late TextEditingController _freeDemurrageController;
  late TextEditingController _expectedWhDaysController;
  late TextEditingController _ownerController;
  late TextEditingController _notesController;

  int _tab = 0;
  int _quoteRevision = 0;

  int? _selectedImportFileId;
  int? _selectedScenarioSessionId;
  int? _selectedScenarioItemId;
  String? _selectedScenarioProviderName;

  String _shipmentType = 'Ocean FCL';
  String _freightTerms = 'Collect';
  String _status = 'Draft';
  String? _shippingLineName;
  int? _shippingLineId;
  String? _freightForwarderName;
  int? _freightForwarderId;
  int? _polLocationId;
  int? _podLocationId;
  int? _rfqRequestId;

  DateTime? _etd;
  DateTime? _eta;
  DateTime? _atd;
  String? _containerMismatchReason;

  final bool _isStackable = true;
  List<ContainerAllocationModel> _containers = [];
  List<BookingChargeModel> _charges = [];
  bool _has40ftMismatch = false;
  bool _has20ftMismatch = false;
  bool get _hasQuoteMismatch => _has40ftMismatch || _has20ftMismatch;

  String? _getQuoteMismatchError(BuildContext context) {
    if (!_hasQuoteMismatch) return null;
    final l = AppLocalizations.of(context);
    if (_has40ftMismatch && _has20ftMismatch) {
      return l.fbkQuoteEquipmentMismatchBoth;
    } else if (_has40ftMismatch) {
      return l.fbkQuoteEquipmentMismatch40ft;
    } else {
      return l.fbkQuoteEquipmentMismatch20ft;
    }
  }

  // Full 17 quote items state matching Phase 1
  String _mainQuoteCurrency = 'USD';
  double? _originalQuoteTotalUsd;
  double? _originalContainer40ftPrice;
  double? _originalContainer20ftPrice;
  double? _originalLclCbmPrice;
  double? _originalExpressCourierPrice;

  bool _container40ftApp = false;
  double _container40ftPrice = 0.0;
  String _container40ftCur = 'USD';
  int _container40ftQty = 1;

  bool _container20ftApp = false;
  double _container20ftPrice = 0.0;
  String _container20ftCur = 'USD';
  int _container20ftQty = 0;

  bool _lclCbmApp = false;
  double _lclCbmPrice = 0.0;
  String _lclCbmCur = 'USD';
  double _lclCbmQty = 0.0;

  bool _expressCourierApp = false;
  double _expressCourierPrice = 0.0;
  String _expressCourierCur = 'USD';

  bool _eurAtrApp = false;
  double _eurAtrPrice = 0.0;
  String _eurAtrCur = 'USD';

  bool _solasVgmApp = false;
  double _solasVgmPrice = 0.0;
  String _solasVgmCur = 'USD';

  bool _vgmNotifApp = false;
  double _vgmNotifPrice = 0.0;
  String _vgmNotifCur = 'USD';

  bool _telexReleaseApp = false;
  double _telexReleasePrice = 0.0;
  String _telexReleaseCur = 'USD';

  bool _insuranceApp = false;
  double _insurancePrice = 0.0;
  String _insuranceCur = 'USD';

  bool _cancellationApp = false;
  double _cancellationPrice = 0.0;
  String _cancellationCur = 'USD';

  bool _ics2App = false;
  double _ics2Price = 0.0;
  String _ics2Cur = 'USD';

  bool _otherFeesApp = false;
  double _otherFeesPrice = 0.0;
  String _otherFeesCur = 'USD';

  bool _docFeesApp = false;
  double _docFeesPrice = 0.0;
  String _docFeesCur = 'USD';

  bool _waiverApp = false;
  double _waiverPrice = 0.0;
  String _waiverCur = 'USD';

  bool _dthcApp = false;
  double _dthcPrice = 0.0;
  String _dthcCur = 'USD';

  bool _storagePerWeekApp = false;
  double _storagePerWeekPrice = 0.0;
  String _storagePerWeekCur = 'USD';

  bool _extraDayStorageApp = false;
  double _extraDayStoragePrice = 0.0;
  String _extraDayStorageCur = 'USD';

  bool _isSaving = false;

  /// Editing an existing booking (a clone is a NEW booking: create path, no id).
  bool get _isEdit => widget.bookingToEdit != null && !widget.isClone;

  @override
  void initState() {
    super.initState();
    final b = widget.bookingToEdit;
    _bookingConfirmNoController = TextEditingController(text: widget.isClone ? "" : (b?.bookingConfirmationNo ?? ""));
    _polController = TextEditingController(text: b?.polName ?? '');
    _podController = TextEditingController(text: b?.podName ?? '');
    _vesselNameController = TextEditingController(text: widget.isClone ? "" : (b?.vesselName ?? ""));
    _voyageNoController = TextEditingController(text: widget.isClone ? "" : (b?.voyageNumber ?? ""));
    _releaseOrderNoController = TextEditingController(text: widget.isClone ? "" : (b?.containerReleaseOrderNo ?? ""));
    _freeDemurrageController = TextEditingController(text: b?.freeDemurrageDays != null ? b!.freeDemurrageDays.toString() : '');
    _expectedWhDaysController = TextEditingController(text: (b?.expectedWarehouseDays ?? 7).toString());
    _ownerController = TextEditingController(text: widget.isClone ? '' : (b?.owner ?? ''));
    _notesController = TextEditingController(text: b?.notes ?? '');

    _selectedImportFileId = b?.importFileId;
    _selectedScenarioSessionId = b?.scenarioSessionId;
    _selectedScenarioItemId = b?.scenarioItemId;
    _selectedScenarioProviderName = b?.scenarioProviderName;
    _containerMismatchReason = b?.containerMismatchReason;

    _shipmentType = b?.shipmentType ?? 'Ocean FCL';
    _freightTerms = b?.freightTerms ?? 'Collect';
    _status = widget.isClone ? 'Draft' : (b?.status ?? 'Draft');
    _shippingLineName = b?.shippingLineName;
    _shippingLineId = b?.shippingLineId;
    _freightForwarderName = b?.freightForwarderName;
    _freightForwarderId = b?.freightForwarderId;
    _polLocationId = b?.polLocationId;
    _podLocationId = b?.podLocationId;
    _rfqRequestId = b?.rfqRequestId;

    if (b?.etd != null) _etd = DateTime.tryParse(b!.etd!);
    if (b?.eta != null) _eta = DateTime.tryParse(b!.eta!);
    if (!widget.isClone && b?.atd != null) _atd = DateTime.tryParse(b!.atd!);

    if (b?.containersData != null && b!.containersData.isNotEmpty) {
      _containers = List.from(b.containersData);
    }

    if (b?.costChargesData != null && b!.costChargesData.isNotEmpty) {
      _charges = List.from(b.costChargesData);
    }

    if (b?.quotationDetailsData != null && b!.quotationDetailsData.isNotEmpty) {
      _loadQuotationDataFromMap(b.quotationDetailsData);
    }
  }

  void _loadQuotationDataFromMap(Map<String, dynamic> q) {
    _mainQuoteCurrency = q['main_quote_currency'] ?? 'USD';
    _originalQuoteTotalUsd = (q['original_quote_total_usd'] as num?)?.toDouble() ?? widget.bookingToEdit?.originalFreightCostUsd;
    _originalContainer40ftPrice = (q['original_container_40ft_price'] as num?)?.toDouble();
    _originalContainer20ftPrice = (q['original_container_20ft_price'] as num?)?.toDouble();
    _originalLclCbmPrice = (q['original_lcl_cbm_price'] as num?)?.toDouble();
    _originalExpressCourierPrice = (q['original_express_courier_price'] as num?)?.toDouble();

    _container40ftApp = q['container_40ft_app'] ?? false;
    _container40ftPrice = (q['container_40ft_price'] as num?)?.toDouble() ?? 0.0;
    _container40ftCur = q['container_40ft_cur'] ?? 'USD';
    _container40ftQty = q['container_40ft_qty'] ?? 1;

    _container20ftApp = q['container_20ft_app'] ?? false;
    _container20ftPrice = (q['container_20ft_price'] as num?)?.toDouble() ?? 0.0;
    _container20ftCur = q['container_20ft_cur'] ?? 'USD';
    _container20ftQty = q['container_20ft_qty'] ?? 0;

    _lclCbmApp = q['lcl_cbm_app'] ?? false;
    _lclCbmPrice = (q['lcl_cbm_price'] as num?)?.toDouble() ?? 0.0;
    _lclCbmCur = q['lcl_cbm_cur'] ?? 'USD';
    _lclCbmQty = (q['lcl_cbm_qty'] as num?)?.toDouble() ?? 0.0;

    _expressCourierApp = q['express_courier_app'] ?? false;
    _expressCourierPrice = (q['express_courier_price'] as num?)?.toDouble() ?? 0.0;
    _expressCourierCur = q['express_courier_cur'] ?? 'USD';

    _eurAtrApp = q['eur_atr_app'] ?? false;
    _eurAtrPrice = (q['eur_atr_price'] as num?)?.toDouble() ?? 0.0;
    _eurAtrCur = q['eur_atr_cur'] ?? 'USD';

    _solasVgmApp = q['solas_vgm_app'] ?? false;
    _solasVgmPrice = (q['solas_vgm_price'] as num?)?.toDouble() ?? 0.0;
    _solasVgmCur = q['solas_vgm_cur'] ?? 'USD';

    _vgmNotifApp = q['vgm_notif_app'] ?? false;
    _vgmNotifPrice = (q['vgm_notif_price'] as num?)?.toDouble() ?? 0.0;
    _vgmNotifCur = q['vgm_notif_cur'] ?? 'USD';

    _telexReleaseApp = q['telex_release_app'] ?? false;
    _telexReleasePrice = (q['telex_release_price'] as num?)?.toDouble() ?? 0.0;
    _telexReleaseCur = q['telex_release_cur'] ?? 'USD';

    _insuranceApp = q['insurance_app'] ?? false;
    _insurancePrice = (q['insurance_price'] as num?)?.toDouble() ?? 0.0;
    _insuranceCur = q['insurance_cur'] ?? 'USD';

    _cancellationApp = q['cancellation_app'] ?? false;
    _cancellationPrice = (q['cancellation_price'] as num?)?.toDouble() ?? 0.0;
    _cancellationCur = q['cancellation_cur'] ?? 'USD';

    _ics2App = q['ics2_app'] ?? false;
    _ics2Price = (q['ics2_price'] as num?)?.toDouble() ?? 0.0;
    _ics2Cur = q['ics2_cur'] ?? 'USD';

    _otherFeesApp = q['other_fees_app'] ?? false;
    _otherFeesPrice = (q['other_fees_price'] as num?)?.toDouble() ?? 0.0;
    _otherFeesCur = q['other_fees_cur'] ?? 'USD';

    _docFeesApp = q['doc_fees_app'] ?? false;
    _docFeesPrice = (q['doc_fees_price'] as num?)?.toDouble() ?? 0.0;
    _docFeesCur = q['doc_fees_cur'] ?? 'USD';

    _waiverApp = q['waiver_app'] ?? false;
    _waiverPrice = (q['waiver_price'] as num?)?.toDouble() ?? 0.0;
    _waiverCur = q['waiver_cur'] ?? 'USD';

    _dthcApp = q['dthc_app'] ?? false;
    _dthcPrice = (q['dthc_price'] as num?)?.toDouble() ?? 0.0;
    _dthcCur = q['dthc_cur'] ?? 'USD';

    _storagePerWeekApp = q['storage_per_week_app'] ?? false;
    _storagePerWeekPrice = (q['storage_per_week_price'] as num?)?.toDouble() ?? 0.0;
    _storagePerWeekCur = q['storage_per_week_cur'] ?? 'USD';

    _extraDayStorageApp = q['extra_day_storage_app'] ?? false;
    _extraDayStoragePrice = (q['extra_day_storage_price'] as num?)?.toDouble() ?? 0.0;
    _extraDayStorageCur = q['extra_day_storage_cur'] ?? 'USD';
  }

  Map<String, dynamic> _buildQuotationDataMap() {
    return {
      'main_quote_currency': _mainQuoteCurrency,
      'container_40ft_app': _container40ftApp,
      'container_40ft_price': _container40ftPrice,
      'container_40ft_cur': _container40ftCur,
      'container_40ft_qty': _container40ftQty,
      'container_20ft_app': _container20ftApp,
      'container_20ft_price': _container20ftPrice,
      'container_20ft_cur': _container20ftCur,
      'container_20ft_qty': _container20ftQty,
      'lcl_cbm_app': _lclCbmApp,
      'lcl_cbm_price': _lclCbmPrice,
      'lcl_cbm_cur': _lclCbmCur,
      'lcl_cbm_qty': _lclCbmQty,
      'express_courier_app': _expressCourierApp,
      'express_courier_price': _expressCourierPrice,
      'express_courier_cur': _expressCourierCur,
      'eur_atr_app': _eurAtrApp,
      'eur_atr_price': _eurAtrPrice,
      'eur_atr_cur': _eurAtrCur,
      'solas_vgm_app': _solasVgmApp,
      'solas_vgm_price': _solasVgmPrice,
      'solas_vgm_cur': _solasVgmCur,
      'vgm_notif_app': _vgmNotifApp,
      'vgm_notif_price': _vgmNotifPrice,
      'vgm_notif_cur': _vgmNotifCur,
      'telex_release_app': _telexReleaseApp,
      'telex_release_price': _telexReleasePrice,
      'telex_release_cur': _telexReleaseCur,
      'insurance_app': _insuranceApp,
      'insurance_price': _insurancePrice,
      'insurance_cur': _insuranceCur,
      'cancellation_app': _cancellationApp,
      'cancellation_price': _cancellationPrice,
      'cancellation_cur': _cancellationCur,
      'ics2_app': _ics2App,
      'ics2_price': _ics2Price,
      'ics2_cur': _ics2Cur,
      'other_fees_app': _otherFeesApp,
      'other_fees_price': _otherFeesPrice,
      'other_fees_cur': _otherFeesCur,
      'doc_fees_app': _docFeesApp,
      'doc_fees_price': _docFeesPrice,
      'doc_fees_cur': _docFeesCur,
      'waiver_app': _waiverApp,
      'waiver_price': _waiverPrice,
      'waiver_cur': _waiverCur,
      'dthc_app': _dthcApp,
      'dthc_price': _dthcPrice,
      'dthc_cur': _dthcCur,
      'storage_per_week_app': _storagePerWeekApp,
      'storage_per_week_price': _storagePerWeekPrice,
      'storage_per_week_cur': _storagePerWeekCur,
      'extra_day_storage_app': _extraDayStorageApp,
      'extra_day_storage_price': _extraDayStoragePrice,
      'extra_day_storage_cur': _extraDayStorageCur,
      if (_originalQuoteTotalUsd != null) 'original_quote_total_usd': _originalQuoteTotalUsd,
      if (_originalContainer40ftPrice != null) 'original_container_40ft_price': _originalContainer40ftPrice,
      if (_originalContainer20ftPrice != null) 'original_container_20ft_price': _originalContainer20ftPrice,
      if (_originalLclCbmPrice != null) 'original_lcl_cbm_price': _originalLclCbmPrice,
      if (_originalExpressCourierPrice != null) 'original_express_courier_price': _originalExpressCourierPrice,
    };
  }

  @override
  void dispose() {
    _bookingConfirmNoController.dispose();
    _polController.dispose();
    _podController.dispose();
    _vesselNameController.dispose();
    _voyageNoController.dispose();
    _releaseOrderNoController.dispose();
    _freeDemurrageController.dispose();
    _expectedWhDaysController.dispose();
    _ownerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyScenarioQuote(ShippingEvaluationModel session, ShippingScenarioItemModel item) {
    setState(() {
      _quoteRevision++;
      _selectedScenarioSessionId = session.sessionId;
      _selectedScenarioItemId = item.itemId;
      _selectedScenarioProviderName = item.providerName;

      _shippingLineName = item.providerName;
      _freightForwarderName = item.providerName;
      _vesselNameController.text = item.vesselName;
      if (item.voyageNumber != null && item.voyageNumber!.isNotEmpty) {
        _voyageNoController.text = item.voyageNumber!;
      }
      if (item.polName != null && item.polName!.isNotEmpty) {
        _polController.text = item.polName!;
      }
      if (item.podName != null && item.podName!.isNotEmpty) {
        _podController.text = item.podName!;
      }
      final parsedEtd = DateTime.tryParse(item.sailingDate);
      if (parsedEtd != null) _etd = parsedEtd;
      final parsedEta = DateTime.tryParse(item.estimatedArrivalDate);
      if (parsedEta != null) _eta = parsedEta;
      _freeDemurrageController.text = item.freeTimeDays.toString();
      if (item.quotationCurrency != null) _mainQuoteCurrency = item.quotationCurrency!;
      _originalQuoteTotalUsd = item.totalQuotationAmount;
      _originalContainer40ftPrice = item.container40ftPrice;
      _originalContainer20ftPrice = item.container20ftPrice;
      _originalLclCbmPrice = item.lclCbmPrice;
      _originalExpressCourierPrice = item.expressCourierPrice;

      // Map all 17 quote breakdown parameters
      _container40ftApp = item.container40ftApplicable;
      _container40ftPrice = item.container40ftPrice;
      _container40ftCur = item.container40ftCurrency;
      _container40ftQty = item.container40ftQty > 0 ? item.container40ftQty : 1;

      _container20ftApp = item.container20ftApplicable;
      _container20ftPrice = item.container20ftPrice;
      _container20ftCur = item.container20ftCurrency;
      _container20ftQty = item.container20ftQty;

      _lclCbmApp = item.lclCbmApplicable;
      _lclCbmPrice = item.lclCbmPrice;
      _lclCbmCur = item.lclCbmCurrency;
      _lclCbmQty = item.lclCbmQty;

      _expressCourierApp = item.expressCourierApplicable;
      _expressCourierPrice = item.expressCourierPrice;
      _expressCourierCur = item.expressCourierCurrency;

      _eurAtrApp = item.eurAtrApplicable;
      _eurAtrPrice = item.eurAtrPrice;
      _eurAtrCur = item.eurAtrCurrency;

      _solasVgmApp = item.solasVgmApplicable;
      _solasVgmPrice = item.solasVgmPrice;
      _solasVgmCur = item.solasVgmCurrency;

      _vgmNotifApp = item.vgmNotificationApplicable;
      _vgmNotifPrice = item.vgmNotificationPrice;
      _vgmNotifCur = item.vgmNotificationCurrency;

      _telexReleaseApp = item.telexReleaseApplicable;
      _telexReleasePrice = item.telexReleasePrice;
      _telexReleaseCur = item.telexReleaseCurrency;

      _insuranceApp = item.insuranceApplicable;
      _insurancePrice = item.insurancePrice;
      _insuranceCur = item.insuranceCurrency;

      _cancellationApp = item.bookingCancellationApplicable;
      _cancellationPrice = item.bookingCancellationPrice;
      _cancellationCur = item.bookingCancellationCurrency;

      _ics2App = item.ics2FilingFeeApplicable;
      _ics2Price = item.ics2FilingFeePrice;
      _ics2Cur = item.ics2FilingFeeCurrency;

      _otherFeesApp = item.othersFeeApplicable;
      _otherFeesPrice = item.othersFeePrice;
      _otherFeesCur = item.othersFeeCurrency;

      _docFeesApp = item.documentFeesApplicable;
      _docFeesPrice = item.documentFeesPrice;
      _docFeesCur = item.documentFeesCurrency;

      _waiverApp = item.waiverLetterFeeApplicable;
      _waiverPrice = item.waiverLetterFeePrice;
      _waiverCur = item.waiverLetterFeeCurrency;

      _dthcApp = item.dthcApplicable;
      _dthcPrice = item.dthcPrice;
      _dthcCur = item.dthcCurrency;

      _storagePerWeekApp = item.storagePerWeekApplicable;
      _storagePerWeekPrice = item.storagePerWeekPrice;
      _storagePerWeekCur = item.storagePerWeekCurrency;

      _extraDayStorageApp = item.extraDayStorageApplicable;
      _extraDayStoragePrice = item.extraDayStoragePrice;
      _extraDayStorageCur = item.extraDayStorageCurrency;

      // Equipment follows the quotation (type + quantity only: container and
      // seal numbers and VGM weights are real data entered later, never invented).
      final List<ContainerAllocationModel> newContainers = [];
      if (item.container40ftApplicable && item.container40ftQty > 0) {
        newContainers.add(ContainerAllocationModel(containerType: '40HC', quantity: item.container40ftQty));
      }
      if (item.container20ftApplicable && item.container20ftQty > 0) {
        newContainers.add(ContainerAllocationModel(containerType: '20GP', quantity: item.container20ftQty));
      }
      if (newContainers.isNotEmpty) {
        _containers = newContainers;
        _shipmentType = 'Ocean FCL';
      } else if (item.lclCbmApplicable && item.lclCbmQty > 0) {
        _shipmentType = 'Ocean LCL';
      }

      // Rebuild charges list
      _rebuildChargesFromQuoteBreakdown();
    });

    final l = AppLocalizations.of(context);
    FbkUi.snack(context, l.freightBookingQuoteAppliedSuccess(item.providerName, item.vesselName),
        severity: AppSeverity.success);
  }

  FbkQuoteState get _currentQuoteState => FbkQuoteState(
        container40ftApp: _container40ftApp,
        container40ftPrice: _container40ftPrice,
        container40ftCur: _container40ftCur,
        container40ftQty: _container40ftQty,
        container20ftApp: _container20ftApp,
        container20ftPrice: _container20ftPrice,
        container20ftCur: _container20ftCur,
        container20ftQty: _container20ftQty,
        lclCbmApp: _lclCbmApp,
        lclCbmPrice: _lclCbmPrice,
        lclCbmCur: _lclCbmCur,
        lclCbmQty: _lclCbmQty,
        dthcApp: _dthcApp,
        dthcPrice: _dthcPrice,
        dthcCur: _dthcCur,
        storagePerWeekApp: _storagePerWeekApp,
        storagePerWeekPrice: _storagePerWeekPrice,
        storagePerWeekCur: _storagePerWeekCur,
        extraDayStorageApp: _extraDayStorageApp,
        extraDayStoragePrice: _extraDayStoragePrice,
        extraDayStorageCur: _extraDayStorageCur,
        solasVgmApp: _solasVgmApp,
        solasVgmPrice: _solasVgmPrice,
        solasVgmCur: _solasVgmCur,
        vgmNotifApp: _vgmNotifApp,
        vgmNotifPrice: _vgmNotifPrice,
        vgmNotifCur: _vgmNotifCur,
        telexReleaseApp: _telexReleaseApp,
        telexReleasePrice: _telexReleasePrice,
        telexReleaseCur: _telexReleaseCur,
        expressCourierApp: _expressCourierApp,
        expressCourierPrice: _expressCourierPrice,
        expressCourierCur: _expressCourierCur,
        eurAtrApp: _eurAtrApp,
        eurAtrPrice: _eurAtrPrice,
        eurAtrCur: _eurAtrCur,
        insuranceApp: _insuranceApp,
        insurancePrice: _insurancePrice,
        insuranceCur: _insuranceCur,
        docFeesApp: _docFeesApp,
        docFeesPrice: _docFeesPrice,
        docFeesCur: _docFeesCur,
        waiverApp: _waiverApp,
        waiverPrice: _waiverPrice,
        waiverCur: _waiverCur,
        ics2App: _ics2App,
        ics2Price: _ics2Price,
        ics2Cur: _ics2Cur,
        otherFeesApp: _otherFeesApp,
        otherFeesPrice: _otherFeesPrice,
        otherFeesCur: _otherFeesCur,
        cancellationApp: _cancellationApp,
        cancellationPrice: _cancellationPrice,
        cancellationCur: _cancellationCur,
      );

  void _rebuildChargesFromQuoteBreakdown() {
    final result = BookingChargeBuilder.build(_currentQuoteState, containers: _containers);
    _charges = result.charges;
    _has40ftMismatch = result.has40ftMismatch;
    _has20ftMismatch = result.has20ftMismatch;
  }


  Future<void> _submitWithContainerValidation(ContainerRecommendationResult? rec) async {
    final l = AppLocalizations.of(context);
    if (hasMixedCurrencies(_currentQuoteState)) {
      if (_tab != 1) setState(() => _tab = 1);
      FbkUi.snack(context, l.fbkMixedCurrencyError, severity: AppSeverity.danger);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      // Required fields live on the first tab: bring the user back to the errors.
      if (_tab != 0) setState(() => _tab = 0);
      return;
    }

    setState(() => _rebuildChargesFromQuoteBreakdown());
    if (_hasQuoteMismatch) {
      if (_tab != 0) setState(() => _tab = 0);
      FbkUi.snack(context, _getQuoteMismatchError(context)!, severity: AppSeverity.danger);
      return;
    }

    // Check Container Matching
    if (rec != null) {
      int assignedTotal = _containers.fold(0, (sum, c) => sum + c.quantity);
      String assignedType = _containers.isNotEmpty ? _containers.first.containerType : 'N/A';
      String suggestedType = rec.recommendedContainerCode;
      int suggestedTotal = rec.requiredContainersCount;

      bool isMismatch = (assignedTotal != suggestedTotal) || (_containers.length == 1 && assignedType != suggestedType);

      if (isMismatch && (_containerMismatchReason == null || _containerMismatchReason!.trim().isEmpty)) {
        final assignedStr = '$assignedTotal x $assignedType';
        final suggestedStr = '$suggestedTotal x $suggestedType';

        final shouldProceed = await FbkPrompts.confirmMismatch(context, assignedStr, suggestedStr);
        if (!shouldProceed) return;
        if (!mounted) return;

        // Prompt user for mandatory reason
        final reason = await FbkPrompts.askMismatchReason(context);
        if (reason == null) return;
        setState(() => _containerMismatchReason = reason);
      }
    }

    _doSave();
  }

  Future<void> _doSave() async {
    setState(() => _rebuildChargesFromQuoteBreakdown());
    if (_hasQuoteMismatch) {
      if (_tab != 0) setState(() => _tab = 0);
      FbkUi.snack(context, _getQuoteMismatchError(context)!, severity: AppSeverity.danger);
      return;
    }

    setState(() => _isSaving = true);
    final l = AppLocalizations.of(context);
    try {

      final owner = _ownerController.text.trim();
      final payload = {
        if (_bookingConfirmNoController.text.trim().isNotEmpty)
          'booking_confirmation_no': _bookingConfirmNoController.text.trim(),
        'import_file_id': _selectedImportFileId,
        if (_rfqRequestId != null) 'rfq_request_id': _rfqRequestId,
        'scenario_session_id': _selectedScenarioSessionId,
        'scenario_item_id': _selectedScenarioItemId,
        'scenario_provider_name': _selectedScenarioProviderName,
        if (_freightForwarderId != null) 'freight_forwarder_id': _freightForwarderId,
        'freight_forwarder_name': _freightForwarderName,
        if (_shippingLineId != null) 'shipping_line_id': _shippingLineId,
        'shipping_line_name': _shippingLineName,
        'shipment_type': _shipmentType,
        if (_polLocationId != null) 'pol_location_id': _polLocationId,
        'pol_name': _polController.text.trim(),
        if (_podLocationId != null) 'pod_location_id': _podLocationId,
        'pod_name': _podController.text.trim(),
        'etd': _etd?.toIso8601String(),
        'eta': _eta?.toIso8601String(),
        'atd': _atd?.toIso8601String(),
        'free_demurrage_days': _freeDemurrageController.text.trim().isNotEmpty ? int.tryParse(_freeDemurrageController.text.trim()) : null,
        'expected_warehouse_days': int.parse(_expectedWhDaysController.text.trim()),
        'vessel_name': _vesselNameController.text.trim(),
        'voyage_number': _voyageNoController.text.trim(),
        'container_release_order_no': _releaseOrderNoController.text.trim(),
        'freight_terms': _freightTerms,
        'container_mismatch_reason': _containerMismatchReason,
        'containers_data': _containers.map((c) => c.toJson()).toList(),
        'cost_charges_data': _charges.map((c) => c.toJson()).toList(),
        'quotation_details_data': _buildQuotationDataMap(),
        'original_freight_cost_usd': _originalQuoteTotalUsd,
        'status': _status,
        if (owner.isNotEmpty) 'owner': owner,
        'notes': _notesController.text.trim(),
      };

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
          final existingBookings = ref.read(freightBookingProvider).valueOrNull ?? [];
          final duplicate = existingBookings.where((b) => b.importFileId == _selectedImportFileId && b.isActive).toList();
          if (duplicate.isNotEmpty) {
            await _handleDuplicate(duplicate.first);
            return;
          }
        }
        FbkUi.snack(context, '${l.error}: ${ApiErrorText.of(l, e)}', severity: AppSeverity.danger);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// An active booking already exists for the selected file: warn, then either
  /// clear the file or switch to editing the existing booking.
  Future<void> _handleDuplicate(ShipmentBookingModel existing) async {
    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final curFile = importFiles.where((f) => f.importFileId == existing.importFileId).toList();
    final fileLabel = curFile.isNotEmpty
        ? '${curFile.first.primaryNameWithCode} (${curFile.first.companyName})'
        : 'IMP-${existing.importFileId}';

    final switchToEdit = await FbkPrompts.duplicateBooking(context, existing: existing, fileLabel: fileLabel);
    if (!mounted) return;
    if (!switchToEdit) {
      setState(() => _selectedImportFileId = null);
      return;
    }
    // Close this form, then open the existing booking in the next frame.
    final nav = Navigator.of(context);
    nav.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!nav.context.mounted) return;
      showDialog(
        context: nav.context,
        barrierDismissible: false,
        builder: (c) => FreightBookingFormDialog(bookingToEdit: existing),
      );
    });
  }

  double get _computedCurrentExecutedFreight {
    final charges = buildChargesFromQuote(_currentQuoteState);
    return charges.fold<double>(0.0, (sum, c) => sum + c.total);
  }

  Widget _liveSavingsBanner() {
    if (_originalQuoteTotalUsd == null || _originalQuoteTotalUsd! <= 0) {
      return const SizedBox.shrink();
    }
    final orig = _originalQuoteTotalUsd!;
    final exec = _computedCurrentExecutedFreight;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: FbkSavingsSummary(
        original: orig,
        executed: exec,
        hasSavings: exec < orig,
        hasIncrease: exec > orig,
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime? current,
    required DateTime fallback,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? fallback,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => onPicked(d));
  }

  Widget _costRow(String title, bool app, ValueChanged<bool> onApp, double price, ValueChanged<double> onPrice,
      String cur, ValueChanged<String> onCur,
      {int? qty, ValueChanged<int>? onQty, double? cbm, ValueChanged<double>? onCbm}) {
    return FbkCostItemRow(
      key: ValueKey('fbkCost_${title}_$_quoteRevision'),
      title: title,
      isApplicable: app,
      onToggle: (v) {
        setState(() => onApp(v));
        _rebuildChargesFromQuoteBreakdown();
      },
      price: price,
      onPriceChanged: (v) {
        setState(() => onPrice(v));
        _rebuildChargesFromQuoteBreakdown();
      },
      currency: cur,
      onCurrencyChanged: (v) {
        setState(() => onCur(v));
        _rebuildChargesFromQuoteBreakdown();
      },
      quantity: qty,
      onQuantityChanged: onQty == null
          ? null
          : (v) {
              setState(() => onQty(v));
              _rebuildChargesFromQuoteBreakdown();
            },
      doubleQty: cbm,
      onDoubleQtyChanged: onCbm == null
          ? null
          : (v) {
              setState(() => onCbm(v));
              _rebuildChargesFromQuoteBreakdown();
            },
    );
  }

  Widget _costTab(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.freightBookingCostBreakdownTitle,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context)),
              ),
            ),
            AppStatusBadge(
              label: l.freightBookingBaseCurrencyLabel(_mainQuoteCurrency),
              severity: AppSeverity.info,
              size: AppStatusBadgeSize.small,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _liveSavingsBanner(),
        _costRow(l.freightBookingItem40ft, _container40ftApp, (v) => _container40ftApp = v, _container40ftPrice,
            (v) => _container40ftPrice = v, _container40ftCur, (v) => _container40ftCur = v,
            qty: _container40ftQty, onQty: (v) => _container40ftQty = v),
        _costRow(l.freightBookingItem20ft, _container20ftApp, (v) => _container20ftApp = v, _container20ftPrice,
            (v) => _container20ftPrice = v, _container20ftCur, (v) => _container20ftCur = v,
            qty: _container20ftQty, onQty: (v) => _container20ftQty = v),
        _costRow(l.freightBookingItemLcl, _lclCbmApp, (v) => _lclCbmApp = v, _lclCbmPrice, (v) => _lclCbmPrice = v,
            _lclCbmCur, (v) => _lclCbmCur = v,
            cbm: _lclCbmQty, onCbm: (v) => _lclCbmQty = v),
        _costRow(l.freightBookingItemCourier, _expressCourierApp, (v) => _expressCourierApp = v, _expressCourierPrice,
            (v) => _expressCourierPrice = v, _expressCourierCur, (v) => _expressCourierCur = v),
        _costRow(l.freightBookingItemEur1, _eurAtrApp, (v) => _eurAtrApp = v, _eurAtrPrice, (v) => _eurAtrPrice = v,
            _eurAtrCur, (v) => _eurAtrCur = v),
        _costRow(l.freightBookingItemVgm, _solasVgmApp, (v) => _solasVgmApp = v, _solasVgmPrice,
            (v) => _solasVgmPrice = v, _solasVgmCur, (v) => _solasVgmCur = v),
        _costRow(l.freightBookingItemVgmNotif, _vgmNotifApp, (v) => _vgmNotifApp = v, _vgmNotifPrice,
            (v) => _vgmNotifPrice = v, _vgmNotifCur, (v) => _vgmNotifCur = v),
        _costRow(l.freightBookingItemTelex, _telexReleaseApp, (v) => _telexReleaseApp = v, _telexReleasePrice,
            (v) => _telexReleasePrice = v, _telexReleaseCur, (v) => _telexReleaseCur = v),
        if (_insuranceApp || _insurancePrice > 0)
          Container(
            key: const ValueKey('fbkInsuranceHint'),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.freightBookingInsuranceHint,
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
              ],
            ),
          ),

        _costRow(l.freightBookingItemCancellation, _cancellationApp, (v) => _cancellationApp = v, _cancellationPrice,
            (v) => _cancellationPrice = v, _cancellationCur, (v) => _cancellationCur = v),
        _costRow(l.freightBookingItemIcs2, _ics2App, (v) => _ics2App = v, _ics2Price, (v) => _ics2Price = v,
            _ics2Cur, (v) => _ics2Cur = v),
        _costRow(l.freightBookingItemOther, _otherFeesApp, (v) => _otherFeesApp = v, _otherFeesPrice,
            (v) => _otherFeesPrice = v, _otherFeesCur, (v) => _otherFeesCur = v),
        _costRow(l.freightBookingItemDocFees, _docFeesApp, (v) => _docFeesApp = v, _docFeesPrice,
            (v) => _docFeesPrice = v, _docFeesCur, (v) => _docFeesCur = v),
        _costRow(l.freightBookingItemWaiver, _waiverApp, (v) => _waiverApp = v, _waiverPrice, (v) => _waiverPrice = v,
            _waiverCur, (v) => _waiverCur = v),
        _costRow(l.freightBookingItemDthc, _dthcApp, (v) => _dthcApp = v, _dthcPrice, (v) => _dthcPrice = v,
            _dthcCur, (v) => _dthcCur = v),
        _costRow(l.freightBookingItemStorageWeek, _storagePerWeekApp, (v) => _storagePerWeekApp = v,
            _storagePerWeekPrice, (v) => _storagePerWeekPrice = v, _storagePerWeekCur, (v) => _storagePerWeekCur = v),
        _costRow(l.freightBookingItemStorageExtra, _extraDayStorageApp, (v) => _extraDayStorageApp = v,
            _extraDayStoragePrice, (v) => _extraDayStoragePrice = v, _extraDayStorageCur,
            (v) => _extraDayStorageCur = v),
      ],
    );
  }

  List<SearchableDropdownItem<String>> _portItems(List<dynamic> ports) => [
        for (final p in ports)
          SearchableDropdownItem<String>(value: p.locationName, label: p.locationName, subtitle: p.locationType),
      ];

  InputDecoration _dd(String hint) => ccInputDecoration(hint: hint);

  Widget _quotesSection(AppLocalizations l, List<ShippingEvaluationModel> matchingSessions) {
    final pairs = <(ShippingEvaluationModel, ShippingScenarioItemModel)>[
      for (final s in matchingSessions)
        for (final item in s.items) (s, item),
    ];
    return CcFormSection(
      title: l.freightBookingEvaluatedQuotesHeader,
      icon: Icons.local_shipping,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pairs.isEmpty)
            Text(l.freightBookingNoEvaluatedQuotes,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)))
          else ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                AppStatusBadge(
                  label: l.freightBookingAvailableQuotesBadge(pairs.length),
                  severity: AppSeverity.info,
                  size: AppStatusBadgeSize.small,
                ),
                Text(l.freightBookingApplyQuoteInstruction,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
              ],
            ),
            const SizedBox(height: 10),
            for (final pair in pairs)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: FbkQuoteCard(
                  session: pair.$1,
                  item: pair.$2,
                  isSelected: _selectedScenarioItemId == pair.$2.itemId ||
                      (_selectedScenarioProviderName == pair.$2.providerName &&
                          _vesselNameController.text == pair.$2.vesselName),
                  onApply: () => _applyScenarioQuote(pair.$1, pair.$2),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _detailsTab(
    AppLocalizations l, {
    required List<dynamic> importFiles,
    required List<dynamic> shippingLines,
    required List<dynamic> freightForwarders,
    required List<dynamic> ports,
    required List<ShippingEvaluationModel> shippingSessions,
    required List<ShippingEvaluationModel> matchingSessions,
    required bool cargoMetricsMissing,
  }) {
    final int delayDays = (_atd != null && _etd != null) ? _atd!.difference(_etd!).inDays : 0;
    final int whDays = int.tryParse(_expectedWhDaysController.text.trim()) ?? 7;
    final DateTime? computedWhArrival =
        _eta?.add(Duration(days: (delayDays > 0 ? delayDays : 0) + whDays));
    final portItems = _portItems(ports);
    final polValue = _polController.text.trim().isEmpty ? null : _polController.text;
    final podValue = _podController.text.trim().isEmpty ? null : _podController.text;

    String? reqText(String? v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CcFormSection(
          title: l.fbkSectionFile,
          icon: Icons.folder_special,
          child: CcFieldRow(
            children: [
              CcField(
                label: l.freightBookingImportFileLabel,
                child: SearchableDropdownField<int?>(
                  value: _selectedImportFileId,
                  labelText: l.freightBookingImportFileLabel,
                  searchHintText: l.freightBookingImportFileHint,
                  hintText: l.fbkSelectHint,
                      decoration: _dd(l.fbkSelectHint),
                  validator: (_) => _selectedImportFileId == null ? l.fbkValidatorImportFile : null,
                  items: importFiles
                      .map((f) => SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} (${f.companyName})',
                            subtitle: f.supplierName,
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) {
                      setState(() => _selectedImportFileId = null);
                      return;
                    }
                    // Check if there is already an active booking for this file
                    final existingBookings = ref.read(freightBookingProvider).valueOrNull ?? [];
                    final duplicate = existingBookings
                        .where((b) =>
                            b.importFileId == val &&
                            b.isActive &&
                            (!_isEdit || b.bookingId != widget.bookingToEdit!.bookingId))
                        .toList();

                    if (duplicate.isNotEmpty) {
                      _handleDuplicate(duplicate.first);
                      return;
                    }

                    setState(() {
                      _selectedImportFileId = val;
                      // If there are evaluated quotes, auto-select recommended
                      final matched = shippingSessions.where((s) => s.importFileId == val).toList();
                      if (matched.isNotEmpty && matched.first.items.isNotEmpty) {
                        final rec = matched.first.items.firstWhere((i) => i.isRecommended, orElse: () => matched.first.items.first);
                        _applyScenarioQuote(matched.first, rec);
                      }
                    });
                  },
                ),
              ),
              CcField(
                label: l.freightBookingConfirmNoInputLabel,
                child: TextFormField(
                  controller: _bookingConfirmNoController,
                  textDirection: TextDirection.ltr,
                  decoration: ccInputDecoration(prefix: Icons.confirmation_number_outlined),
                ),
              ),
            ],
          ),
        ),
        if (_selectedImportFileId != null) ...[
          const SizedBox(height: 12),
          _quotesSection(l, matchingSessions),
        ],
        const SizedBox(height: 12),
        CcFormSection(
          title: l.fbkSectionCarrierRoute,
          icon: Icons.alt_route,
          child: Column(
            children: [
              CcFieldRow(
                children: [
                  CcField(
                    label: l.freightBookingShippingLineLabel,
                    child: SearchableDropdownField<String>(
                      value: _shippingLineName,
                      labelText: l.freightBookingShippingLineLabel,
                      searchHintText: l.freightBookingShippingLineHint,
                      hintText: l.fbkSelectHint,
                      decoration: _dd(l.fbkSelectHint),
                      validator: (_) => reqText(_shippingLineName) == null ? null : l.fbkValidatorShippingLine,
                      items: [
                        for (final s in shippingLines)
                          SearchableDropdownItem<String>(value: s.partnerName, label: s.partnerName, subtitle: s.partnerType),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          final match = shippingLines.where((s) => s.partnerName == val).firstOrNull;
                          setState(() {
                            _shippingLineName = val;
                            _shippingLineId = match?.providerId;
                          });
                        }
                      },
                    ),
                  ),
                  CcField(
                    label: l.freightBookingForwarderLabel,
                    child: SearchableDropdownField<String>(
                      value: _freightForwarderName,
                      labelText: l.freightBookingForwarderLabel,
                      searchHintText: l.freightBookingForwarderHint,
                      hintText: l.fbkSelectHint,
                      decoration: _dd(l.fbkSelectHint),
                      items: [
                        for (final f in freightForwarders)
                          SearchableDropdownItem<String>(value: f.partnerName, label: f.partnerName, subtitle: f.partnerType),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          final match = freightForwarders.where((f) => f.partnerName == val).firstOrNull;
                          setState(() {
                            _freightForwarderName = val;
                            _freightForwarderId = match?.providerId;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CcFieldRow(
                children: [
                  CcField(
                    label: l.freightBookingPolLabel,
                    child: SearchableDropdownField<String>(
                      value: polValue,
                      labelText: l.freightBookingPolLabel,
                      searchHintText: l.freightBookingPolHint,
                      hintText: l.fbkSelectHint,
                      decoration: _dd(l.fbkSelectHint),
                      validator: (_) => reqText(_polController.text) == null ? null : l.fbkValidatorPol,
                      items: portItems,
                      onChanged: (val) {
                        if (val != null) {
                          final match = ports.where((p) => p.locationName == val).firstOrNull;
                          setState(() {
                            _polController.text = val;
                            _polLocationId = match?.locationId;
                          });
                        }
                      },
                    ),
                  ),
                  CcField(
                    label: l.freightBookingPodLabel,
                    child: SearchableDropdownField<String>(
                      value: podValue,
                      labelText: l.freightBookingPodLabel,
                      searchHintText: l.freightBookingPodHint,
                      hintText: l.fbkSelectHint,
                      decoration: _dd(l.fbkSelectHint),
                      validator: (_) => reqText(_podController.text) == null ? null : l.fbkValidatorPod,
                      items: portItems,
                      onChanged: (val) {
                        if (val != null) {
                          final match = ports.where((p) => p.locationName == val).firstOrNull;
                          setState(() {
                            _podController.text = val;
                            _podLocationId = match?.locationId;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CcFormSection(
          title: l.fbkSectionSchedule,
          icon: Icons.event_note,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CcFieldRow(
                children: [
                  FbkDateField(
                    label: l.freightBookingEtdLabel,
                    value: _etd,
                    placeholder: l.fbkSelectDate,
                    validator: (_) => _etd == null ? l.fbkValidatorEtd : null,
                    onTap: () => _pickDate(
                      current: _etd,
                      fallback: DateTime.now(),
                      onPicked: (d) => _etd = d,
                    ),
                  ),
                  FbkDateField(
                    label: l.freightBookingEtaLabel,
                    value: _eta,
                    placeholder: l.fbkSelectDate,
                    validator: (_) => _eta == null ? l.fbkValidatorEta : null,
                    onTap: () => _pickDate(
                      current: _eta,
                      fallback: _etd ?? DateTime.now(),
                      onPicked: (d) => _eta = d,
                    ),
                  ),
                  FbkDateField(
                    label: l.freightBookingAtdLabel,
                    value: _atd,
                    placeholder: l.freightBookingPendingDate,
                    onTap: () => _pickDate(
                      current: _atd,
                      fallback: _etd ?? DateTime.now(),
                      onPicked: (d) => _atd = d,
                    ),
                    onClear: () => setState(() => _atd = null),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FbkNotice(
                message: delayDays > 0 ? l.freightBookingDelayBannerDelayed(delayDays) : l.freightBookingDelayBannerOnTime,
                severity: delayDays > 0 ? AppSeverity.danger : AppSeverity.success,
                icon: delayDays > 0 ? Icons.alarm_off : Icons.check_circle,
                trailing: computedWhArrival == null
                    ? null
                    : l.freightBookingExpectedWhArrival(FbkFormat.pickedDate(computedWhArrival)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CcFormSection(
          title: l.fbkSectionTerms,
          icon: Icons.rule,
          child: CcFieldRow(
            children: [
              CcField(
                label: l.freightBookingFreeDaysInput,
                child: TextFormField(
                  controller: _freeDemurrageController,
                  keyboardType: TextInputType.number,
                  decoration: ccInputDecoration(prefix: Icons.timelapse_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    return (n == null || n < 0) ? l.fbkValidatorFreeDays : null;
                  },
                ),
              ),
              CcField(
                label: l.freightBookingWarehouseDaysInput,
                child: TextFormField(
                  controller: _expectedWhDaysController,
                  keyboardType: TextInputType.number,
                  decoration: ccInputDecoration(prefix: Icons.warehouse_outlined),
                  onChanged: (v) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l.fbkWarehouseExpectedDaysRequired;
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) return l.fbkWarehouseExpectedDaysInvalid;
                    return null;
                  },
                ),
              ),
              CcField(
                label: l.freightBookingStatusInputLabel,
                child: SearchableDropdownField<String>(
                  value: _status,
                  labelText: l.freightBookingStatusInputLabel,
                  searchHintText: l.freightBookingFilterStatusHint,
                  hintText: l.fbkSelectHint,
                      decoration: _dd(l.fbkSelectHint),
                  items: [
                    SearchableDropdownItem(value: 'Draft', label: l.freightBookingStatusDraft),
                    SearchableDropdownItem(value: 'Booking Requested', label: l.freightBookingStatusRequested),
                    SearchableDropdownItem(value: 'Cancelled', label: l.fbkStatusCancelled),
                    // Confirmed / Amended / Sailed come from the confirm and departure
                    // flows; an existing booking still shows its own (unchanged) status.
                    if (!const {'Draft', 'Booking Requested', 'Cancelled'}.contains(_status))
                      SearchableDropdownItem(value: _status, label: FbkUi.status(l, _status).label),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CcFormSection(
          title: l.fbkSectionVessel,
          icon: Icons.directions_boat_filled_outlined,
          child: CcFieldRow(
            children: [
              CcField(
                label: l.freightBookingVesselNameInput,
                child: TextFormField(
                  controller: _vesselNameController,
                  decoration: ccInputDecoration(prefix: Icons.directions_boat_filled_outlined),
                ),
              ),
              CcField(
                label: l.freightBookingVoyageNoInput,
                child: TextFormField(
                  controller: _voyageNoController,
                  textDirection: TextDirection.ltr,
                  decoration: ccInputDecoration(prefix: Icons.tag),
                ),
              ),
              CcField(
                label: l.freightBookingReleaseOrderInput,
                child: TextFormField(
                  controller: _releaseOrderNoController,
                  textDirection: TextDirection.ltr,
                  decoration: ccInputDecoration(prefix: Icons.assignment_turned_in_outlined),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CcFormSection(
          title: l.fbkSectionEquipment,
          icon: Icons.inventory_2_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CcFieldRow(
                children: [
                  CcField(
                    label: l.freightBookingContainerTypeInput,
                    child: SearchableDropdownField<String>(
                      value: _containers.isNotEmpty ? _containers.first.containerType : null,
                      labelText: l.freightBookingContainerTypeInput,
                      searchHintText: '20GP, 40HC...',
                      hintText: l.fbkSelectHint,
                      decoration: _dd(l.fbkSelectHint),
                      items: const [
                        SearchableDropdownItem(value: '20GP', label: '20GP Standard'),
                        SearchableDropdownItem(value: '40GP', label: '40GP Standard'),
                        SearchableDropdownItem(value: '40HC', label: '40HC High Cube'),
                        SearchableDropdownItem(value: '45HC', label: '45HC High Cube'),
                        SearchableDropdownItem(value: '20RF', label: '20RF Reefer'),
                        SearchableDropdownItem(value: '40RF', label: '40RF Reefer'),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            if (_containers.isEmpty) {
                              _containers.add(ContainerAllocationModel(containerType: val, quantity: 1));
                            } else {
                              _containers[0] = ContainerAllocationModel(
                                containerType: val,
                                quantity: _containers[0].quantity,
                                individualContainers: _containers[0].individualContainers,
                                vgmWeightKg: _containers[0].vgmWeightKg,
                              );
                            }
                            _rebuildChargesFromQuoteBreakdown();
                          });
                        }
                      },
                    ),
                  ),
                  CcField(
                    label: l.freightBookingContainersQtyInput,
                    child: TextFormField(
                      key: ValueKey('fbkQty_$_quoteRevision'),
                      initialValue: _containers.isNotEmpty ? _containers.first.quantity.toString() : '',
                      keyboardType: TextInputType.number,
                      decoration: ccInputDecoration(prefix: Icons.numbers),
                      onChanged: (val) {
                        final q = int.tryParse(val) ?? 1;
                        setState(() {
                          if (_containers.isEmpty) {
                            _containers.add(ContainerAllocationModel(containerType: '40HC', quantity: q));
                          } else {
                            _containers[0] = ContainerAllocationModel(
                              containerType: _containers[0].containerType,
                              quantity: q,
                              individualContainers: _containers[0].individualContainers,
                              vgmWeightKg: _containers[0].vgmWeightKg,
                            );
                          }
                          _rebuildChargesFromQuoteBreakdown();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_hasQuoteMismatch) ...[
                FbkNotice(
                  key: const Key('fbkQuoteEquipmentMismatchNotice'),
                  message: _getQuoteMismatchError(context)!,
                  severity: AppSeverity.danger,
                  icon: Icons.error_outline,
                ),
                const SizedBox(height: 8),
              ],
              FbkNotice(message: l.fbkEquipmentNote, severity: AppSeverity.info, icon: Icons.info_outline),
              if (cargoMetricsMissing) ...[
                const SizedBox(height: 8),
                FbkNotice(message: l.cshCargoMetricsMissing, severity: AppSeverity.warning, icon: Icons.warning_amber_rounded),
              ],
            ],
          ),
        ),
      ],
    );
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

    // Quotes for selected file
    final matchingSessions = _selectedImportFileId != null
        ? shippingSessions.where((s) => s.importFileId == _selectedImportFileId).toList()
        : <ShippingEvaluationModel>[];

    // Cargo volume / weight come only from the linked packing lists and POs.
    double totalCargoCbm = 0.0;
    double totalCargoWeightKg = 0.0;
    if (_selectedImportFileId != null && importFiles.any((f) => f.importFileId == _selectedImportFileId)) {
      final curFile = importFiles.firstWhere((f) => f.importFileId == _selectedImportFileId);
      for (var pl in curFile.packingListsData) {
        totalCargoCbm += pl.cbm;
        totalCargoWeightKg += pl.grossWeightKg;
      }
      final filePos = poList.where((p) => (curFile.poIds ?? []).contains(p.poId)).toList();
      for (var po in filePos) {
        for (var pl in po.packingListItems) {
          totalCargoCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
          totalCargoWeightKg += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
        }
      }
    }

    // No cargo metrics -> no container recommendation (nothing is invented).
    final hasCargoMetrics = totalCargoCbm > 0 || totalCargoWeightKg > 0;
    ContainerRecommendationResult? activeContainerRec;
    if (hasCargoMetrics) {
      final dual = ContainerRequirementEngine.calculateBoth(
        totalCbm: totalCargoCbm,
        totalWeightKg: totalCargoWeightKg,
      );
      activeContainerRec = _isStackable ? dual.stackableResult : dual.nonStackableResult;
    }

    final l = AppLocalizations.of(context);
    final isEdit = _isEdit;

    return CcStageDialogShell(
      title: isEdit ? l.freightBookingEditDialogTitle(widget.bookingToEdit!.bookingCode) : l.freightBookingNewDialogTitle,
      icon: Icons.directions_boat,
      maxWidth: 980,
      isSubmitting: _isSaving,
      confirmKey: const Key('fbkFormSaveBtn'),
      confirmLabel: isEdit ? l.freightBookingBtnUpdate : l.freightBookingBtnSaveConfirm,
      confirmIcon: Icons.check,
      onConfirm: () => _submitWithContainerValidation(activeContainerRec),
      headerActions: [
        if (isEdit)
          IconButton(
            key: const Key('fbkFormAuditBtn'),
            icon: Icon(Icons.history_rounded, color: AppTheme.white.withValues(alpha: 0.78)),
            tooltip: l.fbkAuditLogBtn,
            onPressed: () {
              RowHistoryDialog.show(
                context,
                entityType: 'ShipmentBooking',
                entityId: widget.bookingToEdit!.bookingId,
                entityTitle: l.fbkAuditEntityTitle(widget.bookingToEdit!.bookingCode),
              );
            },
          ),
      ],
      footerLeading: FbkButtonWrap(
        buttons: [
          AppButton(
            label: l.freightBookingBtnLiveReload,
            icon: Icons.refresh,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: _isSaving
                ? null
                : () {
                    ref.read(freightBookingProvider.notifier).refresh();
                    ref.read(importFilesProvider.notifier).fetchImportFiles();
                  },
          ),
          if (!_isEdit)
            AppButton(
              key: const Key('fbkFormClearBtn'),
              label: l.freightBookingBtnClearNew,
              icon: Icons.cleaning_services_outlined,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: _isSaving
                  ? null
                  : () {
                      _formKey.currentState?.reset();
                      setState(() {
                        _selectedImportFileId = null;
                        _selectedScenarioSessionId = null;
                        _selectedScenarioItemId = null;
                        _selectedScenarioProviderName = null;
                        _bookingConfirmNoController.clear();
                        _vesselNameController.clear();
                        _voyageNoController.clear();
                        _notesController.clear();
                        _releaseOrderNoController.clear();
                        _shippingLineName = null;
                        _shippingLineId = null;
                        _freightForwarderName = null;
                        _freightForwarderId = null;
                        _polLocationId = null;
                        _polController.clear();
                        _podLocationId = null;
                        _podController.clear();
                        _etd = null;
                        _eta = null;
                        _freeDemurrageController.text = '14';
                        _expectedWhDaysController.text = '7';
                        _status = 'Draft';
                        _containers = [];
                        _charges = [];
                      });
                    },
            ),
          AppButton(
            key: const Key('fbkFormSaveDraftBtn'),
            label: l.freightBookingBtnSaveDraft,
            icon: Icons.save_outlined,
            variant: AppButtonVariant.saveDraft,
            size: AppButtonSize.small,
            onPressed: _isSaving
                ? null
                : () {
                    if (!_isEdit) {
                      _status = 'Draft';
                    }
                    _submitWithContainerValidation(activeContainerRec);
                  },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShippingStepSwitcher(
              selectedIndex: _tab,
              titles: [l.freightBookingTabBookingDetails, l.freightBookingTabCostBreakdown],
              icons: const [Icons.description, Icons.attach_money],
              onSelected: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 14),
            // Both tabs stay mounted (Offstage) so validators cover every field.
            Offstage(
              offstage: _tab != 0,
              child: _detailsTab(
                l,
                importFiles: importFiles,
                shippingLines: shippingLines,
                freightForwarders: freightForwarders,
                ports: ports,
                shippingSessions: shippingSessions,
                matchingSessions: matchingSessions,
                cargoMetricsMissing: _selectedImportFileId != null && !hasCargoMetrics,
              ),
            ),
            Offstage(offstage: _tab != 1, child: _costTab(l)),
          ],
        ),
      ),
    );
  }
}
