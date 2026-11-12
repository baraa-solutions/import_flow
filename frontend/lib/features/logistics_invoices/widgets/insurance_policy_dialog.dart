import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';
import '../repositories/logistics_invoices_repository.dart';
import 'document_party_selectors.dart';

class InsurancePolicyDialog extends ConsumerStatefulWidget {
  final InsurancePolicyModel? initialPolicy;
  /// Import file context of the caller; null opens the dialog with no file selected.
  final int? defaultShipmentId;
  final String? defaultBlNumber;

  const InsurancePolicyDialog({
    super.key,
    this.initialPolicy,
    this.defaultShipmentId,
    this.defaultBlNumber,
  });

  @override
  ConsumerState<InsurancePolicyDialog> createState() => _InsurancePolicyDialogState();
}

class _InsurancePolicyDialogState extends ConsumerState<InsurancePolicyDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _shipmentId;
  int? _companyId;
  String _companyName = '';
  late TextEditingController _blNumberCtrl;
  late TextEditingController _policyNumberCtrl;
  late TextEditingController _insuredValueCtrl;
  late TextEditingController _premiumRateCtrl;
  late TextEditingController _beneficiaryCtrl;
  late TextEditingController _notesCtrl;

  String _coverageType = 'all_risks';
  String _currency = 'USD';
  // Filled from the policy or from the backend preview of the selected file (never a hard-coded rate).
  double _exchangeRate = 0.0;
  bool _isLoading = false;
  bool _isGeneratingInvoice = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPolicy;

    // A new policy starts blank: no default file, insurer, policy number, insured value or beneficiary.
    _shipmentId = p?.shipmentId ?? widget.defaultShipmentId;
    _blNumberCtrl = TextEditingController(text: p?.blNumber ?? widget.defaultBlNumber ?? '');
    _companyId = p?.insuranceCompanyId;
    _companyName = p?.insuranceCompanyName ?? '';
    _policyNumberCtrl = TextEditingController(text: p?.policyNumber ?? '');
    _insuredValueCtrl = TextEditingController(text: p?.insuredValueFx.toString() ?? '');
    _premiumRateCtrl = TextEditingController(text: (p?.premiumRate ?? 0.35).toString());
    _beneficiaryCtrl = TextEditingController(text: p?.beneficiary ?? '');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');

    _coverageType = p?.coverageType ?? 'all_risks';
    _currency = p?.insuredValueCurrency ?? 'USD';
    _exchangeRate = p?.exchangeRate ?? 0.0;

    if (p == null) {
      _loadPreview();
    }
  }

  @override
  void dispose() {
    _blNumberCtrl.dispose();
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
      final shipmentId = _shipmentId;
      if (shipmentId == null) return;
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
    if (_exchangeRate <= 0) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic
              ? 'لا يوجد سعر صرف لعملة القيمة التأمينية. اختر ملف الشحنة أو سجّل سعر الصرف أولاً.'
              : 'No exchange rate for the insured value currency. Select the import file or record the rate first.',
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      final payload = {
        'shipment_id': _shipmentId,
        'bl_number': _blNumberCtrl.text.trim().isEmpty ? null : _blNumberCtrl.text.trim(),
        'insurance_company_id': _companyId,
        'insurance_company_name': _companyName,
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
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            isArabic
                ? 'تم إصدار وثيقة التأمين البحري بنجاح!'
                : 'Marine insurance policy issued successfully!',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'Failed to save policy: $e',
            severity: AppSeverity.danger,
          ),
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
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            isArabic
                ? 'تم توليد الفاتورة من الوثيقة بنجاح!'
                : 'Invoice generated from policy!',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'Failed: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingInvoice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isEdit = widget.initialPolicy != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
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
                    isEdit
                        ? (isArabic ? 'وثيقة التأمين البحري: ${widget.initialPolicy!.policyCode}' : 'Marine Policy: ${widget.initialPolicy!.policyCode}')
                        : (isArabic ? 'إصدار وثيقة تأمين بحري جديدة' : 'Issue Marine Insurance Policy'),
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
                    child: ImportFileSelectField(
                      key: const ValueKey('policyImportFileField'),
                      value: _shipmentId,
                      isArabic: Localizations.localeOf(context).languageCode == 'ar',
                      onChanged: widget.initialPolicy != null
                          ? null
                          : (id) {
                              setState(() => _shipmentId = id);
                              _loadPreview();
                            },
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
                    child: PartnerSelectField(
                      key: const ValueKey('policyInsurerField'),
                      value: _companyId,
                      label: 'Insurance Company',
                      isArabic: Localizations.localeOf(context).languageCode == 'ar',
                      typeKeywords: const ['insurance', 'تأمين'],
                      onChanged: (p) => setState(() {
                        _companyId = p?.providerId;
                        _companyName = p?.partnerName ?? '';
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<String>(
                      value: _coverageType,
                      labelText: 'Coverage Clause',
                      decoration: const InputDecoration(labelText: 'Coverage Clause', isDense: true, border: OutlineInputBorder()),
                      items: const [
                        SearchableDropdownItem<String>(value: 'all_risks', label: 'All Risks (شامل كافة الأخطار)'),
                        SearchableDropdownItem<String>(value: 'icc_a', label: 'ICC (A) — Standard Marine'),
                        SearchableDropdownItem<String>(value: 'icc_b', label: 'ICC (B) — Major Casualties'),
                        SearchableDropdownItem<String>(value: 'icc_c', label: 'ICC (C) — Total Loss Only'),
                        SearchableDropdownItem<String>(value: 'war_srcc', label: 'War & Strikes (أخطار حرب وإضرابات)'),
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _metricText(isArabic ? 'قسط الأساس (أجنبي)' : 'Base Premium (FX)', '${_premiumAmountFx.toStringAsFixed(2)} $_currency'),
                        _metricText(isArabic ? 'قسط الأساس (ج.م)' : 'Base Premium (EGP)', '${_premiumAmountEgp.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}'),
                        _metricText(isArabic ? 'دمغة نسبية (0.1%)' : 'Stamp Duty (0.1%)', '${_stampDutyEgp.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}'),
                        _metricText(isArabic ? 'رسوم الرقابة (12%)' : 'FRA Fee (12%)', '${_supervisoryFeeEgp.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}'),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic ? 'إجمالي قسط التأمين والرسوم المستحقة:' : 'Net Payable Premium:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${_netPremiumEgp.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}',
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
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم المستفيد' : 'Beneficiary',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEdit && !widget.initialPolicy!.invoiceGenerated) ...[
                    AppButton(
                      label: isArabic ? 'توليد فاتورة خدمة' : 'Generate Service Invoice',
                      variant: AppButtonVariant.warning,
                      icon: Icons.receipt_long,
                      isLoading: _isGeneratingInvoice,
                      onPressed: _generateInvoice,
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: isEdit
                        ? (isArabic ? 'تحديث الوثيقة' : 'Update Policy')
                        : (isArabic ? 'إصدار الوثيقة' : 'Issue Policy'),
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
