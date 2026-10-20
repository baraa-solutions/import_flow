class ShipmentEtaTrackingLogModel {
  final int logId;
  final int bookingId;
  final int importFileId;
  final String trackingDate;
  final String? vesselLocation;
  final String currentEta;
  final int delayDays;
  final String? remarks;
  final bool isAtaConfirmed;
  final String? confirmedAta;
  final String createdAt;
  final String? createdBy;

  ShipmentEtaTrackingLogModel({
    required this.logId,
    required this.bookingId,
    required this.importFileId,
    required this.trackingDate,
    this.vesselLocation,
    required this.currentEta,
    this.delayDays = 0,
    this.remarks,
    this.isAtaConfirmed = false,
    this.confirmedAta,
    required this.createdAt,
    this.createdBy,
  });

  factory ShipmentEtaTrackingLogModel.fromJson(Map<String, dynamic> json) {
    return ShipmentEtaTrackingLogModel(
      logId: json['log_id'] ?? 0,
      bookingId: json['booking_id'] ?? 0,
      importFileId: json['import_file_id'] ?? 0,
      trackingDate: json['tracking_date'] ?? '',
      vesselLocation: json['vessel_location'],
      currentEta: json['current_eta'] ?? '',
      delayDays: json['delay_days'] ?? 0,
      remarks: json['remarks'],
      isAtaConfirmed: json['is_ata_confirmed'] ?? false,
      confirmedAta: json['confirmed_ata'],
      createdAt: json['created_at'] ?? '',
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'booking_id': bookingId,
      'import_file_id': importFileId,
      'tracking_date': trackingDate,
      'vessel_location': vesselLocation,
      'current_eta': currentEta,
      'delay_days': delayDays,
      'remarks': remarks,
      'is_ata_confirmed': isAtaConfirmed,
      'confirmed_ata': confirmedAta,
      'created_at': createdAt,
      'created_by': createdBy,
    };
  }
}
