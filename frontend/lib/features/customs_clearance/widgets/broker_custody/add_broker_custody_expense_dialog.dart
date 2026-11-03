import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/broker_custody_model.dart';

class AddBrokerCustodyExpenseDialog extends StatefulWidget {
  final BrokerCustodyAdvanceModel advance;
  final Future<void> Function({
    required String expenseCategory,
    required double amount,
    required bool isEInvoiceBacked,
    String? eInvoiceUuid,
    String? receiptReference,
    String? notes,
  }) onSubmit;

  const AddBrokerCustodyExpenseDialog({
    super.key,
    required this.advance,
    required this.onSubmit,
  });

  @override
  State<AddBrokerCustodyExpenseDialog> createState() => _AddBrokerCustodyExpenseDialogState();
}

class _AddBrokerCustodyExpenseDialogState extends State<AddBrokerCustodyExpenseDialog> {
  String _category = 'OFFICIAL_DUTIES_TAXES';
  late final TextEditingController _amountController;
  bool _isEInvoice = false;
  late final TextEditingController _uuidController;
  late final TextEditingController _refController;
  late final TextEditingController _notesController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _uuidController = TextEditingController();
    _refController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _uuidController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      AppTheme.snackBar(context, 'يرجى إدخال مبلغ صحيح', severity: AppSeverity.warning);
      return;
    }
    setState(() => _isSubmitting = true);
    Navigator.of(context).pop();
    await widget.onSubmit(
      expenseCategory: _category,
      amount: amt,
      isEInvoiceBacked: _isEInvoice,
      eInvoiceUuid: _uuidController.text.trim().isNotEmpty ? _uuidController.text.trim() : null,
      receiptReference: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إضافة بند مصروف للعهدة — ${widget.advance.advanceCode}'),
      content: SizedBox(
        width: 500,
        child: SelectionArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchableDropdownField<String>(
                  value: _category,
                  labelText: 'بند وتصنيف المصروف',
                  items: const [
                    SearchableDropdownItem(value: 'OFFICIAL_DUTIES_TAXES', label: 'ضرائب ورسوم جمركية رسمية (معفية من الخصم)'),
                    SearchableDropdownItem(value: 'PORT_AUTHORITY_FEES', label: 'رسوم وأرضيات هيئة الميناء'),
                    SearchableDropdownItem(value: 'LAB_TESTING_FEES', label: 'رسوم فحص معملي وسحب عينات'),
                    SearchableDropdownItem(value: 'HANDLING_AND_PORTERAGE', label: 'عتالة ومصروفات مناولة وتعتيق'),
                    SearchableDropdownItem(value: 'INSPECTION_TRANSPORT', label: 'انتقالات لجان الكشف والمعاينة'),
                    SearchableDropdownItem(value: 'SUNDRY_PETTY_CASH', label: 'نثريات ومصروفات متنوعة'),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'المبلغ الإجمالي (ج.م)',
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        label: 'رقم الإيصال أو المستند',
                        controller: _refController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('معتمد بفاتورة إلكترونية ضريبية رسمية', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  value: _isEInvoice,
                  onChanged: (v) => setState(() => _isEInvoice = v ?? false),
                ),
                if (_isEInvoice) ...[
                  const SizedBox(height: 8),
                  CustomTextField(
                    label: 'الرقم التعريفي الموحد للفاتورة الإلكترونية',
                    controller: _uuidController,
                    hint: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6)),
                  child: const Text(
                    'ملاحظة ضريبية: يتم تلقائياً خصم 1% ضريبة خصم وتحصيل (نموذج 41) على الأتعاب والمصروفات غير السيادية طبقاً للقانون المصري.',
                    style: TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  ),
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'ملاحظات وتفاصيل إضافية',
                  controller: _notesController,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        AppButton(
          label: 'حفظ واحتساب البند',
          variant: AppButtonVariant.primary,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}
