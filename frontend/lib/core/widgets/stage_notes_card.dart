import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/file_picker_helper.dart';
import '../localization/app_localizations.dart';
import '../models/stage_note_model.dart';
import '../services/stage_notes_service.dart';
import '../theme/app_theme.dart';
import 'buttons/app_button.dart';
import 'app_status_badge.dart';
import 'custom_text_field.dart';
import '../utils/app_format.dart';

/// Unified Notes & Attachments Card for all screens and shipment stages.
///
/// Features:
/// 1. Interactive `+` button to add a new note row.
/// 2. Multi-line note input box.
/// 3. Attachment picker (📎) supporting PDFs, images, spreadsheets, and docs.
/// 4. Chronological history log showing author, date/time, and selectable note text.
/// 5. Downloadable attached files list with native "Save As" file dialog.
class StageNotesCard extends ConsumerStatefulWidget {
  final String screenCode;
  final int? recordId;
  final String? stageCode;
  final String? title;
  final bool initiallyExpanded;
  final VoidCallback? onNoteAdded;

  const StageNotesCard({
    super.key,
    required this.screenCode,
    this.recordId,
    this.stageCode,
    this.title,
    this.initiallyExpanded = true,
    this.onNoteAdded,
  });

  /// Opens the Notes & Attachments card inside a modal dialog
  static Future<void> showAsDialog(
    BuildContext context, {
    required String screenCode,
    int? recordId,
    String? stageCode,
    String? title,
    VoidCallback? onNoteAdded,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8.0),
            child: StageNotesCard(
              screenCode: screenCode,
              recordId: recordId,
              stageCode: stageCode,
              title: title,
              initiallyExpanded: true,
              onNoteAdded: onNoteAdded,
            ),
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<StageNotesCard> createState() => _StageNotesCardState();
}

class _StageNotesCardState extends ConsumerState<StageNotesCard> {
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _showAddForm = false;
  bool _isCardExpanded = true;
  String? _errorMessage;

  StageNotesSummaryModel? _summary;

  final TextEditingController _noteController = TextEditingController();
  final List<PlatformFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _isCardExpanded = widget.initiallyExpanded;
    _fetchNotes();
  }

  @override
  void didUpdateWidget(covariant StageNotesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenCode != widget.screenCode ||
        oldWidget.recordId != widget.recordId ||
        oldWidget.stageCode != widget.stageCode) {
      _fetchNotes();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(stageNotesServiceProvider);
      final res = await service.fetchNotes(
        screenCode: widget.screenCode,
        recordId: widget.recordId,
        stageCode: widget.stageCode,
      );
      if (mounted) {
        setState(() {
          _summary = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'xlsx', 'xls', 'csv', 'docx', 'doc', 'txt'],
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final valid = FilePickerHelper.resolveFilesWithBytes(result.files);
      setState(() {
        _selectedFiles.addAll(valid);
      });
    }
  }

  void _removeSelectedFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submitNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) {
      AppTheme.snackBar(
        context,
        'يرجى كتابة نص الملاحظة قبل الحفظ',
        severity: AppSeverity.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(stageNotesServiceProvider);
      await service.createNote(
        screenCode: widget.screenCode,
        noteText: text,
        recordId: widget.recordId,
        stageCode: widget.stageCode,
        files: _selectedFiles.isNotEmpty ? _selectedFiles : null,
      );

      _noteController.clear();
      _selectedFiles.clear();

      if (mounted) {
        setState(() {
          _showAddForm = false;
          _isSubmitting = false;
        });
        AppTheme.snackBar(
          context,
          'تم حفظ الملاحظة والمرفقات بنجاح',
          severity: AppSeverity.success,
        );
      }

      await _fetchNotes();
      widget.onNoteAdded?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppTheme.snackBar(
          context,
          'فشل حفظ الملاحظة: $e',
          severity: AppSeverity.danger,
        );
      }
    }
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'excel':
        return Icons.table_chart_rounded;
      case 'word':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return AppTheme.crimson;
      case 'image':
        return AppTheme.cobalt;
      case 'excel':
        return AppTheme.emerald;
      case 'word':
        return AppTheme.cobalt;
      default:
        return AppTheme.charcoal;
    }
  }

  String _formatDateTime(DateTime dt) => AppFormat.dateTime(dt);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isAr = l.isArabic;
    final totalNotes = _summary?.totalNotes ?? 0;
    final totalAtts = _summary?.totalAttachments ?? 0;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 16),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.rate_review_outlined, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title ?? (isAr ? 'الملاحظات والمرفقات وسجل المتابعة' : 'Notes, Attachments & History'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                if (totalNotes > 0) ...[
                  AppStatusBadge(
                    label: isAr ? '$totalNotes ملاحظة' : '$totalNotes Notes',
                    severity: AppSeverity.info,
                  ),
                  const SizedBox(width: 6),
                ],
                if (totalAtts > 0) ...[
                  AppStatusBadge(
                    label: isAr ? '$totalAtts مرفق' : '$totalAtts Attachments',
                    severity: AppSeverity.success,
                    icon: Icons.attachment_rounded,
                  ),
                  const SizedBox(width: 8),
                ],
                // ➕ Add Note Button
                AppButton(
                  label: isAr ? 'إضافة ملاحظة' : 'Add Note',
                  icon: _showAddForm ? Icons.remove : Icons.add,
                  variant: _showAddForm ? AppButtonVariant.secondary : AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: () {
                    setState(() {
                      _showAddForm = !_showAddForm;
                      if (_showAddForm) _isCardExpanded = true;
                    });
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: isAr ? 'تحديث الملاحظات' : 'Refresh Notes',
                  onPressed: _isLoading ? null : _fetchNotes,
                ),
                IconButton(
                  icon: Icon(_isCardExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
                  tooltip: _isCardExpanded ? (isAr ? 'طي القسم' : 'Collapse') : (isAr ? 'توسيع القسم' : 'Expand'),
                  onPressed: () => setState(() => _isCardExpanded = !_isCardExpanded),
                ),
              ],
            ),
          ),

          if (_isCardExpanded) ...[
            const Divider(height: 1),

            // ── Inline Add Note Form (shown when + is pressed) ────────────
            if (_showAddForm)
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade900
                    : AppTheme.cobalt.withValues(alpha: 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 18, color: AppTheme.cobalt),
                        const SizedBox(width: 6),
                        Text(
                          isAr ? 'تدوين ملاحظة جديدة وإرفاق مستندات' : 'Write New Note & Attach Files',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      controller: _noteController,
                      maxLines: 3,
                      label: isAr ? 'نص الملاحظة *' : 'Note Content *',
                      hint: isAr
                          ? 'اكتب تفاصيل الملاحظة التشغيلية أو التوجيهات...'
                          : 'Enter operational note details or instructions...',
                    ),
                    const SizedBox(height: 10),

                    // Attachments row
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cobalt,
                            side: const BorderSide(color: AppTheme.cobalt),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.attach_file_rounded, size: 18),
                          label: Text(
                            isAr ? 'إرفاق ملفات (صور / PDF / مستندات)' : 'Attach Files (Images/PDF/Docs)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _isSubmitting ? null : _pickAttachments,
                        ),
                        const SizedBox(width: 12),
                        if (_selectedFiles.isNotEmpty)
                          Text(
                            isAr ? 'تم اختيار ${_selectedFiles.length} ملفات' : '${_selectedFiles.length} files selected',
                            style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),

                    // Selected files chips
                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedFiles.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final f = entry.value;
                          final sizeKb = (f.size / 1024).toStringAsFixed(1);
                          return Chip(
                            backgroundColor: AppTheme.cobalt.withValues(alpha: 0.08),
                            avatar: const Icon(Icons.file_present_rounded, size: 16, color: AppTheme.cobalt),
                            label: Text(
                              '${f.name} ($sizeKb KB)',
                              style: const TextStyle(fontSize: 11),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => _removeSelectedFile(idx),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 14),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(
                          label: isAr ? 'إلغاء' : 'Cancel',
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _showAddForm = false;
                                    _noteController.clear();
                                    _selectedFiles.clear();
                                  });
                                },
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: isAr ? 'حفظ الملاحظة' : 'Save Note',
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          icon: Icons.check,
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _submitNote,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ── Notes List / History Timeline ─────────────────────────────
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.crimson, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchNotes,
                      child: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                    ),
                  ],
                ),
              )
            else if (totalNotes == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.speaker_notes_off_outlined, size: 28, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text(
                        isAr
                            ? 'لا توجد ملاحظات مسجلة بعد. اضغط على "+ إضافة ملاحظة" لإدراج أول ملاحظة ومرفقات.'
                            : 'No notes logged yet. Click "+ Add Note" to insert your first note & attachments.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                itemCount: _summary!.notes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final note = _summary!.notes[index];
                  return _buildNoteItem(note, isAr);
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteItem(StageNoteModel note, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade800
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author & Timestamp Row
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.cobalt.withValues(alpha: 0.15),
                child: Text(
                  note.createdBy.isNotEmpty ? note.createdBy[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cobalt,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                note.createdBy,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (note.stageCode != null && note.stageCode!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    note.stageCode!,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(note.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Note Content Text
          SelectableText(
            note.noteText,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),

          // Attached Files List
          if (note.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attachment_rounded, size: 14, color: AppTheme.cobalt),
                const SizedBox(width: 4),
                Text(
                  isAr ? 'المرفقات (${note.attachments.length}):' : 'Attachments (${note.attachments.length}):',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: note.attachments.map((att) {
                final icon = _getFileIcon(att.fileType);
                final color = _getFileColor(att.fileType);
                return InkWell(
                  onTap: () {
                    final service = ref.read(stageNotesServiceProvider);
                    service.downloadAttachment(
                      context: context,
                      attachment: att,
                      screenTitle: widget.title ?? widget.screenCode,
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            att.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${att.formattedSize})',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.download_rounded, size: 14, color: color),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
