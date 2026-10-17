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

    for (final inv in _openInvoices) {
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
    if (!_formKey.currentState!.validate()) return;
    if (_voucherAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment amount must be greater than zero!'), backgroundColor: Colors.red),
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
          const SnackBar(content: Text('Payment voucher & knock-offs processed successfully!'), backgroundColor: Colors.green),
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
                    'Logistics Payment Voucher & Knock-off (سند دفع وإقفال فواتير)',
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
                      decoration: const InputDecoration(labelText: 'Partner ID *', isDense: true, border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _loadOpenInvoices(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _partnerNameCtrl,
                      decoration: const InputDecoration(labelText: 'Partner Name *', isDense: true, border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(labelText: 'Payment Amount *', isDense: true, border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        setState(() {
                          _autoAllocateFifo();
                        });
                      },
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: 'Currency', isDense: true, border: OutlineInputBorder()),
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
                      decoration: const InputDecoration(labelText: 'Payment Method', isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (تحويل بنكي)')),
                        DropdownMenuItem(value: 'CHEQUE', child: Text('Bank Cheque (شيك بنكي)')),
                        DropdownMenuItem(value: 'CASH', child: Text('Cash (نقداً)')),
                      ],
                      onChanged: (v) => setState(() => _paymentMethod = v ?? 'BANK_TRANSFER'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _bankRefCtrl,
                      decoration: const InputDecoration(labelText: 'Bank Reference / Cheque #', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      initialValue: _exchangeRate.toString(),
                      decoration: const InputDecoration(labelText: 'CBE Rate', isDense: true, border: OutlineInputBorder()),
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
                    Text('Voucher (EGP): ${_totalVoucherEgp.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Knocked Off: ${_totalAllocatedEgp.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald)),
                    Text('Unallocated: ${_unallocatedEgp.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _unallocatedEgp > 0 ? AppTheme.orange : Colors.grey)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.auto_fix_high, size: 14),
                      label: const Text('FIFO Auto-Knock'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _autoAllocateFifo()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Open Invoices Table
              const Text('Select Open Invoices to Knock Off (إقفال الفواتير المفتوحة):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Expanded(
                child: _isLoadingInvoices
                    ? const Center(child: CircularProgressIndicator())
                    : _openInvoices.isEmpty
                        ? Center(
                            child: Text(
                              'No open invoices found for this partner.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ListView.separated(
                              itemCount: _openInvoices.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final inv = _openInvoices[i];
                                final currentKnock = _knockoffAllocations[inv.invoiceId] ?? 0.0;
                                final isFullyKnocked = currentKnock >= inv.remainingAmountEgp;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isFullyKnocked ? Icons.check_circle : Icons.radio_button_unchecked,
                                        size: 16,
                                        color: isFullyKnocked ? AppTheme.emerald : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${inv.invoiceCode} — #${inv.invoiceNumber}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            Text(
                                              'B/L: ${inv.blNumber ?? "N/A"} | Date: ${inv.invoiceDate.toIso8601String().split("T").first}',
                                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Remaining: ${inv.remainingAmountEgp.toStringAsFixed(2)} EGP (${inv.totalAmountFx.toStringAsFixed(2)} ${inv.currency})',
                                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 140,
                                        child: TextFormField(
                                          key: ValueKey('knock_${inv.invoiceId}_$currentKnock'),
                                          initialValue: currentKnock.toStringAsFixed(2),
                                          decoration: const InputDecoration(
                                            labelText: 'Knock (EGP)',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (v) {
                                            final val = double.tryParse(v) ?? 0.0;
                                            setState(() {
                                              _knockoffAllocations[inv.invoiceId] = val;
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
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Process Payment Voucher',
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
