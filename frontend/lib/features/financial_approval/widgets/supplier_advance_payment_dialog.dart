import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';

/// Shows the Foreign Supplier Advance Payment Request Dialog (FN-01)
Future<PaymentRequestModel?> showSupplierAdvancePaymentDialog(
  BuildContext context,
  WidgetRef ref, {
  required int importFileId,
  required String importFileCode,
  String? fileTitle,
  int? supplierId,
  required String supplierName,
  int? projectId,
  int? poId,
  double? totalAmountForeign,
  String currency = 'USD',
}) {
  return showDialog<PaymentRequestModel>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => SupplierAdvancePaymentDialog(
      importFileId: importFileId,
      importFileCode: importFileCode,
      fileTitle: fileTitle,
      supplierId: supplierId,
      supplierName: supplierName,
      projectId: projectId,
      poId: poId,
      totalAmountForeign: totalAmountForeign,
      currency: currency,
    ),
  );
}

/// Dedicated Dialog for Issuing Supplier Advance Payment Requests (FN-01)
class SupplierAdvancePaymentDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;
  final String? fileTitle;
  final int? supplierId;
  final String supplierName;
  final int? projectId;
  final int? poId;
  final double? totalAmountForeign;
  final String currency;

  const SupplierAdvancePaymentDialog({
    super.key,
    required this.importFileId,
    required this.importFileCode,
    this.fileTitle,
    this.supplierId,
    required this.supplierName,
    this.projectId,
    this.poId,
    this.totalAmountForeign,
    this.currency = 'USD',
  });

  @override
  ConsumerState<SupplierAdvancePaymentDialog> createState() =>
      _SupplierAdvancePaymentDialogState();
}

class _SupplierAdvancePaymentDialogState
    extends ConsumerState<SupplierAdvancePaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _exchangeRateController;
  late TextEditingController _beneficiaryController;
  late TextEditingController _bankNameController;
  late TextEditingController _swiftController;
  late TextEditingController _ibanController;
  late TextEditingController _notesController;

  double _basePoAmount = 0.0;
  String _currency = 'USD';
  double _selectedPercentage = 30.0;
  bool _isCustomPercentage = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoadingPrefill = true;
  bool _isSubmitting = false;
  int? _selectedSupplierId;
  int? _primaryPoId;
  GuideMatchResultModel? _guideMatchResult;

  static const List<double> _standardPercentages = [10.0, 20.0, 30.0, 50.0, 100.0];

  @override
  void initState() {
    super.initState();
    _currency = widget.currency.isNotEmpty ? widget.currency : 'USD';
    _selectedSupplierId = widget.supplierId;
    _primaryPoId = widget.poId;
    _basePoAmount = widget.totalAmountForeign ?? 0.0;

    _titleController = TextEditingController(
      text: 'طلب دفعة مقدمة (30%) - ${widget.importFileCode} - ${widget.supplierName}',
    );
    _amountController = TextEditingController();
    _exchangeRateController = TextEditingController(text: '50.0');
    _beneficiaryController = TextEditingController(text: widget.supplierName);
    _bankNameController = TextEditingController();
    _swiftController = TextEditingController();
    _ibanController = TextEditingController();
    _notesController = TextEditingController();

    _loadPrefillData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _exchangeRateController.dispose();
    _beneficiaryController.dispose();
    _bankNameController.dispose();
    _swiftController.dispose();
    _ibanController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _resolveExchangeRate(String currCode) {
    if (currCode.toUpperCase() == 'EGP') return 1.0;
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final cur = currencies
        .where((c) => c.currencyCode.toUpperCase() == currCode.toUpperCase())
        .firstOrNull;
    if (cur != null) {
      if (cur.isBaseCurrency) return 1.0;
      if (cur.latestCommercialRate != null && cur.latestCommercialRate! > 0) {
        return cur.latestCommercialRate!;
      }
    }
    return 50.0;
  }

  Future<void> _loadPrefillData() async {
    setState(() => _isLoadingPrefill = true);
    try {
      final prefill = await ref
          .read(importBudgetsProvider.notifier)
          .fetchBudgetPrefill(widget.importFileId);

      final poList = ref.read(purchaseOrdersProvider).purchaseOrders;
      final linkedPOs = poList
          .where((po) => po.importFileId == widget.importFileId)
          .toList();

      if (linkedPOs.isNotEmpty && _primaryPoId == null) {
        _primaryPoId = linkedPOs.first.poId;
      }

      double poTotal = 0.0;
      if (prefill != null && prefill.totalInvoiceAmount > 0) {
        poTotal = prefill.totalInvoiceAmount;
      } else if (linkedPOs.isNotEmpty) {
        for (final p in linkedPOs) {
          poTotal += p.totalAmountFob > 0
              ? p.totalAmountFob
              : p.items.fold(0.0, (sum, it) => sum + (it.quantity * it.unitPrice));
        }
      } else if (widget.totalAmountForeign != null && widget.totalAmountForeign! > 0) {
        poTotal = widget.totalAmountForeign!;
      }

      final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
      final supObj = suppliers
          .where((s) =>
              (widget.supplierId != null && s.supplierId == widget.supplierId) ||
              s.companyName.trim().toLowerCase() == widget.supplierName.trim().toLowerCase() ||
              (prefill != null &&
                  s.companyName.trim().toLowerCase() ==
                      prefill.supplierName.trim().toLowerCase()))
          .firstOrNull;

      final effBank = (supObj?.bankName != null && supObj!.bankName!.isNotEmpty)
          ? supObj.bankName!
          : (prefill?.bankName ?? '');
      final effSwift = (supObj?.swiftCode != null && supObj!.swiftCode!.isNotEmpty)
          ? supObj.swiftCode!
          : (prefill?.swiftCode ?? '');
      final effIban = (supObj?.iban != null && supObj!.iban!.isNotEmpty)
          ? supObj.iban!
          : ((supObj?.accountNumber != null && supObj!.accountNumber!.isNotEmpty)
              ? supObj.accountNumber!
              : (prefill?.iban ?? prefill?.accountNumber ?? ''));
      final effBeneficiary = (supObj?.companyName != null && supObj!.companyName.isNotEmpty)
          ? supObj.companyName
          : (prefill?.beneficiaryName ?? widget.supplierName);

      final effCurr = (prefill != null && prefill.invoiceCurrency.isNotEmpty)
          ? prefill.invoiceCurrency
          : _currency;
      final effRate = _resolveExchangeRate(effCurr);

      if (mounted) {
        setState(() {
          _basePoAmount = poTotal;
          _currency = effCurr;
          _selectedSupplierId = supObj?.supplierId ?? widget.supplierId;
          _beneficiaryController.text = effBeneficiary;
          _bankNameController.text = effBank;
          _swiftController.text = effSwift;
          _ibanController.text = effIban;
          _exchangeRateController.text = effRate.toStringAsFixed(2);

          _calculateAndApplyAmount(_selectedPercentage);
          _isLoadingPrefill = false;
        });
      }
    } catch (_) {
      if (mounted) {
        _calculateAndApplyAmount(_selectedPercentage);
        setState(() => _isLoadingPrefill = false);
      }
    }
    _loadGuide();
  }

  Future<void> _loadGuide() async {
    try {
      final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
        supplier: widget.supplierName,
        paymentMethod: 'ADVANCE_PAYMENT',
        importFileReference: widget.importFileCode,
      );
      if (mounted) {
        setState(() => _guideMatchResult = res);
      }
    } catch (_) {}
  }

  void _calculateAndApplyAmount(double percentage) {
    setState(() {
      _selectedPercentage = percentage;
      _isCustomPercentage = !_standardPercentages.contains(percentage);
      final calculated = _basePoAmount * (percentage / 100.0);
      _amountController.text = calculated > 0 ? calculated.toStringAsFixed(2) : '';
      // Stored title: English regardless of the UI language.
      _titleController.text =
          'Advance Payment (${percentage.toStringAsFixed(0)}%) - ${widget.importFileCode} - ${widget.supplierName}';
    });
  }

  void _onAmountManuallyChanged(String val) {
    final amount = double.tryParse(val) ?? 0.0;
    if (_basePoAmount > 0 && amount > 0) {
      final calculatedPct = (amount / _basePoAmount) * 100.0;
      setState(() {
        _selectedPercentage = double.parse(calculatedPct.toStringAsFixed(1));
        _isCustomPercentage = !_standardPercentages.contains(_selectedPercentage);
      });
    }
  }

  Future<void> _submitAdvancePayment() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'يرجى إدخال قيمة دفعة مقدمة صالحة أكبر من الصفر' : 'Please enter a valid advance payment amount greater than zero'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rate = double.tryParse(_exchangeRateController.text.trim()) ?? 50.0;
    final totalEgp = amount * rate;

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'import_file_id': widget.importFileId,
        'purchase_order_id': _primaryPoId,
        'supplier_id': _selectedSupplierId,
        'project_id': widget.projectId,
        'payment_type': 'ADVANCE_PAYMENT',
        'title': _titleController.text.trim(),
        'amount': amount,
        'currency': _currency,
        'exchange_rate': rate,
        'amount_egp': totalEgp,
        'beneficiary_name': _beneficiaryController.text.trim(),
        'bank_name': _bankNameController.text.trim(),
        'swift_code': _swiftController.text.trim().toUpperCase(),
        'iban': _ibanController.text.trim().replaceAll(' ', ''),
        'due_date':
            '${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}',
        'notes': _notesController.text.trim().isEmpty
            ? 'Advance payment of ${_selectedPercentage.toStringAsFixed(0)}% requested via ImportFlow ERP'
            : _notesController.text.trim(),
      };

      final created = await ref
          .read(paymentRequestsProvider.notifier)
          .createPaymentRequest(payload);

      ref.invalidate(paymentRequestsProvider);
      ref.invalidate(importFilesProvider);

      if (mounted) {
        Navigator.pop(context, created);

        final taskInfo = (created?.smartTaskCode != null)
            ? (isAr ? ' وتم توليد المهمة الذكية ${created!.smartTaskCode}' : ' and smart task ${created!.smartTaskCode} generated')
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr
                  ? '✅ تم إصدار طلب سداد الدفعة المقدمة (${created?.paymentCode ?? 'بنجاح'})$taskInfo وإخطار قسم المالية ومتابعة ملف الاستيراد (STEP_04)'
                  : '✅ Advance payment request issued (${created?.paymentCode ?? 'Success'})$taskInfo and Finance notified (STEP_04)',
            ),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'فشل إصدار طلب السداد: $e' : 'Failed to issue payment request: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth - 32).clamp(360.0, 740.0);

    final currentAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final currentRate =
        double.tryParse(_exchangeRateController.text.trim()) ?? 50.0;
    final totalEgp = currentAmount * currentRate;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              isAr ? 'طلب سداد الدفعة المقدمة للمورد (FN-01)' : 'Supplier Advance Payment (FN-01)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.charcoal,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.importFileCode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.cobalt,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAr
                              ? 'المورد الأجنبي: ${widget.supplierName} | المرحلة: STEP_04 (اعتمادات الميزانية وسداد الموردين)'
                              : 'Supplier: ${widget.supplierName} | Stage: STEP_04 (Budget & Supplier Payment)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : Colors.grey.shade600,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoadingPrefill)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(strokeWidth: 2),
                        const SizedBox(height: 12),
                        Text(isAr ? 'جاري جلب بيانات أمر الشراء وحسابات المورد...' : 'Fetching purchase order and supplier accounts...'),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_guideMatchResult != null && _guideMatchResult!.matchedEntries.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ExperienceGuideAlertBanner(
                                matchResult: _guideMatchResult!,
                                supplier: widget.supplierName,
                              ),
                            ),

                          // Top Metric Card: PO Total FOB & Exchange Rate
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAr ? 'إجمالي أمر الشراء (PO FOB Total):' : 'PO FOB Total:',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_basePoAmount.toStringAsFixed(2)} $_currency',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.amber.shade300
                                              : Colors.amber.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  width: 1,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAr ? 'سعر صرف العملة المعتمد:' : 'Approved Exchange Rate:',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '1 $_currency = ${_exchangeRateController.text} EGP',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppTheme.darkTextPrimary
                                              : AppTheme.charcoal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Advance Percentage Chips Selector
                          Text(
                            isAr ? 'نسبة الدفعة المقدمة المطلوبة (Advance Percentage):' : 'Required Advance Percentage:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.charcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ..._standardPercentages.map((pct) {
                                final isSelected =
                                    !_isCustomPercentage && _selectedPercentage == pct;
                                final isRecommended = pct == 30.0;
                                return ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark
                                                  ? AppTheme.darkTextPrimary
                                                  : AppTheme.charcoal),
                                        ),
                                      ),
                                      if (isRecommended) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white.withOpacity(0.25)
                                                : Colors.amber.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isAr ? 'شائع' : 'Common',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.amber.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFFD97706),
                                  backgroundColor: isDark
                                      ? AppTheme.darkCardBackground
                                      : Colors.grey.shade100,
                                  onSelected: (_) => _calculateAndApplyAmount(pct),
                                );
                              }),
                              ChoiceChip(
                                label: Text(
                                  isAr ? 'مخصص (${_selectedPercentage.toStringAsFixed(1)}%)' : 'Custom (${_selectedPercentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontWeight: _isCustomPercentage
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _isCustomPercentage
                                        ? Colors.white
                                        : (isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.charcoal),
                                  ),
                                ),
                                selected: _isCustomPercentage,
                                selectedColor: AppTheme.cobalt,
                                backgroundColor: isDark
                                    ? AppTheme.darkCardBackground
                                    : Colors.grey.shade100,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _isCustomPercentage = true);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Row: Foreign Amount & EGP Total Display
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _amountController,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: isAr
                                        ? 'قيمة الدفعة المقدمة ($_currency) *'
                                        : 'Advance Payment Amount ($_currency) *',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.attach_money),
                                    suffixText: _currency,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return isAr
                                          ? 'يرجى إدخال قيمة الدفعة'
                                          : 'Please enter payment amount';
                                    }
                                    final parsed = double.tryParse(v);
                                    if (parsed == null || parsed <= 0) {
                                      return isAr
                                          ? 'القيمة يجب أن تكون أكبر من الصفر'
                                          : 'Amount must be greater than zero';
                                    }
                                    return null;
                                  },
                                  onChanged: _onAmountManuallyChanged,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _exchangeRateController,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: isAr ? 'سعر الصرف (EGP) *' : 'Exchange Rate (EGP) *',
                                    border: const OutlineInputBorder(),
                                    suffixText: 'EGP',
                                  ),
                                  validator: (v) =>
                                      (v == null || double.tryParse(v) == null)
                                          ? (isAr ? 'سعر غير صالح' : 'Invalid rate')
                                          : null,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // EGP Live Conversion Result Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.emerald.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.currency_exchange,
                                  size: 18,
                                  color: AppTheme.emerald,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isAr
                                      ? 'المعادل بالجنيه المصري (EGP): '
                                      : 'Equivalent in EGP: ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${totalEgp.toStringAsFixed(2)} ${isAr ? 'ج.م' : 'EGP'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.emerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Request Title
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: isAr ? 'عنوان طلب السداد *' : 'Payment Request Title *',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? (isAr ? 'مطلوب' : 'Required') : null,
                          ),
                          const SizedBox(height: 12),

                          // Supplier Banking Details Section
                          Text(
                            isAr
                                ? 'بيانات الحساب البنكي للمورد المستفيد (Beneficiary Bank):'
                                : 'Supplier Beneficiary Bank Details:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.charcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _beneficiaryController,
                                  decoration: InputDecoration(
                                    labelText: isAr ? 'اسم المستفيد *' : 'Beneficiary Name *',
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? (isAr ? 'مطلوب' : 'Required') : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _bankNameController,
                                  decoration: InputDecoration(
                                    labelText: isAr ? 'اسم البنك *' : 'Bank Name *',
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? (isAr ? 'مطلوب' : 'Required') : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _swiftController,
                                  decoration: InputDecoration(
                                    labelText: isAr
                                        ? 'كود السويفت (SWIFT / BIC) *'
                                        : 'SWIFT / BIC Code *',
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? (isAr ? 'مطلوب' : 'Required') : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _ibanController,
                                  decoration: InputDecoration(
                                    labelText: isAr
                                        ? 'رقم الحساب أو الآيبان (IBAN) *'
                                        : 'Account Number / IBAN *',
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? (isAr ? 'مطلوب' : 'Required') : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Due Date & Notes
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _dueDate,
                                      firstDate: DateTime.now().subtract(
                                        const Duration(days: 30),
                                      ),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setState(() => _dueDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: isAr ? 'تاريخ الاستحقاق المطلوب *' : 'Requested Due Date *',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      '${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: isAr
                                  ? 'ملاحظات وتوجيهات إضافية للمالية'
                                  : 'Additional notes for Finance',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Informational Workflow Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.cobalt.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppTheme.cobalt,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isAr
                                        ? 'عند التأكيد، سيتم إنشاء طلب السداد بحالة (Pending Approval) وإرسال إشعار فوري لمسؤول المالية (Finance Officer) وتوليد مهمة ذكية (Smart Task)، مع ترقية ملف الشحنة آلياً للمرحلة STEP_04.'
                                        : 'Upon confirmation, the payment request will be created with status (Pending Approval), notifying the Finance Officer, generating a Smart Task, and advancing the Import File to STEP_04.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.cobalt,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Action Buttons (Wrap so long English labels never overflow the dialog width)
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text(isAr ? 'إلغاء' : 'Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSubmitting
                          ? (isAr ? 'جاري الإصدار والإخطار...' : 'Issuing & Notifying...')
                          : (isAr ? 'إصدار طلب السداد وإخطار المالية' : 'Issue Payment Request & Notify Finance'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSubmitting ? null : _submitAdvancePayment,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
