import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../services/inspection_appeal_service.dart';

class NewAppealDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final VoidCallback onSaved;

  const NewAppealDialog({
    super.key,
    this.initialImportFileId,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    int? initialImportFileId,
    required VoidCallback onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => NewAppealDialog(
        initialImportFileId: initialImportFileId,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<NewAppealDialog> createState() => _NewAppealDialogState();
}

class _NewAppealDialogState extends ConsumerState<NewAppealDialog> {
  late final TextEditingController _fileIdController;
  final _sampleNoController = TextEditingController();
  final _reasonController = TextEditingController();
  String _authority = 'GOEIC';
  String _initialResult = 'NON_CONFORMING_CHEMICAL';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fileIdController = TextEditingController(text: widget.initialImportFileId?.toString() ?? '');
  }

  @override
  void dispose() {
    _fileIdController.dispose();
    _sampleNoController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final fid = int.tryParse(_fileIdController.text.trim());
    if (fid == null || _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'يرجى إدخال رقم الملف وأسباب التظلم', severity: AppSeverity.warning),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final service = ref.read(inspectionAppealServiceProvider);
      await service.createAppeal(
        importFileId: fid,
        regulatoryAuthority: _authority,
        sampleNumber: _sampleNoController.text.trim().isNotEmpty ? _sampleNoController.text.trim() : null,
        initialTestResult: _initialResult,
        rejectionReason: _reasonController.text.trim(),
        appealSubmissionDate: DateTime.now().toIso8601String(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'تم قيد التظلم المعملي رسمياً وإخطار اللجنة المختصة', severity: AppSeverity.success),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'فشل في قيد التظلم: $e', severity: AppSeverity.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.biotech_outlined, color: AppTheme.cobalt),
          SizedBox(width: 8),
          Text('تقديم تظلم معملي جديد على نتيجة الفحص'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SelectionArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  label: 'معرف الملف الاستيرادي',
                  controller: _fileIdController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                SearchableDropdownField<String>(
                  value: _authority,
                  labelText: 'الجهة الرقابية المختصة',
                  items: const [
                    SearchableDropdownItem(value: 'GOEIC', label: 'الهيئة العامة للرقابة على الصادرات والواردات'),
                    SearchableDropdownItem(value: 'NFSA', label: 'الهيئة القومية لسلامة الغذاء'),
                    SearchableDropdownItem(value: 'EDA', label: 'هيئة الدواء المصرية'),
                    SearchableDropdownItem(value: 'NTRA', label: 'الجهاز القومي لتنظيم الاتصالات'),
                    SearchableDropdownItem(value: 'ATOMIC_ENERGY', label: 'هيئة الطاقة الذرية'),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _authority = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'رقم العينة المعملية المسحوبة',
                        controller: _sampleNoController,
                        hint: 'SMP-2026-9876',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SearchableDropdownField<String>(
                        value: _initialResult,
                        labelText: 'نوع عدم المطابقة',
                        items: const [
                          SearchableDropdownItem(value: 'NON_CONFORMING_CHEMICAL', label: 'غير مطابق كيميائياً'),
                          SearchableDropdownItem(value: 'NON_CONFORMING_MICROBIAL', label: 'غير مطابق ميكروبياً'),
                          SearchableDropdownItem(value: 'NON_CONFORMING_VISUAL', label: 'غير مطابق ظاهرياً'),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _initialResult = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'أسباب ومبررات التظلم الفنية',
                  controller: _reasonController,
                  maxLines: 2,
                  hint: 'طلب إعادة التحليل بمعمل مرجعي معتمد أو فحص العينة المحفوظة...',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        AppButton(
          label: 'قيد التظلم رسمياً',
          variant: AppButtonVariant.primary,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _handleSave,
        ),
      ],
    );
  }
}
