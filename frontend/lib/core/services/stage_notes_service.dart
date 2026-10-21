import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../models/stage_note_model.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import 'file_save_helper.dart';

final stageNotesServiceProvider = Provider<StageNotesService>((ref) {
  final dio = ref.watch(dioProvider);
  return StageNotesService(dio);
});

class StageNotesService {
  final Dio _dio;

  StageNotesService(this._dio);

  /// Fetch notes summary with chronological history and attachments
  Future<StageNotesSummaryModel> fetchNotes({
    required String screenCode,
    int? recordId,
    String? stageCode,
  }) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/stage-notes',
      queryParameters: {
        'screen_code': screenCode,
        if (recordId != null) 'record_id': recordId,
        if (stageCode != null && stageCode.isNotEmpty) 'stage_code': stageCode,
      },
    );

    return StageNotesSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Create a new note with optional attachments (images, PDFs, documents)
  Future<StageNoteModel> createNote({
    required String screenCode,
    required String noteText,
    int? recordId,
    String? stageCode,
    List<PlatformFile>? files,
  }) async {
    final Map<String, dynamic> formMap = {
      'screen_code': screenCode,
      'note_text': noteText,
      if (recordId != null) 'record_id': recordId.toString(),
      if (stageCode != null && stageCode.isNotEmpty) 'stage_code': stageCode,
    };

    if (files != null && files.isNotEmpty) {
      final uploadFiles = <MultipartFile>[];
      for (final f in files) {
        if (f.bytes != null) {
          uploadFiles.add(
            MultipartFile.fromBytes(f.bytes!, filename: f.name),
          );
        }
      }
      if (uploadFiles.isNotEmpty) {
        formMap['files'] = uploadFiles;
      }
    }

    final formData = FormData.fromMap(formMap);

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/stage-notes',
      data: formData,
    );

    return StageNoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Download an attachment file using the mandatory Save As Dialog protocol
  Future<void> downloadAttachment({
    required BuildContext context,
    required StageNoteAttachmentModel attachment,
    required String screenTitle,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        '${ApiConstants.baseUrl}${attachment.downloadUrl}',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          AppTheme.snackBar(
            context,
            'تعذر تحميل الملف المرفق أو الملف فارغ',
            severity: AppSeverity.danger,
          );
        }
        return;
      }

      final ext = attachment.fileName.contains('.')
          ? attachment.fileName.split('.').last
          : 'bin';
      final baseName = attachment.fileName.contains('.')
          ? attachment.fileName.substring(0, attachment.fileName.lastIndexOf('.'))
          : attachment.fileName;

      if (context.mounted) {
        await FileSaveHelper.exportAndSaveFile(
          context: context,
          bytes: bytes,
          stageName: screenTitle,
          importFileNameOrCode: baseName,
          extension: ext,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppTheme.snackBar(
          context,
          'فشل تنزيل المرفق: $e',
          severity: AppSeverity.danger,
        );
      }
    }
  }

  /// Soft-delete note
  Future<bool> deleteNote(int noteId) async {
    final response = await _dio.delete('${ApiConstants.baseUrl}/stage-notes/$noteId');
    return response.statusCode == 200;
  }
}
