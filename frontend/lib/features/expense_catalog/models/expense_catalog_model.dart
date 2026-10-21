class ExpenseCatalogModel {
  final String code;
  final String canonicalNameAr;
  final String? canonicalNameEn;
  final String category;
  final String unitType;
  final bool allowComposite;
  final List<String> recognitionPatterns;
  final bool isActive;
  final DateTime? createdAt;

  const ExpenseCatalogModel({
    required this.code,
    required this.canonicalNameAr,
    this.canonicalNameEn,
    required this.category,
    this.unitType = 'fixed',
    this.allowComposite = false,
    this.recognitionPatterns = const [],
    this.isActive = true,
    this.createdAt,
  });

  factory ExpenseCatalogModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCatalogModel(
      code: json['code']?.toString() ?? '',
      canonicalNameAr: json['canonical_name_ar']?.toString() ?? '',
      canonicalNameEn: json['canonical_name_en']?.toString(),
      category: json['category']?.toString() ?? 'Other Fees',
      unitType: json['unit_type']?.toString() ?? 'fixed',
      allowComposite: json['allow_composite'] as bool? ?? false,
      recognitionPatterns: (json['recognition_patterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'canonical_name_ar': canonicalNameAr,
      'canonical_name_en': canonicalNameEn,
      'category': category,
      'unit_type': unitType,
      'allow_composite': allowComposite,
      'recognition_patterns': recognitionPatterns,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

class BrokerMappingModel {
  final String brokerName;
  final String rawItemName;
  final String catalogCode;
  final String canonicalNameAr;
  final String? canonicalNameEn;
  final String category;
  final String unitType;
  final double confidenceScore;
  final String matchConfidence;
  final String source;

  const BrokerMappingModel({
    required this.brokerName,
    required this.rawItemName,
    required this.catalogCode,
    required this.canonicalNameAr,
    this.canonicalNameEn,
    required this.category,
    this.unitType = 'fixed',
    this.confidenceScore = 1.0,
    this.matchConfidence = 'high',
    this.source = 'broker_memory',
  });

  factory BrokerMappingModel.fromJson(Map<String, dynamic> json) {
    return BrokerMappingModel(
      brokerName: json['broker_name']?.toString() ?? '',
      rawItemName: json['raw_item_name']?.toString() ?? '',
      catalogCode: json['catalog_code']?.toString() ?? json['code']?.toString() ?? '',
      canonicalNameAr: json['canonical_name_ar']?.toString() ?? '',
      canonicalNameEn: json['canonical_name_en']?.toString(),
      category: json['category']?.toString() ?? '',
      unitType: json['unit_type']?.toString() ?? 'fixed',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 1.0,
      matchConfidence: json['match_confidence']?.toString() ?? 'high',
      source: json['source']?.toString() ?? 'broker_memory',
    );
  }
}
