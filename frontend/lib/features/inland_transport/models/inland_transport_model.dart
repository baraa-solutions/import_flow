/// TR-01: Inland Transport Coordination Model
/// تنسيق وحجز سيارات وسائقي النقل الداخلي للمخزن وتتبع زمن الخروج والوصول
class InlandTransportModel {
  final int transportId;
  final String transportCode;
  final int importFileId;
  final String waybillNumber;
  final String bookingDate;
  final int? carrierId;
  final String carrierName;
  final String truckPlateNumber;
  final String truckType;
  final String driverName;
  final String driverPhone;
  final String? driverNationalId;
  final String? containerNumbers;
  final String pickupPortLocation;
  final String destinationWarehouse;
  final String plannedDepartureAt;
  final String? actualDepartureAt;
  final String expectedArrivalAt;
  final String? actualArrivalAt;
  final double transportFareEgp;
  final String status;
  final String? trackingNotes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  InlandTransportModel({
    required this.transportId,
    required this.transportCode,
    required this.importFileId,
    required this.waybillNumber,
    required this.bookingDate,
    this.carrierId,
    required this.carrierName,
    required this.truckPlateNumber,
    this.truckType = 'FLATBED',
    required this.driverName,
    required this.driverPhone,
    this.driverNationalId,
    this.containerNumbers,
    required this.pickupPortLocation,
    this.destinationWarehouse = 'Main Warehouse - Cairo',
    required this.plannedDepartureAt,
    this.actualDepartureAt,
    required this.expectedArrivalAt,
    this.actualArrivalAt,
    this.transportFareEgp = 0.0,
    this.status = 'Booking Confirmed',
    this.trackingNotes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InlandTransportModel.fromJson(Map<String, dynamic> json) {
    return InlandTransportModel(
      transportId: json['transport_id'] ?? 0,
      transportCode: json['transport_code'] ?? '',
      importFileId: json['import_file_id'] ?? 0,
      waybillNumber: json['waybill_number'] ?? '',
      bookingDate: json['booking_date'] ?? '',
      carrierId: json['carrier_id'],
      carrierName: json['carrier_name'] ?? '',
      truckPlateNumber: json['truck_plate_number'] ?? '',
      truckType: json['truck_type'] ?? 'FLATBED',
      driverName: json['driver_name'] ?? '',
      driverPhone: json['driver_phone'] ?? '',
      driverNationalId: json['driver_national_id'],
      containerNumbers: json['container_numbers'],
      pickupPortLocation: json['pickup_port_location'] ?? '',
      destinationWarehouse: json['destination_warehouse'] ?? 'Main Warehouse - Cairo',
      plannedDepartureAt: json['planned_departure_at'] ?? '',
      actualDepartureAt: json['actual_departure_at'],
      expectedArrivalAt: json['expected_arrival_at'] ?? '',
      actualArrivalAt: json['actual_arrival_at'],
      transportFareEgp: (json['transport_fare_egp'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'Booking Confirmed',
      trackingNotes: json['tracking_notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transport_id': transportId,
      'transport_code': transportCode,
      'import_file_id': importFileId,
      'waybill_number': waybillNumber,
      'booking_date': bookingDate,
      if (carrierId != null) 'carrier_id': carrierId,
      'carrier_name': carrierName,
      'truck_plate_number': truckPlateNumber,
      'truck_type': truckType,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      if (driverNationalId != null) 'driver_national_id': driverNationalId,
      if (containerNumbers != null) 'container_numbers': containerNumbers,
      'pickup_port_location': pickupPortLocation,
      'destination_warehouse': destinationWarehouse,
      'planned_departure_at': plannedDepartureAt,
      if (actualDepartureAt != null) 'actual_departure_at': actualDepartureAt,
      'expected_arrival_at': expectedArrivalAt,
      if (actualArrivalAt != null) 'actual_arrival_at': actualArrivalAt,
      'transport_fare_egp': transportFareEgp,
      'status': status,
      if (trackingNotes != null) 'tracking_notes': trackingNotes,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  InlandTransportModel copyWith({
    int? transportId,
    String? transportCode,
    int? importFileId,
    String? waybillNumber,
    String? bookingDate,
    int? carrierId,
    String? carrierName,
    String? truckPlateNumber,
    String? truckType,
    String? driverName,
    String? driverPhone,
    String? driverNationalId,
    String? containerNumbers,
    String? pickupPortLocation,
    String? destinationWarehouse,
    String? plannedDepartureAt,
    String? actualDepartureAt,
    String? expectedArrivalAt,
    String? actualArrivalAt,
    double? transportFareEgp,
    String? status,
    String? trackingNotes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return InlandTransportModel(
      transportId: transportId ?? this.transportId,
      transportCode: transportCode ?? this.transportCode,
      importFileId: importFileId ?? this.importFileId,
      waybillNumber: waybillNumber ?? this.waybillNumber,
      bookingDate: bookingDate ?? this.bookingDate,
      carrierId: carrierId ?? this.carrierId,
      carrierName: carrierName ?? this.carrierName,
      truckPlateNumber: truckPlateNumber ?? this.truckPlateNumber,
      truckType: truckType ?? this.truckType,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverNationalId: driverNationalId ?? this.driverNationalId,
      containerNumbers: containerNumbers ?? this.containerNumbers,
      pickupPortLocation: pickupPortLocation ?? this.pickupPortLocation,
      destinationWarehouse: destinationWarehouse ?? this.destinationWarehouse,
      plannedDepartureAt: plannedDepartureAt ?? this.plannedDepartureAt,
      actualDepartureAt: actualDepartureAt ?? this.actualDepartureAt,
      expectedArrivalAt: expectedArrivalAt ?? this.expectedArrivalAt,
      actualArrivalAt: actualArrivalAt ?? this.actualArrivalAt,
      transportFareEgp: transportFareEgp ?? this.transportFareEgp,
      status: status ?? this.status,
      trackingNotes: trackingNotes ?? this.trackingNotes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
