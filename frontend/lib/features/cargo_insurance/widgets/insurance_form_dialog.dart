import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../cargo_shipping/providers/cargo_shipping_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/cargo_insurance_model.dart';
import '../providers/cargo_insurance_provider.dart';

// =============================================================================
// Form Dialog: Add / Edit & Calculate Insurance Certificate
// =============================================================================
class CargoInsuranceFormDialog extends ConsumerStatefulWidget {
  final CargoInsuranceModel? certificateToEdit;
  final int? initialImportFileId;
  const CargoInsuranceFormDialog({super.key, this.certificateToEdit, this.initialImportFileId});

  @override
  ConsumerState<CargoInsuranceFormDialog> createState() => CargoInsuranceFormDialogState();
}

class CargoInsuranceFormDialogState extends ConsumerState<CargoInsuranceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedImportFileId;
  String _policyType = 'SPECIFIC';
  final TextEditingController _insuredEntityCtrl = TextEditingController();
  final TextEditingController _insuranceCompanyCtrl = TextEditingController();
  final TextEditingController _policyNoCtrl = TextEditingController();

  String _transportMode = 'OCEAN';
  final TextEditingController _carrierCtrl = TextEditingController();
  final TextEditingController _vesselFlightCtrl = TextEditingController();
  final TextEditingController _voyageNoCtrl = TextEditingController();
  final TextEditingController _trackingRefCtrl = TextEditingController();
  final TextEditingController _polCtrl = TextEditingController();
  final TextEditingController _podCtrl = TextEditingController();
  final TextEditingController _finalDestCtrl = TextEditingController();

  String _currency = 'USD';
  final TextEditingController _exchangeRateCtrl = TextEditingController();
  final TextEditingController _invoiceValueCtrl = TextEditingController(text: '0.0');
  final TextEditingController _freightCostCtrl = TextEditingController(text: '0.0');
  final TextEditingController _otherCostsCtrl = TextEditingController(text: '0.0');
  // Rate overrides: empty = backend system parameters (no client-side rates).
  final TextEditingController _markupCtrl = TextEditingController();

  String _coverageClause = 'ICC_A';
  bool _includeWarAndStrikes = true;
  final TextEditingController _minPremiumCtrl = TextEditingController();
  final TextEditingController _issuanceFeeCtrl = TextEditingController();
  final TextEditingController _taxRateCtrl = TextEditingController();

  final TextEditingController _goodsDescCtrl = TextEditingController();
  final TextEditingController _packageCountCtrl = TextEditingController();
  final TextEditingController _packageTypeCtrl = TextEditingController();
  final TextEditingController _grossWeightCtrl = TextEditingController();
  final TextEditingController _surveyAgentCtrl = TextEditingController();
  final TextEditingController _claimsPayableAtCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  bool _isSaving = false;
  InsuranceCalculationResultModel? _calculationPreview;
  String? _calcError;
  Timer? _calcDebounce;
  int _calcSeq = 0;

  @override
  void initState() {
    super.initState();
    if (widget.certificateToEdit != null) {
      final c = widget.certificateToEdit!;
      _selectedImportFileId = c.importFileId;
      _policyType = c.policyType;
      _insuredEntityCtrl.text = c.insuredEntityName;
      _insuranceCompanyCtrl.text = c.insuranceCompanyName ?? '';
      _policyNoCtrl.text = c.policyNumber ?? '';
      _transportMode = c.transportMode;
      _carrierCtrl.text = c.carrierName ?? '';
      _vesselFlightCtrl.text = c.vesselOrFlightNo ?? '';
      _voyageNoCtrl.text = c.voyageNumber ?? '';
      _trackingRefCtrl.text = c.trackingReference ?? '';
      _polCtrl.text = c.portOfLoading;
      _podCtrl.text = c.portOfDischarge;
      _finalDestCtrl.text = c.finalDestination ?? '';
      _currency = c.currency;
      _exchangeRateCtrl.text = c.exchangeRate.toString();
      _invoiceValueCtrl.text = c.invoiceValue.toString();
      _freightCostCtrl.text = c.freightCost.toString();
      _otherCostsCtrl.text = c.otherLogisticsCosts.toString();
      _markupCtrl.text = c.markupPercentage.toString();
      _coverageClause = c.coverageClause;
      _includeWarAndStrikes = c.includeWarAndStrikes;
      _minPremiumCtrl.text = c.minimumPremium.toString();
      _issuanceFeeCtrl.text = c.issuanceFee.toString();
      _taxRateCtrl.text = c.taxRate.toString();
      _goodsDescCtrl.text = c.goodsDescription ?? '';
      _packageCountCtrl.text = c.packageCount?.toString() ?? '';
      _packageTypeCtrl.text = c.packageType ?? '';
      _grossWeightCtrl.text = c.grossWeightKg?.toString() ?? '';
      _surveyAgentCtrl.text = c.surveyAgentInDestination ?? '';
      _claimsPayableAtCtrl.text = c.claimsPayableAt ?? '';
      _remarksCtrl.text = c.remarks ?? '';
    } else if (widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoFillFromImportFile(widget.initialImportFileId!);
      });
    }
    _runLiveCalculation();
  }

  @override
  void dispose() {
    _calcDebounce?.cancel();
    _insuredEntityCtrl.dispose();
    _insuranceCompanyCtrl.dispose();
    _policyNoCtrl.dispose();
    _carrierCtrl.dispose();
    _vesselFlightCtrl.dispose();
    _voyageNoCtrl.dispose();
    _trackingRefCtrl.dispose();
    _polCtrl.dispose();
    _podCtrl.dispose();
    _finalDestCtrl.dispose();
    _exchangeRateCtrl.dispose();
    _invoiceValueCtrl.dispose();
    _freightCostCtrl.dispose();
    _otherCostsCtrl.dispose();
    _markupCtrl.dispose();
    _minPremiumCtrl.dispose();
    _issuanceFeeCtrl.dispose();
    _taxRateCtrl.dispose();
    _goodsDescCtrl.dispose();
    _packageCountCtrl.dispose();
    _packageTypeCtrl.dispose();
    _grossWeightCtrl.dispose();
    _surveyAgentCtrl.dispose();
    _claimsPayableAtCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _autoFillFromImportFile(int fileId) {
    final files = ref.read(importFilesProvider).value ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file != null) {
      _onImportFileSelected(file);
    }
  }

  /// Rate overrides typed by the user (or stored on the certificate being edited).
  /// Empty means "use the backend system parameters".
  double? _optionalNumber(TextEditingController c) => double.tryParse(c.text.trim());

  Map<String, dynamic> _calculationPayload() {
    return {
      'invoice_value': double.tryParse(_invoiceValueCtrl.text) ?? 0.0,
      'freight_cost': double.tryParse(_freightCostCtrl.text) ?? 0.0,
      'other_costs': double.tryParse(_otherCostsCtrl.text) ?? 0.0,
      'coverage_clause': _coverageClause,
      'transport_mode': _transportMode,
      'include_war_and_strikes': _includeWarAndStrikes,
      'currency': _currency,
      if (_optionalNumber(_markupCtrl) != null) 'markup_percentage': _optionalNumber(_markupCtrl),
      if (_optionalNumber(_minPremiumCtrl) != null) 'minimum_premium': _optionalNumber(_minPremiumCtrl),
      if (_optionalNumber(_issuanceFeeCtrl) != null) 'issuance_fee': _optionalNumber(_issuanceFeeCtrl),
      if (_optionalNumber(_taxRateCtrl) != null) 'tax_rate': _optionalNumber(_taxRateCtrl),
    };
  }

  /// Premium preview from `POST /cargo-insurance/calculate` (debounced). The
  /// engine and its rates live on the backend only.
  void _runLiveCalculation() {
    _calcDebounce?.cancel();
    _calcDebounce = Timer(const Duration(milliseconds: 400), _fetchCalculation);
  }

  Future<void> _fetchCalculation() async {
    final seq = ++_calcSeq;
    try {
      final result = await ref.read(cargoInsuranceProvider.notifier).calculateInsurance(_calculationPayload());
      if (!mounted || seq != _calcSeq) return;
      setState(() {
        _calculationPreview = result;
        _calcError = null;
      });
    } catch (e) {
      if (!mounted || seq != _calcSeq) return;
      setState(() {
        _calcError = ApiErrorText.of(context.l10n, e);
      });
    }
  }

  void _onImportFileSelected(ImportFileModel? file) {
    if (file == null) return;

    final bookings = ref.read(freightBookingProvider).value ?? [];
    final linkedBooking = bookings.where((b) => b.importFileId == file.importFileId && b.isActive).firstOrNull;

    final shippingRecords = ref.read(cargoShippingProvider).value ?? [];
    final linkedShipping = shippingRecords.where((s) => s.importFileId == file.importFileId && s.isActive).firstOrNull;

    final purchaseOrders = ref.read(purchaseOrdersProvider).purchaseOrders;
    final linkedPOs = purchaseOrders.where((po) => po.importFileId == file.importFileId && po.isActive).toList();

    // 1. Transport Mode
    String mode = 'OCEAN';
    final bookingMode = (linkedBooking?.shipmentType ?? '').toLowerCase();
    final fileMode = file.shipmentMode.toLowerCase();
    if (bookingMode.contains('air') || fileMode.contains('air') || fileMode.contains('جوي')) {
      mode = 'AIR';
    } else if (bookingMode.contains('land') || bookingMode.contains('road') || fileMode.contains('land') || fileMode.contains('road') || fileMode.contains('بري')) {
      mode = 'ROAD';
    } else {
      mode = 'OCEAN';
    }

    // 2. Carrier Name
    String carrier = '';
    if (linkedBooking != null) {
      carrier = linkedBooking.shippingLineName ?? linkedBooking.freightForwarderName ?? linkedBooking.scenarioProviderName ?? '';
    }
    if (carrier.isEmpty) {
      carrier = file.brokerName ?? '';
    }

    // 3. Vessel / Flight & Voyage
    String vessel = '';
    String voyage = '';
    if (linkedBooking != null) {
      if (linkedBooking.vesselName != null && linkedBooking.vesselName!.isNotEmpty) {
        vessel = linkedBooking.vesselName!;
      }
      if (linkedBooking.voyageNumber != null && linkedBooking.voyageNumber!.isNotEmpty) {
        voyage = linkedBooking.voyageNumber!;
      }
    }

    // 4. Port of Loading (POL)
    String pol = '';
    if (linkedBooking != null && linkedBooking.polName != null && linkedBooking.polName!.isNotEmpty) {
      pol = linkedBooking.polName!;
    } else if (file.portOfLoading != null && file.portOfLoading!.isNotEmpty) {
      pol = file.portOfLoading!;
    }

    // 5. Port of Discharge (POD)
    String pod = '';
    if (linkedBooking != null && linkedBooking.podName != null && linkedBooking.podName!.isNotEmpty) {
      pod = linkedBooking.podName!;
    } else if (file.portOfDischarge != null && file.portOfDischarge!.isNotEmpty) {
      pod = file.portOfDischarge!;
    }

    // 6. B/L / AWB / Tracking Reference
    String bl = '';
    if (linkedShipping != null && linkedShipping.courierTrackingData.trackingNumber != null && linkedShipping.courierTrackingData.trackingNumber!.isNotEmpty) {
      bl = linkedShipping.courierTrackingData.trackingNumber!;
    } else if (linkedBooking != null && linkedBooking.bookingConfirmationNo != null && linkedBooking.bookingConfirmationNo!.isNotEmpty) {
      bl = linkedBooking.bookingConfirmationNo!;
    } else if (linkedBooking != null && linkedBooking.containerReleaseOrderNo != null && linkedBooking.containerReleaseOrderNo!.isNotEmpty) {
      bl = linkedBooking.containerReleaseOrderNo!;
    } else if (file.customFileNumber != null && file.customFileNumber!.isNotEmpty) {
      bl = file.customFileNumber!;
    }

    // 7. Invoice Value (FOB)
    double invVal = 0.0;
    if (file.invoicesData.isNotEmpty) {
      invVal = file.invoicesData.fold<double>(0.0, (sum, item) => sum + item.amount);
    }
    if (invVal <= 0.0 && linkedPOs.isNotEmpty) {
      invVal = linkedPOs.fold<double>(0.0, (sum, po) => sum + po.totalAmountFob);
    }
    if (invVal <= 0.0 && file.estimatedCost > 0.0) {
      invVal = file.estimatedCost;
    }

    // 8. Freight Cost
    double freightCost = 0.0;
    final bookedFreight = linkedBooking?.totalFreightCostUsd;
    if (bookedFreight != null && bookedFreight > 0.0) {
      freightCost = bookedFreight;
    }

    // 9. Currency
    String curr = 'USD';
    if (file.invoicesData.isNotEmpty && file.invoicesData.first.currency.isNotEmpty) {
      curr = file.invoicesData.first.currency.toUpperCase();
    } else if (linkedPOs.isNotEmpty && (linkedPOs.first.currencyCode ?? '').isNotEmpty) {
      curr = linkedPOs.first.currencyCode!.toUpperCase();
    } else if (file.estimatedCostCurrency.isNotEmpty) {
      curr = file.estimatedCostCurrency.toUpperCase();
    }

    // 10. Goods Description & Packages & Weight
    int? pkgCount;
    double? grossWeight;
    String? goodsDesc;
    if (file.packingListsData.isNotEmpty) {
      final totalP = file.packingListsData.fold<int>(0, (sum, p) => sum + p.totalPackages);
      final totalW = file.packingListsData.fold<double>(0.0, (sum, p) => sum + p.grossWeightKg);
      if (totalP > 0) pkgCount = totalP;
      if (totalW > 0) grossWeight = totalW;
    }
    if (file.projectNames != null && file.projectNames!.isNotEmpty) {
      goodsDesc = file.projectNames;
    } else if (linkedPOs.isNotEmpty) {
      final descs = linkedPOs.map((po) => po.items.map((it) => it.itemDescription).where((d) => d.isNotEmpty).join(', ')).where((d) => d.isNotEmpty).join('; ');
      if (descs.isNotEmpty) goodsDesc = descs;
    }

    setState(() {
      _selectedImportFileId = file.importFileId;
      _insuredEntityCtrl.text = file.companyName;
      _transportMode = mode;
      if (mode == 'AIR') {
        _coverageClause = 'AIR_ALL_RISKS';
      } else if (_coverageClause == 'AIR_ALL_RISKS') {
        _coverageClause = 'ICC_A';
      }
      if (carrier.isNotEmpty) _carrierCtrl.text = carrier;
      if (vessel.isNotEmpty) _vesselFlightCtrl.text = vessel;
      if (voyage.isNotEmpty) _voyageNoCtrl.text = voyage;
      if (pol.isNotEmpty) _polCtrl.text = pol;
      if (pod.isNotEmpty) _podCtrl.text = pod;
      if (bl.isNotEmpty) _trackingRefCtrl.text = bl;
      _invoiceValueCtrl.text = invVal > 0.0 ? invVal.toStringAsFixed(2) : '0.0';
      _freightCostCtrl.text = freightCost > 0.0 ? freightCost.toStringAsFixed(2) : '0.0';
      _currency = curr;

      if (pkgCount != null) _packageCountCtrl.text = pkgCount.toString();
      if (grossWeight != null) _grossWeightCtrl.text = grossWeight.toStringAsFixed(1);
      if (goodsDesc != null && goodsDesc.isNotEmpty) _goodsDescCtrl.text = goodsDesc;
    });

    _runLiveCalculation();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFiles = ref.watch(importFilesProvider).asData?.value ?? [];

    return Form(
      key: _formKey,
      child: SelectionArea(
        child: CcStageDialogShell(
          title: widget.certificateToEdit == null
              ? l.insuranceDialogNewTitle
              : l.insuranceDialogEditTitle(widget.certificateToEdit!.certificateCode),
          icon: Icons.shield_rounded,
          accent: AppTheme.cobalt,
          maxWidth: 1100,
          chips: [
            if (widget.certificateToEdit != null)
              CcHeaderChip(Icons.tag, widget.certificateToEdit!.certificateCode, ltr: true),
          ],
          confirmLabel: l.insuranceSaveDraftBtn,
          loadingLabel: l.insuranceSavingState,
          isSubmitting: _isSaving,
          onConfirm: _saveCertificate,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.insuranceDialogSubtitle,
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context)),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final left = _buildInputsColumn(l, importFiles);
                  final right = _buildCalculationColumn(l);
                  if (c.maxWidth < 820) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [left, const SizedBox(height: 16), right],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: left),
                      const SizedBox(width: 18),
                      Expanded(flex: 4, child: right),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Left column: linked file, parties, voyage, financial inputs and coverage.
  Widget _buildInputsColumn(AppLocalizations l, List<ImportFileModel> importFiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Linked Import File
        SearchableDropdownField<int>(
          value: _selectedImportFileId,
          labelText: l.insuranceFieldLinkImportFile,
          hintText: l.insuranceFieldLinkImportFileHint,
          items: importFiles
              .map((f) => SearchableDropdownItem(
                    value: f.importFileId,
                    label: '${f.primaryNameWithCode} - ${f.companyName} (${f.incotermCode} - ${f.shipmentMode})',
                  ))
              .toList(),
          onChanged: (val) {
            final selected = importFiles.firstWhere((f) => f.importFileId == val);
            _onImportFileSelected(selected);
          },
        ),
        const SizedBox(height: 12),

        // 2. Insured Entity & Policy Type
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _insuredEntityCtrl,
                decoration: InputDecoration(
                  labelText: l.insuranceFieldInsuredEntity,
                  prefixIcon: const Icon(Icons.person_pin_rounded, size: 18),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l.insuranceFieldInsuredEntityRequired : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: SearchableDropdownField<String>(
                value: _policyType,
                labelText: l.insuranceFieldPolicyType,
                hintText: l.insuranceFieldPolicyTypeHint,
                items: [
                  SearchableDropdownItem(
                    value: 'SPECIFIC',
                    label: l.insurancePolicyTypeSpecific,
                  ),
                  SearchableDropdownItem(
                    value: 'OPEN_DECLARATION',
                    label: l.insurancePolicyTypeOpen,
                  ),
                ],
                onChanged: (v) => setState(() => _policyType = v ?? 'SPECIFIC'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Insurance Provider & Policy Number
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _insuranceCompanyCtrl,
                decoration: InputDecoration(
                  labelText: l.insuranceFieldInsuranceCompany,
                  prefixIcon: const Icon(Icons.assured_workload_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _policyNoCtrl,
                decoration: InputDecoration(
                  labelText: l.insuranceFieldPolicyNumber,
                  prefixIcon: const Icon(Icons.confirmation_number_rounded, size: 18),
                  hintText: 'POL-2026-XXXX',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. Voyage & Transport Details
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.1).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.insuranceSecVoyageDetails,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SearchableDropdownField<String>(
                      value: _transportMode,
                      labelText: l.insuranceFieldTransportMode,
                      hintText: l.insuranceFieldTransportModeHint,
                      items: [
                        SearchableDropdownItem(
                          value: 'OCEAN',
                          label: l.insuranceTransportModeOcean,
                        ),
                        SearchableDropdownItem(
                          value: 'AIR',
                          label: l.insuranceTransportModeAir,
                        ),
                        SearchableDropdownItem(
                          value: 'ROAD',
                          label: l.insuranceTransportModeRoad,
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _transportMode = v ?? 'OCEAN';
                          if (_transportMode == 'AIR') _coverageClause = 'AIR_ALL_RISKS';
                          if (_transportMode == 'OCEAN' && _coverageClause == 'AIR_ALL_RISKS') _coverageClause = 'ICC_A';
                        });
                        _runLiveCalculation();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _carrierCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldCarrier,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _vesselFlightCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldVesselFlight,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _polCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldPol,
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? l.required : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _podCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldPod,
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? l.required : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _trackingRefCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldBlTracking,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Financial Inputs (Invoice + Freight + Currency)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _invoiceValueCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.insuranceFieldInvoiceValue,
                  prefixIcon: const Icon(Icons.receipt_rounded, size: 18),
                ),
                onChanged: (_) => _runLiveCalculation(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _freightCostCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.insuranceFieldFreightCost,
                  prefixIcon: const Icon(Icons.directions_boat_rounded, size: 18),
                ),
                onChanged: (_) => _runLiveCalculation(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: SearchableDropdownField<String>(
                value: _currency,
                labelText: l.insuranceFieldCurrency,
                hintText: l.insuranceFieldCurrencyHint,
                items: [
                  SearchableDropdownItem(value: 'USD', label: l.insuranceCurrUsd),
                  SearchableDropdownItem(value: 'EUR', label: l.insuranceCurrEur),
                  SearchableDropdownItem(value: 'EGP', label: l.insuranceCurrEgp),
                  SearchableDropdownItem(value: 'CNY', label: l.insuranceCurrCny),
                  SearchableDropdownItem(value: 'GBP', label: l.insuranceCurrGbp),
                ],
                onChanged: (v) {
                  setState(() => _currency = v ?? 'USD');
                  _runLiveCalculation();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 6. Coverage Clauses & War/Strikes Toggle
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.emerald.withValues(alpha: 0.1).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.insuranceSecCoverageClauses,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
              ),
              const SizedBox(height: 8),
              SearchableDropdownField<String>(
                value: _coverageClause,
                labelText: l.insuranceFieldCoverageClause,
                hintText: l.insuranceFieldCoverageClauseHint,
                items: [
                  SearchableDropdownItem(
                    value: 'ICC_A',
                    label: l.insuranceClauseIccA,
                  ),
                  SearchableDropdownItem(
                    value: 'AIR_ALL_RISKS',
                    label: l.insuranceClauseAirAllRisks,
                  ),
                  SearchableDropdownItem(
                    value: 'ICC_B',
                    label: l.insuranceClauseIccB,
                  ),
                  SearchableDropdownItem(
                    value: 'ICC_C',
                    label: l.insuranceClauseIccC,
                  ),
                ],
                onChanged: (v) {
                  setState(() => _coverageClause = v ?? 'ICC_A');
                  _runLiveCalculation();
                },
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  setState(() => _includeWarAndStrikes = !_includeWarAndStrikes);
                  _runLiveCalculation();
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: _includeWarAndStrikes,
                      activeColor: AppTheme.emerald,
                      onChanged: (v) {
                        setState(() => _includeWarAndStrikes = v ?? true);
                        _runLiveCalculation();
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.insuranceWarAndStrikesTitle,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            l.insuranceWarAndStrikesSubtitle,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Right column: live premium matrix (from POST /cargo-insurance/calculate)
  /// and the cargo specification fields.
  Widget _buildCalculationColumn(AppLocalizations l) {
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Text(
        l.insuranceSecBreakdownTitle,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
      ),
      const SizedBox(height: 12),

      if (_calcError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(_calcError!, style: const TextStyle(color: AppTheme.crimson, fontSize: 12)),
        ),
      if (_calculationPreview != null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderOf(context)),
            boxShadow: [
              BoxShadow(color: AppTheme.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              _buildBreakdownRow(
                l.insuranceBreakdownCifBase,
                '${_calculationPreview!.cifValue.toStringAsFixed(2)} $_currency',
                isBold: false,
              ),
              const Divider(height: 10),
              _buildBreakdownRow(
                l.insuranceBreakdownInsuredValue,
                '${_calculationPreview!.insuredValue.toStringAsFixed(2)} $_currency',
                isBold: true,
                valueColor: AppTheme.cobalt,
              ),
              const Divider(height: 10),
              _buildBreakdownRow(
                l.insuranceBreakdownBasePremium((_calculationPreview!.baseRate * 100).toStringAsFixed(2)),
                '${_calculationPreview!.basePremium.toStringAsFixed(2)} $_currency',
                isBold: false,
              ),
              if (_includeWarAndStrikes) ...[
                const SizedBox(height: 4),
                _buildBreakdownRow(
                  l.insuranceBreakdownWarStrikes,
                  '+ ${_calculationPreview!.warStrikesPremium.toStringAsFixed(2)} $_currency',
                  isBold: false,
                  valueColor: AppTheme.orange,
                ),
              ],
              const Divider(height: 10),
              _buildBreakdownRow(
                l.insuranceBreakdownNetPremium,
                '${_calculationPreview!.netPremium.toStringAsFixed(2)} $_currency',
                isBold: false,
              ),
              const SizedBox(height: 4),
              _buildBreakdownRow(
                l.insuranceBreakdownIssuanceFee,
                '+ ${_calculationPreview!.issuanceFee.toStringAsFixed(2)} $_currency',
                isBold: false,
              ),
              const SizedBox(height: 4),
              _buildBreakdownRow(
                l.insuranceBreakdownTaxes,
                '+ ${_calculationPreview!.taxAmount.toStringAsFixed(2)} $_currency',
                isBold: false,
              ),
              const Divider(height: 14, thickness: 1.5),
              _buildBreakdownRow(
                l.insuranceBreakdownTotalPayable,
                '${_calculationPreview!.totalPayablePremium.toStringAsFixed(2)} $_currency',
                isBold: true,
                valueColor: AppTheme.emerald,
                fontSize: 14,
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),

      // Cargo Specifications
      Text(
        l.insuranceSecCargoSpecs,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: _goodsDescCtrl,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: l.insuranceFieldGoodsDesc,
          hintText: l.insuranceFieldGoodsDescHint,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _packageCountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.insuranceFieldPackagesCount,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _grossWeightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.insuranceFieldGrossWeight,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

        ],
      ),
    );
  }


  Widget _buildBreakdownRow(String label, String value, {bool isBold = false, Color? valueColor, double fontSize = 12}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: AppTheme.charcoal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppTheme.charcoal,
          ),
        ),
      ],
    );
  }

  Future<void> _saveCertificate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final l = context.l10n;

    final payload = {
      'import_file_id': _selectedImportFileId,
      'policy_type': _policyType,
      'insured_entity_name': _insuredEntityCtrl.text.trim(),
      'insurance_company_name': _insuranceCompanyCtrl.text.trim().isNotEmpty ? _insuranceCompanyCtrl.text.trim() : null,
      'policy_number': _policyNoCtrl.text.trim().isNotEmpty ? _policyNoCtrl.text.trim() : null,
      'transport_mode': _transportMode,
      'carrier_name': _carrierCtrl.text.trim().isNotEmpty ? _carrierCtrl.text.trim() : null,
      'vessel_or_flight_no': _vesselFlightCtrl.text.trim().isNotEmpty ? _vesselFlightCtrl.text.trim() : null,
      'voyage_number': _voyageNoCtrl.text.trim().isNotEmpty ? _voyageNoCtrl.text.trim() : null,
      'tracking_reference': _trackingRefCtrl.text.trim().isNotEmpty ? _trackingRefCtrl.text.trim() : null,
      'port_of_loading': _polCtrl.text.trim(),
      'port_of_discharge': _podCtrl.text.trim(),
      'final_destination': _finalDestCtrl.text.trim().isNotEmpty ? _finalDestCtrl.text.trim() : null,
      'currency': _currency,
      if (_optionalNumber(_exchangeRateCtrl) != null) 'exchange_rate': _optionalNumber(_exchangeRateCtrl),
      'invoice_value': double.tryParse(_invoiceValueCtrl.text) ?? 0.0,
      'freight_cost': double.tryParse(_freightCostCtrl.text) ?? 0.0,
      'other_logistics_costs': double.tryParse(_otherCostsCtrl.text) ?? 0.0,
      if (_optionalNumber(_markupCtrl) != null) 'markup_percentage': _optionalNumber(_markupCtrl),
      'coverage_clause': _coverageClause,
      'include_war_and_strikes': _includeWarAndStrikes,
      if (_optionalNumber(_minPremiumCtrl) != null) 'minimum_premium': _optionalNumber(_minPremiumCtrl),
      if (_optionalNumber(_issuanceFeeCtrl) != null) 'issuance_fee': _optionalNumber(_issuanceFeeCtrl),
      if (_optionalNumber(_taxRateCtrl) != null) 'tax_rate': _optionalNumber(_taxRateCtrl),
      'goods_description': _goodsDescCtrl.text.trim().isNotEmpty ? _goodsDescCtrl.text.trim() : null,
      'package_count': int.tryParse(_packageCountCtrl.text),
      'package_type': _packageTypeCtrl.text.trim().isNotEmpty ? _packageTypeCtrl.text.trim() : null,
      'gross_weight_kg': double.tryParse(_grossWeightCtrl.text),
      'survey_agent_in_destination': _surveyAgentCtrl.text.trim().isNotEmpty ? _surveyAgentCtrl.text.trim() : null,
      'claims_payable_at': _claimsPayableAtCtrl.text.trim().isNotEmpty ? _claimsPayableAtCtrl.text.trim() : null,
      'remarks': _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
    };

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (widget.certificateToEdit == null) {
        await ref.read(cargoInsuranceProvider.notifier).createCertificate(payload);
        if (mounted) {
          messenger.showSnackBar(
            AppTheme.snackBar(context, l.insuranceCreatedSuccessMsg, severity: AppSeverity.success),
          );
        }
      } else {
        await ref.read(cargoInsuranceProvider.notifier).updateCertificate(widget.certificateToEdit!.certificateId, payload);
        if (mounted) {
          messenger.showSnackBar(
            AppTheme.snackBar(context, l.insuranceUpdatedSuccessMsg, severity: AppSeverity.success),
          );
        }
      }
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(context, l.insuranceSaveErrorMsg(ApiErrorText.of(l, e)), severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
