import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';
import '../repositories/logistics_invoices_repository.dart';

class LogisticsPaymentDialog extends ConsumerStatefulWidget {
  final int defaultPartnerId;
  final String defaultPartnerName;

  const LogisticsPaymentDialog({
    super.key,
    this.defaultPartnerId = 1,
    this.defaultPartnerName = 'Logistics Partner',
  });

  @override
  ConsumerState<LogisticsPaymentDialog> createState() => _LogisticsPaymentDialogState();
}

class _LogisticsPaymentDialogState extends ConsumerState<LogisticsPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _partnerIdCtrl;
  late TextEditingController _partnerNameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _bankRefCtrl;
  late TextEditingController _notesCtrl;

  String _currency = 'EGP';
  double _exchangeRate = 1.0;
  String _paymentMethod = 'BANK_TRANSFER';
  bool _isLoading = false;
  bool _isLoadingInvoices = false;

  List<LogisticsInvoiceModel> _openInvoices = [];
  final Map<int, double> _knockoffAllocations = {};

  @override
  void initState() {
    super.initState();
    _partnerIdCtrl = TextEditingController(text: widget.defaultPartnerId.toString());
    _partnerNameCtrl = TextEditingController(text: widget.defaultPartnerName);
    _amountCtrl = TextEditingController(text: '100000');
    _bankRefCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    _loadOpenInvoices();
  }

  @override
  void dispose() {
    _partnerIdCtrl.dispose();
    _partnerNameCtrl.dispose();
    _amountCtrl.dispose();
    _bankRefCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOpenInvoices() async {
    setState(() => _isLoadingInvoices = true);
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      final partnerId = int.tryParse(_partnerIdCtrl.text) ?? widget.defaultPartnerId;
      final invoices = await repo.getPartnerOpenInvoices(partnerId);

      setState(() {
        _openInvoices = invoices;
        _autoAllocateFifo();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingInvoices = false);
    }
  }

  void _autoAllocateFifo() {
    _knockoffAllocations.clear();
    double remainingToAllocate = _totalVoucherEgp;

    final openList = _openInvoices
        .where((inv) => inv.remainingAmountEgp > 0.01 && inv.paymentStatus != 'FULLY_PAID')
        .toList();
    for (final inv in openList) {
      if (remainingToAllocate <= 0) break;
      final canPay = inv.remainingAmountEgp;
      final allocated = remainingToAllocate >= canPay ? canPay : remainingToAllocate;
      _knockoffAllocations[inv.invoiceId] = allocated;
      remainingToAllocate -= allocated;
    }
  }

  double get _voucherAmount => double.tryParse(_amountCtrl.text) ?? 0.0;
  double get _totalVoucherEgp => _voucherAmount * _exchangeRate;
  double get _totalAllocatedEgp => _knockoffAllocations.values.fold(0.0, (acc, item) => acc + item);
  double get _unallocatedEgp => _totalVoucherEgp - _totalAllocatedEgp;

  Future<void> _submitVoucher() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (!_formKey.currentState!.validate()) return;
    if (_voucherAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يجب أن يكون مبلغ الدفعة أكبر من الصفر!' : 'Payment amount must be greater than zero!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      final knockoffs = _knockoffAllocations.entries
          .where((e) => e.value > 0)
          .map((e) => {
                'invoice_id': e.key,
                'knocked_amount_egp': e.value,
              })
          .toList();

      final payload = {
        'partner_id': int.parse(_partnerIdCtrl.text),
        'partner_name': _partnerNameCtrl.text.trim(),
        'payment_date': DateTime.now().toIso8601String(),
        'amount': _voucherAmount,
        'currency': _currency,
        'exchange_rate': _exchangeRate,
        'amount_egp': _totalVoucherEgp,
        'cbe_rate_date': DateTime.now().toIso8601String().split('T').first,
        'payment_method': _paymentMethod,
        'bank_reference': _bankRefCtrl.text.trim().isEmpty ? null : _bankRefCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'knockoffs': knockoffs,
      };

      await repo.createPaymentVoucher(payload);
      ref.invalidate(paymentVouchersListProvider);
      ref.invalidate(logisticsInvoicesListProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic
                ? 'تم تسجيل سند الدفع وإقفال الفواتير بنجاح!'
                : 'Payment voucher & knock-offs processed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final openUnpaidInvoices = _openInvoices
        .where((inv) => inv.remainingAmountEgp > 0.01 && inv.paymentStatus != 'FULLY_PAID')
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 820,
        height: 680,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    isArabic
                        ? 'سند دفع وإقفال فواتير الخدمات اللوجستية'
                        : 'Logistics Payment Voucher & Knock-off',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.charcoal,
                    ),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 20),
              // Partner and Voucher Amount Row
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _partnerIdCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'معرف الشريك *' : 'Partner ID *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _loadOpenInvoices(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _partnerNameCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'اسم الشريك *' : 'Partner Name *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'مبلغ الدفعة *' : 'Payment Amount *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        setState(() {
                          _autoAllocateFifo();
                        });
                      },
                      validator: (v) => v == null || v.isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'العملة' : 'Currency',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'EGP', child: Text('EGP')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                      ],
                      onChanged: (v) => setState(() => _currency = v ?? 'EGP'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Payment Method, Bank Ref, and Exchange Rate Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'طريقة الدفع' : 'Payment Method',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text(isArabic ? 'تحويل بنكي' : 'Bank Transfer')),
                        DropdownMenuItem(value: 'CHEQUE', child: Text(isArabic ? 'شيك بنكي' : 'Bank Cheque')),
                        DropdownMenuItem(value: 'CASH', child: Text(isArabic ? 'نقداً' : 'Cash')),
                      ],
                      onChanged: (v) => setState(() => _paymentMethod = v ?? 'BANK_TRANSFER'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _bankRefCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'رقم التحويل / الشيك البنكي' : 'Bank Reference / Cheque #',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      initialValue: _exchangeRate.toString(),
                      decoration: InputDecoration(
                        labelText: isArabic ? 'سعر صرف البنك المركزي' : 'CBE Rate',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final r = double.tryParse(v);
                        if (r != null) {
                          setState(() {
                            _exchangeRate = r;
                            _autoAllocateFifo();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Allocation Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161E28) : const Color(0xFFEDF2F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${isArabic ? "قيمة السند (ج.م):" : "Voucher (EGP):"} ${_totalVoucherEgp.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('${isArabic ? "المسدد (ج.م):" : "Knocked Off:"} ${_totalAllocatedEgp.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald)),
                    Text('${isArabic ? "غير الموزع (ج.م):" : "Unallocated:"} ${_unallocatedEgp.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _unallocatedEgp > 0 ? AppTheme.orange : Colors.grey)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.auto_fix_high, size: 14),
                      label: Text(isArabic ? 'توزيع تلقائي (FIFO)' : 'FIFO Auto-Knock'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _autoAllocateFifo()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Open Invoices Table
              Text(
                isArabic
                    ? 'قائمة الفواتير المفتوحة غير المسددة للإقفال:'
                    : 'Select Open Invoices to Knock Off:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _isLoadingInvoices
                    ? const Center(child: CircularProgressIndicator())
                    : openUnpaidInvoices.isEmpty
                        ? Center(
                            child: Text(
                              isArabic
                                  ? 'لا توجد فواتير مفتوحة غير مسددة لهذا الشريك.'
                                  : 'No open invoices found for this partner.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ListView.separated(
                              itemCount: openUnpaidInvoices.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final inv = openUnpaidInvoices[i];
                                final currentKnock = _knockoffAllocations[inv.invoiceId] ?? 0.0;
                                final isFullyKnocked = currentKnock >= inv.remainingAmountEgp;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isFullyKnocked
                                        ? (isDark ? AppTheme.emerald.withValues(alpha: 0.1) : Colors.green.shade50.withValues(alpha: 0.5))
                                        : Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isFullyKnocked ? Icons.check_circle : Icons.radio_button_unchecked,
                                        size: 18,
                                        color: isFullyKnocked ? AppTheme.emerald : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  '${isArabic ? "فاتورة" : "Inv"} #${inv.invoiceNumber}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    inv.invoiceCode,
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: (inv.paymentStatus == 'PARTIALLY_PAID' ? AppTheme.orange : Colors.grey).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    inv.paymentStatus == 'PARTIALLY_PAID'
                                                        ? (isArabic ? 'مسددة جزئياً' : 'Partially Paid')
                                                        : (isArabic ? 'غير مسددة' : 'Unpaid'),
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: inv.paymentStatus == 'PARTIALLY_PAID' ? AppTheme.orange : Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${isArabic ? "بوليصة" : "B/L"}: ${inv.blNumber ?? "—"} | ${isArabic ? "تاريخ" : "Date"}: ${inv.invoiceDate.toIso8601String().split("T").first}',
                                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${isArabic ? "إجمالي القيمة" : "Total"}: ${inv.totalAmountFx.toStringAsFixed(2)} ${inv.currency}',
                                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.cobalt),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${isArabic ? "المتبقي للسداد" : "Remaining"}: ${inv.remainingAmountEgp.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: isFullyKnocked ? AppTheme.emerald : Colors.red.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 140,
                                        child: TextFormField(
                                          key: ValueKey('knock_${inv.invoiceId}_$currentKnock'),
                                          initialValue: currentKnock > 0 ? currentKnock.toStringAsFixed(2) : '',
                                          decoration: InputDecoration(
                                            labelText: isArabic ? 'سداد (ج.م)' : 'Knock (EGP)',
                                            isDense: true,
                                            border: const OutlineInputBorder(),
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (v) {
                                            final val = double.tryParse(v) ?? 0.0;
                                            setState(() {
                                              _knockoffAllocations[inv.invoiceId] = val.clamp(0.0, inv.remainingAmountEgp);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: isArabic ? 'تنفيذ سند الدفع' : 'Process Payment Voucher',
                    variant: AppButtonVariant.primary,
                    icon: Icons.check,
                    isLoading: _isLoading,
                    onPressed: _submitVoucher,
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
