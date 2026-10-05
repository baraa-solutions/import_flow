

class CourierEntryModel {
  String courierNo;
  String courierCompany;
  String? dispatchDate;
  bool isReceived;
  String? receivedDate;
  String? receivedTime;
  String? receivedBy;
  String? trackingUrl;
  String? podReference;
  String status;
  String? notes;

  CourierEntryModel({
    required this.courierNo,
    this.courierCompany = 'DHL',
    this.dispatchDate,
    this.isReceived = false,
    this.receivedDate,
    this.receivedTime,
    this.receivedBy,
    this.trackingUrl,
    this.podReference,
    this.status = 'DISPATCHED',
    this.notes,
  });

  factory CourierEntryModel.fromJson(Map<String, dynamic> json) {
    return CourierEntryModel(
      courierNo: json['courier_no']?.toString() ?? '',
      courierCompany: json['courier_company']?.toString() ?? 'DHL',
      dispatchDate: json['dispatch_date']?.toString(),
      isReceived: json['is_received'] == true,
      receivedDate: json['received_date']?.toString(),
      receivedTime: json['received_time']?.toString(),
      receivedBy: json['received_by']?.toString(),
      trackingUrl: json['tracking_url']?.toString(),
      podReference: json['pod_reference']?.toString(),
      status: json['status']?.toString() ?? (json['is_received'] == true ? 'DELIVERED' : 'IN_TRANSIT'),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courier_no': courierNo,
      'courier_company': courierCompany,
      'dispatch_date': dispatchDate,
      'is_received': isReceived,
      'received_date': receivedDate,
      'received_time': receivedTime,
      'received_by': receivedBy,
      'tracking_url': trackingUrl,
      'pod_reference': podReference,
      'status': status,
      'notes': notes,
    };
  }

  CourierEntryModel copyWith({
    String? courierNo,
    String? courierCompany,
    String? dispatchDate,
    bool? isReceived,
    String? receivedDate,
    String? receivedTime,
    String? receivedBy,
    String? trackingUrl,
    String? podReference,
    String? status,
    String? notes,
  }) {
    return CourierEntryModel(
      courierNo: courierNo ?? this.courierNo,
      courierCompany: courierCompany ?? this.courierCompany,
      dispatchDate: dispatchDate ?? this.dispatchDate,
      isReceived: isReceived ?? this.isReceived,
      receivedDate: receivedDate ?? this.receivedDate,
      receivedTime: receivedTime ?? this.receivedTime,
      receivedBy: receivedBy ?? this.receivedBy,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      podReference: podReference ?? this.podReference,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

class OriginalDocumentItemModel {
  String category;
  String documentName;
  String isRequired; // 'Yes', 'No', 'Conditional'
  String responsibleParty; // 'Supplier', 'Freight Forwarder', 'Inspection Agency', 'Bank', 'Importer'
  String? courierNo;
  bool isReceived;
  String? receivedDate;
  bool isVerified;
  String? verifiedBy;
  String? verificationDate;
  String status; // 'Pending', 'In Transit', 'Received', 'Verified', 'Discrepant', 'Not Required'
  String? remarks;

  OriginalDocumentItemModel({
    this.category = 'Commercial',
    required this.documentName,
    this.isRequired = 'Yes',
    this.responsibleParty = 'Supplier',
    this.courierNo,
    this.isReceived = false,
    this.receivedDate,
    this.isVerified = false,
    this.verifiedBy,
    this.verificationDate,
    this.status = 'Pending',
    this.remarks,
  });

  factory OriginalDocumentItemModel.fromJson(Map<String, dynamic> json) {
    return OriginalDocumentItemModel(
      category: json['category']?.toString() ?? 'Commercial',
      documentName: json['document_name']?.toString() ?? '',
      isRequired: json['is_required']?.toString() ?? 'Yes',
      responsibleParty: json['responsible_party']?.toString() ?? 'Supplier',
      courierNo: json['courier_no']?.toString(),
      isReceived: json['is_received'] == true,
      receivedDate: json['received_date']?.toString(),
      isVerified: json['is_verified'] == true,
      verifiedBy: json['verified_by']?.toString(),
      verificationDate: json['verification_date']?.toString(),
      status: json['status']?.toString() ?? 'Pending',
      remarks: json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'document_name': documentName,
      'is_required': isRequired,
      'responsible_party': responsibleParty,
      'courier_no': courierNo,
      'is_received': isReceived,
      'received_date': receivedDate,
      'is_verified': isVerified,
      'verified_by': verifiedBy,
      'verification_date': verificationDate,
      'status': status,
      'remarks': remarks,
    };
  }

  OriginalDocumentItemModel copyWith({
    String? category,
    String? documentName,
    String? isRequired,
    String? responsibleParty,
    String? courierNo,
    bool? isReceived,
    String? receivedDate,
    bool? isVerified,
    String? verifiedBy,
    String? verificationDate,
    String? status,
    String? remarks,
  }) {
    return OriginalDocumentItemModel(
      category: category ?? this.category,
      documentName: documentName ?? this.documentName,
      isRequired: isRequired ?? this.isRequired,
      responsibleParty: responsibleParty ?? this.responsibleParty,
      courierNo: courierNo ?? this.courierNo,
      isReceived: isReceived ?? this.isReceived,
      receivedDate: receivedDate ?? this.receivedDate,
      isVerified: isVerified ?? this.isVerified,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verificationDate: verificationDate ?? this.verificationDate,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
    );
  }
}

class OriginalDocumentsCollectionSessionModel {
  final int collectionId;
  final String collectionCode;
  final int importFileId;
  final String importFileCode;
  final String? acidNumber;
  final String? importerName;
  final String? supplierName;
  final String status;
  final List<CourierEntryModel> couriersList;
  final List<OriginalDocumentItemModel> documentsList;
  final int totalDocumentsCount;
  final int receivedDocumentsCount;
  final int verifiedDocumentsCount;
  final int pendingDocumentsCount;
  final double completionPercentage;
  final String? discrepancyOverrideReason;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String updatedBy;

  OriginalDocumentsCollectionSessionModel({
    required this.collectionId,
    required this.collectionCode,
    required this.importFileId,
    required this.importFileCode,
    this.acidNumber,
    this.importerName,
    this.supplierName,
    required this.status,
    required this.couriersList,
    required this.documentsList,
    required this.totalDocumentsCount,
    required this.receivedDocumentsCount,
    required this.verifiedDocumentsCount,
    required this.pendingDocumentsCount,
    required this.completionPercentage,
    this.discrepancyOverrideReason,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory OriginalDocumentsCollectionSessionModel.fromJson(Map<String, dynamic> json) {
    return OriginalDocumentsCollectionSessionModel(
      collectionId: json['collection_id'] ?? 0,
      collectionCode: json['collection_code']?.toString() ?? '',
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code']?.toString() ?? '',
      acidNumber: json['acid_number']?.toString(),
      importerName: json['importer_name']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      status: json['status']?.toString() ?? 'DRAFT',
      couriersList: (json['couriers_list'] as List<dynamic>? ?? [])
          .map((c) => CourierEntryModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      documentsList: (json['documents_list'] as List<dynamic>? ?? [])
          .map((d) => OriginalDocumentItemModel.fromJson(d as Map<String, dynamic>))
          .toList(),
      totalDocumentsCount: json['total_documents_count'] ?? 0,
      receivedDocumentsCount: json['received_documents_count'] ?? 0,
      verifiedDocumentsCount: json['verified_documents_count'] ?? 0,
      pendingDocumentsCount: json['pending_documents_count'] ?? 0,
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      discrepancyOverrideReason: json['discrepancy_override_reason']?.toString(),
      notes: json['notes']?.toString(),
      isActive: json['is_active'] != false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
      createdBy: json['created_by']?.toString() ?? '',
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
      updatedBy: json['updated_by']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collection_id': collectionId,
      'collection_code': collectionCode,
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'acid_number': acidNumber,
      'importer_name': importerName,
      'supplier_name': supplierName,
      'status': status,
      'couriers_list': couriersList.map((c) => c.toJson()).toList(),
      'documents_list': documentsList.map((d) => d.toJson()).toList(),
      'total_documents_count': totalDocumentsCount,
      'received_documents_count': receivedDocumentsCount,
      'verified_documents_count': verifiedDocumentsCount,
      'pending_documents_count': pendingDocumentsCount,
      'completion_percentage': completionPercentage,
      'discrepancy_override_reason': discrepancyOverrideReason,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
    };
  }
}

class OriginalDocumentsAutoPopulateModel {
  final int importFileId;
  final String importFileCode;
  final String? acidNumber;
  final String? importerName;
  final String? supplierName;
  final List<CourierEntryModel> defaultCouriers;
  final List<OriginalDocumentItemModel> requiredDocuments;
  final OriginalDocumentsCollectionSessionModel? existingSession;

  OriginalDocumentsAutoPopulateModel({
    required this.importFileId,
    required this.importFileCode,
    this.acidNumber,
    this.importerName,
    this.supplierName,
    required this.defaultCouriers,
    required this.requiredDocuments,
    this.existingSession,
  });

  factory OriginalDocumentsAutoPopulateModel.fromJson(Map<String, dynamic> json) {
    return OriginalDocumentsAutoPopulateModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code']?.toString() ?? '',
      acidNumber: json['acid_number']?.toString(),
      importerName: json['importer_name']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      defaultCouriers: (json['default_couriers'] as List<dynamic>? ?? [])
          .map((c) => CourierEntryModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      requiredDocuments: (json['required_documents'] as List<dynamic>? ?? [])
          .map((d) => OriginalDocumentItemModel.fromJson(d as Map<String, dynamic>))
          .toList(),
      existingSession: json['existing_session'] != null
          ? OriginalDocumentsCollectionSessionModel.fromJson(json['existing_session'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CourierReceiptProofRequestModel {
  final int importFileId;
  final String courierNo;
  final String receivedDate;
  final String? receivedTime;
  final String receivedBy;
  final String? podReference;
  final String? notes;
  final bool markDocumentsReceived;

  CourierReceiptProofRequestModel({
    required this.importFileId,
    required this.courierNo,
    required this.receivedDate,
    this.receivedTime,
    required this.receivedBy,
    this.podReference,
    this.notes,
    this.markDocumentsReceived = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'courier_no': courierNo,
      'received_date': receivedDate,
      'received_time': receivedTime,
      'received_by': receivedBy,
      'pod_reference': podReference,
      'notes': notes,
      'mark_documents_received': markDocumentsReceived,
    };
  }
}

class CourierAlertItemModel {
  final String courierNo;
  final String courierCompany;
  final int importFileId;
  final String importFileCode;
  final String? acidNumber;
  final String? importerName;
  final String? supplierName;
  final String? dispatchDate;
  final int daysInTransit;
  final String alertLevel; // 'INFO', 'WARNING', 'CRITICAL'
  final String alertMessageAr;
  final String alertMessageEn;

  CourierAlertItemModel({
    required this.courierNo,
    required this.courierCompany,
    required this.importFileId,
    required this.importFileCode,
    this.acidNumber,
    this.importerName,
    this.supplierName,
    this.dispatchDate,
    this.daysInTransit = 0,
    this.alertLevel = 'INFO',
    required this.alertMessageAr,
    required this.alertMessageEn,
  });

  factory CourierAlertItemModel.fromJson(Map<String, dynamic> json) {
    return CourierAlertItemModel(
      courierNo: json['courier_no']?.toString() ?? '',
      courierCompany: json['courier_company']?.toString() ?? 'DHL',
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code']?.toString() ?? '',
      acidNumber: json['acid_number']?.toString(),
      importerName: json['importer_name']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      dispatchDate: json['dispatch_date']?.toString(),
      daysInTransit: json['days_in_transit'] ?? 0,
      alertLevel: json['alert_level']?.toString() ?? 'INFO',
      alertMessageAr: json['alert_message_ar']?.toString() ?? '',
      alertMessageEn: json['alert_message_en']?.toString() ?? '',
    );
  }
}

class CourierAlertsResponseModel {
  final int totalActiveCouriers;
  final int pendingReceiptCount;
  final int delayedCount;
  final int deliveredCount;
  final List<CourierAlertItemModel> alerts;

  CourierAlertsResponseModel({
    this.totalActiveCouriers = 0,
    this.pendingReceiptCount = 0,
    this.delayedCount = 0,
    this.deliveredCount = 0,
    this.alerts = const [],
  });

  factory CourierAlertsResponseModel.fromJson(Map<String, dynamic> json) {
    return CourierAlertsResponseModel(
      totalActiveCouriers: json['total_active_couriers'] ?? 0,
      pendingReceiptCount: json['pending_receipt_count'] ?? 0,
      delayedCount: json['delayed_count'] ?? 0,
      deliveredCount: json['delivered_count'] ?? 0,
      alerts: (json['alerts'] as List<dynamic>? ?? [])
          .map((a) => CourierAlertItemModel.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CourierFlatItemModel {
  final String courierNo;
  final String courierCompany;
  final int importFileId;
  final String importFileCode;
  final String? importerName;
  final String? supplierName;
  final String? dispatchDate;
  final bool isReceived;
  final String? receivedDate;
  final String? receivedTime;
  final String? receivedBy;
  final String? trackingUrl;
  final String? podReference;
  final String status;
  final int daysInTransit;
  final int associatedDocsCount;
  final String? notes;

  CourierFlatItemModel({
    required this.courierNo,
    required this.courierCompany,
    required this.importFileId,
    required this.importFileCode,
    this.importerName,
    this.supplierName,
    this.dispatchDate,
    this.isReceived = false,
    this.receivedDate,
    this.receivedTime,
    this.receivedBy,
    this.trackingUrl,
    this.podReference,
    this.status = 'IN_TRANSIT',
    this.daysInTransit = 0,
    this.associatedDocsCount = 0,
    this.notes,
  });

  factory CourierFlatItemModel.fromJson(Map<String, dynamic> json) {
    return CourierFlatItemModel(
      courierNo: json['courier_no']?.toString() ?? '',
      courierCompany: json['courier_company']?.toString() ?? 'DHL',
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code']?.toString() ?? '',
      importerName: json['importer_name']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      dispatchDate: json['dispatch_date']?.toString(),
      isReceived: json['is_received'] == true,
      receivedDate: json['received_date']?.toString(),
      receivedTime: json['received_time']?.toString(),
      receivedBy: json['received_by']?.toString(),
      trackingUrl: json['tracking_url']?.toString(),
      podReference: json['pod_reference']?.toString(),
      status: json['status']?.toString() ?? 'IN_TRANSIT',
      daysInTransit: json['days_in_transit'] ?? 0,
      associatedDocsCount: json['associated_docs_count'] ?? 0,
      notes: json['notes']?.toString(),
    );
  }
}

