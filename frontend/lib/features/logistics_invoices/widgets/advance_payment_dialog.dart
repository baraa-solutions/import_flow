import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/logistics_invoices_provider.dart';
import '../repositories/logistics_invoices_repository.dart';

class AdvancePaymentDialog extends ConsumerStatefulWidget {
  final int defaultShipmentId;
  final String? defaultBlNumber;

  const AdvancePaymentDialog({
    super.key,
    this.defaultShipmentId = 1,
    this.defaultBlNumber,
  });

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
    _blNumberCtrl = TextEditingController(text: widget.defaultBlNumber ?? '');
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
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            isArabic
                ? 'تم تسجيل دفعة العهدة الجمركية بنجاح!'
                : 'Clearance advance payment recorded successfully!',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'Error: $e',
            severity: AppSeverity.danger,
          ),
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
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
                    isArabic ? 'تسجيل دفعة / عهدة مخلص جمركي' : 'Record Clearance Advance Payment',
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
                      decoration: InputDecoration(
                        labelText: isArabic ? 'رقم الشحنة *' : 'Shipment ID *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _blNumberCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'رقم البوليصة' : 'B/L Number',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
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
                      decoration: InputDecoration(
                        labelText: isArabic ? 'معرف المخلص *' : 'Partner ID *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _partnerNameCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'اسم المخلص الجمركي *' : 'Broker / Partner Name *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
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
                      decoration: InputDecoration(
                        labelText: isArabic ? 'مبلغ العهدة *' : 'Advance Amount *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => v == null || v.isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: SearchableDropdownField<String>(
                      value: _currency,
                      labelText: isArabic ? 'العملة' : 'Currency',
                      decoration: InputDecoration(
                        labelText: isArabic ? 'العملة' : 'Currency',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        SearchableDropdownItem<String>(value: 'EGP', label: 'EGP'),
                        SearchableDropdownItem<String>(value: 'USD', label: 'USD'),
                        SearchableDropdownItem<String>(value: 'EUR', label: 'EUR'),
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
                    Text(
                      isArabic ? 'إجمالي العهدة (ج.م):' : 'Total Advance (EGP):',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_amountEgp.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'ملاحظات / الغرض من العهدة' : 'Notes / Custody Purpose',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
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
                    label: isArabic ? 'صرف العهدة' : 'Disburse Advance',
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
      ),
    );
  }
}
