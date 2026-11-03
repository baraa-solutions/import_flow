import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Actions footer for the price list dialog.
/// Displays financial totals, multi-currency conversion estimates, cancel and save buttons.
class PriceListFormActions extends StatelessWidget {
  final List<Map<String, dynamic>> itemsState;
  final double? usdRefRate;
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const PriceListFormActions({
    super.key,
    required this.itemsState,
    required this.usdRefRate,
    required this.isSaving,
    required this.isEditing,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final egpTotal = itemsState
        .where((i) => (i['currency']?.toString() ?? 'EGP') == 'EGP')
        .fold(0.0, (sum, i) => sum + ((i['standard_price'] as num?)?.toDouble() ?? 0.0));
    final usdTotal = itemsState
        .where((i) => (i['currency']?.toString() ?? 'EGP') == 'USD')
        .fold(0.0, (sum, i) => sum + ((i['standard_price'] as num?)?.toDouble() ?? 0.0));
    final totalPriced = itemsState.where((i) {
      final pType = i['price_type']?.toString() ?? '';
      final stdP = (i['standard_price'] as num?)?.toDouble() ?? 0.0;
      final minP = (i['min_price'] as num?)?.toDouble();
      return pType == 'negotiable' || stdP > 0 || (minP != null && minP > 0);
    }).length;

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.cloudWhite)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '${l.totalExpensesCountSummary(itemsState.length, totalPriced)}  |  ${egpTotal.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
              if (usdTotal > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '|  \$${usdTotal.toStringAsFixed(0)} USD',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                ),
                if (usdRefRate != null && usdRefRate! > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    isAr
                        ? '(إجمالي تقديري: ${(egpTotal + (usdTotal * usdRefRate!)).toStringAsFixed(0)} ج.م)'
                        : '(Est. Total: ${(egpTotal + (usdTotal * usdRefRate!)).toStringAsFixed(0)} EGP)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  ),
                ],
              ],
            ],
          ),
          Row(
            children: [
              AppButton(
                label: l.cancel,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: onCancel,
              ),
              const SizedBox(width: 8),
              AppButton(
                label: isSaving
                    ? l.saving
                    : (isEditing ? l.savePriceListEditsBtn : l.createAndSavePriceListBtn),
                icon: Icons.save,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                isLoading: isSaving,
                onPressed: isSaving ? null : onSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
