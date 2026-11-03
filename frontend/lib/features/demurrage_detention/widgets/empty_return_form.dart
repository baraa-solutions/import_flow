import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/app_date_picker_field.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/ltr_text.dart';

/// Data payload submitted by [EmptyReturnForm].
class EmptyReturnFormData {
  final DateTime emptyReturnDate;
  final String eirNumber;
  final String? depotName;
  final String? conditionStatus;
  final String? notes;

  const EmptyReturnFormData({
    required this.emptyReturnDate,
    required this.eirNumber,
    this.depotName,
    this.conditionStatus,
    this.notes,
  });
}

/// 📋 Compact Empty Container Return & Demurrage Freeze Form — ImportFlow ERP
class EmptyReturnForm extends StatefulWidget {
  final String? containerNumber;
  final String? containerType;
  final String? initialEirNumber;
  final DateTime? initialReturnDate;
  final String? initialDepotName;
  final bool isSubmitting;
  final Future<void> Function(EmptyReturnFormData data) onSubmit;
  final VoidCallback? onCancel;

  const EmptyReturnForm({
    super.key,
    this.containerNumber,
    this.containerType,
    this.initialEirNumber,
    this.initialReturnDate,
    this.initialDepotName,
    this.isSubmitting = false,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<EmptyReturnForm> createState() => _EmptyReturnFormState();
}

class _EmptyReturnFormState extends State<EmptyReturnForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _emptyReturnDate;
  late final TextEditingController _eirNumberCtrl;
  late final TextEditingController _depotNameCtrl;
  late final TextEditingController _notesCtrl;
  String _conditionStatus = 'SOUND_CLEAN';

  @override
  void initState() {
    super.initState();
    _emptyReturnDate = widget.initialReturnDate ?? DateTime.now();
    _eirNumberCtrl = TextEditingController(text: widget.initialEirNumber ?? '');
    _depotNameCtrl = TextEditingController(text: widget.initialDepotName ?? '');
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _eirNumberCtrl.dispose();
    _depotNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit(
      EmptyReturnFormData(
        emptyReturnDate: _emptyReturnDate,
        eirNumber: _eirNumberCtrl.text.trim(),
        depotName: _depotNameCtrl.text.trim().isEmpty ? null : _depotNameCtrl.text.trim(),
        conditionStatus: _conditionStatus,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;

    return SelectionArea(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'تنبيه نظامي: توثيق إيصال الإرجاع يوقف عداد غرامات التأخير والأرضيات لهذه الحاوية فوراً.'
                          : 'Notice: Registering the EIR receipt immediately freezes daily demurrage accrual.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.containerNumber != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.charcoalSurface, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.sorourCobalt),
                    const SizedBox(width: 6),
                    Text(isArabic ? 'رقم الحاوية:' : 'Container:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 6),
                    LtrText(widget.containerNumber!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    if (widget.containerType != null) ...[
                      const SizedBox(width: 6),
                      Text('[${widget.containerType}]', style: const TextStyle(fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppDatePickerField(
                    label: isArabic ? 'تاريخ تسليم الفارغ' : 'Empty Return Date',
                    value: _emptyReturnDate,
                    isRequired: true,
                    onChanged: (val) {
                      if (val != null) setState(() => _emptyReturnDate = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _eirNumberCtrl,
                    label: isArabic ? 'رقم إيصال الاستلام' : 'EIR Receipt Number',
                    hint: isArabic ? 'مثال: إي آي آر 998877' : 'e.g. EIR-998877',
                    icon: Icons.receipt_long_outlined,
                    isRequired: true,
                    textDirection: TextDirection.ltr,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isArabic ? 'يرجى إدخال رقم إيصال الاستلام' : 'Please enter the EIR receipt number')
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _depotNameCtrl,
                    label: isArabic ? 'مستودع التسليم' : 'Empty Return Depot',
                    hint: isArabic ? 'مثال: مستودع الدخيلة' : 'e.g. Dekheila Depot',
                    icon: Icons.warehouse_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SearchableDropdownField<String>(
                    labelText: isArabic ? 'حالة الحاوية عند الفحص' : 'Container Condition',
                    value: _conditionStatus,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'حالة الحاوية عند الفحص' : 'Container Condition',
                      prefixIcon: const Icon(Icons.fact_check_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      SearchableDropdownItem(value: 'SOUND_CLEAN', label: isArabic ? 'سليمة ونظيفة' : 'Sound and Clean'),
                      SearchableDropdownItem(value: 'DAMAGED', label: isArabic ? 'بها تلفيات' : 'Damaged'),
                      SearchableDropdownItem(value: 'REQUIRES_WASHING', label: isArabic ? 'تحتاج غسيل' : 'Requires Washing'),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _conditionStatus = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _notesCtrl,
              label: isArabic ? 'ملاحظات إضافية' : 'Additional Notes',
              hint: isArabic ? 'أي ملاحظات تشغيلية أو فنية...' : 'Any operational notes...',
              icon: Icons.notes_outlined,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onCancel != null) ...[
                  AppButton(
                    label: isArabic ? 'إلغاء' : 'Cancel',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.medium,
                    onPressed: widget.isSubmitting ? null : widget.onCancel,
                  ),
                  const SizedBox(width: 12),
                ],
                AppButton(
                  label: isArabic ? 'اعتماد الإرجاع وإيقاف الغرامة' : 'Confirm Return & Stop Fine',
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.medium,
                  icon: Icons.check_circle_outline,
                  isLoading: widget.isSubmitting,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
