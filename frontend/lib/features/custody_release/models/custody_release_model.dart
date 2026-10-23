class CustodyReleaseDossierModel {
  final int custodyId;
  final String custodyCode;
  final int importFileId;
  final int? warehouseId;
  final String? warehouseAddress;
  final String custodyUndertakingNumber;
  final String? judicialOfficerName;
  final int leadSealsCount;
  final List<String> leadSealNumbers;
  final String? transportPermitNumber;
  final String status;
  final bool lockActive;
  final String? finalClearanceLetterNumber;
  final DateTime? releaseApprovedAt;
  final String? breachReason;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final bool isActive;

  const CustodyReleaseDossierModel({
    required this.custodyId,
    required this.custodyCode,
    required this.importFileId,
    this.warehouseId,
    this.warehouseAddress,
    required this.custodyUndertakingNumber,
    this.judicialOfficerName,
    this.leadSealsCount = 0,
    this.leadSealNumbers = const [],
    this.transportPermitNumber,
    this.status = 'RELEASED_UNDER_CUSTODY',
    this.lockActive = true,
    this.finalClearanceLetterNumber,
    this.releaseApprovedAt,
    this.breachReason,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.isActive = true,
  });

  factory CustodyReleaseDossierModel.fromJson(Map<String, dynamic> json) {
    return CustodyReleaseDossierModel(
      custodyId: json['custody_id'] as int? ?? 0,
      custodyCode: json['custody_code']?.toString() ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      warehouseId: json['warehouse_id'] as int?,
      warehouseAddress: json['warehouse_address']?.toString(),
      custodyUndertakingNumber: json['custody_undertaking_number']?.toString() ?? '',
      judicialOfficerName: json['judicial_officer_name']?.toString(),
      leadSealsCount: json['lead_seals_count'] as int? ?? 0,
      leadSealNumbers: (json['lead_seal_numbers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      transportPermitNumber: json['transport_permit_number']?.toString(),
      status: json['status']?.toString() ?? 'RELEASED_UNDER_CUSTODY',
      lockActive: json['lock_active'] as bool? ?? true,
      finalClearanceLetterNumber: json['final_clearance_letter_number']?.toString(),
      releaseApprovedAt: json['release_approved_at'] != null
          ? DateTime.tryParse(json['release_approved_at'].toString())
          : null,
      breachReason: json['breach_reason']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
