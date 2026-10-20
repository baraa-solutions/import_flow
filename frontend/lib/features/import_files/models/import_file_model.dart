import '../../../core/localization/system_messages/system_message_renderer.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/utils/bidi_text.dart';

class InvoiceItemModel {
  final String invoiceNo;
  final String invoiceType;
  final String? date;
  final double amount;
  final String currency;

  InvoiceItemModel({
    required this.invoiceNo,
    this.invoiceType = 'Proforma Invoice',
    this.date,
    this.amount = 0.0,
    this.currency = 'USD',
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      invoiceNo: json['invoice_no'] ?? '',
      invoiceType: json['invoice_type'] ?? 'Proforma Invoice',
      date: json['date'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_no': invoiceNo,
      'invoice_type': invoiceType,
      'date': date,
      'amount': amount,
      'currency': currency,
    };
  }
}

class PackingListItemModel {
  final String plNo;
  final String? date;
  final int totalPackages;
  final double grossWeightKg;
  final double cbm;
  final bool isStackable;

  PackingListItemModel({
    required this.plNo,
    this.date,
    this.totalPackages = 0,
    this.grossWeightKg = 0.0,
    this.cbm = 0.0,
    this.isStackable = true,
  });

  factory PackingListItemModel.fromJson(Map<String, dynamic> json) {
    return PackingListItemModel(
      plNo: json['pl_no'] ?? '',
      date: json['date'],
      totalPackages: json['total_packages'] ?? 0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      cbm: (json['cbm'] as num?)?.toDouble() ?? 0.0,
      isStackable: json['is_stackable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pl_no': plNo,
      'date': date,
      'total_packages': totalPackages,
      'gross_weight_kg': grossWeightKg,
      'cbm': cbm,
      'is_stackable': isStackable,
    };
  }
}

class ImportFileModel {
  final int importFileId;
  final String importFileCode;
  final String? customFileNumber;
  final int? companyId;
  final String companyName;
  final int? supplierId;
  final String supplierName;
  final int? brokerId;
  final String? brokerName;
  final String? poNumber;
  final List<int>? poIds;
  final String? piNumber;
  final List<InvoiceItemModel> invoicesData;
  final List<PackingListItemModel> packingListsData;
  final List<int> projectIds;
  final String? projectNames;
  final String shipmentMode;
  final String incotermCode;
  final String priority;
  final String shipmentCategory;
  final String? requiredEta;
  final String? fileOpeningDate;
  final String? selectedScenario;
  final String? pickupAddress;
  final String? portOfLoading;
  final String? portOfDischarge;
  final String? cargoReadyDate;
  final int? targetFreeDays;
  final String? serviceTypePreference;
  final String? shippingInstructionsNotes;
  final String? acidNumber;
  final String? acidRequestDate;
  final String? acidIssueDate;
  final String? acidExpiryDate;
  final int? acidExecutionDays;
  final bool isCustomsReleased;
  final String? customsReleasedAt;
  final String? customsReleasePermitNo;
  final String? customsReleaseType;
  final String? customsReleaseOfficer;
  final String? customsGatePassNo;
  final String? blNumber;
  final String? bookingNo;
  final String? vesselName;
  final double totalClearanceExpensesEgp;
  final String clearanceInvoicesStatus;
  final String inlandTransportStatus;
  final String? inlandTransportBookingNo;
  final String? inlandCarrierName;
  final String? inlandTruckPlateNo;
  final String? inlandDriverName;
  final String? inlandDriverPhone;
  final double inlandTransportCostEgp;
  final String? inlandDepartureDate;
  final String? inlandExpectedArrivalDate;
  final String? inlandActualArrivalDate;
  final String? emptyContainersReturnedAt;
  final String? emptyContainersReturnStatus;
  final String? emptyContainersEirNumbers;
  final String? emptyContainersDepotName;
  final String? financialSettlementStatus;
  final String? financialSettlementDate;
  final int financialSettlementInvoicesCount;
  final double financialSettlementTotalEgp;
  final double actualLandedCostTotalEgp;
  final double actualLandedCostMarkupFactor;
  final double actualLandedCostVarianceEgp;
  final double actualLandedCostVariancePct;
  final String? actualLandedCostCalculatedAt;
  final String? dossierExportedAt;
  final String? dossierExportedBy;
  final String? form4No;
  final String? form4RequestDate;
  final String? form4ReceivedDate;
  final int? form4ExecutionDays;
  final String? swiftNo;
  final String? form46No;
  final String? form46Date;
  final String? form46Status;
  final int? cargoxEnvelopeId;
  final String? cargoxEnvelopeCode;
  final String? cargoxEnvelopeStatus;
  final String? cargoxTransferredAt;
  final String? originalDocumentsStatus;
  final String? originalDocumentsReceivedAt;
  final String? originalDocumentsCourierNo;
  final String? originalDocumentsSessionCode;
  final String? customsBrokerDelegationNo;
  final String? customsBrokerDelegatedAt;
  final String? customsBrokerAuthorizationStatus;
  final String? deliveryOrderNo;
  final String? deliveryOrderDate;
  final String? deliveryOrderExpiryDate;
  final String? deliveryOrderStatus;
  final double customsDutyPaidAmount;
  final String? customsDutyReceiptNo;
  final String? customsDutySadadNo;
  final String? customsDutyPaymentDate;
  final String? customsDutyPaymentStatus;
  final double estimatedCost;
  final String estimatedCostCurrency;
  final String currentModule;
  final String currentStage;
  final double progressPercent;
  final String nextAction;
  final String? initialStartingStage;
  final String? initialStartingStep;
  final String? pausedAtStage;
  final String? pausedAtStep;
  final String? holdReason;
  /// HOLD_REASON code when the hold used a predefined reason (null for free text / legacy rows).
  final String? holdReasonCode;
  /// Single-language storage codes next to the English text columns (null on legacy rows):
  /// [currentModule] -> [currentStepCode], [currentStage] -> [currentPhaseId] / [currentStageCode],
  /// [nextAction] -> [nextActionCode] + [nextActionParams].
  final String? currentStepCode;
  final int? currentPhaseId;
  final String? currentStageCode;
  final String? nextActionCode;
  final Map<String, dynamic>? nextActionParams;
  final String? holdDate;
  final List<String> skippedStages;
  final String status;
  final String owner;
  final String? notes;
  final String? closureReason;
  final String? closedAtPhase;
  final String? hsCode;
  final String? productCategory;
  final bool isActive;
  final int? clonedFromId;
  final String? clonedFromCode;
  final int? parentImportFileId;
  final String? parentFileCode;
  final bool isPartialShipment;
  final String createdAt;
  final String updatedAt;

  bool get isChildPartial => parentImportFileId != null;
  bool get isParentPartial => isPartialShipment && parentImportFileId == null;

  String get displayName => (customFileNumber != null && customFileNumber!.trim().isNotEmpty)
      ? customFileNumber!.trim()
      : importFileCode;

  /// Returns the primary file title with code:
  /// e.g. "PET Stock (IMP-2026-0004)" or "IMP-2026-0004" if no custom name
  String get primaryNameWithCode {
    if (customFileNumber != null &&
        customFileNumber!.trim().isNotEmpty &&
        customFileNumber!.trim() != importFileCode) {
      return '${customFileNumber!.trim()} ($importFileCode)';
    }
    return importFileCode;
  }

  ImportFileModel({
    required this.importFileId,
    required this.importFileCode,
    this.customFileNumber,
    this.companyId,
    required this.companyName,
    this.supplierId,
    required this.supplierName,
    this.brokerId,
    this.brokerName,
    this.poNumber,
    this.poIds,
    this.piNumber,
    this.invoicesData = const [],
    this.packingListsData = const [],
    this.projectIds = const [],
    this.projectNames,
    this.shipmentMode = 'Sea FCL',
    this.incotermCode = 'FOB',
    this.priority = 'High',
    this.shipmentCategory = 'New Purchase',
    this.requiredEta,
    this.fileOpeningDate,
    this.selectedScenario,
    this.pickupAddress,
    this.portOfLoading,
    this.portOfDischarge = 'El Dekheila Port (non TMT)',
    this.cargoReadyDate,
    this.targetFreeDays = 21,
    this.serviceTypePreference = 'Direct',
    this.shippingInstructionsNotes,
    this.acidNumber,
    this.acidRequestDate,
    this.acidIssueDate,
    this.acidExpiryDate,
    this.acidExecutionDays,
    this.isCustomsReleased = false,
    this.customsReleasedAt,
    this.customsReleasePermitNo,
    this.customsReleaseType,
    this.customsReleaseOfficer,
    this.customsGatePassNo,
    this.blNumber,
    this.bookingNo,
    this.vesselName,
    this.totalClearanceExpensesEgp = 0.0,
    this.clearanceInvoicesStatus = 'Pending Invoices',
    this.inlandTransportStatus = 'Not Booked',
    this.inlandTransportBookingNo,
    this.inlandCarrierName,
    this.inlandTruckPlateNo,
    this.inlandDriverName,
    this.inlandDriverPhone,
    this.inlandTransportCostEgp = 0.0,
    this.inlandDepartureDate,
    this.inlandExpectedArrivalDate,
    this.inlandActualArrivalDate,
    this.emptyContainersReturnedAt,
    this.emptyContainersReturnStatus,
    this.emptyContainersEirNumbers,
    this.emptyContainersDepotName,
    this.financialSettlementStatus,
    this.financialSettlementDate,
    this.financialSettlementInvoicesCount = 0,
    this.financialSettlementTotalEgp = 0.0,
    this.actualLandedCostTotalEgp = 0.0,
    this.actualLandedCostMarkupFactor = 1.0,
    this.actualLandedCostVarianceEgp = 0.0,
    this.actualLandedCostVariancePct = 0.0,
    this.actualLandedCostCalculatedAt,
    this.dossierExportedAt,
    this.dossierExportedBy,
    this.form4No,
    this.form4RequestDate,
    this.form4ReceivedDate,
    this.form4ExecutionDays,
    this.swiftNo,
    this.form46No,
    this.form46Date,
    this.form46Status,
    this.cargoxEnvelopeId,
    this.cargoxEnvelopeCode,
    this.cargoxEnvelopeStatus,
    this.cargoxTransferredAt,
    this.originalDocumentsStatus,
    this.originalDocumentsReceivedAt,
    this.originalDocumentsCourierNo,
    this.originalDocumentsSessionCode,
    this.customsBrokerDelegationNo,
    this.customsBrokerDelegatedAt,
    this.customsBrokerAuthorizationStatus,
    this.deliveryOrderNo,
    this.deliveryOrderDate,
    this.deliveryOrderExpiryDate,
    this.deliveryOrderStatus,
    this.customsDutyPaidAmount = 0.0,
    this.customsDutyReceiptNo,
    this.customsDutySadadNo,
    this.customsDutyPaymentDate,
    this.customsDutyPaymentStatus,
    this.estimatedCost = 0.0,
    this.estimatedCostCurrency = 'USD',
    required this.currentModule,
    required this.currentStage,
    this.progressPercent = 10.0,
    required this.nextAction,
    this.initialStartingStage = 'Phase 1 - Planning & Feasibility',
    this.initialStartingStep = 'STEP_01',
    this.pausedAtStage,
    this.pausedAtStep,
    this.holdReason,
    this.holdReasonCode,
    this.currentStepCode,
    this.currentPhaseId,
    this.currentStageCode,
    this.nextActionCode,
    this.nextActionParams,
    this.holdDate,
    this.skippedStages = const [],
    this.status = 'Open',
    this.owner = 'Kamal',
    this.notes,
    this.closureReason,
    this.closedAtPhase,
    this.hsCode,
    this.productCategory,
    this.isActive = true,
    this.clonedFromId,
    this.clonedFromCode,
    this.parentImportFileId,
    this.parentFileCode,
    this.isPartialShipment = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Value for DisplayNameResolver.resolveStepName: [currentStepCode] when the backend
  /// sent it, else the legacy [currentModule] text (`STEP_xx ...`).
  String get displayStepKey => currentStepCode ?? currentModule;

  /// Stage/phase label for coded rows, or null for legacy rows (callers then resolve the
  /// legacy text with DisplayNameResolver):
  /// - a special stage code (CUSTOMS_RELEASED, DUTY_PAID, ...) -> its STAGE label, else the
  ///   stored [currentStage] text;
  /// - otherwise [currentPhaseId] (or PHASE_n) -> the backend phase title.
  String? codedStageLabel(AppLocalizations l10n) {
    final stage = currentStageCode;
    if (stage != null && !stage.startsWith('PHASE_')) {
      return DomainEnums.labelIfKnown(l10n, DomainEnumType.stage, stage) ??
          (currentStage.trim().isNotEmpty ? currentStage : stage);
    }
    final id = currentPhaseId ?? (stage == null ? null : int.tryParse(stage.substring(6)));
    return id == null ? null : SystemMessageRenderer.phaseTitle(id, isArabic: l10n.isArabic);
  }

  /// Stage/phase to show: [codedStageLabel], else [legacy] applied to [currentStage].
  String displayStage(AppLocalizations l10n, String Function(String legacyText) legacy) =>
      codedStageLabel(l10n) ?? legacy(currentStage);

  /// [nextAction] rendered from [nextActionCode], or null when there is no usable code.
  String? renderedNextAction(AppLocalizations l10n) => SystemMessageRenderer.tryRender(
      code: nextActionCode, params: nextActionParams, part: SystemMessagePart.action, l10n: l10n);

  /// Next action to show: the rendered code, else the stored text through
  /// [DisplayNameResolver.resolveActionTitle] (legacy rows).
  /// [forExport] strips the bidi isolates (clipboard, CSV/Excel/PDF).
  String displayNextAction(AppLocalizations l10n, {bool forExport = false}) {
    final text = renderedNextAction(l10n) ?? DisplayNameResolver.resolveActionTitle(nextAction, isArabic: l10n.isArabic);
    return forExport ? stripBidiIsolates(text) : text;
  }

  static int? _parseInt(Object? raw) =>
      raw is num ? raw.toInt() : int.tryParse(raw?.toString().trim() ?? '');

  factory ImportFileModel.fromJson(Map<String, dynamic> json) {
    var rawInvoices = json['invoices_data'] as List<dynamic>? ?? [];
    var rawPacking = json['packing_lists_data'] as List<dynamic>? ?? [];
    var rawProjects = json['project_ids'] as List<dynamic>? ?? [];
    var rawSkipped = json['skipped_stages'] as List<dynamic>? ?? [];

    return ImportFileModel(
      importFileId: json['import_file_id'],
      importFileCode: json['import_file_code'] ?? '',
      customFileNumber: json['custom_file_number'],
      companyId: json['company_id'],
      companyName: json['company_name'] ?? '',
      supplierId: json['supplier_id'],
      supplierName: json['supplier_name'] ?? '',
      brokerId: json['broker_id'],
      brokerName: json['broker_name'],
      poNumber: json['po_number'],
      poIds: (json['po_ids'] as List<dynamic>?)?.map((e) => e as int).toList(),
      piNumber: json['pi_number'],
      invoicesData: rawInvoices.map((i) => InvoiceItemModel.fromJson(i)).toList(),
      packingListsData: rawPacking.map((p) => PackingListItemModel.fromJson(p)).toList(),
      projectIds: rawProjects.map((p) => p as int).toList(),
      projectNames: json['project_names'],
      shipmentMode: json['shipment_mode'] ?? 'Sea FCL',
      incotermCode: json['incoterm_code'] ?? 'FOB',
      priority: json['priority'] ?? 'High',
      shipmentCategory: json['shipment_category'] ?? 'New Purchase',
      requiredEta: json['required_eta'],
      fileOpeningDate: json['file_opening_date'],
      selectedScenario: json['selected_scenario'],
      pickupAddress: json['pickup_address'],
      portOfLoading: json['port_of_loading'],
      portOfDischarge: json['port_of_discharge'] ?? 'El Dekheila Port (non TMT)',
      cargoReadyDate: json['cargo_ready_date'],
      targetFreeDays: json['target_free_days'] as int? ?? 21,
      serviceTypePreference: json['service_type_preference'] ?? 'Direct',
      shippingInstructionsNotes: json['shipping_instructions_notes'],
      acidNumber: json['acid_number'],
      acidRequestDate: json['acid_request_date'],
      acidIssueDate: json['acid_issue_date'],
      acidExpiryDate: json['acid_expiry_date'],
      acidExecutionDays: json['acid_execution_days'] as int?,
      isCustomsReleased: json['is_customs_released'] ?? false,
      customsReleasedAt: json['customs_released_at'],
      customsReleasePermitNo: json['customs_release_permit_no'],
      customsReleaseType: json['customs_release_type'],
      customsReleaseOfficer: json['customs_release_officer'],
      customsGatePassNo: json['customs_gate_pass_no'],
      blNumber: json['bl_number'],
      bookingNo: json['booking_no'],
      vesselName: json['vessel_name'],
      totalClearanceExpensesEgp: (json['total_clearance_expenses_egp'] as num?)?.toDouble() ?? 0.0,
      clearanceInvoicesStatus: json['clearance_invoices_status'] ?? 'Pending Invoices',
      inlandTransportStatus: json['inland_transport_status'] ?? 'Not Booked',
      inlandTransportBookingNo: json['inland_transport_booking_no'],
      inlandCarrierName: json['inland_carrier_name'],
      inlandTruckPlateNo: json['inland_truck_plate_no'],
      inlandDriverName: json['inland_driver_name'],
      inlandDriverPhone: json['inland_driver_phone'],
      inlandTransportCostEgp: (json['inland_transport_cost_egp'] as num?)?.toDouble() ?? 0.0,
      inlandDepartureDate: json['inland_departure_date'],
      inlandExpectedArrivalDate: json['inland_expected_arrival_date'],
      inlandActualArrivalDate: json['inland_actual_arrival_date'],
      emptyContainersReturnedAt: json['empty_containers_returned_at'],
      emptyContainersReturnStatus: json['empty_containers_return_status'],
      emptyContainersEirNumbers: json['empty_containers_eir_numbers'],
      emptyContainersDepotName: json['empty_containers_depot_name'],
      financialSettlementStatus: json['financial_settlement_status'],
      financialSettlementDate: json['financial_settlement_date'],
      financialSettlementInvoicesCount: json['financial_settlement_invoices_count'] as int? ?? 0,
      financialSettlementTotalEgp: (json['financial_settlement_total_egp'] as num?)?.toDouble() ?? 0.0,
      actualLandedCostTotalEgp: (json['actual_landed_cost_total_egp'] as num?)?.toDouble() ?? 0.0,
      actualLandedCostMarkupFactor: (json['actual_landed_cost_markup_factor'] as num?)?.toDouble() ?? 1.0,
      actualLandedCostVarianceEgp: (json['actual_landed_cost_variance_egp'] as num?)?.toDouble() ?? 0.0,
      actualLandedCostVariancePct: (json['actual_landed_cost_variance_pct'] as num?)?.toDouble() ?? 0.0,
      actualLandedCostCalculatedAt: json['actual_landed_cost_calculated_at'],
      dossierExportedAt: json['dossier_exported_at'],
      dossierExportedBy: json['dossier_exported_by'],
      form4No: json['form4_no'],
      form4RequestDate: json['form4_request_date'],
      form4ReceivedDate: json['form4_received_date'],
      form4ExecutionDays: json['form4_execution_days'] as int?,
      swiftNo: json['swift_no'],
      form46No: json['form46_no'],
      form46Date: json['form46_date'],
      form46Status: json['form46_status'],
      cargoxEnvelopeId: json['cargox_envelope_id'],
      cargoxEnvelopeCode: json['cargox_envelope_code'],
      cargoxEnvelopeStatus: json['cargox_envelope_status'],
      cargoxTransferredAt: json['cargox_transferred_at'],
      originalDocumentsStatus: json['original_documents_status'],
      originalDocumentsReceivedAt: json['original_documents_received_at'],
      originalDocumentsCourierNo: json['original_documents_courier_no'],
      originalDocumentsSessionCode: json['original_documents_session_code'],
      customsBrokerDelegationNo: json['customs_broker_delegation_no'],
      customsBrokerDelegatedAt: json['customs_broker_delegated_at'],
      customsBrokerAuthorizationStatus: json['customs_broker_authorization_status'],
      deliveryOrderNo: json['delivery_order_no'],
      deliveryOrderDate: json['delivery_order_date'],
      deliveryOrderExpiryDate: json['delivery_order_expiry_date'],
      deliveryOrderStatus: json['delivery_order_status'],
      customsDutyPaidAmount: (json['customs_duty_paid_amount'] as num?)?.toDouble() ?? 0.0,
      customsDutyReceiptNo: json['customs_duty_receipt_no'],
      customsDutySadadNo: json['customs_duty_sadad_no'],
      customsDutyPaymentDate: json['customs_duty_payment_date'],
      customsDutyPaymentStatus: json['customs_duty_payment_status'],
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      estimatedCostCurrency: json['estimated_cost_currency'] ?? 'USD',
      currentModule: json['current_module'] ?? '',
      currentStage: json['current_stage'] ?? '',
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      nextAction: json['next_action'] ?? '',
      initialStartingStage: json['initial_starting_stage'],
      initialStartingStep: json['initial_starting_step'],
      pausedAtStage: json['paused_at_stage'],
      pausedAtStep: json['paused_at_step'],
      holdReason: json['hold_reason'],
      holdReasonCode: json['hold_reason_code'] as String?,
      currentStepCode: SystemMessageRenderer.parseCode(json['current_step_code']),
      currentPhaseId: _parseInt(json['current_phase_id']),
      currentStageCode: SystemMessageRenderer.parseCode(json['current_stage_code']),
      nextActionCode: SystemMessageRenderer.parseCode(json['next_action_code']),
      nextActionParams: SystemMessageRenderer.parseParams(json['next_action_params']),
      holdDate: json['hold_date'],
      skippedStages: rawSkipped.map((s) => s.toString()).toList(),
      status: json['status'] ?? 'Open',
      owner: json['owner'] ?? 'Kamal',
      notes: json['notes'],
      closureReason: json['closure_reason'],
      closedAtPhase: json['closed_at_phase'],
      hsCode: json['hs_code'],
      productCategory: json['product_category'],
      isActive: json['is_active'] ?? true,
      clonedFromId: json['cloned_from_id'],
      clonedFromCode: json['cloned_from_code'],
      parentImportFileId: json['parent_import_file_id'] as int?,
      parentFileCode: json['parent_file_code'] as String?,
      isPartialShipment: json['is_partial_shipment'] as bool? ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      if (clonedFromId != null) 'cloned_from_id': clonedFromId,
      if (clonedFromCode != null) 'cloned_from_code': clonedFromCode,
      if (parentImportFileId != null) 'parent_import_file_id': parentImportFileId,
      if (parentFileCode != null) 'parent_file_code': parentFileCode,
      'is_partial_shipment': isPartialShipment,
      if (hsCode != null) 'hs_code': hsCode,
      if (productCategory != null) 'product_category': productCategory,
      'custom_file_number': customFileNumber,
      'company_id': companyId,
      'company_name': companyName,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'broker_id': brokerId,
      'broker_name': brokerName,
      'po_number': poNumber,
      'po_ids': poIds,
      'pi_number': piNumber,
      'invoices_data': invoicesData.map((i) => i.toJson()).toList(),
      'packing_lists_data': packingListsData.map((p) => p.toJson()).toList(),
      'project_ids': projectIds,
      'project_names': projectNames,
      'shipment_mode': shipmentMode,
      'incoterm_code': incotermCode,
      'priority': priority,
      'shipment_category': shipmentCategory,
      'required_eta': requiredEta,
      'file_opening_date': fileOpeningDate,
      'selected_scenario': selectedScenario,
      'pickup_address': pickupAddress,
      'port_of_loading': portOfLoading,
      'port_of_discharge': portOfDischarge,
      'cargo_ready_date': cargoReadyDate,
      'target_free_days': targetFreeDays,
      'service_type_preference': serviceTypePreference,
      'shipping_instructions_notes': shippingInstructionsNotes,
      'acid_number': acidNumber,
      'acid_request_date': acidRequestDate,
      'acid_issue_date': acidIssueDate,
      'acid_expiry_date': acidExpiryDate,
      'acid_execution_days': acidExecutionDays,
      'is_customs_released': isCustomsReleased,
      'customs_released_at': customsReleasedAt,
      if (customsReleasePermitNo != null) 'customs_release_permit_no': customsReleasePermitNo,
      if (blNumber != null) 'bl_number': blNumber,
      if (bookingNo != null) 'booking_no': bookingNo,
      if (vesselName != null) 'vessel_name': vesselName,
      if (customsReleaseType != null) 'customs_release_type': customsReleaseType,
      if (customsReleaseOfficer != null) 'customs_release_officer': customsReleaseOfficer,
      if (customsGatePassNo != null) 'customs_gate_pass_no': customsGatePassNo,
      if (totalClearanceExpensesEgp > 0) 'total_clearance_expenses_egp': totalClearanceExpensesEgp,
      'clearance_invoices_status': clearanceInvoicesStatus,
      'inland_transport_status': inlandTransportStatus,
      if (inlandTransportBookingNo != null) 'inland_transport_booking_no': inlandTransportBookingNo,
      if (inlandCarrierName != null) 'inland_carrier_name': inlandCarrierName,
      if (inlandTruckPlateNo != null) 'inland_truck_plate_no': inlandTruckPlateNo,
      if (inlandDriverName != null) 'inland_driver_name': inlandDriverName,
      if (inlandDriverPhone != null) 'inland_driver_phone': inlandDriverPhone,
      if (inlandTransportCostEgp > 0) 'inland_transport_cost_egp': inlandTransportCostEgp,
      if (inlandDepartureDate != null) 'inland_departure_date': inlandDepartureDate,
      if (inlandExpectedArrivalDate != null) 'inland_expected_arrival_date': inlandExpectedArrivalDate,
      if (inlandActualArrivalDate != null) 'inland_actual_arrival_date': inlandActualArrivalDate,
      if (emptyContainersReturnedAt != null) 'empty_containers_returned_at': emptyContainersReturnedAt,
      if (emptyContainersReturnStatus != null) 'empty_containers_return_status': emptyContainersReturnStatus,
      if (emptyContainersEirNumbers != null) 'empty_containers_eir_numbers': emptyContainersEirNumbers,
      if (emptyContainersDepotName != null) 'empty_containers_depot_name': emptyContainersDepotName,
      if (financialSettlementStatus != null) 'financial_settlement_status': financialSettlementStatus,
      if (financialSettlementDate != null) 'financial_settlement_date': financialSettlementDate,
      'financial_settlement_invoices_count': financialSettlementInvoicesCount,
      'financial_settlement_total_egp': financialSettlementTotalEgp,
      'actual_landed_cost_total_egp': actualLandedCostTotalEgp,
      'actual_landed_cost_markup_factor': actualLandedCostMarkupFactor,
      'actual_landed_cost_variance_egp': actualLandedCostVarianceEgp,
      'actual_landed_cost_variance_pct': actualLandedCostVariancePct,
      if (actualLandedCostCalculatedAt != null) 'actual_landed_cost_calculated_at': actualLandedCostCalculatedAt,
      if (dossierExportedAt != null) 'dossier_exported_at': dossierExportedAt,
      if (dossierExportedBy != null) 'dossier_exported_by': dossierExportedBy,
      'form4_no': form4No,
      'form4_request_date': form4RequestDate,
      'form4_received_date': form4ReceivedDate,
      'form4_execution_days': form4ExecutionDays,
      'swift_no': swiftNo,
      'form46_no': form46No,
      'form46_date': form46Date,
      'form46_status': form46Status,
      if (cargoxEnvelopeId != null) 'cargox_envelope_id': cargoxEnvelopeId,
      if (cargoxEnvelopeCode != null) 'cargox_envelope_code': cargoxEnvelopeCode,
      if (cargoxEnvelopeStatus != null) 'cargox_envelope_status': cargoxEnvelopeStatus,
      if (cargoxTransferredAt != null) 'cargox_transferred_at': cargoxTransferredAt,
      if (originalDocumentsStatus != null) 'original_documents_status': originalDocumentsStatus,
      if (originalDocumentsReceivedAt != null) 'original_documents_received_at': originalDocumentsReceivedAt,
      if (originalDocumentsCourierNo != null) 'original_documents_courier_no': originalDocumentsCourierNo,
      if (originalDocumentsSessionCode != null) 'original_documents_session_code': originalDocumentsSessionCode,
      if (customsBrokerDelegationNo != null) 'customs_broker_delegation_no': customsBrokerDelegationNo,
      if (customsBrokerDelegatedAt != null) 'customs_broker_delegated_at': customsBrokerDelegatedAt,
      if (customsBrokerAuthorizationStatus != null) 'customs_broker_authorization_status': customsBrokerAuthorizationStatus,
      if (deliveryOrderNo != null) 'delivery_order_no': deliveryOrderNo,
      if (deliveryOrderDate != null) 'delivery_order_date': deliveryOrderDate,
      if (deliveryOrderExpiryDate != null) 'delivery_order_expiry_date': deliveryOrderExpiryDate,
      if (deliveryOrderStatus != null) 'delivery_order_status': deliveryOrderStatus,
      if (customsDutyPaidAmount > 0) 'customs_duty_paid_amount': customsDutyPaidAmount,
      if (customsDutyReceiptNo != null) 'customs_duty_receipt_no': customsDutyReceiptNo,
      if (customsDutySadadNo != null) 'customs_duty_sadad_no': customsDutySadadNo,
      if (customsDutyPaymentDate != null) 'customs_duty_payment_date': customsDutyPaymentDate,
      if (customsDutyPaymentStatus != null) 'customs_duty_payment_status': customsDutyPaymentStatus,
      'estimated_cost': estimatedCost,
      'estimated_cost_currency': estimatedCostCurrency,
      if (initialStartingStage != null) 'initial_starting_stage': initialStartingStage,
      if (initialStartingStep != null) 'initial_starting_step': initialStartingStep,
      if (pausedAtStage != null) 'paused_at_stage': pausedAtStage,
      if (pausedAtStep != null) 'paused_at_step': pausedAtStep,
      if (holdReason != null) 'hold_reason': holdReason,
      if (holdReasonCode != null) 'hold_reason_code': holdReasonCode,
      if (holdDate != null) 'hold_date': holdDate,
      'skipped_stages': skippedStages,
      'status': status,
      'owner': owner,
      'notes': notes,
      'is_active': isActive,
    };
  }
}

class FreightRfqDataModel {
  final int importFileId;
  final String importFileCode;
  final String? customFileNumber;
  final String companyName;
  final String supplierName;
  final String incotermCode;
  final String commodity;
  final String hsCodes;
  final String shipmentMode;
  final bool isAir;
  final String recommendedContainers;
  final double totalCbm;
  final double grossWeightKg;
  final double netWeightKg;
  final double volumetricWeightKg;
  final double chargeableWeightKg;
  final int totalPackages;
  final String packagesBreakdown;
  final String stackability;
  final String pickupAddress;
  final String portOfLoading;
  final String portOfDischarge;
  final String cargoReadyDate;
  final int targetFreeDays;
  final String serviceType;
  final String specialRequirements;
  final String emailSubject;
  final String emailBodyTemplate;
  final String whatsappTextTemplate;

  FreightRfqDataModel({
    required this.importFileId,
    required this.importFileCode,
    this.customFileNumber,
    required this.companyName,
    required this.supplierName,
    required this.incotermCode,
    required this.commodity,
    this.hsCodes = '',
    required this.shipmentMode,
    this.isAir = false,
    required this.recommendedContainers,
    required this.totalCbm,
    required this.grossWeightKg,
    required this.netWeightKg,
    this.volumetricWeightKg = 0.0,
    this.chargeableWeightKg = 0.0,
    required this.totalPackages,
    required this.packagesBreakdown,
    this.stackability = 'Stackable',
    required this.pickupAddress,
    required this.portOfLoading,
    required this.portOfDischarge,
    required this.cargoReadyDate,
    required this.targetFreeDays,
    required this.serviceType,
    required this.specialRequirements,
    required this.emailSubject,
    required this.emailBodyTemplate,
    required this.whatsappTextTemplate,
  });

  factory FreightRfqDataModel.fromJson(Map<String, dynamic> json) {
    return FreightRfqDataModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      customFileNumber: json['custom_file_number'],
      companyName: json['company_name'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      incotermCode: json['incoterm_code'] ?? 'EXW',
      commodity: json['commodity'] ?? '',
      hsCodes: json['hs_codes_str'] ?? (json['hs_codes'] is List ? (json['hs_codes'] as List).join(', ') : ''),
      shipmentMode: json['shipment_mode'] ?? 'Sea FCL',
      isAir: json['is_air'] ?? (json['shipment_mode']?.toString().toLowerCase().contains('air') == true),
      recommendedContainers: json['recommended_containers'] ?? '',
      totalCbm: (json['total_cbm'] as num?)?.toDouble() ?? 0.0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      netWeightKg: (json['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      volumetricWeightKg: (json['volumetric_weight_kg'] as num?)?.toDouble() ?? 0.0,
      chargeableWeightKg: (json['chargeable_weight_kg'] as num?)?.toDouble() ?? ((json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0),
      totalPackages: (json['total_packages'] as num?)?.toInt() ?? 0,
      packagesBreakdown: json['packages_breakdown'] ?? '',
      stackability: json['stackability'] ?? 'Stackable',
      pickupAddress: json['pickup_address'] ?? '',
      portOfLoading: json['port_of_loading'] ?? '',
      portOfDischarge: json['port_of_discharge'] ?? '',
      cargoReadyDate: json['cargo_ready_date'] ?? '',
      targetFreeDays: (json['target_free_days'] as num?)?.toInt() ?? 21,
      serviceType: json['service_type'] ?? 'Direct',
      specialRequirements: json['special_requirements'] ?? '',
      emailSubject: json['email_subject'] ?? '',
      emailBodyTemplate: json['email_body_template'] ?? '',
      whatsappTextTemplate: json['whatsapp_text_template'] ?? '',
    );
  }
}

class ImportMasterReportSummaryModel {
  final int totalImportFiles;
  final int openFilesCount;
  final int inProgressCount;
  final int closedFilesCount;
  final double? totalEstimatedCost;
  final Map<String, double> estimatedCostByCurrency;
  final List<ImportFileModel> files;

  ImportMasterReportSummaryModel({
    required this.totalImportFiles,
    required this.openFilesCount,
    required this.inProgressCount,
    required this.closedFilesCount,
    this.totalEstimatedCost,
    this.estimatedCostByCurrency = const {},
    required this.files,
  });

  factory ImportMasterReportSummaryModel.fromJson(Map<String, dynamic> json) {
    var rawFiles = json['files'] as List<dynamic>? ?? [];
    final Map<String, double> costByCurrency = {};
    if (json['estimated_cost_by_currency'] != null && json['estimated_cost_by_currency'] is Map) {
      (json['estimated_cost_by_currency'] as Map).forEach((k, v) {
        if (v is num) {
          costByCurrency[k.toString()] = v.toDouble();
        }
      });
    }
    return ImportMasterReportSummaryModel(
      totalImportFiles: json['total_import_files'] ?? 0,
      openFilesCount: json['open_files_count'] ?? 0,
      inProgressCount: json['in_progress_count'] ?? 0,
      closedFilesCount: json['closed_files_count'] ?? 0,
      totalEstimatedCost: (json['total_estimated_cost'] as num?)?.toDouble(),
      estimatedCostByCurrency: costByCurrency,
      files: rawFiles.map((f) => ImportFileModel.fromJson(f)).toList(),
    );
  }
}
