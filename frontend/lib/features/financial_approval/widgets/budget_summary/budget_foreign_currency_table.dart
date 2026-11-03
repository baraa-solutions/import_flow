import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class BudgetForeignCurrencyTable extends StatelessWidget {
  final double invForeign;
  final String invCurr;
  final double invEgpVal;
  final double frtForeign;
  final String frtCurr;
  final double frtEgpVal;

  const BudgetForeignCurrencyTable({
    super.key,
    required this.invForeign,
    required this.invCurr,
    required this.invEgpVal,
    required this.frtForeign,
    required this.frtCurr,
    required this.frtEgpVal,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. ${l.estimatedInvoiceValue} & ${l.estimatedFreightCost}:',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.cobalt,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 550;
            final table = Table(
              border: TableBorder.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
              ),
              columnWidths: isNarrow
                  ? const {
                      0: FixedColumnWidth(160),
                      1: FixedColumnWidth(120),
                      2: FixedColumnWidth(90),
                      3: FixedColumnWidth(120),
                    }
                  : const {
                      0: FlexColumnWidth(2.0),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.2),
                      3: FlexColumnWidth(1.5),
                    },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppTheme.cobalt),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.categoryCol,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.amountInCurrencyCol,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.currencyCol,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.equivalentEgpCol,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.estimatedInvoiceValue,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        invForeign.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        invCurr,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        '${invEgpVal.toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emerald,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.estimatedFreightCost,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        frtForeign.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        frtCurr,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        '${frtEgpVal.toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emerald,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkElevatedSurface
                        : AppTheme.charcoalSurface,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.totalExpenses,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        invCurr.toUpperCase() == frtCurr.toUpperCase()
                            ? (invForeign + frtForeign).toStringAsFixed(2)
                            : '${invForeign.toStringAsFixed(2)} ($invCurr)\n+ ${frtForeign.toStringAsFixed(2)} ($frtCurr)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        invCurr.toUpperCase() == frtCurr.toUpperCase() ? invCurr : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        '${(invEgpVal + frtEgpVal).toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emerald,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );

            return isNarrow
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 490),
                      child: table,
                    ),
                  )
                : table;
          },
        ),
      ],
    );
  }
}
