import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

class NewBrokerCustodyAdvanceDialog extends StatefulWidget {
  final int? initialImportFileId;
  final Future<void> Function({
    required int importFileId,
    required int brokerId,
    required String brokerName,
    required double advanceAmount,
    required String disbursementDate,
    required String paymentMethod,
    String? notes,
  }) onSubmit;

  const NewBrokerCustodyAdvanceDialog({
    super.key,
    required this.initialImportFileId,
    required this.onSubmit,
  });

  @override
  State<NewBrokerCustodyAdvanceDialog> createState() => _NewBrokerCustodyAdvanceDialogState();
}

class _NewBrokerCustodyAdvanceDialogState extends State<NewBrokerCustodyAdvanceDialog> {
  late final TextEditingController _fileIdController;
  late final TextEditingController _brokerIdController;
  late final TextEditingController _brokerNameController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final TextEditingController _notesController;
  String _paymentMethod = 'BANK_TRANSFER';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fileIdController = TextEditingController(text: widget.initialImportFileId?.toString() ?? '');
    _brokerIdController = TextEditingController(text: '1');
    _brokerNameController = TextEditingController();
    _amountController = TextEditingController();
    _dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _fileIdController.dispose();
    _brokerIdController.dispose();
    _brokerNameController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final fid = int.tryParse(_fileIdController.text.trim());
    final bid = int.tryParse(_brokerIdController.text.trim()) ?? 1;
    final amt = double.tryParse(_amountController.text.trim());
    if (fid == null || amt == null || _brokerNameController.text.trim().isEmpty) {
      AppTheme.snackBar(context, 'يرجى استيفاء الحقول الإلزامية ومبلغ العهدة', severity: AppSeverity.warning);
      return;
    }
    setState(() => _isSubmitting = true);
    Navigator.of(context).pop();
    await widget.onSubmit(
      importFileId: fid,
      brokerId: bid,
      brokerName: _brokerNameController.text.trim(),
      advanceAmount: amt,
      disbursementDate: _dateController.text.trim(),
      paymentMethod: _paymentMethod,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.payments_outlined, color: AppTheme.cobalt),
          SizedBox(width: 8),
          Text('صرف عهدة مالية جديدة للمخلص الجمركي'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SelectionArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'معرف الملف الاستيرادي',
                        controller: _fileIdController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        label: 'معرف المخلص الجمركي',
                        controller: _brokerIdController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'اسم المخلص الجمركي / المكتب',
                  controller: _brokerNameController,
                  hint: 'مكتب الإسكندرية للخدمات الجمركية',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'مبلغ العهدة المصروفة (ج.م)',
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        label: 'تاريخ الصرف (YYYY-MM-DD)',
                        controller: _dateController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SearchableDropdownField<String>(
                  value: _paymentMethod,
                  labelText: 'طريقة الصرف',
                  items: const [
                    SearchableDropdownItem(value: 'BANK_TRANSFER', label: 'تحويل بنكي'),
                    SearchableDropdownItem(value: 'CHECK', label: 'شيك مصرفي'),
                    SearchableDropdownItem(value: 'CASH', label: 'نقدي من الخزينة'),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentMethod = v);
                  },
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'ملاحظات الصرف والغرض من العهدة',
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
          label: 'صرف وقيد العهدة',
          variant: AppButtonVariant.primary,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}
