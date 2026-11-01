import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';

class FreightMonitorPortTariffsTab extends StatelessWidget {
  final List<dynamic> portTariffs;
  final bool isLoadingTariffs;
  final VoidCallback onFetchPortTariffs;

  const FreightMonitorPortTariffsTab({
    super.key,
    required this.portTariffs,
    required this.isLoadingTariffs,
    required this.onFetchPortTariffs,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (isLoadingTariffs) {
      return const CcStateView.loading();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${l10n.freightDataTabPortTariffs} (${portTariffs.length})",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            AppButton(
              onPressed: onFetchPortTariffs,
              icon: Icons.refresh_rounded,
              label: l10n.freightDataRefreshStatus,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
            ),
          ],
        ),
        const SizedBox(height: 10),

        Expanded(
          child: portTariffs.isEmpty
              ? CcStateView.empty(
                  message: l10n.freightDataNoDecreesFound,
                  icon: Icons.gavel_rounded,
                )
              : ListView.separated(
                  itemCount: portTariffs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final t = portTariffs[idx];
                    final effFrom = t['effective_from'] ?? '';
                    final effTo = t['effective_to'] ?? l10n.freightDataActiveOngoing;
                    final slabs = (t['rate_slabs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: AppTheme.cardDecorationOf(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.gavel_rounded, color: AppTheme.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${t['tariff_version']} — ${t['port_authority']} (${t['container_type']})",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                tooltip: l10n.freightDataCopySlabRateTooltip,
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  "${t['tariff_version']} | ${t['port_authority']} | ${t['container_type']} | $effFrom - $effTo",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${l10n.freightDataEffectiveFromCol}: $effFrom  |  ${l10n.freightDataEffectiveToCol}: $effTo  |  ${l10n.freightDataFreeDaysLabel}: ${t['free_days']} ${l10n.freightDataDayUnit}",
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                          ),
                          if (t['source_document'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              "${l10n.freightDataSourceDocCol}: ${t['source_document']}",
                              style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: slabs.map((s) {
                              final toDay = s['to_day'] != null ? "${s['to_day']}" : "∞";
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceAltOf(context),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  border: Border.all(color: AppTheme.borderOf(context)),
                                ),
                                child: LtrText(
                                  "${s['from_day']}-$toDay: ${s['rate_per_day']} ${l10n.egpCurrency}",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
