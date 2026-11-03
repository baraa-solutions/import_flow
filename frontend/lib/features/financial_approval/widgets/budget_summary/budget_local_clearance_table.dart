import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class BudgetLocalClearanceTable extends StatelessWidget {
  final double custEgp;
  final double clrEgp;
  final String? activeBrokerName;
  final bool hasBroker;

  const BudgetLocalClearanceTable({
    super.key,
    required this.custEgp,
    required this.clrEgp,
    required this.activeBrokerName,
    required this.hasBroker,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. ${l.clearanceAndTransportEstimate}:',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.orange,
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
                      0: FixedColumnWidth(180),
                      1: FixedColumnWidth(150),
                      2: FixedColumnWidth(140),
                    }
                  : const {
                      0: FlexColumnWidth(2.0),
                      1: FlexColumnWidth(1.8),
                      2: FlexColumnWidth(1.5),
                    },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppTheme.orange),
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
                        l.responsiblePartyLabel,
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
                        l.customsAndVatEstimate,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        l.customsAuthority,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        '${custEgp.toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.wcagCobalt,
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
                        l.clearanceAndTransportEstimate,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        hasBroker
                            ? '${l.customsBrokerLabel} $activeBrokerName'
                            : l.customsBrokerLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: hasBroker ? FontWeight.bold : FontWeight.normal,
                          color: isDark
                              ? (hasBroker ? AppTheme.orange : AppTheme.darkTextSecondary)
                              : (hasBroker ? AppTheme.charcoal : null),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        '${clrEgp.toStringAsFixed(2)} EGP',
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
                    color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoalSurface,
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
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CopyableText(
                        '${(custEgp + clrEgp).toStringAsFixed(2)} EGP',
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
                      constraints: const BoxConstraints(minWidth: 470),
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
