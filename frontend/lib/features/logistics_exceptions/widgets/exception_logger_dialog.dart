import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker_field.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/standard_form_action_bar.dart';
import '../logistics_exceptions_provider.dart';

class ExceptionLoggerDialog extends ConsumerStatefulWidget {
  const ExceptionLoggerDialog({super.key});

  @override
  ConsumerState<ExceptionLoggerDialog> createState() => _ExceptionLoggerDialogState();
}

class _ExceptionLoggerDialogState extends ConsumerState<ExceptionLoggerDialog> {
  final _formKey = GlobalKey<FormState>();

  String _exceptionType = 'VESSEL_ROLLOVER';
  String _severity = 'HIGH';
  final _titleArController = TextEditingController();
  final _descController = TextEditingController();
  final _delayDaysController = TextEditingController(text: '7');
  final _acidNumberController = TextEditingController();
  DateTime? _acidOriginalExpiry;
  DateTime? _acidAdjustedExpiry;
  bool _delayKpiSuspended = true;
  final _suspensionReasonController = TextEditingController(
    text: 'تعليق مؤشرات التأخير تلقائياً بسبب حدوث اضطراب ملاحي خارج عن الإرادة',
  );
  bool _isSaving = false;

  final List<SearchableDropdownItem<String>> _typeOptions = const [
    SearchableDropdownItem(value: 'VESSEL_ROLLOVER', label: 'تدحرج الشحنة وتأخر الباخرة'),
    SearchableDropdownItem(value: 'BLANK_SAILING', label: 'إلغاء رحلة ملاحية مجدولة'),
    SearchableDropdownItem(value: 'PORT_CONGESTION', label: 'ازدحام وتكدس أرصفة الميناء'),
    SearchableDropdownItem(value: 'VALUATION_DISPUTE', label: 'نزاع تثمين وقيمة جمركية'),
    SearchableDropdownItem(value: 'CUSTOMS_HOLD', label: 'تحفظ وتعليق جمركي'),
    SearchableDropdownItem(value: 'DEMURRAGE_RISK', label: 'خطر وشيك لغرامات الأرضيات'),
    SearchableDropdownItem(value: 'OTHER', label: 'اضطراب تشغيلي آخر'),
  ];

  final List<SearchableDropdownItem<String>> _severityOptions = const [
    SearchableDropdownItem(value: 'LOW', label: 'منخفض'),
    SearchableDropdownItem(value: 'MEDIUM', label: 'متوسط'),
    SearchableDropdownItem(value: 'HIGH', label: 'مرتفع'),
    SearchableDropdownItem(value: 'CRITICAL', label: 'حرج جداً'),
  ];

  @override
  void dispose() {
    _titleArController.dispose();
    _descController.dispose();
    _delayDaysController.dispose();
    _acidNumberController.dispose();
    _suspensionReasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final delayDays = int.tryParse(_delayDaysController.text.trim()) ?? 0;
      final payload = {
        'exception_type': _exceptionType,
        'severity': _severity,
        'title_ar': _titleArController.text.trim(),
        'title_en': _titleArController.text.trim(),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'delay_impact_days': delayDays,
        'acid_number': _acidNumberController.text.trim().isEmpty ? null : _acidNumberController.text.trim(),
        'acid_original_expiry': _acidOriginalExpiry?.toIso8601String().substring(0, 10),
        'acid_adjusted_expiry': _acidAdjustedExpiry?.toIso8601String().substring(0, 10),
        'delay_kpi_suspended': _delayKpiSuspended,
        'suspension_reason': _delayKpiSuspended ? _suspensionReasonController.text.trim() : null,
      };

      await ref.read(logisticsExceptionsActionsProvider).createException(payload);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, 'تم تسجيل الاستثناء وتعليق مؤشرات التأخير بنجاح', severity: AppSeverity.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, 'فشل في حفظ الاستثناء: $e', severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: SelectionArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.crimson.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تسجيل استثناء أو اضطراب لوجستي',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'توثيق أحداث الشحن الطارئة ومواءمة الصلاحيات وتعليق مؤشرات التأخير',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SearchableDropdownField<String>(
                                  labelText: 'نوع الاستثناء',
                                  value: _exceptionType,
                                  items: _typeOptions,
                                  onChanged: (v) => setState(() => _exceptionType = v ?? 'OTHER'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SearchableDropdownField<String>(
                                  labelText: 'مستوى الأهمية',
                                  value: _severity,
                                  items: _severityOptions,
                                  onChanged: (v) => setState(() => _severity = v ?? 'MEDIUM'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleArController,
                            decoration: const InputDecoration(
                              labelText: 'عنوان الاستثناء أو الحدث',
                              hintText: 'مثال: تأخر باخرة ميرسك في ميناء الترانزيت',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _delayDaysController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'أيام التأخير المتوقعة',
                                    suffixText: 'يوم',
                                  ),
                                  validator: (v) => (v == null || int.tryParse(v.trim()) == null) ? 'أدخل عدداً صحيحاً' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _acidNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم القيد الجمركي المبدئي',
                                    hintText: '19 رقماً',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: AppDatePickerField(
                                  label: 'تاريخ انتهاء الصلاحية الأصلي',
                                  value: _acidOriginalExpiry,
                                  onChanged: (d) => setState(() => _acidOriginalExpiry = d),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: AppDatePickerField(
                                  label: 'تاريخ الانتهاء المقترح بعد التمديد',
                                  value: _acidAdjustedExpiry,
                                  onChanged: (d) => setState(() => _acidAdjustedExpiry = d),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('تعليق مؤشرات قياس التأخير لهذه الشحنة'),
                                  subtitle: const Text('إعفاء مسؤولي العمليات من نسب التأخير لاحتسابها كظرف قاهر'),
                                  value: _delayKpiSuspended,
                                  activeThumbColor: AppTheme.orange,
                                  onChanged: (v) => setState(() => _delayKpiSuspended = v),
                                ),
                                if (_delayKpiSuspended) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _suspensionReasonController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'سبب التعليق والتوثيق',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'تفاصيل إضافية عن الاستثناء',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StandardFormActionBar(
                    isSaving: _isSaving,
                    submitLabel: 'تسجيل الاستثناء والتعليق',
                    closeLabel: 'إلغاء',
                    onSubmit: _submit,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
