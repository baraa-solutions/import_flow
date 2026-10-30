import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/currency_model.dart';
import '../providers/currencies_provider.dart';

/// Modal dialog for updating or recording a new commercial/customs exchange rate.
class CurrencyRateUpdateDialog extends ConsumerStatefulWidget {
  final int? preSelectedCurrencyId;

  const CurrencyRateUpdateDialog({
    super.key,
    this.preSelectedCurrencyId,
  });

  /// Static helper to display the update dialog.
  static Future<void> show(
    BuildContext context, {
    int? preSelectedCurrencyId,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => CurrencyRateUpdateDialog(
        preSelectedCurrencyId: preSelectedCurrencyId,
      ),
    );
  }

  @override
  ConsumerState<CurrencyRateUpdateDialog> createState() =>
      _CurrencyRateUpdateDialogState();
}

class _CurrencyRateUpdateDialogState
    extends ConsumerState<CurrencyRateUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _commCtrl;
  late final TextEditingController _custCtrl;
  int? _selectedCurrencyId;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _commCtrl = TextEditingController();
    _custCtrl = TextEditingController();
    _selectedCurrencyId = widget.preSelectedCurrencyId;
  }

  @override
  void dispose() {
    _commCtrl.dispose();
    _custCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(List<CurrencyModel> nonBaseCurrencies) async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCurrencyId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final rateModel = ExchangeRateModel(
        currencyId: _selectedCurrencyId!,
        commercialRate: double.parse(_commCtrl.text.trim()),
        customsRate: double.parse(_custCtrl.text.trim()),
        effectiveDate: _selectedDate.toIso8601String().split('T').first,
      );

      bool ok = false;
      try {
        ok = await ref.read(currenciesProvider.notifier).addExchangeRate(rateModel);
      } on DioException catch (dioErr) {
        if (!mounted) return;
        final errCode = ApiErrorText.code(dioErr);
        if (errCode == ApiErrorCode.currencyRateExists) {
          final confirmReplace = await showDialog<bool>(
            context: context,
            builder: (c) => SelectionArea(
              child: AlertDialog(
                title: Text(l10n.warning),
                content: Text(ApiErrorText.of(l10n, dioErr)),
                actions: [
                  AppButton(
                    label: l10n.cancel,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(c, false),
                  ),
                  AppButton(
                    label: l10n.confirm,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(c, true),
                  ),
                ],
              ),
            ),
          );
          if (confirmReplace == true) {
            ok = await ref
                .read(currenciesProvider.notifier)
                .addExchangeRate(rateModel, replace: true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, ApiErrorText.of(l10n, dioErr),
                severity: AppSeverity.danger),
          );
        }
      }

      if (ok && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nonBaseCurrencies = ref
            .watch(currenciesProvider)
            .valueOrNull
            ?.where((c) => !c.isBaseCurrency)
            .toList() ??
        [];

    if (nonBaseCurrencies.isEmpty) {
      return AlertDialog(
        title: Text(l10n.updateExchangeRatesDialogTitle),
        content: Text(l10n.noCurrenciesFound),
        actions: [
          AppButton(
            label: l10n.cancel,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }

    _selectedCurrencyId ??= nonBaseCurrencies.first.currencyId;

    return SelectionArea(
      child: AlertDialog(
        title: Text(l10n.updateExchangeRatesDialogTitle),
      content: SelectionArea(
        child: SizedBox(
          width: 450,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchableDropdownField<int?>(
                  value: _selectedCurrencyId,
                  labelText: l10n.selectForeignCurrencyLabel,
                  searchHintText: l10n.searchCurrenciesHint,
                  items: nonBaseCurrencies
                      .map((c) => SearchableDropdownItem<int?>(
                            value: c.currencyId,
                            label:
                                '${c.currencyCode} — ${c.currencyName} (${c.currencySymbol})',
                            searchValue: '${c.currencyCode} ${c.currencyName}',
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedCurrencyId = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.commercialRateInputLabel,
                    hintText: l10n.rateInputHint,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.currencyCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _commCtrl.text),
                    ),
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return l10n.enterValidRateError;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _custCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.customsRateInputLabel,
                    hintText: l10n.rateInputHint,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.currencyCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _custCtrl.text),
                    ),
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return l10n.enterValidRateError;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppDatePickerField(
                  value: _selectedDate,
                  label: l10n.effectiveDateLabel(
                      _selectedDate.toIso8601String().split('T').first),
                  onChanged: (picked) {
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l10n.cancel,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
        AppButton(
          label: l10n.saveRateSubmitBtn,
          variant: AppButtonVariant.success,
          size: AppButtonSize.small,
          isLoading: _isSubmitting,
          onPressed: () => _handleSubmit(nonBaseCurrencies),
        ),
      ],
    ),
    );
  }
}
