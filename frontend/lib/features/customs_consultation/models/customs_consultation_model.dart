import 'dart:convert';

class ClearanceExpenseTypeModel {
  final int expenseId;
  final String expenseCode;
  final String nameAr;
  final String? nameEn;
  final String category;
  final String defaultUnit;
  final String defaultCurrency;
  final int displayOrder;
  final bool isActive;

  ClearanceExpenseTypeModel({
    required this.expenseId,
    required this.expenseCode,
    required this.nameAr,
    this.nameEn,
    required this.category,
    required this.defaultUnit,
    this.defaultCurrency = 'EGP',
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory ClearanceExpenseTypeModel.fromJson(Map<String, dynamic> json) {
    return ClearanceExpenseTypeModel(
      expenseId: json['expense_id'] ?? 0,
      expenseCode: json['expense_code'] ?? '',
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'],
      category: json['category'] ?? 'CLEARANCE_FEES',
      defaultUnit: json['default_unit'] ?? 'PER_INVOICE',
      defaultCurrency: json['default_currency'] ?? 'EGP',
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expense_id': expenseId,
      'expense_code': expenseCode,
      'name_ar': nameAr,
      if (nameEn != null) 'name_en': nameEn,
      'category': category,
      'default_unit': defaultUnit,
      'default_currency': defaultCurrency,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }
}

class BrokerPriceListItemModel {
  final int? itemId;
  final int? priceListId;
  final int? expenseTypeId;
  final String expenseName;
  final String category;
  final String unitType;
  final double standardPrice;
  final String currency;
  final double? minPrice;
  final double? maxPrice;
  final String? notes;
  final bool isActive;

  BrokerPriceListItemModel({
    this.itemId,
    this.priceListId,
    this.expenseTypeId,
    required this.expenseName,
    required this.category,
    required this.unitType,
    required this.standardPrice,
    this.currency = 'EGP',
    this.minPrice,
    this.maxPrice,
    this.notes,
    this.isActive = true,
  });

  factory BrokerPriceListItemModel.fromJson(Map<String, dynamic> json) {
    return BrokerPriceListItemModel(
      itemId: json['item_id'],
      priceListId: json['price_list_id'],
      expenseTypeId: json['expense_type_id'],
      expenseName: json['expense_name'] ?? '',
      category: json['category'] ?? '',
      unitType: json['unit_type'] ?? 'Per Invoice',
      standardPrice: (json['standard_price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'EGP',
      minPrice: (json['min_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (itemId != null) 'item_id': itemId,
      if (priceListId != null) 'price_list_id': priceListId,
      if (expenseTypeId != null) 'expense_type_id': expenseTypeId,
      'expense_name': expenseName,
      'category': category,
      'unit_type': unitType,
      'standard_price': standardPrice,
      'currency': currency,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (notes != null) 'notes': notes,
      'is_active': isActive,
    };
  }
}

class BrokerPriceListModel {
  final int priceListId;
  final String priceListCode;
  final String title;
  final int brokerId;
  final String brokerName;
  final String? portName;
  final String effectiveFrom;
  final String? effectiveTo;
  final int version;
  final bool isActive;
  final String? notes;
  final int? clonedFromId;
  final String? clonedFromCode;
  final List<BrokerPriceListItemModel> items;

  BrokerPriceListModel({
    required this.priceListId,
    required this.priceListCode,
    required this.title,
    required this.brokerId,
    required this.brokerName,
    this.portName,
    required this.effectiveFrom,
    this.effectiveTo,
    this.version = 1,
    this.isActive = true,
    this.notes,
    this.clonedFromId,
    this.clonedFromCode,
    this.items = const [],
  });

  factory BrokerPriceListModel.fromJson(Map<String, dynamic> json) {
    return BrokerPriceListModel(
      priceListId: json['price_list_id'] ?? 0,
      priceListCode: json['price_list_code'] ?? '',
      title: json['title'] ?? '',
      brokerId: json['broker_id'] ?? 0,
      brokerName: json['broker_name'] ?? '',
      portName: json['port_name'],
      effectiveFrom: json['effective_from'] ?? '',
      effectiveTo: json['effective_to'],
      version: json['version'] ?? 1,
      isActive: json['is_active'] ?? true,
      notes: json['notes'],
      clonedFromId: json['cloned_from_id'],
      clonedFromCode: json['cloned_from_code'],
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => BrokerPriceListItemModel.fromJson(i))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'price_list_id': priceListId,
      'price_list_code': priceListCode,
      'title': title,
      'broker_id': brokerId,
      'broker_name': brokerName,
      if (portName != null) 'port_name': portName,
      'effective_from': effectiveFrom,
      if (effectiveTo != null) 'effective_to': effectiveTo,
      if (clonedFromId != null) 'cloned_from_id': clonedFromId,
      if (clonedFromCode != null) 'cloned_from_code': clonedFromCode,
      'version': version,
      'is_active': isActive,
      if (notes != null) 'notes': notes,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

class CustomsBrokerQuoteItemModel {
  final int? quoteItemId;
  final int? consultationId;
  final int? expenseTypeId;
  final String expenseName;
  final String category;
  final String unitType;
  final double unitPrice;
  final String currency;
  final double qty;
  final bool isApplicable;
  final double totalAmount;
  final String? notes;

  CustomsBrokerQuoteItemModel({
    this.quoteItemId,
    this.consultationId,
    this.expenseTypeId,
    required this.expenseName,
    required this.category,
    this.unitType = 'Per Invoice',
    this.unitPrice = 0.0,
    this.currency = 'EGP',
    this.qty = 1.0,
    this.isApplicable = true,
    this.totalAmount = 0.0,
    this.notes,
  });

  factory CustomsBrokerQuoteItemModel.fromJson(Map<String, dynamic> json) {
    return CustomsBrokerQuoteItemModel(
      quoteItemId: json['quote_item_id'],
      consultationId: json['consultation_id'],
      expenseTypeId: json['expense_type_id'],
      expenseName: json['expense_name'] ?? '',
      category: json['category'] ?? '',
      unitType: json['unit_type'] ?? 'Per Invoice',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'EGP',
      qty: (json['qty'] as num?)?.toDouble() ?? 1.0,
      isApplicable: json['is_applicable'] ?? true,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (quoteItemId != null) 'quote_item_id': quoteItemId,
      if (consultationId != null) 'consultation_id': consultationId,
      if (expenseTypeId != null) 'expense_type_id': expenseTypeId,
      'expense_name': expenseName,
      'category': category,
      'unit_type': unitType,
      'unit_price': unitPrice,
      'currency': currency,
      'qty': qty,
      'is_applicable': isApplicable,
      'total_amount': totalAmount,
      if (notes != null) 'notes': notes,
    };
  }

  CustomsBrokerQuoteItemModel copyWith({
    int? quoteItemId,
    int? consultationId,
    int? expenseTypeId,
    String? expenseName,
    String? category,
    String? unitType,
    double? unitPrice,
    String? currency,
    double? qty,
    bool? isApplicable,
    double? totalAmount,
    String? notes,
  }) {
    return CustomsBrokerQuoteItemModel(
      quoteItemId: quoteItemId ?? this.quoteItemId,
      consultationId: consultationId ?? this.consultationId,
      expenseTypeId: expenseTypeId ?? this.expenseTypeId,
      expenseName: expenseName ?? this.expenseName,
      category: category ?? this.category,
      unitType: unitType ?? this.unitType,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      qty: qty ?? this.qty,
      isApplicable: isApplicable ?? this.isApplicable,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
    );
  }
}

class CustomsChecklistItemModel {
  final int? itemId;
  final int? consultationId;
  final String documentType;
  final String? hsCode;
  final bool isRequired;
  final String requiredText; // '✓', 'حسب الحالة', 'لاحقاً', 'حسب Incoterm'
  final bool isBlockingShipment;
  final String responsibleParty;
  final String status; // Pending, Received, Verified, Approved, Rejected
  final String? receivedDate; // تاريخ العرض / الاستلام
  final String? verifiedDate; // تاريخ الموافقة النهائية (auto once approved)
  final String? regulatoryAgency;
  final String? remarks;
  final String? correctiveActionRequired;

  CustomsChecklistItemModel({
    this.itemId,
    this.consultationId,
    required this.documentType,
    this.hsCode,
    this.isRequired = true,
    this.requiredText = '✓',
    this.isBlockingShipment = true,
    this.responsibleParty = 'Customs Broker',
    this.status = 'Pending',
    this.receivedDate,
    this.verifiedDate,
    this.regulatoryAgency,
    this.remarks,
    this.correctiveActionRequired,
  });

  factory CustomsChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return CustomsChecklistItemModel(
      itemId: json['item_id'],
      consultationId: json['consultation_id'],
      documentType: json['document_type'] ?? '',
      hsCode: json['hs_code'],
      isRequired: json['is_required'] ?? true,
      requiredText: json['required_text'] ?? ((json['is_required'] ?? true) ? '✓' : 'حسب الحالة'),
      isBlockingShipment: json['is_blocking_shipment'] ?? true,
      responsibleParty: json['responsible_party'] ?? 'Customs Broker',
      status: json['status'] ?? 'Pending',
      receivedDate: json['received_date'],
      verifiedDate: json['verified_date'],
      regulatoryAgency: json['regulatory_agency'],
      remarks: json['remarks'],
      correctiveActionRequired: json['corrective_action_required'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (itemId != null) 'item_id': itemId,
      if (consultationId != null) 'consultation_id': consultationId,
      'document_type': documentType,
      'hs_code': (hsCode != null && hsCode!.trim().isNotEmpty) ? hsCode : null,
      'is_required': isRequired,
      'required_text': requiredText,
      'is_blocking_shipment': isBlockingShipment,
      'responsible_party': responsibleParty,
      'status': status,
      'received_date': (receivedDate != null && receivedDate!.trim().isNotEmpty) ? receivedDate : null,
      'verified_date': (verifiedDate != null && verifiedDate!.trim().isNotEmpty) ? verifiedDate : null,
      'regulatory_agency': (regulatoryAgency != null && regulatoryAgency!.trim().isNotEmpty) ? regulatoryAgency : null,
      'remarks': (remarks != null && remarks!.trim().isNotEmpty) ? remarks : null,
      'corrective_action_required': (correctiveActionRequired != null && correctiveActionRequired!.trim().isNotEmpty) ? correctiveActionRequired : null,
    };
  }

  CustomsChecklistItemModel copyWith({
    int? itemId,
    int? consultationId,
    String? documentType,
    String? hsCode,
    bool? isRequired,
    String? requiredText,
    bool? isBlockingShipment,
    String? responsibleParty,
    String? status,
    String? receivedDate,
    String? verifiedDate,
    String? regulatoryAgency,
    String? remarks,
    String? correctiveActionRequired,
  }) {
    return CustomsChecklistItemModel(
      itemId: itemId ?? this.itemId,
      consultationId: consultationId ?? this.consultationId,
      documentType: documentType ?? this.documentType,
      hsCode: hsCode ?? this.hsCode,
      isRequired: isRequired ?? this.isRequired,
      requiredText: requiredText ?? this.requiredText,
      isBlockingShipment: isBlockingShipment ?? this.isBlockingShipment,
      responsibleParty: responsibleParty ?? this.responsibleParty,
      status: status ?? this.status,
      receivedDate: receivedDate ?? this.receivedDate,
      verifiedDate: verifiedDate ?? this.verifiedDate,
      regulatoryAgency: regulatoryAgency ?? this.regulatoryAgency,
      remarks: remarks ?? this.remarks,
      correctiveActionRequired: correctiveActionRequired ?? this.correctiveActionRequired,
    );
  }
}

class CustomsConsultationModel {
  final int consultationId;
  final String consultationCode;
  final String title;
  final int? importFileId;
  final int brokerId;
  final String brokerName;
  final String? brokerContactPerson;
  final int? brokerPriceListId;
  final int? poId;
  final int? projectId;
  final String overallStatus; // Pending Review, In Progress, Action Required, Clearance Ready, Blocked
  final bool hasBlockingIssues;
  final double readinessPercentage;
  final double estimatedDutiesEgp;
  final double totalBrokerFeesEgp;
  final double customsExchangeRate;
  final String customsCurrency;
  final String? calculationDate;
  final String? notes;
  final bool isActive;
  final int? clonedFromId;
  final String? clonedFromCode;
  final String createdAt;
  final String updatedAt;
  final String? importFileCode;
  final List<CustomsChecklistItemModel> checklistItems;
  final List<CustomsBrokerQuoteItemModel> brokerQuoteItems;
  final int totalDocumentsCount;
  final int approvedDocumentsCount;
  final int blockingIssuesCount;
  final int appliedBrokerItemsCount;

  CustomsConsultationModel({
    required this.consultationId,
    required this.consultationCode,
    required this.title,
    this.importFileId,
    required this.brokerId,
    required this.brokerName,
    this.brokerContactPerson,
    this.brokerPriceListId,
    this.poId,
    this.projectId,
    required this.overallStatus,
    this.hasBlockingIssues = false,
    this.readinessPercentage = 0.0,
    this.estimatedDutiesEgp = 0.0,
    this.totalBrokerFeesEgp = 0.0,
    this.customsExchangeRate = 1.0,
    this.customsCurrency = 'USD',
    this.calculationDate,
    this.notes,
    this.isActive = true,
    this.clonedFromId,
    this.clonedFromCode,
    required this.createdAt,
    required this.updatedAt,
    this.importFileCode,
    this.checklistItems = const [],
    this.brokerQuoteItems = const [],
    this.totalDocumentsCount = 0,
    this.approvedDocumentsCount = 0,
    this.blockingIssuesCount = 0,
    this.appliedBrokerItemsCount = 0,
  });

  factory CustomsConsultationModel.fromJson(Map<String, dynamic> json) {
    double exRate = (json['customs_exchange_rate'] as num?)?.toDouble() ?? 1.0;
    String curr = json['customs_currency'] ?? 'USD';
    String? calcDate = json['calculation_date'];
    String? rawNotes = json['notes'];
    String? cleanNotes = rawNotes;

    // Check if notes contains SNAPSHOT metadata
    if (rawNotes != null && rawNotes.contains('<!-- SNAPSHOT:')) {
      try {
        final startIdx = rawNotes.indexOf('<!-- SNAPSHOT:') + '<!-- SNAPSHOT:'.length;
        final endIdx = rawNotes.indexOf('-->', startIdx);
        if (endIdx != -1) {
          final jsonStr = rawNotes.substring(startIdx, endIdx).trim();
          final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (meta['customs_exchange_rate'] != null) {
            exRate = (meta['customs_exchange_rate'] as num).toDouble();
          }
          if (meta['customs_currency'] != null) {
            curr = meta['customs_currency'].toString();
          }
          if (meta['calculation_date'] != null) {
            calcDate = meta['calculation_date'].toString();
          }
          cleanNotes = rawNotes.substring(endIdx + 3).trim();
          if (cleanNotes.isEmpty) cleanNotes = null;
        }
      } catch (_) {}
    }

    return CustomsConsultationModel(
      consultationId: json['consultation_id'],
      consultationCode: json['consultation_code'] ?? '',
      title: json['title'] ?? '',
      importFileId: json['import_file_id'],
      brokerId: json['broker_id'],
      brokerName: json['broker_name'] ?? '',
      brokerContactPerson: json['broker_contact_person'],
      brokerPriceListId: json['broker_price_list_id'],
      poId: json['po_id'],
      projectId: json['project_id'],
      overallStatus: json['overall_status'] ?? 'Pending Review',
      hasBlockingIssues: json['has_blocking_issues'] ?? false,
      readinessPercentage: (json['readiness_percentage'] as num?)?.toDouble() ?? 0.0,
      estimatedDutiesEgp: (json['estimated_duties_egp'] as num?)?.toDouble() ?? 0.0,
      totalBrokerFeesEgp: (json['total_broker_fees_egp'] as num?)?.toDouble() ?? 0.0,
      customsExchangeRate: exRate,
      customsCurrency: curr,
      calculationDate: calcDate,
      notes: cleanNotes,
      isActive: json['is_active'] ?? true,
      clonedFromId: json['cloned_from_id'],
      clonedFromCode: json['cloned_from_code'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      importFileCode: json['import_file_code'],
      checklistItems: (json['checklist_items'] as List<dynamic>?)
              ?.map((item) => CustomsChecklistItemModel.fromJson(item))
              .toList() ??
          [],
      brokerQuoteItems: (json['broker_quote_items'] as List<dynamic>?)
              ?.map((item) => CustomsBrokerQuoteItemModel.fromJson(item))
              .toList() ??
          [],
      totalDocumentsCount: json['total_documents_count'] ?? 0,
      approvedDocumentsCount: json['approved_documents_count'] ?? 0,
      blockingIssuesCount: json['blocking_issues_count'] ?? 0,
      appliedBrokerItemsCount: json['applied_broker_items_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    String? packedNotes = notes;
    final metaMap = {
      'customs_exchange_rate': customsExchangeRate,
      'customs_currency': customsCurrency,
      if (calculationDate != null) 'calculation_date': calculationDate,
    };
    final metaStr = '<!-- SNAPSHOT: ${jsonEncode(metaMap)} -->';
    if (packedNotes != null && packedNotes.isNotEmpty) {
      if (packedNotes.contains('<!-- SNAPSHOT:')) {
        final endIdx = packedNotes.indexOf('-->');
        if (endIdx != -1) {
          packedNotes = packedNotes.substring(endIdx + 3).trim();
        }
      }
      packedNotes = '$metaStr\n$packedNotes';
    } else {
      packedNotes = metaStr;
    }

    return {
      'consultation_id': consultationId,
      'consultation_code': consultationCode,
      'title': title,
      if (importFileId != null) 'import_file_id': importFileId,
      'broker_id': brokerId,
      'broker_name': brokerName,
      'broker_contact_person': brokerContactPerson,
      if (brokerPriceListId != null) 'broker_price_list_id': brokerPriceListId,
      'po_id': poId,
      'project_id': projectId,
      'overall_status': overallStatus,
      'has_blocking_issues': hasBlockingIssues,
      'readiness_percentage': readinessPercentage,
      'estimated_duties_egp': estimatedDutiesEgp,
      'total_broker_fees_egp': totalBrokerFeesEgp,
      'customs_exchange_rate': customsExchangeRate,
      'customs_currency': customsCurrency,
      if (calculationDate != null) 'calculation_date': calculationDate,
      'notes': packedNotes,
      'is_active': isActive,
      if (clonedFromId != null) 'cloned_from_id': clonedFromId,
      if (clonedFromCode != null) 'cloned_from_code': clonedFromCode,
      'checklist_items': checklistItems.map((item) => item.toJson()).toList(),
      'broker_quote_items': brokerQuoteItems.map((item) => item.toJson()).toList(),
    };
  }

  CustomsConsultationModel copyWith({
    int? consultationId,
    String? consultationCode,
    String? title,
    int? importFileId,
    int? brokerId,
    String? brokerName,
    String? brokerContactPerson,
    int? brokerPriceListId,
    int? poId,
    int? projectId,
    String? overallStatus,
    bool? hasBlockingIssues,
    double? readinessPercentage,
    double? estimatedDutiesEgp,
    double? totalBrokerFeesEgp,
    double? customsExchangeRate,
    String? customsCurrency,
    String? calculationDate,
    String? notes,
    bool? isActive,
    int? clonedFromId,
    String? clonedFromCode,
    String? createdAt,
    String? updatedAt,
    String? importFileCode,
    List<CustomsChecklistItemModel>? checklistItems,
    List<CustomsBrokerQuoteItemModel>? brokerQuoteItems,
    int? totalDocumentsCount,
    int approvedDocumentsCount = 0,
    int blockingIssuesCount = 0,
    int appliedBrokerItemsCount = 0,
  }) {
    return CustomsConsultationModel(
      consultationId: consultationId ?? this.consultationId,
      consultationCode: consultationCode ?? this.consultationCode,
      title: title ?? this.title,
      importFileId: importFileId ?? this.importFileId,
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      brokerContactPerson: brokerContactPerson ?? this.brokerContactPerson,
      brokerPriceListId: brokerPriceListId ?? this.brokerPriceListId,
      poId: poId ?? this.poId,
      projectId: projectId ?? this.projectId,
      overallStatus: overallStatus ?? this.overallStatus,
      hasBlockingIssues: hasBlockingIssues ?? this.hasBlockingIssues,
      readinessPercentage: readinessPercentage ?? this.readinessPercentage,
      estimatedDutiesEgp: estimatedDutiesEgp ?? this.estimatedDutiesEgp,
      totalBrokerFeesEgp: totalBrokerFeesEgp ?? this.totalBrokerFeesEgp,
      customsExchangeRate: customsExchangeRate ?? this.customsExchangeRate,
      customsCurrency: customsCurrency ?? this.customsCurrency,
      calculationDate: calculationDate ?? this.calculationDate,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      clonedFromId: clonedFromId ?? this.clonedFromId,
      clonedFromCode: clonedFromCode ?? this.clonedFromCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      importFileCode: importFileCode ?? this.importFileCode,
      checklistItems: checklistItems ?? this.checklistItems,
      brokerQuoteItems: brokerQuoteItems ?? this.brokerQuoteItems,
      totalDocumentsCount: totalDocumentsCount ?? this.totalDocumentsCount,
      approvedDocumentsCount: approvedDocumentsCount,
      blockingIssuesCount: blockingIssuesCount,
      appliedBrokerItemsCount: appliedBrokerItemsCount,
    );
  }
}

// ==============================================================================
// Customs Re-estimation & Variance Comparison Models
// ==============================================================================

/// `comparison_lines[].status` value for a line with no HS code or no tariff valid on the estimate
/// date: it carries zero taxes and is excluded from every total.
const String kLineStatusTariffMissing = 'TARIFF_MISSING';

class LineVarianceComparisonModel {
  final String itemName;
  final String hsCode;
  final String? countryOfOrigin;
  /// `OK` or [kLineStatusTariffMissing].
  final String status;
  final double preliminaryQty;
  final double finalQty;
  final double qtyVariance;
  final double preliminaryUnitPrice;
  final double finalUnitPrice;
  final double unitPriceVariance;
  final double preliminaryFobEgp;
  final double finalFobEgp;
  final double fobVarianceEgp;
  final double preliminaryCifEgp;
  final double finalCifEgp;
  final double cifVarianceEgp;
  final double dutyRatePct;
  final double preliminaryDutyEgp;
  final double finalDutyEgp;
  final double dutyVarianceEgp;
  final double vatRatePct;
  final double preliminaryVatEgp;
  final double finalVatEgp;
  final double vatVarianceEgp;
  final double preliminaryTotalTaxesEgp;
  final double finalTotalTaxesEgp;
  final double totalTaxesVarianceEgp;

  LineVarianceComparisonModel({
    this.status = 'OK',
    required this.itemName,
    required this.hsCode,
    this.countryOfOrigin,
    this.preliminaryQty = 0.0,
    this.finalQty = 0.0,
    this.qtyVariance = 0.0,
    this.preliminaryUnitPrice = 0.0,
    this.finalUnitPrice = 0.0,
    this.unitPriceVariance = 0.0,
    this.preliminaryFobEgp = 0.0,
    this.finalFobEgp = 0.0,
    this.fobVarianceEgp = 0.0,
    this.preliminaryCifEgp = 0.0,
    this.finalCifEgp = 0.0,
    this.cifVarianceEgp = 0.0,
    this.dutyRatePct = 0.0,
    this.preliminaryDutyEgp = 0.0,
    this.finalDutyEgp = 0.0,
    this.dutyVarianceEgp = 0.0,
    this.vatRatePct = 0.0,
    this.preliminaryVatEgp = 0.0,
    this.finalVatEgp = 0.0,
    this.vatVarianceEgp = 0.0,
    this.preliminaryTotalTaxesEgp = 0.0,
    this.finalTotalTaxesEgp = 0.0,
    this.totalTaxesVarianceEgp = 0.0,
  });

  bool get isTariffMissing => status == kLineStatusTariffMissing;

  factory LineVarianceComparisonModel.fromJson(Map<String, dynamic> json) {
    return LineVarianceComparisonModel(
      itemName: json['item_name'] ?? '',
      hsCode: json['hs_code'] ?? '',
      countryOfOrigin: json['country_of_origin'],
      status: (json['status'] as String?) ?? 'OK',
      preliminaryQty: (json['preliminary_qty'] as num?)?.toDouble() ?? 0.0,
      finalQty: (json['final_qty'] as num?)?.toDouble() ?? 0.0,
      qtyVariance: (json['qty_variance'] as num?)?.toDouble() ?? 0.0,
      preliminaryUnitPrice: (json['preliminary_unit_price'] as num?)?.toDouble() ?? 0.0,
      finalUnitPrice: (json['final_unit_price'] as num?)?.toDouble() ?? 0.0,
      unitPriceVariance: (json['unit_price_variance'] as num?)?.toDouble() ?? 0.0,
      preliminaryFobEgp: (json['preliminary_fob_egp'] as num?)?.toDouble() ?? 0.0,
      finalFobEgp: (json['final_fob_egp'] as num?)?.toDouble() ?? 0.0,
      fobVarianceEgp: (json['fob_variance_egp'] as num?)?.toDouble() ?? 0.0,
      preliminaryCifEgp: (json['preliminary_cif_egp'] as num?)?.toDouble() ?? 0.0,
      finalCifEgp: (json['final_cif_egp'] as num?)?.toDouble() ?? 0.0,
      cifVarianceEgp: (json['cif_variance_egp'] as num?)?.toDouble() ?? 0.0,
      dutyRatePct: (json['duty_rate_pct'] as num?)?.toDouble() ?? 0.0,
      preliminaryDutyEgp: (json['preliminary_duty_egp'] as num?)?.toDouble() ?? 0.0,
      finalDutyEgp: (json['final_duty_egp'] as num?)?.toDouble() ?? 0.0,
      dutyVarianceEgp: (json['duty_variance_egp'] as num?)?.toDouble() ?? 0.0,
      vatRatePct: (json['vat_rate_pct'] as num?)?.toDouble() ?? 0.0,
      preliminaryVatEgp: (json['preliminary_vat_egp'] as num?)?.toDouble() ?? 0.0,
      finalVatEgp: (json['final_vat_egp'] as num?)?.toDouble() ?? 0.0,
      vatVarianceEgp: (json['vat_variance_egp'] as num?)?.toDouble() ?? 0.0,
      preliminaryTotalTaxesEgp: (json['preliminary_total_taxes_egp'] as num?)?.toDouble() ?? 0.0,
      finalTotalTaxesEgp: (json['final_total_taxes_egp'] as num?)?.toDouble() ?? 0.0,
      totalTaxesVarianceEgp: (json['total_taxes_variance_egp'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomsRecalculationResponseModel {
  final int importFileId;
  final String importFileCode;
  final String? finalInvoiceNumber;
  final int? reconciliationSessionId;
  final bool isReconciled;
  final String sourceDescription;
  /// FINAL side rate (EGP per unit of [finalCurrency]).
  final double? exchangeRate;
  final double? preliminaryExchangeRate;
  final String? preliminaryCurrency;
  final String? finalCurrency;

  /// `table` (customs rate table on the date) or `manual` (value sent in the request).
  final String exchangeRateSource;
  /// `table` / `manual` for the preliminary side.
  final String preliminaryExchangeRateSource;
  final String estimateDate;
  final double preliminaryFobEgp;
  final double finalFobEgp;
  final double fobVarianceEgp;
  final double preliminaryCifEgp;
  final double finalCifEgp;
  final double cifVarianceEgp;
  final double preliminaryDutyEgp;
  final double finalDutyEgp;
  final double dutyVarianceEgp;
  final double preliminaryVatEgp;
  final double finalVatEgp;
  final double vatVarianceEgp;
  final double preliminaryTotalTaxesEgp;
  final double finalTotalTaxesEgp;
  final double totalTaxesVarianceEgp;
  final double variancePercentage;
  final String forecastStatus;
  final List<LineVarianceComparisonModel> comparisonLines;
  /// Lines with status TARIFF_MISSING (excluded from the totals).
  final int tariffMissingLinesCount;

  CustomsRecalculationResponseModel({
    required this.importFileId,
    required this.importFileCode,
    this.finalInvoiceNumber,
    this.reconciliationSessionId,
    this.isReconciled = false,
    required this.sourceDescription,
    this.exchangeRate,
    this.preliminaryExchangeRate,
    this.preliminaryCurrency,
    this.finalCurrency,
    this.exchangeRateSource = 'table',
    this.preliminaryExchangeRateSource = 'table',
    required this.estimateDate,
    this.preliminaryFobEgp = 0.0,
    this.finalFobEgp = 0.0,
    this.fobVarianceEgp = 0.0,
    this.preliminaryCifEgp = 0.0,
    this.finalCifEgp = 0.0,
    this.cifVarianceEgp = 0.0,
    this.preliminaryDutyEgp = 0.0,
    this.finalDutyEgp = 0.0,
    this.dutyVarianceEgp = 0.0,
    this.preliminaryVatEgp = 0.0,
    this.finalVatEgp = 0.0,
    this.vatVarianceEgp = 0.0,
    this.preliminaryTotalTaxesEgp = 0.0,
    this.finalTotalTaxesEgp = 0.0,
    this.totalTaxesVarianceEgp = 0.0,
    this.variancePercentage = 0.0,
    this.forecastStatus = "Balanced",
    this.comparisonLines = const [],
    this.tariffMissingLinesCount = 0,
  });

  factory CustomsRecalculationResponseModel.fromJson(Map<String, dynamic> json) {
    return CustomsRecalculationResponseModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      finalInvoiceNumber: json['final_invoice_number'],
      reconciliationSessionId: json['reconciliation_session_id'],
      isReconciled: json['is_reconciled'] ?? false,
      sourceDescription: json['source_description'] ?? '',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
      preliminaryExchangeRate: (json['preliminary_exchange_rate'] as num?)?.toDouble(),
      preliminaryCurrency: json['preliminary_currency'] as String?,
      finalCurrency: json['final_currency'] as String?,
      exchangeRateSource: (json['exchange_rate_source'] as String?) ?? 'table',
      preliminaryExchangeRateSource: (json['preliminary_exchange_rate_source'] as String?) ?? 'table',
      estimateDate: json['estimate_date'] ?? '',
      preliminaryFobEgp: (json['preliminary_fob_egp'] as num?)?.toDouble() ?? 0.0,
      finalFobEgp: (json['final_fob_egp'] as num?)?.toDouble() ?? 0.0,
      fobVarianceEgp: (json['fob_variance_egp'] as num?)?.toDouble() ?? 0.0,
      preliminaryCifEgp: (json['preliminary_cif_egp'] as num?)?.toDouble() ?? 0.0,
      finalCifEgp: (json['final_cif_egp'] as num?)?.toDouble() ?? 0.0,
      cifVarianceEgp: (json['cif_variance_egp'] as num?)?.toDouble() ?? 0.0,
      preliminaryDutyEgp: (json['preliminary_duty_egp'] as num?)?.toDouble() ?? 0.0,
      finalDutyEgp: (json['final_duty_egp'] as num?)?.toDouble() ?? 0.0,
      dutyVarianceEgp: (json['duty_variance_egp'] as num?)?.toDouble() ?? 0.0,
      preliminaryVatEgp: (json['preliminary_vat_egp'] as num?)?.toDouble() ?? 0.0,
      finalVatEgp: (json['final_vat_egp'] as num?)?.toDouble() ?? 0.0,
      vatVarianceEgp: (json['vat_variance_egp'] as num?)?.toDouble() ?? 0.0,
      preliminaryTotalTaxesEgp: (json['preliminary_total_taxes_egp'] as num?)?.toDouble() ?? 0.0,
      finalTotalTaxesEgp: (json['final_total_taxes_egp'] as num?)?.toDouble() ?? 0.0,
      totalTaxesVarianceEgp: (json['total_taxes_variance_egp'] as num?)?.toDouble() ?? 0.0,
      variancePercentage: (json['variance_percentage'] as num?)?.toDouble() ?? 0.0,
      forecastStatus: json['forecast_status'] ?? 'Balanced',
      comparisonLines: (json['comparison_lines'] as List<dynamic>?)
              ?.map((c) => LineVarianceComparisonModel.fromJson(c))
              .toList() ??
          [],
      tariffMissingLinesCount: (json['tariff_missing_lines_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomsItemCalcRow {
  final String? itemKey;
  final bool isAgreementEligible;
  final String hsCode;
  final String description;
  final double qty;
  final String unit;
  final double foreignPrice;
  final double fobEgp;
  final double freightEgp;
  final double insuranceEgp;
  final double cifEgp;
  final double dutyRate;
  final double baseDutyRate;
  final double dutyAmountEgp;
  final double vatRate;
  final double vatBaseEgp;
  final double vatAmountEgp;
  final double scheduleTaxRate;
  final double scheduleTaxAmountEgp;
  final double developmentFeeRate;
  final double developmentFeeAmountEgp;
  final double customsServiceFeeRate;
  final double customsServiceFeeAmountEgp;
  final double totalTaxesAndDutiesEgp;
  final bool requiresCoo;
  final bool requiresInspection;
  final bool requiresAcid;
  final String? regulatoryAuthority;
  final String? priorApprovalNote;
  final String? countryOfOrigin;
  final String? appliedAgreementName;
  final bool hasExemption;
  final String? exemptionConditionsNote;
  final String? requiredDocument;
  final bool isTariffMissing;
  final String? status;

  bool get isCalculated => status == 'CALCULATED';

  CustomsItemCalcRow({
    this.itemKey,
    this.isAgreementEligible = false,
    required this.hsCode,
    required this.description,
    required this.qty,
    required this.unit,
    required this.foreignPrice,
    required this.fobEgp,
    required this.freightEgp,
    required this.insuranceEgp,
    required this.cifEgp,
    required this.dutyRate,
    required this.baseDutyRate,
    required this.dutyAmountEgp,
    required this.vatRate,
    required this.vatBaseEgp,
    required this.vatAmountEgp,
    required this.scheduleTaxRate,
    required this.scheduleTaxAmountEgp,
    required this.developmentFeeRate,
    required this.developmentFeeAmountEgp,
    required this.customsServiceFeeRate,
    required this.customsServiceFeeAmountEgp,
    required this.totalTaxesAndDutiesEgp,
    required this.requiresCoo,
    required this.requiresInspection,
    required this.requiresAcid,
    this.regulatoryAuthority,
    this.priorApprovalNote,
    this.countryOfOrigin,
    this.appliedAgreementName,
    this.hasExemption = false,
    this.exemptionConditionsNote,
    this.requiredDocument,
    this.isTariffMissing = false,
    this.status,
  });
}


extension CustomsRecalculationRates on CustomsRecalculationResponseModel {
  bool get isManualRate => exchangeRateSource == 'manual';
  bool get isPreliminaryManualRate => preliminaryExchangeRateSource == 'manual';

  /// A separate preliminary rate only makes sense (and can be entered) when the two sides differ in currency.
  bool get hasDifferentCurrencies =>
      preliminaryCurrency != null && finalCurrency != null && preliminaryCurrency != finalCurrency;

  static String _piece(String? currency, double rate) =>
      '${currency == null || currency.isEmpty ? '' : '$currency '}${rate.toStringAsFixed(4)}';

  /// "USD 49.5000" (currency omitted when the backend did not send it).
  String get finalRateText => exchangeRate == null ? '—' : _piece(finalCurrency, exchangeRate!);

  /// Null when there is no separate preliminary rate to show.
  String? get preliminaryRateText =>
      preliminaryExchangeRate == null ? null : _piece(preliminaryCurrency, preliminaryExchangeRate!);
}
