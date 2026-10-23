class ContainerSpecModel {
  final String code;
  final String name;
  final double internalLengthM;
  final double internalWidthM;
  final double internalHeightM;
  final double doorWidthM;
  final double doorHeightM;
  final double maxPayloadKg;
  final double totalCbmCapacity;
  final double totalFloorAreaM2;

  const ContainerSpecModel({
    required this.code,
    required this.name,
    required this.internalLengthM,
    required this.internalWidthM,
    required this.internalHeightM,
    required this.doorWidthM,
    required this.doorHeightM,
    required this.maxPayloadKg,
    required this.totalCbmCapacity,
    required this.totalFloorAreaM2,
  });

  factory ContainerSpecModel.fromJson(Map<String, dynamic> json) {
    return ContainerSpecModel(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      internalLengthM: (json['internal_length_m'] as num?)?.toDouble() ?? 0.0,
      internalWidthM: (json['internal_width_m'] as num?)?.toDouble() ?? 0.0,
      internalHeightM: (json['internal_height_m'] as num?)?.toDouble() ?? 0.0,
      doorWidthM: (json['door_width_m'] as num?)?.toDouble() ?? 0.0,
      doorHeightM: (json['door_height_m'] as num?)?.toDouble() ?? 0.0,
      maxPayloadKg: (json['max_payload_kg'] as num?)?.toDouble() ?? 0.0,
      totalCbmCapacity: (json['total_cbm_capacity'] as num?)?.toDouble() ?? 0.0,
      totalFloorAreaM2: (json['total_floor_area_m2'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ContainerOptionEvaluationModel {
  final String containerCode;
  final String containerName;
  final String status;
  final int requiredCount;
  final double totalCbm;
  final double totalWeightKg;
  final double floorAreaRequiredM2;
  final double containerFloorAreaM2;
  final double volumeUtilizationPct;
  final double weightUtilizationPct;
  final double floorUtilizationPct;
  final List<String> reasonsAr;

  const ContainerOptionEvaluationModel({
    required this.containerCode,
    required this.containerName,
    required this.status,
    required this.requiredCount,
    required this.totalCbm,
    required this.totalWeightKg,
    required this.floorAreaRequiredM2,
    required this.containerFloorAreaM2,
    required this.volumeUtilizationPct,
    required this.weightUtilizationPct,
    required this.floorUtilizationPct,
    required this.reasonsAr,
  });

  factory ContainerOptionEvaluationModel.fromJson(Map<String, dynamic> json) {
    return ContainerOptionEvaluationModel(
      containerCode: json['container_code']?.toString() ?? '',
      containerName: json['container_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      requiredCount: json['required_count'] as int? ?? 1,
      totalCbm: (json['total_cbm'] as num?)?.toDouble() ?? 0.0,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble() ?? 0.0,
      floorAreaRequiredM2: (json['floor_area_required_m2'] as num?)?.toDouble() ?? 0.0,
      containerFloorAreaM2: (json['container_floor_area_m2'] as num?)?.toDouble() ?? 0.0,
      volumeUtilizationPct: (json['volume_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      weightUtilizationPct: (json['weight_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      floorUtilizationPct: (json['floor_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      reasonsAr: (json['reasons_ar'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class ContainerLoaderEvaluationResultModel {
  final String recommendedContainer;
  final String recommendedContainerName;
  final int recommendedCount;
  final String status;
  final double totalCbm;
  final double totalWeightKg;
  final bool isStackable;
  final double floorUtilizationPct;
  final double volumeUtilizationPct;
  final double weightUtilizationPct;
  final List<String> reasonsAr;
  final List<ContainerOptionEvaluationModel> allOptions;

  const ContainerLoaderEvaluationResultModel({
    required this.recommendedContainer,
    required this.recommendedContainerName,
    required this.recommendedCount,
    required this.status,
    required this.totalCbm,
    required this.totalWeightKg,
    required this.isStackable,
    required this.floorUtilizationPct,
    required this.volumeUtilizationPct,
    required this.weightUtilizationPct,
    required this.reasonsAr,
    required this.allOptions,
  });

  factory ContainerLoaderEvaluationResultModel.fromJson(Map<String, dynamic> json) {
    return ContainerLoaderEvaluationResultModel(
      recommendedContainer: json['recommended_container']?.toString() ?? '',
      recommendedContainerName: json['recommended_container_name']?.toString() ?? '',
      recommendedCount: json['recommended_count'] as int? ?? 1,
      status: json['status']?.toString() ?? '',
      totalCbm: (json['total_cbm'] as num?)?.toDouble() ?? 0.0,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble() ?? 0.0,
      isStackable: json['is_stackable'] as bool? ?? false,
      floorUtilizationPct: (json['floor_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      volumeUtilizationPct: (json['volume_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      weightUtilizationPct: (json['weight_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      reasonsAr: (json['reasons_ar'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      allOptions: (json['all_options'] as List<dynamic>?)
              ?.map((e) => ContainerOptionEvaluationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
