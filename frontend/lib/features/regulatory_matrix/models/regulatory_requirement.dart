/// Model representing an HS Code Regulatory Requirement
class RegulatoryRequirement {
  final int id;
  final String hsCode;
  final String agencyCode;
  final String agencyNameAr;
  final String agencyNameEn;
  final String stageTiming;
  final String? requiredDocuments;
  final String? inspectionType;
  final String? regulatoryNotes;
  final bool isMandatory;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;

  const RegulatoryRequirement({
    required this.id,
    required this.hsCode,
    required this.agencyCode,
    required this.agencyNameAr,
    required this.agencyNameEn,
    required this.stageTiming,
    this.requiredDocuments,
    this.inspectionType,
    this.regulatoryNotes,
    this.isMandatory = true,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
  });

  factory RegulatoryRequirement.fromJson(Map<String, dynamic> json) {
    return RegulatoryRequirement(
      id: json['id'] as int? ?? 0,
      hsCode: json['hs_code'] as String? ?? '',
      agencyCode: json['agency_code'] as String? ?? '',
      agencyNameAr: json['agency_name_ar'] as String? ?? '',
      agencyNameEn: json['agency_name_en'] as String? ?? '',
      stageTiming: json['stage_timing'] as String? ?? 'PRE_ARRIVAL',
      requiredDocuments: json['required_documents'] as String?,
      inspectionType: json['inspection_type'] as String?,
      regulatoryNotes: json['regulatory_notes'] as String?,
      isMandatory: json['is_mandatory'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hs_code': hsCode,
      'agency_code': agencyCode,
      'agency_name_ar': agencyNameAr,
      'agency_name_en': agencyNameEn,
      'stage_timing': stageTiming,
      'required_documents': requiredDocuments,
      'inspection_type': inspectionType,
      'regulatory_notes': regulatoryNotes,
      'is_mandatory': isMandatory,
      'is_active': isActive,
    };
  }

  String get localizedTiming {
    switch (stageTiming) {
      case 'PRE_ACID':
        return 'قبل الرقم المسبق';
      case 'PRE_ARRIVAL':
        return 'قبل وصول الشحنة';
      case 'CUSTOMS_EXAMINATION':
        return 'أثناء الكشف والمعاينة';
      case 'POST_CLEARANCE':
        return 'إفراج تحت التحفظ';
      default:
        return stageTiming;
    }
  }

  String get localizedInspection {
    switch (inspectionType) {
      case 'PHYSICAL_INSPECTION':
        return 'كشف ظاهري ومعاينة';
      case 'DOCUMENTARY_CHECK':
        return 'فحص ومطابقة مستندية';
      case 'LAB_SAMPLING':
        return 'سحب عينات وتحليل معملي';
      default:
        return inspectionType ?? 'غير محدد';
    }
  }
}
