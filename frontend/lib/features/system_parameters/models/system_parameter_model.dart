class SystemParameterModel {
  final String paramKey;
  final String paramValue;
  final String? description;
  final bool isActive;
  final DateTime? updatedAt;
  final String? updatedBy;

  const SystemParameterModel({
    required this.paramKey,
    required this.paramValue,
    this.description,
    required this.isActive,
    this.updatedAt,
    this.updatedBy,
  });

  factory SystemParameterModel.fromJson(Map<String, dynamic> json) {
    return SystemParameterModel(
      paramKey: json['param_key']?.toString() ?? '',
      paramValue: json['param_value']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      updatedBy: json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'param_key': paramKey,
      'param_value': paramValue,
      'description': description,
      'is_active': isActive,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  SystemParameterModel copyWith({
    String? paramKey,
    String? paramValue,
    String? description,
    bool? isActive,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SystemParameterModel(
      paramKey: paramKey ?? this.paramKey,
      paramValue: paramValue ?? this.paramValue,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
