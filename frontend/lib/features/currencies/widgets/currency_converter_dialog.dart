import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../providers/currencies_provider.dart';

class CurrencyConverterDialog {
  static void show(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(text: '10000');
    String fromCurr = 'USD';
    String toCurr = 'EGP';
    String rateType = 'commercial';
    Map<String, dynamic>? resultData;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setSheetState) => SelectionArea(
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.currency_exchange, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Text(
                  l10n.liveCurrencyConverterDialogTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.liveCurrencyConverterDialogSubtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: l10n.amountToConvertLabel,
                          hintText: l10n.amountToConvertHint,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.currencyCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, amountCtrl.text),
                          ),
                        ),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val <= 0) return l10n.enterValidAmountError;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: fromCurr,
                              labelText: l10n.fromCurrencyLabel,
                              searchHintText: l10n.searchCurrenciesHint,
                              items: const [
                                SearchableDropdownItem(value: 'USD', label: 'USD'),
                                SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                                SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                                SearchableDropdownItem(value: 'SAR', label: 'SAR'),
                                SearchableDropdownItem(value: 'AED', label: 'AED'),
                                SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                              ],
                              onChanged: (v) {
                                if (v != null) setSheetState(() => fromCurr = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: toCurr,
                              labelText: l10n.toCurrencyLabel,
                              searchHintText: l10n.searchCurrenciesHint,
                              items: const [
                                SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                                SearchableDropdownItem(value: 'USD', label: 'USD'),
                                SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                                SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                              ],
                              onChanged: (v) {
                                if (v != null) setSheetState(() => toCurr = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdownField<String>(
                        value: rateType,
                        labelText: l10n.appliedRateTypeLabel,
                        items: [
                          SearchableDropdownItem(value: 'commercial', label: l10n.rateTypeCommercialOption),
                          SearchableDropdownItem(value: 'customs', label: l10n.rateTypeCustomsOption),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => rateType = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: l10n.convertCurrencyNowBtn,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.medium,
                          icon: Icons.calculate,
                          isLoading: isLoading,
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              setSheetState(() => isLoading = true);
                              final res = await ref.read(currenciesProvider.notifier).convertCurrency(
                                    amount: double.parse(amountCtrl.text.trim()),
                                    fromCurrency: fromCurr,
                                    toCurrency: toCurr,
                                    rateType: rateType,
                                  );
                              setSheetState(() {
                                resultData = res;
                                isLoading = false;
                              });
                            }
                          },
                        ),
                      ),
                      if (resultData != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.convertedAmountLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${resultData!['converted_amount']} ${resultData!['to_currency_code']}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.cobalt,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 17, color: AppTheme.cobalt),
                                        tooltip: l10n.copyValue,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => CopyHelper.copy(
                                          context,
                                          '${resultData!['converted_amount']} ${resultData!['to_currency_code']}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              Text(
                                l10n.appliedRatePrefix(resultData!['applied_rate']),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.baseEgpEquivalentPrefix(resultData!['base_currency_equivalent_egp']),
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (resultData!['summary_ar'] != null &&
                                  Localizations.localeOf(context).languageCode == 'ar') ...[
                                const SizedBox(height: 6),
                                Text(
                                  resultData!['summary_ar'] ?? '',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(l10n.closeBtn),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      amountCtrl.dispose();
    });
  }
}
