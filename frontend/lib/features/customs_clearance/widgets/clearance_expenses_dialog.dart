import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/clearance_expense_invoice_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/app_localizations.dart';

/// CL-05 Modal Dialog: Clearance Fees & Port Invoices
/// تسجيل فواتير المخلص ومصاريف العتالة ونولون الميناء
class ClearanceExpensesDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const ClearanceExpensesDialog({
    super.key,
    required this.file,
    this.clearanceRecord,
  });

  static Future<bool?> show(
    BuildContext context,
    ImportFileModel file, {
    CustomsClearanceModel? clearanceRecord,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClearanceExpensesDialog(
        file: file,
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<ClearanceExpensesDialog> createState() =>
      _ClearanceExpensesDialogState();
}

class _ClearanceExpensesDialogState
    extends ConsumerState<ClearanceExpensesDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showAddForm = false;
  ClearanceInvoicesSummaryModel? _summary;

  // Form Controllers
  late TextEditingController _providerNameController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _amountEgpController;
  late TextEditingController _vatAmountController;
  late TextEditingController _whtAmountController;
  late TextEditingController _notesController;

  String _expenseCategory = 'BROKER_FEES';
  DateTime _invoiceDate = DateTime.now();
  bool _vatIncluded = false;
  bool _whtDeducted = false;
  String _allocationRule = 'Equal';
  final String _currency = 'EGP';

  final List<String> _expenseCategories = DomainEnums.codesOf(DomainEnumType.clearanceExpenseCategory);

  final List<Map<String, String>> _allocationRules = [
    {'value': 'Equal', 'label': 'بالتساوي (Equal)'},
    {'value': 'Value-Based', 'label': 'حسب القيمة (CIF Value)'},
    {'value': 'Weight-Based', 'label': 'حسب الوزن (Gross Weight)'},
    {'value': 'Volume-Based', 'label': 'حسب الحجم (CBM)'},
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadInvoices();
  }

  void _initControllers() {
    _providerNameController = TextEditingController();
    _invoiceNumberController = TextEditingController();
    _amountEgpController = TextEditingController();
    _vatAmountController = TextEditingController(text: '0.00');
    _whtAmountController = TextEditingController(text: '0.00');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _providerNameController.dispose();
    _invoiceNumberController.dispose();
    _amountEgpController.dispose();
    _vatAmountController.dispose();
    _whtAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final summary = await ref
          .read(customsClearanceProvider.notifier)
          .fetchClearanceInvoices(widget.file.importFileId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _providerNameController.clear();
    _invoiceNumberController.clear();
    _amountEgpController.clear();
    _vatAmountController.text = '0.00';
    _whtAmountController.text = '0.00';
    _notesController.clear();
    setState(() {
      _expenseCategory = 'BROKER_FEES';
      _invoiceDate = DateTime.now();
      _vatIncluded = false;
      _whtDeducted = false;
      _allocationRule = 'Equal';
      _showAddForm = false;
    });
  }

  void _recalculateVat() {
    if (_vatIncluded) {
      final amt = double.tryParse(_amountEgpController.text.trim()) ?? 0.0;
      final vat = amt * 0.14;
      _vatAmountController.text = vat.toStringAsFixed(2);
    } else {
      _vatAmountController.text = '0.00';
    }
  }

  void _recalculateWht() {
    if (_whtDeducted) {
      final amt = double.tryParse(_amountEgpController.text.trim()) ?? 0.0;
      final wht = amt * 0.03;
      _whtAmountController.text = wht.toStringAsFixed(2);
    } else {
      _whtAmountController.text = '0.00';
    }
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    final amountEgp = double.tryParse(_amountEgpController.text.trim()) ?? 0.0;
    final vatAmount = _vatIncluded
        ? (double.tryParse(_vatAmountController.text.trim()) ?? 0.0)
        : 0.0;
    final whtAmount = _whtDeducted
        ? (double.tryParse(_whtAmountController.text.trim()) ?? 0.0)
        : 0.0;
    final netPayable = amountEgp + vatAmount - whtAmount;

    final payload = {
      'import_file_id': widget.file.importFileId,
      if (widget.clearanceRecord?.customsClearanceId != null)
        'customs_clearance_id': widget.clearanceRecord!.customsClearanceId,
      'invoice_number': _invoiceNumberController.text.trim(),
      'invoice_date':
          '${_invoiceDate.year}-${_invoiceDate.month.toString().padLeft(2, '0')}-${_invoiceDate.day.toString().padLeft(2, '0')}',
      'provider_name': _providerNameController.text.trim(),
      'expense_category': _expenseCategory,
      'currency': _currency,
      'amount_fx': amountEgp,
      'exchange_rate': 1.0,
      'amount_egp': amountEgp,
      'vat_included': _vatIncluded,
      'vat_amount': vatAmount,
      'wht_deducted': _whtDeducted,
      'wht_amount': whtAmount,
      'net_payable_egp': netPayable,
      'allocation_rule': _allocationRule,
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    };

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(customsClearanceProvider.notifier)
          .createClearanceInvoice(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل فاتورة ${DomainEnums.label(context.l10n, DomainEnumType.clearanceExpenseCategory, _expenseCategory)} بنجاح وترحيلها لتكلفة البضاعة (Landed Cost)',
            ),
            backgroundColor: AppTheme.emerald,
          ),
        );
        _resetForm();
        await _loadInvoices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل الفاتورة: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteInvoice(ClearanceExpenseInvoiceModel invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
            SizedBox(width: 8),
            Text('تأكيد حذف الفاتورة'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف فاتورة "${invoice.invoiceNumber}" الخاصة بـ "${invoice.providerName}"؟\nسيتم تحديث إجمالي تكاليف التخليص تلقائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(customsClearanceProvider.notifier)
          .deleteClearanceInvoice(invoice.invoiceId, widget.file.importFileId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الفاتورة بنجاح وتحديث إجماليات التخليص'),
            backgroundColor: AppTheme.emerald,
          ),
        );
        await _loadInvoices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر حذف الفاتورة: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (DomainEnums.legacyToCode(DomainEnumType.clearanceExpenseCategory, category)) {
      case 'BROKER_FEES':
        return AppTheme.cobalt;
      case 'PORT_DUES_WHARFAGE':
        return AppTheme.flatOrange;
      case 'STEVEDORING_HANDLING':
        return Colors.purple.shade600;
      case 'LABORATORY_TESTING':
        return Colors.teal.shade700;
      case 'STORAGE_DEMURRAGE':
        return AppTheme.crimson;
    }
    return AppTheme.charcoal;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 960 ? 920.0 : screenWidth * 0.95;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            _buildDialogHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryKpiCards(),
                          const SizedBox(height: 16),
                          _buildActionBar(),
                          if (_showAddForm) ...[
                            const SizedBox(height: 16),
                            _buildAddInvoiceForm(),
                          ],
                          const SizedBox(height: 20),
                          _buildInvoicesSection(),
                        ],
                      ),
                    ),
            ),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تسجيل فواتير المخلص ومصاريف التخليص والميناء (CL-05)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ملف الشحنة: ${widget.file.importFileCode} — ${widget.file.supplierName.isNotEmpty ? widget.file.supplierName : 'المورد'} (${(widget.file.form46No != null && widget.file.form46No!.isNotEmpty) ? widget.file.form46No : 'بانتظار البيان'})',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'إغلاق',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryKpiCards() {
    final summary = _summary;
    final totalNet = summary?.netPayableEgp ?? 0.0;
    final brokerFees = summary?.totalClearanceFeesEgp ?? 0.0;
    final portDues = summary?.totalPortDuesEgp ?? 0.0;
    final handling = summary?.totalHandlingStevedoringEgp ?? 0.0;
    final count = summary?.invoicesCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'إجمالي صافي الفواتير',
            value: '${totalNet.toStringAsFixed(2)} ج.م',
            subtitle: '$count فاتورة مسجلة',
            icon: Icons.account_balance_wallet,
            color: AppTheme.emerald,
            highlight: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'أتعاب التخليص الجمركي',
            value: '${brokerFees.toStringAsFixed(2)} ج.م',
            subtitle: 'Clearance Fees',
            icon: Icons.person_search,
            color: AppTheme.cobalt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'نولون ورسوم الميناء',
            value: '${portDues.toStringAsFixed(2)} ج.م',
            subtitle: 'Port Dues & Wharfage',
            icon: Icons.anchor,
            color: AppTheme.flatOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'العتالة والشحن والتفريغ',
            value: '${handling.toStringAsFixed(2)} ج.م',
            subtitle: 'Handling & Stevedoring',
            icon: Icons.forklift,
            color: Colors.purple.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? color.withAlpha(20) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? color : Colors.grey.shade300,
          width: highlight ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: highlight ? color : AppTheme.charcoal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.receipt, size: 20, color: AppTheme.charcoal),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'قائمة فواتير ومصروفات التخليص (${_summary?.invoicesCount ?? 0})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          key: const Key('addClearanceInvoiceBtn'),
          onPressed: () {
            setState(() => _showAddForm = !_showAddForm);
          },
          icon: Icon(_showAddForm ? Icons.close : Icons.add, size: 18),
          label: Text(_showAddForm ? 'إلغاء الإضافة' : 'إضافة فاتورة جديدة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _showAddForm ? Colors.grey.shade600 : AppTheme.cobalt,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddInvoiceForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cobalt.withAlpha(80), width: 1.5),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.note_add, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'تسجيل فاتورة مصروفات جديدة',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cobalt,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'سيتم الترحيل آلياً لمحرك التكلفة Landed Cost',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Row 1: Provider Name & Invoice Number
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('invoiceProviderNameField'),
                    controller: _providerNameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المخلص / مقدم الخدمة *',
                      hintText: 'مثال: شركة الصفا للتخليص الجمركي',
                      prefixIcon: const Icon(Icons.business_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال اسم مقدم الخدمة أو المخلص';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('invoiceNumberField'),
                    controller: _invoiceNumberController,
                    decoration: InputDecoration(
                      labelText: 'رقم الفاتورة *',
                      hintText: 'مثال: INV-2026-9901',
                      prefixIcon: const Icon(Icons.tag),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال رقم الفاتورة';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 1,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _invoiceDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'تاريخ الفاتورة',
                        prefixIcon: const Icon(Icons.calendar_today, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '${_invoiceDate.year}-${_invoiceDate.month.toString().padLeft(2, '0')}-${_invoiceDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 2: Category & Allocation Rule
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    key: const Key('invoiceCategoryDropdown'),
                    value: _expenseCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'بند المصروف / نوع التكلفة *',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _expenseCategories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(
                          DomainEnums.label(context.l10n, DomainEnumType.clearanceExpenseCategory, cat),
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _expenseCategory = val);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    key: const Key('invoiceAllocationRuleDropdown'),
                    value: _allocationRule,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'قاعدة توزيع التكلفة *',
                      prefixIcon: const Icon(Icons.pie_chart_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _allocationRules.map((rule) {
                      return DropdownMenuItem(
                        value: rule['value'],
                        child: Text(
                          rule['label']!,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _allocationRule = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 3: Amount EGP, VAT, WHT
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('invoiceAmountField'),
                    controller: _amountEgpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'مبلغ الفاتورة الأساسي (ج.م) *',
                      hintText: '0.00',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) {
                      _recalculateVat();
                      _recalculateWht();
                    },
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال مبلغ الفاتورة';
                      }
                      final numVal = double.tryParse(val.trim());
                      if (numVal == null || numVal <= 0) {
                        return 'أدخل مبلغاً أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                // VAT switch & amount
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Material(type: MaterialType.transparency, child: CheckboxListTile(
                        title: const Text(
                          'ضريبة القيمة المضافة (14% VAT)',
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: _vatIncluded,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) {
                          setState(() {
                            _vatIncluded = val ?? false;
                            _recalculateVat();
                          });
                        },
                      )),
                      if (_vatIncluded)
                        TextFormField(
                          key: const Key('invoiceVatAmountField'),
                          controller: _vatAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'قيمة ضريبة القيمة المضافة',
                            prefixIcon: const Icon(Icons.percent, size: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // WHT switch & amount
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Material(type: MaterialType.transparency, child: CheckboxListTile(
                        title: const Text(
                          'خصم ضريبة الأرباح (WHT)',
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: _whtDeducted,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) {
                          setState(() {
                            _whtDeducted = val ?? false;
                            _recalculateWht();
                          });
                        },
                      )),
                      if (_whtDeducted)
                        TextFormField(
                          key: const Key('invoiceWhtAmountField'),
                          controller: _whtAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'مبلغ ضريبة الخصم المقتطعة',
                            prefixIcon: const Icon(Icons.remove_circle_outline, size: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Notes
            TextFormField(
              key: const Key('invoiceNotesField'),
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'ملاحظات وتفاصيل إضافية عن الفاتورة',
                hintText: 'أي تفاصيل عن أتعاب الشحن والتفريغ أو رقم إيصال الميناء...',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Submit / Cancel Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _resetForm,
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  key: const Key('saveClearanceInvoiceBtn'),
                  onPressed: _isSubmitting ? null : _submitInvoice,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(_isSubmitting ? 'جاري الحفظ...' : 'حفظ الفاتورة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesSection() {
    final invoices = _summary?.invoices ?? [];

    if (invoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد فواتير تخليص مسجلة حتى الآن',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'اضغط على زر "إضافة فاتورة جديدة" لتسجيل فواتير المخلص الجمركي ونولون الميناء ومصاريف التعتيق والتحاليل.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: invoices.map((inv) => _buildInvoiceCard(inv)).toList(),
    );
  }

  Widget _buildInvoiceCard(ClearanceExpenseInvoiceModel invoice) {
    final catColor = _getCategoryColor(invoice.expenseCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Category Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: catColor.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: catColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DomainEnums.label(context.l10n, DomainEnumType.clearanceExpenseCategory, invoice.expenseCategory),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: catColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'فاتورة #${invoice.invoiceNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${invoice.invoiceCode})',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const Spacer(),
                // Net Payable
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${invoice.netPayableEgp.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                      ),
                    ),
                    if (invoice.vatIncluded || invoice.whtDeducted)
                      Text(
                        'أساسي: ${invoice.amountEgp.toStringAsFixed(2)} | ض.م: +${invoice.vatAmount.toStringAsFixed(2)} | خ.أ: -${invoice.whtAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Delete button
                IconButton(
                  key: Key('deleteInvoiceBtn_${invoice.invoiceId}'),
                  icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                  tooltip: 'حذف الفاتورة',
                  onPressed: () => _deleteInvoice(invoice),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                _buildCardInfo(Icons.business, 'المورد / المخلص', invoice.providerName),
                const SizedBox(width: 24),
                _buildCardInfo(Icons.calendar_today, 'التاريخ', invoice.invoiceDate),
                const SizedBox(width: 24),
                _buildCardInfo(
                  Icons.pie_chart,
                  'التوزيع',
                  invoice.allocationRule == 'Equal'
                      ? 'بالتساوي'
                      : invoice.allocationRule,
                ),
                if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildCardInfo(Icons.notes, 'ملاحظات', invoice.notes!),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardInfo(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.charcoal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.sync_alt, size: 16, color: AppTheme.emerald),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'المصاريف تُرحَّل تلقائياً إلى كشف حساب تكلفة الشحنة (Landed Cost Engine)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.charcoal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
