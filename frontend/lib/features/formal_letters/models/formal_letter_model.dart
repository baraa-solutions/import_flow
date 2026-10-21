class FormalLetterTemplateInfo {
  final String templateType;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;

  const FormalLetterTemplateInfo({
    required this.templateType,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
  });

  factory FormalLetterTemplateInfo.fromJson(Map<String, dynamic> json) {
    return FormalLetterTemplateInfo(
      templateType: json['template_type']?.toString() ?? '',
      titleAr: json['title_ar']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? '',
      descriptionAr: json['description_ar']?.toString() ?? '',
    );
  }
}

class FormalLetterResponseModel {
  final int? letterId;
  final String? letterCode;
  final String templateType;
  final String letterTitleAr;
  final String letterBody;
  final int importFileId;
  final String importFileCode;
  final String generatedAt;

  const FormalLetterResponseModel({
    this.letterId,
    this.letterCode,
    required this.templateType,
    required this.letterTitleAr,
    required this.letterBody,
    required this.importFileId,
    required this.importFileCode,
    required this.generatedAt,
  });

  factory FormalLetterResponseModel.fromJson(Map<String, dynamic> json) {
    return FormalLetterResponseModel(
      letterId: json['letter_id'] as int?,
      letterCode: json['letter_code']?.toString(),
      templateType: json['template_type']?.toString() ?? '',
      letterTitleAr: json['letter_title_ar']?.toString() ?? '',
      letterBody: json['letter_body']?.toString() ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code']?.toString() ?? '',
      generatedAt: json['generated_at']?.toString() ?? '',
    );
  }
}

class FormalLetterRecordModel {
  final int letterId;
  final String letterCode;
  final int importFileId;
  final String templateType;
  final String letterTitleAr;
  final String? recipientName;
  final String letterBody;
  final DateTime createdAt;
  final String createdBy;

  const FormalLetterRecordModel({
    required this.letterId,
    required this.letterCode,
    required this.importFileId,
    required this.templateType,
    required this.letterTitleAr,
    this.recipientName,
    required this.letterBody,
    required this.createdAt,
    required this.createdBy,
  });

  factory FormalLetterRecordModel.fromJson(Map<String, dynamic> json) {
    return FormalLetterRecordModel(
      letterId: json['letter_id'] as int? ?? 0,
      letterCode: json['letter_code']?.toString() ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      templateType: json['template_type']?.toString() ?? '',
      letterTitleAr: json['letter_title_ar']?.toString() ?? '',
      recipientName: json['recipient_name']?.toString(),
      letterBody: json['letter_body']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by']?.toString() ?? '',
    );
  }
}
