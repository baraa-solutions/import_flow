import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class PaymentSupplierBankCard extends StatelessWidget {
  final TextEditingController bankNameController;
  final TextEditingController swiftCodeController;
  final TextEditingController ibanController;
  final bool isNarrow;

  const PaymentSupplierBankCard({
    super.key,
    required this.bankNameController,
    required this.swiftCodeController,
    required this.ibanController,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkElevatedSurface
            : AppTheme.cobaltLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.cobaltBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l.beneficiaryBankDetails}:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.cobalt,
            ),
          ),
          const SizedBox(height: 8),
          if (isNarrow)
            Column(
              children: [
                TextFormField(
                  controller: bankNameController,
                  decoration: InputDecoration(
                    labelText: l.bankNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: swiftCodeController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.swiftCodeLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: ibanController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.ibanAccountLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: bankNameController,
                    decoration: InputDecoration(
                      labelText: l.bankNameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: swiftCodeController,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: l.swiftCodeLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: ibanController,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: l.ibanAccountLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
