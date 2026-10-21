class UploadSessionModel {
  final int id;
  final String sessionRef;
  final String moduleName;
  final String filename;
  final String? fileType;
  final int? fileSizeBytes;
  final String extractionStatus;
  final double confidenceScore;
  final Map<String, dynamic> extractedFields;
  final List<String> missingFields;
  final String? extractionNotes;
  final int? linkedRecordId;
  final String? linkedModule;
  final DateTime? createdAt;

  const UploadSessionModel({
    required this.id,
    required this.sessionRef,
    required this.moduleName,
    required this.filename,
    this.fileType,
    this.fileSizeBytes,
    required this.extractionStatus,
    this.confidenceScore = 0.0,
    this.extractedFields = const {},
    this.missingFields = const [],
    this.extractionNotes,
    this.linkedRecordId,
    this.linkedModule,
    this.createdAt,
  });

  factory UploadSessionModel.fromJson(Map<String, dynamic> json) {
    return UploadSessionModel(
      id: json['id'] as int? ?? 0,
      sessionRef: json['session_ref']?.toString() ?? '',
      moduleName: json['module_name']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      fileType: json['file_type']?.toString(),
      fileSizeBytes: json['file_size_bytes'] as int?,
      extractionStatus: json['extraction_status']?.toString() ?? 'SUCCESS',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      extractedFields: json['extracted_fields'] is Map<String, dynamic>
          ? json['extracted_fields'] as Map<String, dynamic>
          : {},
      missingFields: (json['missing_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      extractionNotes: json['extraction_notes']?.toString(),
      linkedRecordId: json['linked_record_id'] as int?,
      linkedModule: json['linked_module']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
