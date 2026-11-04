import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/logistics_rule.dart';
import '../providers/logistics_rules_provider.dart';

/// Modal dialog for creating or editing an operational logistics rule.
class LogisticsRuleFormDialog extends ConsumerStatefulWidget {
  final LogisticsRule? rule;

  const LogisticsRuleFormDialog({super.key, this.rule});

  @override
  ConsumerState<LogisticsRuleFormDialog> createState() =>
      _LogisticsRuleFormDialogState();
}

class _LogisticsRuleFormDialogState
    extends ConsumerState<LogisticsRuleFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _keyController;
  late TextEditingController _nameArController;
  late TextEditingController _nameEnController;
  late TextEditingController _defaultController;
  late TextEditingController _sourceController;
  late TextEditingController _evidenceController;

  String _scopeType = 'GLOBAL';
  String _valueUnit = 'DAYS';
  String _enforcementLevel = 'WARNING';
  bool _isLoading = false;

  bool get isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _keyController = TextEditingController(text: r?.ruleKey ?? '');
    _nameArController = TextEditingController(text: r?.ruleNameAr ?? '');
    _nameEnController = TextEditingController(text: r?.ruleNameEn ?? '');
    _defaultController =
        TextEditingController(text: r?.conservativeDefault ?? '');
    _sourceController = TextEditingController(text: r?.sourceRef ?? '');
    _evidenceController = TextEditingController(text: r?.evidenceRef ?? '');

    if (r != null) {
      _scopeType = r.scopeType;
      _valueUnit = r.valueUnit;
      _enforcementLevel = r.enforcementLevel;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _defaultController.dispose();
    _sourceController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repo = ref.read(logisticsRulesRepositoryProvider);

    final payload = {
      'rule_name_ar': _nameArController.text.trim(),
      'rule_name_en': _nameEnController.text.trim(),
      'scope_type': _scopeType,
      'value_unit': _valueUnit,
      'enforcement_level': _enforcementLevel,
      'conservative_default': _defaultController.text.trim().isEmpty
          ? null
          : _defaultController.text.trim(),
      'source_ref': _sourceController.text.trim().isEmpty
          ? null
          : _sourceController.text.trim(),
      'evidence_ref': _evidenceController.text.trim().isEmpty
          ? null
          : _evidenceController.text.trim(),
    };

    try {
      if (isEditing) {
        await repo.updateRule(widget.rule!.id, payload);
      } else {
        payload['rule_key'] = _keyController.text.trim();
        await repo.createRule(payload);
      }
      ref.invalidate(logisticsRulesProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEditing ? Icons.edit_note : Icons.add_circle_outline,
                        color: AppTheme.cobalt,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing
                            ? 'تعديل القاعدة التشغيلية (نسخة جديدة)'
                            : 'إضافة قاعدة تشغيلية جديدة',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextFormField(
                    controller: _keyController,
                    enabled: !isEditing,
                    decoration: InputDecoration(
                      labelText: 'رمز القاعدة (Rule Key)',
                      hintText: 'e.g. FREE_DAYS_DEMURRAGE',
                      filled: isEditing,
                      fillColor: isEditing ? AppTheme.cloudWhite : null,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'رمز القاعدة إلزامي'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameArController,
                          decoration: const InputDecoration(
                            labelText: 'الاسم بالعربية *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'الاسم بالعربية مطلوب'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _nameEnController,
                          decoration: const InputDecoration(
                            labelText: 'الاسم بالإنجليزية *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'الاسم بالإنجليزية مطلوب'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SearchableDropdownField<String>(
                          labelText: 'نطاق التطبيق',
                          value: _scopeType,
                          decoration: const InputDecoration(
                            labelText: 'نطاق التطبيق',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            SearchableDropdownItem(value: 'GLOBAL', label: 'شامل (GLOBAL)'),
                            SearchableDropdownItem(value: 'SHIPPING_LINE', label: 'توكيل ملاحي'),
                            SearchableDropdownItem(value: 'PORT', label: 'ميناء'),
                            SearchableDropdownItem(value: 'COMMODITY', label: 'بند سلعي'),
                            SearchableDropdownItem(value: 'CONTAINER_TYPE', label: 'نوع حاوية'),
                          ],
                          onChanged: (v) =>
                              setState(() => _scopeType = v ?? 'GLOBAL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SearchableDropdownField<String>(
                          labelText: 'وحدة القياس',
                          value: _valueUnit,
                          decoration: const InputDecoration(
                            labelText: 'وحدة القياس',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            SearchableDropdownItem(value: 'DAYS', label: 'أيام (DAYS)'),
                            SearchableDropdownItem(value: 'HOURS', label: 'ساعات (HOURS)'),
                            SearchableDropdownItem(value: 'PERCENTAGE', label: 'نسبة مئوية (%)'),
                            SearchableDropdownItem(value: 'KG', label: 'كيلوجرام (KG)'),
                            SearchableDropdownItem(value: 'BOOLEAN', label: 'نعم/لا (شرط)'),
                            SearchableDropdownItem(value: 'MONTHS', label: 'شهور'),
                            SearchableDropdownItem(value: 'TEXT', label: 'نص'),
                          ],
                          onChanged: (v) =>
                              setState(() => _valueUnit = v ?? 'DAYS'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SearchableDropdownField<String>(
                    labelText: 'مستوى الإلزام',
                    value: _enforcementLevel,
                    decoration: const InputDecoration(
                      labelText: 'مستوى الإلزام',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      SearchableDropdownItem(value: 'INFO', label: 'معلوماتي فقط (INFO)'),
                      SearchableDropdownItem(value: 'WARNING', label: 'تنبيه تحذيري (WARNING)'),
                      SearchableDropdownItem(value: 'BLOCKING', label: 'حظر تشغيلي قاطع (BLOCKING)'),
                    ],
                    onChanged: (v) =>
                        setState(() => _enforcementLevel = v ?? 'WARNING'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _defaultController,
                    decoration: const InputDecoration(
                      labelText: 'القيمة الاحترازية الافتراضية (Fallback)',
                      hintText: 'تستخدم للتنبيهات الوقائية لحين التوثيق الرسمي',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sourceController,
                    decoration: const InputDecoration(
                      labelText: 'المرجع القانوني أو اللائحي المقترح',
                      hintText: 'رقم المادة / القانون / الاتفاقية',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _evidenceController,
                    decoration: const InputDecoration(
                      labelText: 'مرجع أو اسم مستند الإثبات',
                      hintText: 'رابط ملف أو اسم المرفق',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: 'إلغاء',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      AppButton(
                        label: isEditing ? 'حفظ كنسخة جديدة' : 'إنشاء القاعدة',
                        variant: AppButtonVariant.primary,
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                    ],
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
