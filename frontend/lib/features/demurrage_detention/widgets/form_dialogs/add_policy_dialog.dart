import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../providers/demurrage_provider.dart';
import 'demurrage_lookups.dart';

/// Add a carrier tariff policy.
class AddPolicyDialog extends ConsumerStatefulWidget {
  const AddPolicyDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const AddPolicyDialog());

  @override
  ConsumerState<AddPolicyDialog> createState() => _AddPolicyDialogState();
}

class _AddPolicyDialogState extends ConsumerState<AddPolicyDialog> {
  final _formKey = GlobalKey<FormState>();
  String _carrier = DemurrageLookups.carriers.first;
  String _cType = DemurrageLookups.containerTypes.first;
  String _currency = 'USD';
  int _demFree = 14;
  int _detFree = 7;
  int _storFree = 5;
  double? _storRate; // required: no hard-coded storage rate
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(currenciesProvider).isLoading) {
        ref.read(currenciesProvider.notifier).fetchCurrencies();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    final ok = await ref.read(demurrageProvider.notifier).createPolicy({
      'carrier_name': _carrier,
      'container_type': _cType,
      'currency': _currency,
      'demurrage_free_days': _demFree,
      'detention_free_days': _detFree,
      'port_storage_free_days': _storFree,
      'port_storage_daily_rate_egp': _storRate,
    });
    final error = ref.read(demurrageProvider).errorObject;
    if (!mounted) return;
    final snack = AppTheme.snackBar(
      context,
      ok ? l.policyCreatedSuccessSnack : ApiErrorText.of(l, error, fallback: l.genericErrorSnack),
      severity: ok ? AppSeverity.success : AppSeverity.danger,
    );
    navigator.pop();
    messenger.showSnackBar(snack);
  }

  Widget _daysField(String label, int initial, ValueChanged<int> onSaved, int fallback, AppLocalizations l) {
    return CcField(
      label: label,
      child: TextFormField(
        initialValue: initial.toString(),
        decoration: ccInputDecoration(suffixText: l.whatIfDaysUnit),
        keyboardType: TextInputType.number,
        onSaved: (v) => onSaved(int.tryParse(v ?? '') ?? fallback),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    return SelectionArea(
      child: Form(
        key: _formKey,
        child: CcStageDialogShell(
          title: l.addPolicyDialogTitle,
          icon: Icons.policy_outlined,
          maxWidth: 640,
          confirmLabel: l.savePolicyBtn,
          confirmVariant: AppButtonVariant.primary,
          confirmIcon: Icons.save_outlined,
          isSubmitting: _isSaving,
          onConfirm: _submit,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CcFormSection(
                title: l.addPolicyDialogTitle,
                icon: Icons.rule_folder_outlined,
                child: Column(
                  children: [
                    CcFieldRow(
                      children: [
                        SearchableDropdownField<String>(
                          labelText: l.shippingLineFieldLabel,
                          value: _carrier,
                          items: DemurrageLookups.carriers
                              .map((c) => SearchableDropdownItem(value: c, label: c))
                              .toList(),
                          onChanged: (c) => setState(() => _carrier = c ?? _carrier),
                        ),
                        SearchableDropdownField<String>(
                          labelText: l.containerTypeFieldLabel,
                          value: _cType,
                          items: DemurrageLookups.containerTypes
                              .map((t) => SearchableDropdownItem(value: t, label: t))
                              .toList(),
                          onChanged: (t) => setState(() => _cType = t ?? _cType),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CcFieldRow(
                      children: [
                        SearchableDropdownField<String>(
                          labelText: l.currencyFieldLabel,
                          value: currencies.any((c) => c.currencyCode == _currency)
                              ? _currency
                              : (_currency.isNotEmpty ? _currency : 'USD'),
                          items: (currencies.isNotEmpty
                                  ? currencies.map((c) => c.currencyCode).toList()
                                  : ['USD', 'EUR', 'EGP', 'CNY', 'GBP', 'SAR', 'AED'])
                              .map((code) => SearchableDropdownItem<String>(value: code, label: code))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _currency = v);
                          },
                        ),
                        _daysField(l.demurrageFreeDaysFieldLabel, _demFree, (v) => _demFree = v, 14, l),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CcFieldRow(
                      children: [
                        _daysField(l.detentionFreeDaysFieldLabel, _detFree, (v) => _detFree = v, 7, l),
                        _daysField(l.portStorageFreeDaysFieldLabel, _storFree, (v) => _storFree = v, 5, l),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CcFieldRow(
                      children: [
                        CcField(
                          label: l.dailyStorageRateEgpFieldLabel,
                          isRequired: true,
                          child: TextFormField(
                            decoration: ccInputDecoration(suffixText: l.egpCurrency),
                            keyboardType: TextInputType.number,
                            validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? l.requiredFieldValidation : null,
                            onSaved: (v) => _storRate = double.tryParse(v ?? ''),
                          ),
                        ),
                        const SizedBox(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
