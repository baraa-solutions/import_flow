import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/stage_note_model.dart';
import 'package:frontend/core/services/stage_notes_service.dart';
import 'package:frontend/core/widgets/stage_notes_card.dart';

import 'package:dio/dio.dart';

class MockStageNotesService extends StageNotesService {
  MockStageNotesService() : super(Dio());

  StageNotesSummaryModel mockSummary = StageNotesSummaryModel(
    screenCode: 'import_files',
    recordId: 101,
    stageCode: 'STEP-01',
    totalNotes: 1,
    totalAttachments: 1,
    notes: [
      StageNoteModel(
        id: 1,
        screenCode: 'import_files',
        recordId: 101,
        stageCode: 'STEP-01',
        noteText: 'Verified delivery order and customs receipt.',
        createdBy: 'Ahmed Sorour',
        createdAt: DateTime(2026, 10, 21, 11, 0),
        attachments: [
          StageNoteAttachmentModel(
            id: 10,
            noteId: 1,
            fileName: 'customs_receipt.pdf',
            fileSizeBytes: 245760,
            fileType: 'pdf',
            downloadUrl: '/api/v1/stage-notes/attachments/10/download',
            createdAt: DateTime(2026, 10, 21, 11, 0),
          ),
        ],
      ),
    ],
  );

  @override
  Future<StageNotesSummaryModel> fetchNotes({
    required String screenCode,
    int? recordId,
    String? stageCode,
  }) async {
    return mockSummary;
  }

  @override
  Future<StageNoteModel> createNote({
    required String screenCode,
    required String noteText,
    int? recordId,
    String? stageCode,
    dynamic files,
  }) async {
    final newNote = StageNoteModel(
      id: 2,
      screenCode: screenCode,
      recordId: recordId,
      stageCode: stageCode,
      noteText: noteText,
      createdBy: 'Test User',
      createdAt: DateTime.now(),
      attachments: [],
    );
    mockSummary = StageNotesSummaryModel(
      screenCode: screenCode,
      recordId: recordId,
      stageCode: stageCode,
      totalNotes: mockSummary.totalNotes + 1,
      totalAttachments: mockSummary.totalAttachments,
      notes: [newNote, ...mockSummary.notes],
    );
    return newNote;
  }
}

void main() {
  group('StageNoteModel Tests', () {
    test('JSON serialization & deserialization', () {
      final json = {
        'id': 5,
        'screen_code': 'customs_clearance',
        'record_id': 12,
        'stage_code': 'PHASE-03',
        'note_text': 'Inspection cleared without reservations.',
        'created_by': 'Karim Customs',
        'created_at': '2026-10-21T10:30:00Z',
        'attachments': [
          {
            'id': 101,
            'note_id': 5,
            'file_name': 'inspection_cert.pdf',
            'file_size_bytes': 1048576,
            'file_type': 'pdf',
            'download_url': '/api/v1/stage-notes/attachments/101/download',
            'created_at': '2026-10-21T10:30:00Z',
          }
        ],
      };

      final note = StageNoteModel.fromJson(json);
      expect(note.id, 5);
      expect(note.screenCode, 'customs_clearance');
      expect(note.recordId, 12);
      expect(note.stageCode, 'PHASE-03');
      expect(note.noteText, 'Inspection cleared without reservations.');
      expect(note.createdBy, 'Karim Customs');
      expect(note.attachments.length, 1);

      final att = note.attachments.first;
      expect(att.fileName, 'inspection_cert.pdf');
      expect(att.formattedSize, '1.0 MB');
      expect(att.fileType, 'pdf');
    });
  });

  group('StageNotesCard Widget Tests', () {
    testWidgets('renders card, notes, attachments, and toggles add note form', (tester) async {
      final mockService = MockStageNotesService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stageNotesServiceProvider.overrideWithValue(mockService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StageNotesCard(
                  screenCode: 'import_files',
                  recordId: 101,
                  stageCode: 'STEP-01',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and badge
      expect(find.byIcon(Icons.rate_review_outlined), findsOneWidget);
      expect(find.text('Verified delivery order and customs receipt.'), findsOneWidget);
      expect(find.text('Ahmed Sorour'), findsOneWidget);
      expect(find.text('customs_receipt.pdf'), findsOneWidget);
      expect(find.text('(240.0 KB)'), findsOneWidget);

      // Verify + button
      final addBtn = find.text('إضافة ملاحظة');
      expect(addBtn, findsOneWidget);

      // Tap + button
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Input box and attachment button should now be visible
      expect(find.text('تدوين ملاحظة جديدة وإرفاق مستندات'), findsOneWidget);
      expect(find.text('إرفاق ملفات (صور / PDF / مستندات)'), findsOneWidget);
      expect(find.text('حفظ الملاحظة'), findsOneWidget);

      // Enter note text
      await tester.enterText(find.byType(TextField).first, 'New test note for verification.');
      await tester.pumpAndSettle();

      // Submit note
      await tester.tap(find.text('حفظ الملاحظة'));
      await tester.pumpAndSettle();

      // Verify newly added note rendered in history
      expect(find.text('New test note for verification.'), findsOneWidget);
    });
  });
}
