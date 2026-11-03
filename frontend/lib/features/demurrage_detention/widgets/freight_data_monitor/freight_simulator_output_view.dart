import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';

class FreightSimulatorOutputView extends StatelessWidget {
  final Map<String, dynamic>? calculationResult;
  final bool isCalculating;
  final String? calcError;
  final VoidCallback onCopyDossier;

  const FreightSimulatorOutputView({
    super.key,
    required this.calculationResult,
    required this.isCalculating,
    required this.calcError,
    required this.onCopyDossier,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (isCalculating) {
      return const CcStateView.loading();
    }
    if (calcError != null) {
      return CcStateView.error(message: calcError!);
    }
    if (calculationResult == null) {
      return CcStateView.empty(
        message: l10n.freightDataSimCalculateBtn,
        icon: Icons.calculate_outlined,
      );
    }

    final res = calculationResult!;
    final det = res['detention'] as Map<String, dynamic>? ?? {};
    final port = res['port_storage'] as Map<String, dynamic>? ?? {};
    final detSlabs = (det['slab_details'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final portSlabs = (port['slab_details'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with 1-click dossier export
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.freightDataConsolidatedSummary,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppButton(
                    onPressed: onCopyDossier,
                    icon: Icons.copy_all_rounded,
                    label: l10n.freightDataCopySimulationDossier,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.small,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Consolidated Total Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.charcoal,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildConsolidatedCol(
                  context: context,
                  label: l10n.freightDataConsolidatedEgp,
                  value: "${res['consolidated_total_egp']} ${l10n.egpCurrency}",
                  color: AppTheme.emerald,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppTheme.white.withValues(alpha: 0.24),
                ),
                _buildConsolidatedCol(
                  context: context,
                  label: l10n.freightDataConsolidatedUsd,
                  value: "${res['consolidated_total_usd']} USD",
                  color: AppTheme.cobalt,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppTheme.white.withValues(alpha: 0.24),
                ),
                _buildConsolidatedCol(
                  context: context,
                  label: l10n.freightDataSimFxRate,
                  value: "${res['exchange_rate_applied']} ${l10n.egpCurrency}",
                  color: AppTheme.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Two Breakdowns Side by Side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carrier Detention (USD)
              Expanded(
                child: _buildBreakdownBox(
                  context: context,
                  title: l10n.freightDataCarrierDetentionTitle,
                  totalText: "${det['total_detention_usd']} USD",
                  freeDays: "${det['free_days']} ${l10n.freightDataDayUnit}",
                  chargeableDays: "${det['chargeable_days']} ${l10n.freightDataDayUnit}",
                  appliedRule: det['shipping_line']?.toString().toUpperCase() ?? '',
                  slabs: detSlabs,
                  color: AppTheme.cobalt,
                  l10n: l10n,
                ),
              ),
              const SizedBox(width: 12),

              // Egyptian Port Storage (EGP)
              Expanded(
                child: _buildBreakdownBox(
                  context: context,
                  title: l10n.freightDataPortStorageTitle,
                  totalText: "${port['total_storage_egp']} ${l10n.egpCurrency}",
                  freeDays: "${port['free_days']} ${l10n.freightDataDayUnit}",
                  chargeableDays: "${port['chargeable_days']} ${l10n.freightDataDayUnit}",
                  appliedRule: port['tariff_version_applied'] ?? '',
                  slabs: portSlabs,
                  color: AppTheme.orange,
                  l10n: l10n,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownBox({
    required BuildContext context,
    required String title,
    required String totalText,
    required String freeDays,
    required String chargeableDays,
    required String appliedRule,
    required List<Map<String, dynamic>> slabs,
    required Color color,
    required AppLocalizations l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14),
                tooltip: l10n.freightDataCopySlabRateTooltip,
                onPressed: () => CopyHelper.copy(context, "$title: $totalText ($appliedRule)"),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 12),
          _kvRow(
            l10n.freightDataFreeDaysLabel,
            freeDays,
            const TextStyle(fontSize: 12),
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          _kvRow(
            l10n.freightDataChargeableDaysLabel,
            chargeableDays,
            const TextStyle(fontSize: 12),
            TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
          ),
          const SizedBox(height: 4),
          _kvRow(
            l10n.freightDataAppliedDecree,
            appliedRule,
            const TextStyle(fontSize: 12),
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.freightDataRateSlabsSummary,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 4),
          ...slabs.map((s) {
            final toDay = s['to_day'] != null ? "${s['to_day']}" : "∞";
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${s['from_day']}-$toDay: ${s['rate']} ${s['currency']}/${l10n.freightDataPerDayUnit} (${s['days_applied']} ${l10n.freightDataDayUnit})",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        "${s['cost']} ${s['currency']}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => CopyHelper.copy(context, "${s['cost']} ${s['currency']}"),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 12),
          _kvRow(
            l10n.freightDataTotalLabel,
            totalText,
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidatedCol({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LtrText(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => CopyHelper.copy(context, value),
                  child: Icon(
                    Icons.copy_rounded,
                    color: AppTheme.white.withValues(alpha: 0.55),
                    size: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String label, String value, TextStyle labelStyle, TextStyle valueStyle) {
    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle, maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Flexible(child: Text(value, style: valueStyle, textAlign: TextAlign.end)),
      ],
    );
  }
}
