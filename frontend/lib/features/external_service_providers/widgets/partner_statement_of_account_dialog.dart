import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/partner_model.dart';
import '../providers/partners_provider.dart';
import 'soa/partner_soa_balance_cards.dart';
import 'soa/partner_soa_dialog_header.dart';
import 'soa/partner_soa_ledger_table.dart';

class PartnerStatementOfAccountDialog extends ConsumerWidget {
  final PartnerModel partner;

  const PartnerStatementOfAccountDialog({super.key, required this.partner});

  static void show(BuildContext context, PartnerModel partner) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PartnerStatementOfAccountDialog(partner: partner),
    );
  }

  static String formatNumber(double val) {
    final parts = val.toStringAsFixed(2).split('.');
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final intPart = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soaAsync = ref.watch(partnerStatementOfAccountProvider(partner.providerId ?? 0));

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.92).clamp(950.0, 1400.0);
    final dialogHeight = (screenSize.height * 0.90).clamp(620.0, 950.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SelectionArea(
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.transparent),
          ),
          child: Column(
            children: [
              // Header & Action Bar
              PartnerSoaDialogHeader(partner: partner, soaAsync: soaAsync),

              // Content Body
              Expanded(
                child: soaAsync.when(
                  loading: () => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.cobalt),
                        const SizedBox(height: 16),
                        Text(
                          l10n.calculatingSoaMsg,
                          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                      ],
                    ),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.crimson, size: 48),
                          const SizedBox(height: 12),
                          Text(l10n.soaFetchError(err.toString()), style: const TextStyle(color: AppTheme.crimson)),
                        ],
                      ),
                    ),
                  ),
                  data: (soa) {
                    if (soa == null) {
                      return Center(child: Text(l10n.noSoaDataAvailable));
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Currency Balance Cards & Equivalent Banner
                          PartnerSoaBalanceCards(
                            soa: soa,
                            isDark: isDark,
                            formatNumber: formatNumber,
                          ),
                          const SizedBox(height: 10),

                          // Ledger Table Breakdown
                          Expanded(
                            child: PartnerSoaLedgerTable(
                              soa: soa,
                              isDark: isDark,
                              formatNumber: formatNumber,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
