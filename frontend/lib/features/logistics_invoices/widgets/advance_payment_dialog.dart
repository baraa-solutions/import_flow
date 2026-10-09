import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../providers/logistics_invoices_provider.dart';
import '../repositories/logistics_invoices_repository.dart';

class AdvancePaymentDialog extends ConsumerStatefulWidget {
  final int defaultShipmentId;

  const AdvancePaymentDialog({super.key, this.defaultShipmentId = 1});

  @override
  ConsumerState<AdvancePaymentDialog> createState() => _AdvancePaymentDialogState();
}

class _AdvancePaymentDialogState extends ConsumerState<AdvancePaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shipmentIdCtrl;
  late TextEditingController _blNumberCtrl;
  late TextEditingController _partnerIdCtrl;
  late TextEditingController _partnerNameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;

  String _currency = 'EGP';
  final double _exchangeRate = 1.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _shipmentIdCtrl = TextEditingController(text: widget.defaultShipmentId.toString());
    _blNumberCtrl = TextEditingController();
    _partnerIdCtrl = TextEditingController(text: '1');
    _partnerNameCtrl = TextEditingController(text: 'Customs Clearance Partner');
    _amountCtrl = TextEditingController(text: '50000');
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _shipmentIdCtrl.dispose();
    _blNumberCtrl.dispose();
    _partnerIdCtrl.dispose();
    _partnerNameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountCtrl.text) ?? 0.0;
  double get _amountEgp => _amount * _exchangeRate;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      final payload = {
        'shipment_id': int.parse(_shipmentIdCtrl.text),
        'bl_number': _blNumberCtrl.text.trim().isEmpty ? null : _blNumberCtrl.text.trim(),
        'clearance_partner_id': int.parse(_partnerIdCtrl.text),
        'clearance_partner_name': _partnerNameCtrl.text.trim(),
        'amount': _amount,
        'currency': _currency,
        'exchange_rate': _exchangeRate,
        'amount_egp': _amountEgp,
        'payment_date': DateTime.now().toIso8601String(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      await repo.createClearanceAdvance(payload);
      ref.invalidate(clearanceAdvancesListProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clearance advance payment recorded successfully!'), backgroundColor: Colors.green),
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
        width: 580,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_outlined, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Record Clearance Advance Payment (عهدة المخلص)',
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _shipmentIdCtrl,
                      decoration: const InputDecoration(labelText: 'Shipment ID *', isDense: true, border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _blNumberCtrl,
                      decoration: const InputDecoration(labelText: 'B/L Number', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _partnerIdCtrl,
                      decoration: const InputDecoration(labelText: 'Partner ID *', isDense: true, border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _partnerNameCtrl,
                      decoration: const InputDecoration(labelText: 'Broker / Partner Name *', isDense: true, border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(labelText: 'Advance Amount *', isDense: true, border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161E28) : const Color(0xFFEDF2F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Advance (EGP):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(
                      '${_amountEgp.toStringAsFixed(2)} EGP',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes / Custody Purpose', isDense: true, border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Disburse Advance',
                    variant: AppButtonVariant.primary,
                    icon: Icons.check,
                    isLoading: _isLoading,
                    onPressed: _submit,
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
