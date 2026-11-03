import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/inspection_appeal_model.dart';
import '../../services/inspection_appeal_service.dart';

class AppealProgressTierDialog extends ConsumerStatefulWidget {
  final InspectionAppealModel item;
  final VoidCallback onSaved;

  const AppealProgressTierDialog({
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
      builder: (ctx) => AppealProgressTierDialog(item: item, onSaved: onSaved),
    );
  }

  @override
  ConsumerState<AppealProgressTierDialog> createState() => _AppealProgressTierDialogState();
}

class _AppealProgressTierDialogState extends ConsumerState<AppealProgressTierDialog> {
  late String _nextTier;
  final _labController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nextTier = widget.item.appealTier == AppealTier.firstAppeal ? 'SECOND_APPEAL' : 'TRIPLICATE_SAMPLE';
  }

  @override
  void dispose() {
    _labController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final service = ref.read(inspectionAppealServiceProvider);
      await service.progressTier(
        widget.item.appealId,
        targetTier: _nextTier,
        triplicateLabAssigned: _labController.text.trim().isNotEmpty ? _labController.text.trim() : null,
        officialLetterRef: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'تم تصعيد التظلم إلى المرحلة التالية بنجاح', severity: AppSeverity.success),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'فشل في تصعيد التظلم: $e', severity: AppSeverity.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تصعيد التظلم إلى مرحلة أعلى — ${widget.item.appealCode}'),
      content: SizedBox(
        width: 480,
        child: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchableDropdownField<String>(
                value: _nextTier,
                labelText: 'المرحلة المستهدفة بالتصعيد',
                items: const [
                  SearchableDropdownItem(value: 'SECOND_APPEAL', label: 'التظلم الثاني (لجنة الخبراء)'),
                  SearchableDropdownItem(value: 'TRIPLICATE_SAMPLE', label: 'التحكيم الثلاثي (العينة المرجعية)'),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _nextTier = v);
                },
              ),
              if (_nextTier == 'TRIPLICATE_SAMPLE') ...[
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'اسم المعمل المحايد المعتمد للتحكيم',
                  controller: _labController,
                  hint: 'المعمل المركزي لجامعة القاهرة، معمل البتروكيماويات...',
                ),
              ],
              const SizedBox(height: 10),
              CustomTextField(
                label: 'رقم خطاب طلب التصعيد',
                controller: _refController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: 'مبررات التصعيد',
                controller: _notesController,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        AppButton(
          label: 'تأكيد التصعيد',
          variant: AppButtonVariant.primary,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _handleSave,
        ),
      ],
    );
  }
}
