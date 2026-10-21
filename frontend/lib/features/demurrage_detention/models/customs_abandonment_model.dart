class CustomsAbandonmentRadarModel {
  final int radarId;
  final int? importFileId;
  final String importFileCode;
  final String portType; // SEAPORT, DRY_PORT, AIRPORT
  final String? portName;
  final String arrivalDate;
  final int maxLegalDays;
  final int daysInPort;
  final int daysRemaining;
  final String riskLevel; // NORMAL, WARNING_15_DAYS, CRITICAL_7_DAYS, UNDER_ABANDONMENT_INVENTORY
  final bool extensionRequested;
  final String? extensionRequestDate;
  final String? extensionReason;
  final String? extensionRequestRef;
  final String? extensionGrantedUntil;
  final bool officialLetterIssued;
  final String abandonmentStatus; // ACTIVE_CLEARING, EXTENSION_PENDING, MOVED_TO_ABANDONED_WAREHOUSE, AUCTION_SCHEDULED, RESOLVED_RELEASED
  final String? importerName;
  final String? cargoDescription;
  final String? customsDeclarationNo;
  final String? blNumber;
  final String? acidNumber;
  final List<String> containerNumbers;
  final String? actionPlan;
  final String? notes;
  final bool isActive;

  CustomsAbandonmentRadarModel({
    required this.radarId,
    this.importFileId,
    required this.importFileCode,
    this.portType = 'SEAPORT',
    this.portName,
    required this.arrivalDate,
    this.maxLegalDays = 60,
    this.daysInPort = 0,
    this.daysRemaining = 60,
    this.riskLevel = 'NORMAL',
    this.extensionRequested = false,
    this.extensionRequestDate,
    this.extensionReason,
    this.extensionRequestRef,
    this.extensionGrantedUntil,
    this.officialLetterIssued = false,
    this.abandonmentStatus = 'ACTIVE_CLEARING',
    this.importerName,
    this.cargoDescription,
    this.customsDeclarationNo,
    this.blNumber,
    this.acidNumber,
    this.containerNumbers = const [],
    this.actionPlan,
    this.notes,
    this.isActive = true,
  });

  factory CustomsAbandonmentRadarModel.fromJson(Map<String, dynamic> json) {
    List<String> parseContainers(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return CustomsAbandonmentRadarModel(
      radarId: json['radar_id'] ?? 0,
      importFileId: json['import_file_id'],
      importFileCode: json['import_file_code'] ?? '',
      portType: json['port_type'] ?? 'SEAPORT',
      portName: json['port_name'],
      arrivalDate: json['arrival_date'] ?? '',
      maxLegalDays: json['max_legal_days'] ?? 60,
      daysInPort: json['days_in_port'] ?? 0,
      daysRemaining: json['days_remaining'] ?? 60,
      riskLevel: json['risk_level'] ?? 'NORMAL',
      extensionRequested: json['extension_requested'] ?? false,
      extensionRequestDate: json['extension_request_date'],
      extensionReason: json['extension_reason'],
      extensionRequestRef: json['extension_request_ref'],
      extensionGrantedUntil: json['extension_granted_until'],
      officialLetterIssued: json['official_letter_issued'] ?? false,
      abandonmentStatus: json['abandonment_status'] ?? 'ACTIVE_CLEARING',
      importerName: json['importer_name'],
      cargoDescription: json['cargo_description'],
      customsDeclarationNo: json['customs_declaration_no'],
      blNumber: json['bl_number'],
      acidNumber: json['acid_number'],
      containerNumbers: parseContainers(json['container_numbers']),
      actionPlan: json['action_plan'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'port_type': portType,
      'port_name': portName,
      'arrival_date': arrivalDate,
      'importer_name': importerName,
      'cargo_description': cargoDescription,
      'customs_declaration_no': customsDeclarationNo,
      'bl_number': blNumber,
      'acid_number': acidNumber,
      'container_numbers': containerNumbers,
      'notes': notes,
    };
  }
}

class CustomsAbandonmentSummaryModel {
  final int totalRadars;
  final int normalCount;
  final int warning15DaysCount;
  final int critical7DaysCount;
  final int underInventoryCount;
  final int extensionPendingCount;
  final int movedToWarehouseCount;
  final int auctionScheduledCount;
  final int resolvedReleasedCount;
  final int seaportCount;
  final int dryPortCount;
  final int airportCount;

  CustomsAbandonmentSummaryModel({
    required this.totalRadars,
    required this.normalCount,
    required this.warning15DaysCount,
    required this.critical7DaysCount,
    required this.underInventoryCount,
    required this.extensionPendingCount,
    required this.movedToWarehouseCount,
    required this.auctionScheduledCount,
    required this.resolvedReleasedCount,
    required this.seaportCount,
    required this.dryPortCount,
    required this.airportCount,
  });

  factory CustomsAbandonmentSummaryModel.fromJson(Map<String, dynamic> json) {
    return CustomsAbandonmentSummaryModel(
      totalRadars: json['total_radars'] ?? 0,
      normalCount: json['normal_count'] ?? 0,
      warning15DaysCount: json['warning_15_days_count'] ?? 0,
      critical7DaysCount: json['critical_7_days_count'] ?? 0,
      underInventoryCount: json['under_inventory_count'] ?? 0,
      extensionPendingCount: json['extension_pending_count'] ?? 0,
      movedToWarehouseCount: json['moved_to_warehouse_count'] ?? 0,
      auctionScheduledCount: json['auction_scheduled_count'] ?? 0,
      resolvedReleasedCount: json['resolved_released_count'] ?? 0,
      seaportCount: json['seaport_count'] ?? 0,
      dryPortCount: json['dry_port_count'] ?? 0,
      airportCount: json['airport_count'] ?? 0,
    );
  }
}

class ExtensionLetterDraftModel {
  final String letterRef;
  final String letterDate;
  final String recipientTitle;
  final String importerName;
  final String importFileCode;
  final String portName;
  final String subject;
  final String formalBodyAr;
  final String legalBasis;
  final Map<String, dynamic> metadata;

  ExtensionLetterDraftModel({
    required this.letterRef,
    required this.letterDate,
    required this.recipientTitle,
    required this.importerName,
    required this.importFileCode,
    required this.portName,
    required this.subject,
    required this.formalBodyAr,
    required this.legalBasis,
    required this.metadata,
  });

  factory ExtensionLetterDraftModel.fromJson(Map<String, dynamic> json) {
    return ExtensionLetterDraftModel(
      letterRef: json['letter_ref'] ?? '',
      letterDate: json['letter_date'] ?? '',
      recipientTitle: json['recipient_title'] ?? '',
      importerName: json['importer_name'] ?? '',
      importFileCode: json['import_file_code'] ?? '',
      portName: json['port_name'] ?? '',
      subject: json['subject'] ?? '',
      formalBodyAr: json['formal_body_ar'] ?? '',
      legalBasis: json['legal_basis'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}
