import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/logistics_rule.dart';
import '../providers/logistics_rules_provider.dart';

/// Modal dialog for verifying an operational rule with official proof.
/// Enforces Maker-Checker and safety guard requirements.
class LogisticsRuleVerifyDialog extends ConsumerStatefulWidget {
  final LogisticsRule rule;

  const LogisticsRuleVerifyDialog({super.key, required this.rule});

  @override
  ConsumerState<LogisticsRuleVerifyDialog> createState() =>
      _LogisticsRuleVerifyDialogState();
}

class _LogisticsRuleVerifyDialogState
    extends ConsumerState<LogisticsRuleVerifyDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _verifiedValueController;
  late TextEditingController _evidenceController;
  late TextEditingController _sourceController;
  DateTime? _reviewDueOn;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _verifiedValueController =
        TextEditingController(text: widget.rule.verifiedValue ?? '');
    _evidenceController =
        TextEditingController(text: widget.rule.evidenceRef ?? '');
    _sourceController =
        TextEditingController(text: widget.rule.sourceRef ?? '');
    _reviewDueOn = widget.rule.reviewDueOn;
  }

  @override
  void dispose() {
    _verifiedValueController.dispose();
    _evidenceController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repo = ref.read(logisticsRulesRepositoryProvider);

    final payload = {
      'verified_value': _verifiedValueController.text.trim(),
      'evidence_ref': _evidenceController.text.trim(),
      'source_ref': _sourceController.text.trim().isEmpty
          ? null
          : _sourceController.text.trim(),
      'review_due_on': _reviewDueOn?.toIso8601String().split('T').first,
    };

    try {
      await repo.verifyRule(widget.rule.id, payload);
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
    final r = widget.rule;

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: AppTheme.emerald),
                      SizedBox(width: 8),
                      Text(
                        'توثيق واعتماد القاعدة التشغيلية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.warningForeground),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security,
                            color: AppTheme.warningForeground, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تنبيه أمان: لا يُملأ هذا الحقل إلا بموجب إثبات رسمي معتمد. التوثيق الذاتي محظور بموجب قواعد الصانع-المدقق (Maker-Checker).',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.warningForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${r.ruleNameAr} (${r.ruleKey})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'الوحدة: ${r.valueUnit} | القيمة الاحترازية الحالية: ${r.conservativeDefault ?? "غير محدد"}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _verifiedValueController,
                    decoration: const InputDecoration(
                      labelText: 'القيمة الموثقة رسمياً *',
                      hintText: 'القيمة الدقيقة بعد التحقق الميداني',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'القيمة الموثقة إلزامية للاعتماد'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _evidenceController,
                    decoration: const InputDecoration(
                      labelText: 'مستند الإثبات المرفق *',
                      hintText: 'رقم أو اسم ملف المستند أو الرابط الرسمي',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'مستند الإثبات إلزامي للاعتماد'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sourceController,
                    decoration: const InputDecoration(
                      labelText: 'المرجع القانوني أو اللائحي',
                      hintText: 'نص المادة / قرار وزاري / منشور تعليمات',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    title: Text(
                      _reviewDueOn == null
                          ? 'موعد المراجعة الدورية (اختياري)'
                          : 'تاريخ المراجعة: ${_reviewDueOn!.toLocal().toString().split(" ").first}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _reviewDueOn ?? DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setState(() => _reviewDueOn = picked);
                      }
                    },
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
                        label: 'اعتماد وتوثيق رسمي',
                        variant: AppButtonVariant.success,
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
