import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_tariff_model.dart';

class HsCodeTaxRatesTab extends StatelessWidget {
  final CustomsTariffModel tariff;

  const HsCodeTaxRatesTab({super.key, required this.tariff});

  Widget _taxCard(BuildContext context, String title, String rate, String subtitle, MaterialColor color) {
    final l = context.l10n;
    return InkWell(
      onTap: () => CopyHelper.copy(context, rate, customMessage: '$title: $rate'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.shade900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tooltip(
                  message: l.hsExplorerCopyCardRateTooltip,
                  child: Icon(Icons.copy_rounded, size: 12, color: color.shade700),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(rate, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color.shade800)),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: color.shade700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.hsTaxRatesSectionHeader,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _taxCard(context, l.hsTaxImportDutyTitle, '${tariff.customsDutyRate}%', l.hsTaxImportDutySub, Colors.blue),
              _taxCard(context, l.hsTaxVatTitle, '${tariff.vatRate}%', l.hsTaxVatSub, Colors.green),
              _taxCard(context, l.hsTaxScheduleTitle, '${tariff.scheduleTaxRate}%', l.hsTaxScheduleSub, Colors.purple),
              _taxCard(context, l.hsTaxDevFeeTitle, '${tariff.developmentFeeRate}%', l.hsTaxDevFeeSub, Colors.orange),
              _taxCard(context, l.hsTaxImportFeeTitle, '${tariff.importFeeRate}%', l.hsTaxImportFeeSub, Colors.deepOrange),
              _taxCard(context, l.hsTaxServiceFeeTitle, '${tariff.customsServiceFeeRate}%', l.hsTaxServiceFeeSub, Colors.teal),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.hsEgyptianCalculationRule,
                    style: const TextStyle(fontSize: 12, color: AppTheme.charcoal),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
