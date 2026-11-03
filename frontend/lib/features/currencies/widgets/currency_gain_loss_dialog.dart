import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../providers/currencies_provider.dart';

class CurrencyGainLossDialog {
  static void show(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(text: '50000');
    final initialRateCtrl = TextEditingController(text: '49.00');
    final settlementRateCtrl = TextEditingController(text: '47.50');
    String currencyCode = 'USD';
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
                const Icon(Icons.trending_up, color: AppTheme.orange),
                const SizedBox(width: 8),
                Text(
                  l10n.fxGainLossDialogTitle,
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
                        l10n.fxGainLossDialogSubtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l10n.foreignAmountLabel,
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: currencyCode,
                              labelText: l10n.currencyLabel,
                              searchHintText: l10n.searchCurrenciesHint,
                              items: const [
                                SearchableDropdownItem(value: 'USD', label: 'USD'),
                                SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                                SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                              ],
                              onChanged: (v) {
                                if (v != null) setSheetState(() => currencyCode = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: initialRateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l10n.initialRateLabel,
                                hintText: l10n.initialRateHint,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.currencyCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, initialRateCtrl.text),
                                ),
                              ),
                              validator: (v) {
                                final val = double.tryParse(v ?? '');
                                if (val == null || val <= 0) return l10n.enterValidRateError;
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: settlementRateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l10n.settlementRateLabel,
                                hintText: l10n.settlementRateHint,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.currencyCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, settlementRateCtrl.text),
                                ),
                              ),
                              validator: (v) {
                                final val = double.tryParse(v ?? '');
                                if (val == null || val <= 0) return l10n.enterValidRateError;
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: l10n.calculateGainLossBtn,
                          variant: AppButtonVariant.warning,
                          size: AppButtonSize.medium,
                          icon: Icons.analytics,
                          isLoading: isLoading,
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              setSheetState(() => isLoading = true);
                              final res = await ref.read(currenciesProvider.notifier).calculateGainLoss(
                                    foreignAmount: double.parse(amountCtrl.text.trim()),
                                    currencyCode: currencyCode,
                                    initialRate: double.parse(initialRateCtrl.text.trim()),
                                    settlementRate: double.parse(settlementRateCtrl.text.trim()),
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
                            color: (resultData!['is_gain'] as bool)
                                ? AppTheme.emerald.withValues(alpha: 0.08)
                                : AppTheme.crimson.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (resultData!['is_gain'] as bool)
                                  ? AppTheme.emerald.withValues(alpha: 0.4)
                                  : AppTheme.crimson.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  AppStatusBadge(
                                    label: resultData!['status_label'] ?? '',
                                    severity: (resultData!['is_gain'] as bool)
                                        ? AppSeverity.success
                                        : AppSeverity.danger,
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${resultData!['variance_egp']} EGP (${resultData!['percentage_change']}%)',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: (resultData!['is_gain'] as bool)
                                              ? AppTheme.emerald
                                              : AppTheme.crimson,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: Icon(
                                          Icons.copy_rounded,
                                          size: 17,
                                          color: (resultData!['is_gain'] as bool)
                                              ? AppTheme.emerald
                                              : AppTheme.crimson,
                                        ),
                                        tooltip: l10n.copyValue,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => CopyHelper.copy(
                                          context,
                                          '${resultData!['variance_egp']} EGP (${resultData!['percentage_change']}%)',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              Text(l10n.initialCostAtBooking(
                                  resultData!['initial_amount_egp'], resultData!['initial_rate'])),
                              const SizedBox(height: 4),
                              Text(l10n.actualCostAtSettlement(
                                  resultData!['settlement_amount_egp'], resultData!['settlement_rate'])),
                              if (resultData!['summary_ar'] != null &&
                                  Localizations.localeOf(context).languageCode == 'ar') ...[
                                const SizedBox(height: 8),
                                Text(
                                  resultData!['summary_ar'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
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
      initialRateCtrl.dispose();
      settlementRateCtrl.dispose();
    });
  }
}
