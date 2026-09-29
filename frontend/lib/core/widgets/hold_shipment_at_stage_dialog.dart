import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../../features/import_files/models/import_file_model.dart';
import '../../features/import_files/providers/import_files_provider.dart';
import '../localization/domain_enum_labels.dart';

class HoldShipmentAtStageDialog extends ConsumerStatefulWidget {
  final ImportFileModel importFile;
  /// Stage title shown in the dialog (UI language).
  final String stageName;
  final String stageCode;
  /// English stage title sent as `stage_name`; falls back to [stageName].
  final String? stageNameEn;
  final VoidCallback? onSuccess;

  const HoldShipmentAtStageDialog({
    super.key,
    required this.importFile,
    required this.stageName,
    this.stageCode = '',
    this.stageNameEn,
    this.onSuccess,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ImportFileModel importFile,
    required String stageName,
    String stageCode = '',
    String? stageNameEn,
    VoidCallback? onSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HoldShipmentAtStageDialog(
        importFile: importFile,
        stageName: stageName,
        stageCode: stageCode,
        stageNameEn: stageNameEn,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  ConsumerState<HoldShipmentAtStageDialog> createState() => _HoldShipmentAtStageDialogState();
}

class _HoldShipmentAtStageDialogState extends ConsumerState<HoldShipmentAtStageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  /// HOLD_REASON code of the picked chip; cleared when the user edits the text.
  String? _selectedReasonCode;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleHold() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    final payload = buildHoldRequest(
      reasonText: _reasonController.text,
      selectedReasonCode: _selectedReasonCode,
      displayedReasonLabel: _selectedReasonCode == null
          ? null
          : DomainEnums.label(context.l10n, DomainEnumType.holdReason, _selectedReasonCode),
      stageName: widget.stageName,
      stageNameEn: widget.stageNameEn,
      stageCode: widget.stageCode,
    );
    final notes = _notesController.text.trim();

    try {
      final updated = await ref.read(importFilesProvider.notifier).holdShipment(
            widget.importFile.importFileId,
            payload.holdReason,
            holdReasonCode: payload.holdReasonCode,
            holdNotes: notes.isNotEmpty ? notes : null,
            stageName: payload.stageName,
            stepName: payload.stepName,
          );

      if (mounted && updated != null) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.holdSuccessNotification(widget.importFile.importFileCode, widget.stageName),
            ),
            backgroundColor: Colors.amber.shade900,
            duration: const Duration(seconds: 4),
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    // OTHER has no chip: typing a free reason is the 'other' path.
    final commonReasons = DomainEnums.codesOf(DomainEnumType.holdReason).where((c) => c != 'OTHER').toList();
    final file = widget.importFile;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(20),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
          border: Border(bottom: BorderSide(color: Colors.amber.shade300)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.stopShipmentAtThisStageBtn,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  Text(
                    '${file.primaryNameWithCode} | ${file.companyName}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Stage Target Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l.fieldCurrentStage}: ${widget.stageName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isAr
                                  ? 'سيتم تعليق الشحنة مؤقتاً عند هذه المرحلة، مع إمكانية استئنافها فوراً في أي وقت بنقرة واحدة.'
                                  : 'Shipment will be held temporarily at this stage and can be resumed anytime with one click.',
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Common Reasons Chips
                Text(
                  isAr ? 'أسباب الإيقاف الشائعة (انقر للاختيار السريع):' : 'Common Hold Reasons (Click to pick):',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: commonReasons.map((code) {
                    final r = DomainEnums.label(l, DomainEnumType.holdReason, code);
                    final isSelected = _selectedReasonCode == code && _reasonController.text == r;
                    return ChoiceChip(
                      label: Text(r, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppTheme.charcoal)),
                      selected: isSelected,
                      selectedColor: Colors.amber.shade800,
                      backgroundColor: Colors.grey.shade100,
                      onSelected: (selected) {
                        setState(() {
                          _selectedReasonCode = selected ? code : null;
                          _reasonController.text = selected ? r : '';
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Reason Required Field
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '${l.holdDialogReasonLabel} *',
                    hintText: isAr ? 'اكتب سبب الإيقاف أو اختر من الأسباب بالأعلى...' : 'Enter hold reason or select from above...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.edit_note, color: Colors.orange),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l.fieldRequired;
                    }
                    if (v.trim().length < 3) {
                      return isAr ? 'يجب ألا يقل سبب الإيقاف عن 3 أحرف.' : 'Reason must be at least 3 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Notes Optional Field
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isAr ? 'ملاحظات وتوجيهات إضافية (اختياري)' : 'Additional Notes (Optional)',
                    hintText: isAr ? 'أي توجيهات لفريق العمل أو المخلص أثناء فترة التوقف...' : 'Instructions for operations team / broker during hold...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.notes, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _handleHold,
          icon: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.pause_circle_filled, size: 18),
          label: Text(l.confirmHoldActionBtn),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.crimson,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }
}

/// Request fields for `POST /import-files/{id}/hold`.
class HoldRequest {
  final String holdReason;
  final String? holdReasonCode;
  final String stageName;
  final String? stepName;

  const HoldRequest({
    required this.holdReason,
    required this.holdReasonCode,
    required this.stageName,
    required this.stepName,
  });
}

/// Builds the language-independent hold request.
///
/// A predefined reason that the user did not edit is sent as its HOLD_REASON
/// code plus the English label; edited or free text is sent as typed with no
/// code. `stage_name` is the English stage title, `step_name` the stage code.
HoldRequest buildHoldRequest({
  required String reasonText,
  required String? selectedReasonCode,
  required String? displayedReasonLabel,
  required String stageName,
  required String? stageNameEn,
  required String stageCode,
}) {
  final text = reasonText.trim();
  final usesPredefined = selectedReasonCode != null &&
      DomainEnums.isCode(DomainEnumType.holdReason, selectedReasonCode) &&
      text == displayedReasonLabel?.trim();
  final englishStage = stageNameEn?.trim();
  return HoldRequest(
    holdReason: usesPredefined ? DomainEnums.englishLabel(DomainEnumType.holdReason, selectedReasonCode) : text,
    holdReasonCode: usesPredefined ? selectedReasonCode : null,
    stageName: (englishStage != null && englishStage.isNotEmpty) ? englishStage : stageName,
    stepName: stageCode.isNotEmpty ? stageCode : null,
  );
}
