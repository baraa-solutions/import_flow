import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/broker_custody_model.dart';
import '../services/broker_custody_service.dart';

class BrokerCustodySettlementDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const BrokerCustodySettlementDialog({super.key, this.initialImportFileId});

  static Future<void> show(BuildContext context, {int? initialImportFileId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BrokerCustodySettlementDialog(initialImportFileId: initialImportFileId),
    );
  }

  @override
  ConsumerState<BrokerCustodySettlementDialog> createState() => _BrokerCustodySettlementDialogState();
}

class _BrokerCustodySettlementDialogState extends ConsumerState<BrokerCustodySettlementDialog> {
  List<BrokerCustodyAdvanceModel> _advances = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(brokerCustodyServiceProvider);
      final list = await service.listAdvances(
        importFileId: widget.initialImportFileId,
      );

      if (mounted) {
        setState(() {
          _advances = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  AppSeverity _statusSeverity(String status) {
    switch (status) {
      case 'SETTLED':
        return AppSeverity.success;
      case 'PARTIALLY_SETTLED':
        return AppSeverity.warning;
      case 'OPEN':
      default:
        return AppSeverity.info;
    }
  }

  void _showNewAdvanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _NewBrokerCustodyAdvanceDialog(
        initialImportFileId: widget.initialImportFileId,
        onSubmit: ({
          required int importFileId,
          required int brokerId,
          required String brokerName,
          required double advanceAmount,
          required String disbursementDate,
          required String paymentMethod,
          String? notes,
        }) async {
          final service = ref.read(brokerCustodyServiceProvider);
          await service.createAdvance(
            importFileId: importFileId,
            brokerId: brokerId,
            brokerName: brokerName,
            advanceAmount: advanceAmount,
            disbursementDate: disbursementDate,
            paymentMethod: paymentMethod,
            notes: notes,
          );
          if (!mounted) return;
          AppTheme.snackBar(context, 'تم صرف وقيد عهدة المخلص بنجاح', severity: AppSeverity.success);
          _loadData();
        },
      ),
    );
  }

  void _showAddExpenseDialog(BrokerCustodyAdvanceModel advance) {
    showDialog(
      context: context,
      builder: (ctx) => _AddBrokerCustodyExpenseDialog(
        advance: advance,
        onSubmit: ({
          required String expenseCategory,
          required double amount,
          required bool isEInvoiceBacked,
          String? eInvoiceUuid,
          String? receiptReference,
          String? notes,
        }) async {
          final service = ref.read(brokerCustodyServiceProvider);
          await service.addExpenseItem(
            advance.advanceId,
            expenseCategory: expenseCategory,
            amount: amount,
            isEInvoiceBacked: isEInvoiceBacked,
            eInvoiceUuid: eInvoiceUuid,
            receiptReference: receiptReference,
            notes: notes,
          );
          if (!mounted) return;
          AppTheme.snackBar(context, 'تمت إضافة بند المصروف وحساب ضريبة الخصم 1% بنجاح', severity: AppSeverity.success);
          _loadData();
        },
      ),
    );
  }

  void _approveItem(BrokerExpenseItemModel item) async {
    try {
      final service = ref.read(brokerCustodyServiceProvider);
      await service.approveExpenseItem(
        item.itemId,
        approvalStatus: 'APPROVED',
        verifiedBy: 'المراجع المالي',
      );
      if (!mounted) return;
      AppTheme.snackBar(context, 'تم اعتماد البند بنجاح تمهيداً للتسوية', severity: AppSeverity.success);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      AppTheme.snackBar(context, 'فشل في اعتماد البند: $e', severity: AppSeverity.danger);
    }
  }

  void _settleAdvance(BrokerCustodyAdvanceModel advance) async {
    try {
      final service = ref.read(brokerCustodyServiceProvider);
      final reconciliation = await service.settleAdvance(advance.advanceId);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Text('تقرير التسوية والمقاصة النهائية — ${reconciliation.advanceCode}'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reconciliation.reconciliationSummary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.5)),
                  const Divider(height: 24),
                  _buildSummaryRow('قيمة العهدة المصروفة:', '${reconciliation.advanceAmount.toStringAsFixed(2)} ج.م', AppTheme.cobalt),
                  _buildSummaryRow('إجمالي المصروفات المطالب بها:', '${reconciliation.totalExpensesClaimed.toStringAsFixed(2)} ج.م', Colors.black87),
                  _buildSummaryRow('ضريبة الخصم والإضافة المستقطعة (1% نموذج 41):', '${reconciliation.totalTaxWithheldW41.toStringAsFixed(2)} ج.م', AppTheme.orange),
                  _buildSummaryRow('صافي المستحق تسويته:', '${reconciliation.totalNetSettled.toStringAsFixed(2)} ج.م', Colors.blueGrey.shade800),
                  const Divider(height: 16),
                  _buildSummaryRow(
                    reconciliation.balanceRemaining >= 0 ? 'المتبقي طرف المخلص (واجب الرد):' : 'مستحق للمخلص (واجب الصرف):',
                    '${reconciliation.balanceRemaining.abs().toStringAsFixed(2)} ج.م',
                    reconciliation.balanceRemaining >= 0 ? AppTheme.emerald : AppTheme.crimson,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AppButton(
              label: 'تم والعودة',
              variant: AppButtonVariant.primary,
              onPressed: () {
                Navigator.of(ctx).pop();
                _loadData();
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppTheme.snackBar(context, 'فشل في تنفيذ التسوية: $e', severity: AppSeverity.danger);
    }
  }

  Widget _buildSummaryRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12.5)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 1150,
        height: 760,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.emerald, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تسوية عهد ومصروفات المخلصين الجمركيين (Broker Custody & Settlement)',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'صرف العهد المالية، تسجيل المصروفات واحتساب ضريبة الخصم 1% (نموذج 41)، وإجراء المقاصة النهائية',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: 'صرف عهدة جديدة',
                    icon: Icons.add_circle_outline,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: _showNewAdvanceDialog,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Advances List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text('خطأ: $_errorMessage', style: const TextStyle(color: AppTheme.crimson)))
                      : _advances.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 54, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  const Text('لا توجد عهد مخلصين مسجلة لهذا الملف حالياً', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            )
                          : SelectionArea(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _advances.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, idx) {
                                  final advance = _advances[idx];

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        // Header of Card
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                advance.advanceCode,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.cobalt),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'المخلص: ${advance.brokerName}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              const SizedBox(width: 8),
                                              AppStatusBadge(
                                                label: advance.statusLabelAr,
                                                severity: _statusSeverity(advance.status),
                                              ),
                                              const Spacer(),
                                              Text(
                                                'العهدة: ${advance.advanceAmount.toStringAsFixed(2)} ج.م | المسوّى: ${advance.settledAmount.toStringAsFixed(2)} ج.م | المتبقي: ${advance.remainingBalance.toStringAsFixed(2)} ج.م',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                              const SizedBox(width: 12),
                                              AppButton(
                                                label: 'إضافة مصروف',
                                                icon: Icons.add,
                                                variant: AppButtonVariant.secondary,
                                                size: AppButtonSize.small,
                                                onPressed: () => _showAddExpenseDialog(advance),
                                              ),
                                              const SizedBox(width: 6),
                                              AppButton(
                                                label: 'تسوية ومقاصة',
                                                icon: Icons.done_all_rounded,
                                                variant: AppButtonVariant.success,
                                                size: AppButtonSize.small,
                                                onPressed: () => _settleAdvance(advance),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Items Table
                                        if (advance.expenseItems.isNotEmpty)
                                          ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            padding: const EdgeInsets.all(8),
                                            itemCount: advance.expenseItems.length,
                                            separatorBuilder: (_, __) => const Divider(height: 1),
                                            itemBuilder: (context, iIdx) {
                                              final item = advance.expenseItems[iIdx];

                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(item.categoryLabelAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                          if (item.receiptReference != null)
                                                            Text('مستند: ${item.receiptReference}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                                        ],
                                                      ),
                                                    ),
                                                    if (item.isEInvoiceBacked)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                                        child: const Text('فاتورة إلكترونية ✔', style: TextStyle(color: Colors.green, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                      ),
                                                    const SizedBox(width: 12),
                                                    Text('الإجمالي: ${item.amount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 12)),
                                                    const SizedBox(width: 12),
                                                    Text('خصم 1%: ${item.taxWithheldAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 12, color: AppTheme.crimson)),
                                                    const SizedBox(width: 12),
                                                    Text('الصافي: ${item.netSettledAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                                    const SizedBox(width: 12),
                                                    AppStatusBadge(
                                                      label: item.approvalStatus == 'APPROVED' ? 'معتمد' : 'قيد المراجعة',
                                                      severity: item.approvalStatus == 'APPROVED' ? AppSeverity.success : AppSeverity.warning,
                                                    ),
                                                    if (item.approvalStatus != 'APPROVED') ...[
                                                      const SizedBox(width: 6),
                                                      IconButton(
                                                        icon: const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 20),
                                                        tooltip: 'اعتماد البند',
                                                        onPressed: () => _approveItem(item),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              );
                                            },
                                          )
                                        else
                                          const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Text('لم يتم تسجيل أي بنود مصروفات لهذه العهدة بعد', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewBrokerCustodyAdvanceDialog extends StatefulWidget {
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

  const _NewBrokerCustodyAdvanceDialog({
    required this.initialImportFileId,
    required this.onSubmit,
  });

  @override
  State<_NewBrokerCustodyAdvanceDialog> createState() => _NewBrokerCustodyAdvanceDialogState();
}

class _NewBrokerCustodyAdvanceDialogState extends State<_NewBrokerCustodyAdvanceDialog> {
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'معرف الملف الاستيرادي (ID)',
                      controller: _fileIdController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomTextField(
                      label: 'معرف المخلص (Broker ID)',
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
                      label: 'مبلغ العهدة المصروفة (ج.م EGP)',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('طريقة الصرف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    items: const [
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('تحويل بنكي (Bank Transfer)')),
                      DropdownMenuItem(value: 'CHECK', child: Text('شيك مصرفي (Check)')),
                      DropdownMenuItem(value: 'CASH', child: Text('نقدي من الخزينة (Cash)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _paymentMethod = v);
                    },
                  ),
                ],
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

class _AddBrokerCustodyExpenseDialog extends StatefulWidget {
  final BrokerCustodyAdvanceModel advance;
  final Future<void> Function({
    required String expenseCategory,
    required double amount,
    required bool isEInvoiceBacked,
    String? eInvoiceUuid,
    String? receiptReference,
    String? notes,
  }) onSubmit;

  const _AddBrokerCustodyExpenseDialog({
    required this.advance,
    required this.onSubmit,
  });

  @override
  State<_AddBrokerCustodyExpenseDialog> createState() => _AddBrokerCustodyExpenseDialogState();
}

class _AddBrokerCustodyExpenseDialogState extends State<_AddBrokerCustodyExpenseDialog> {
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('بند وتصنيف المصروف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: const [
                  DropdownMenuItem(value: 'OFFICIAL_DUTIES_TAXES', child: Text('ضرائب ورسوم جمركية رسمية (معفية من الخصم)')),
                  DropdownMenuItem(value: 'PORT_AUTHORITY_FEES', child: Text('رسوم وأرضيات هيئة الميناء')),
                  DropdownMenuItem(value: 'LAB_TESTING_FEES', child: Text('رسوم فحص معملي وسحب عينات')),
                  DropdownMenuItem(value: 'HANDLING_AND_PORTERAGE', child: Text('عتالة ومصروفات مناولة وتعتيق')),
                  DropdownMenuItem(value: 'INSPECTION_TRANSPORT', child: Text('انتقالات لجان الكشف والمعاينة')),
                  DropdownMenuItem(value: 'SUNDRY_PETTY_CASH', child: Text('نثريات ومصروفات متنوعة')),
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
                      label: 'المبلغ الإجمالي (ج.م EGP)',
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
                  label: 'الرقم التعريفي الموحد للفاتورة الإلكترونية (UUID)',
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
