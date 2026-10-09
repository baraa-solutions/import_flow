import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';
import '../repositories/logistics_invoices_repository.dart';

class InsurancePolicyDialog extends ConsumerStatefulWidget {
  final InsurancePolicyModel? initialPolicy;
  final int defaultShipmentId;

  const InsurancePolicyDialog({
    super.key,
    this.initialPolicy,
    this.defaultShipmentId = 1,
  });

  @override
  ConsumerState<InsurancePolicyDialog> createState() => _InsurancePolicyDialogState();
}

class _InsurancePolicyDialogState extends ConsumerState<InsurancePolicyDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shipmentIdCtrl;
  late TextEditingController _blNumberCtrl;
  late TextEditingController _companyIdCtrl;
  late TextEditingController _companyNameCtrl;
  late TextEditingController _policyNumberCtrl;
  late TextEditingController _insuredValueCtrl;
  late TextEditingController _premiumRateCtrl;
  late TextEditingController _beneficiaryCtrl;
  late TextEditingController _notesCtrl;

  String _coverageType = 'all_risks';
  String _currency = 'USD';
  double _exchangeRate = 48.5;
  bool _isLoading = false;
  bool _isGeneratingInvoice = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPolicy;

    _shipmentIdCtrl = TextEditingController(text: (p?.shipmentId ?? widget.defaultShipmentId).toString());
    _blNumberCtrl = TextEditingController(text: p?.blNumber ?? '');
    _companyIdCtrl = TextEditingController(text: (p?.insuranceCompanyId ?? 1).toString());
    _companyNameCtrl = TextEditingController(text: p?.insuranceCompanyName ?? 'Misr Insurance Co.');
    _policyNumberCtrl = TextEditingController(text: p?.policyNumber ?? 'POL-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}');
    _insuredValueCtrl = TextEditingController(text: (p?.insuredValueFx ?? 55000.0).toString());
    _premiumRateCtrl = TextEditingController(text: (p?.premiumRate ?? 0.35).toString());
    _beneficiaryCtrl = TextEditingController(text: p?.beneficiary ?? 'Sorour Logistics / Financing Bank');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');

    _coverageType = p?.coverageType ?? 'all_risks';
    _currency = p?.insuredValueCurrency ?? 'USD';
    _exchangeRate = p?.exchangeRate ?? 48.5;

    if (p == null) {
      _loadPreview();
    }
  }

  @override
  void dispose() {
    _shipmentIdCtrl.dispose();
    _blNumberCtrl.dispose();
    _companyIdCtrl.dispose();
    _companyNameCtrl.dispose();
    _policyNumberCtrl.dispose();
    _insuredValueCtrl.dispose();
    _premiumRateCtrl.dispose();
    _beneficiaryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      final shipmentId = int.tryParse(_shipmentIdCtrl.text) ?? 1;
      final rate = double.tryParse(_premiumRateCtrl.text) ?? 0.35;
      final preview = await repo.getInsurancePreview(shipmentId, premiumRate: rate, coverageType: _coverageType);

      setState(() {
        _insuredValueCtrl.text = preview.insuredValueFx.toStringAsFixed(2);
        _currency = preview.currency;
        _exchangeRate = preview.exchangeRate;
      });
    } catch (_) {}
  }

  double get _insuredValueFx => double.tryParse(_insuredValueCtrl.text) ?? 0.0;
  double get _premiumRate => double.tryParse(_premiumRateCtrl.text) ?? 0.0;
  double get _premiumAmountFx => _insuredValueFx * (_premiumRate / 100.0);
  double get _premiumAmountEgp => _premiumAmountFx * _exchangeRate;
  double get _stampDutyEgp => _premiumAmountEgp * 0.001; // 0.1%
  double get _supervisoryFeeEgp => _premiumAmountEgp * 0.12; // 12%
  double get _netPremiumEgp => _premiumAmountEgp + _stampDutyEgp + _supervisoryFeeEgp;

  Future<void> _savePolicy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      final payload = {
        'shipment_id': int.parse(_shipmentIdCtrl.text),
        'bl_number': _blNumberCtrl.text.trim().isEmpty ? null : _blNumberCtrl.text.trim(),
        'insurance_company_id': int.parse(_companyIdCtrl.text),
        'insurance_company_name': _companyNameCtrl.text.trim(),
        'policy_number': _policyNumberCtrl.text.trim(),
        'policy_date': DateTime.now().toIso8601String(),
        'coverage_type': _coverageType,
        'insured_value_fx': _insuredValueFx,
        'insured_value_currency': _currency,
        'premium_rate': _premiumRate,
        'premium_amount_fx': _premiumAmountFx,
        'exchange_rate': _exchangeRate,
        'premium_amount_egp': _premiumAmountEgp,
        'stamp_duty_egp': _stampDutyEgp,
        'supervisory_fee_egp': _supervisoryFeeEgp,
        'net_premium_egp': _netPremiumEgp,
        'beneficiary': _beneficiaryCtrl.text.trim().isEmpty ? null : _beneficiaryCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      await repo.createInsurancePolicy(payload);
      ref.invalidate(insurancePoliciesListProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marine insurance policy issued successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save policy: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInvoice() async {
    if (widget.initialPolicy == null) return;
    setState(() => _isGeneratingInvoice = true);
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      await repo.generateInvoiceFromPolicy(widget.initialPolicy!.policyId);
      ref.invalidate(insurancePoliciesListProvider);
      ref.invalidate(logisticsInvoicesListProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice generated from policy!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingInvoice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isEdit = widget.initialPolicy != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 720,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Marine Policy: ${widget.initialPolicy!.policyCode}' : 'Issue Marine Insurance Policy (بوليصة التأمين البحري)',
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _blNumberCtrl,
                      decoration: const InputDecoration(labelText: 'B/L Number', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _policyNumberCtrl,
                      decoration: const InputDecoration(labelText: 'Policy Number *', isDense: true, border: OutlineInputBorder()),
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
                      controller: _companyNameCtrl,
                      decoration: const InputDecoration(labelText: 'Insurance Company Name *', isDense: true, border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _coverageType,
                      decoration: const InputDecoration(labelText: 'Coverage Clause', isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'all_risks', child: Text('All Risks (شامل كافة الأخطار)')),
                        DropdownMenuItem(value: 'icc_a', child: Text('ICC (A) — Standard Marine')),
                        DropdownMenuItem(value: 'icc_b', child: Text('ICC (B) — Major Casualties')),
                        DropdownMenuItem(value: 'icc_c', child: Text('ICC (C) — Total Loss Only')),
                        DropdownMenuItem(value: 'war_srcc', child: Text('War & Strikes (أخطار حرب وإضرابات)')),
                      ],
                      onChanged: (v) => setState(() => _coverageType = v ?? 'all_risks'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Insured Value (CIF + 10%) & Premium Rate
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _insuredValueCtrl,
                      decoration: InputDecoration(
                        labelText: 'Insured Value (CIF + 10%) *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixText: _currency,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _premiumRateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Premium Rate %',
                        isDense: true,
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      initialValue: _exchangeRate.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Exchange Rate',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final r = double.tryParse(v);
                        if (r != null) setState(() => _exchangeRate = r);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Egyptian Insurance Law Calculation Strip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161E28) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _metricText('Base Premium (FX)', '${_premiumAmountFx.toStringAsFixed(2)} $_currency'),
                        _metricText('Base Premium (EGP)', '${_premiumAmountEgp.toStringAsFixed(2)} EGP'),
                        _metricText('Stamp Duty (0.1%)', '${_stampDutyEgp.toStringAsFixed(2)} EGP'),
                        _metricText('FRA Fee (12%)', '${_supervisoryFeeEgp.toStringAsFixed(2)} EGP'),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Net Payable Premium (إجمالي قسط التأمين والرسوم):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${_netPremiumEgp.toStringAsFixed(2)} EGP',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _beneficiaryCtrl,
                decoration: const InputDecoration(labelText: 'Beneficiary (المستفيد)', isDense: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEdit && !widget.initialPolicy!.invoiceGenerated) ...[
                    AppButton(
                      label: 'Generate Service Invoice',
                      variant: AppButtonVariant.warning,
                      icon: Icons.receipt_long,
                      isLoading: _isGeneratingInvoice,
                      onPressed: _generateInvoice,
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  AppButton(
                    label: isEdit ? 'Update Policy' : 'Issue Policy',
                    variant: AppButtonVariant.primary,
                    icon: Icons.check,
                    isLoading: _isLoading,
                    onPressed: _savePolicy,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
