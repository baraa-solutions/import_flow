/// Stage & Screen Notes — Data Models
class StageNoteAttachmentModel {
  final int id;
  final int noteId;
  final String fileName;
  final int fileSizeBytes;
  final String fileType;
  final String downloadUrl;
  final DateTime createdAt;

  const StageNoteAttachmentModel({
    required this.id,
    required this.noteId,
    required this.fileName,
    required this.fileSizeBytes,
    required this.fileType,
    required this.downloadUrl,
    required this.createdAt,
  });

  factory StageNoteAttachmentModel.fromJson(Map<String, dynamic> json) {
    return StageNoteAttachmentModel(
      id: json['id'] as int? ?? 0,
      noteId: json['note_id'] as int? ?? 0,
      fileName: json['file_name'] as String? ?? '',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      fileType: json['file_type'] as String? ?? 'generic',
      downloadUrl: json['download_url'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class StageNoteModel {
  final int id;
  final String screenCode;
  final int? recordId;
  final String? stageCode;
  final String noteText;
  final String createdBy;
  final DateTime createdAt;
  final List<StageNoteAttachmentModel> attachments;

  const StageNoteModel({
    required this.id,
    required this.screenCode,
    this.recordId,
    this.stageCode,
    required this.noteText,
    required this.createdBy,
    required this.createdAt,
    required this.attachments,
  });

  factory StageNoteModel.fromJson(Map<String, dynamic> json) {
    final rawAtts = json['attachments'] as List? ?? [];
    return StageNoteModel(
      id: json['id'] as int? ?? 0,
      screenCode: json['screen_code'] as String? ?? '',
      recordId: json['record_id'] as int?,
      stageCode: json['stage_code'] as String?,
      noteText: json['note_text'] as String? ?? '',
      createdBy: json['created_by'] as String? ?? 'User',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      attachments: rawAtts
          .map((a) => StageNoteAttachmentModel.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
    );
  }
}

class StageNotesSummaryModel {
  final String screenCode;
  final int? recordId;
  final String? stageCode;
  final int totalNotes;
  final int totalAttachments;
  final List<StageNoteModel> notes;

  const StageNotesSummaryModel({
    required this.screenCode,
    this.recordId,
    this.stageCode,
    required this.totalNotes,
    required this.totalAttachments,
    required this.notes,
  });

  factory StageNotesSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'] as List? ?? [];
    return StageNotesSummaryModel(
      screenCode: json['screen_code'] as String? ?? '',
      recordId: json['record_id'] as int?,
      stageCode: json['stage_code'] as String?,
      totalNotes: json['total_notes'] as int? ?? 0,
      totalAttachments: json['total_attachments'] as int? ?? 0,
      notes: rawNotes
          .map((n) => StageNoteModel.fromJson(Map<String, dynamic>.from(n as Map)))
          .toList(),
    );
  }
}
