import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/inspection_appeal_model.dart';
import '../../services/inspection_appeal_service.dart';

class AppealDecisionDialog extends ConsumerStatefulWidget {
  final InspectionAppealModel item;
  final VoidCallback onSaved;

  const AppealDecisionDialog({
    super.key,
    required this.item,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required InspectionAppealModel item,
    required VoidCallback onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AppealDecisionDialog(item: item, onSaved: onSaved),
    );
  }

  @override
  ConsumerState<AppealDecisionDialog> createState() => _AppealDecisionDialogState();
}

class _AppealDecisionDialogState extends ConsumerState<AppealDecisionDialog> {
  String _decision = 'OVERTURNED_CONFORMING';
  late final TextEditingController _letterController;
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _letterController = TextEditingController(text: widget.item.officialLetterRef ?? '');
  }

  @override
  void dispose() {
    _letterController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final service = ref.read(inspectionAppealServiceProvider);
      await service.recordCommitteeDecision(
        widget.item.appealId,
        appealResult: _decision,
        appealCommitteeDate: DateTime.now().toIso8601String(),
        officialLetterRef: _letterController.text.trim().isNotEmpty ? _letterController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'تم اعتماد وتوثيق قرار لجنة التظلمات بنجاح', severity: AppSeverity.success),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'فشل في حفظ القرار: $e', severity: AppSeverity.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تسجيل قرار لجنة التظلمات — ${widget.item.appealCode}'),
      content: SizedBox(
        width: 480,
        child: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchableDropdownField<String>(
                value: _decision,
                labelText: 'قرار اللجنة النهائي',
                items: const [
                  SearchableDropdownItem(
                    value: 'OVERTURNED_CONFORMING',
                    label: 'قبول التظلم وإلغاء الرفض (مطابق للإفراج)',
                  ),
                  SearchableDropdownItem(
                    value: 'UPHELD_REJECTED',
                    label: 'تأييد قرار الرفض (إحالة لإعادة التصدير)',
                  ),
                  SearchableDropdownItem(
                    value: 'PENDING',
                    label: 'استمرار الفحص والمراجعة (معلق)',
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _decision = v);
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'رقم الخطاب أو القرار الرسمي الصادر',
                controller: _letterController,
                hint: 'قرار رقم 104 لسنة 2026',
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: 'حيثيات وملاحظات القرار',
                controller: _notesController,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        AppButton(
          label: 'حفظ القرار',
          variant: AppButtonVariant.primary,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _handleSave,
        ),
      ],
    );
  }
}
