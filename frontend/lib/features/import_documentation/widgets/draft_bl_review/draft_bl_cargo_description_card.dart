import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Card displaying cargo, consignee, and shipper particulars:
/// - Shipper particulars & registration ID
/// - Consignee & Importer Tax ID
/// - Notify party
/// - Cargo / Goods description
/// - Packages count, Gross weight, Net weight, and Volume (CBM)
class DraftBlCargoDescriptionCard extends StatelessWidget {
  final String? shipper;
  final String? consignee;
  final String? notifyParty;
  final String? goodsDescription;
  final int? packagesCount;
  final double? grossWeight;
  final double? netWeight;
  final double? cbm;
  final String? acidNumber;
  final String? importerTaxId;
  final String? shipperRegId;

  const DraftBlCargoDescriptionCard({
    super.key,
    this.shipper,
    this.consignee,
    this.notifyParty,
    this.goodsDescription,
    this.packagesCount,
    this.grossWeight,
    this.netWeight,
    this.cbm,
    this.acidNumber,
    this.importerTaxId,
    this.shipperRegId,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.borderOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header
              Row(
                children: [
                  const Icon(Icons.description_outlined, color: AppTheme.cobalt, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l.draftBlSummaryPackages,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Parties Grid: Shipper, Consignee, Notify Party
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  final shipperWidget = _buildPartyTile(
                    context,
                    title: l.draftBlSummaryShipper,
                    name: shipper ?? l.unspecified,
                    subDetail: shipperRegId != null && shipperRegId!.isNotEmpty
                        ? '${l.draftBlSummaryShipperReg}: $shipperRegId'
                        : null,
                    icon: Icons.business,
                    color: AppTheme.wcagCobalt,
                  );

                  final consigneeWidget = _buildPartyTile(
                    context,
                    title: l.draftBlSummaryConsignee,
                    name: consignee ?? l.unspecified,
                    subDetail: importerTaxId != null && importerTaxId!.isNotEmpty
                        ? '${l.draftBlSummaryImporterTaxId}: $importerTaxId'
                        : null,
                    icon: Icons.account_balance,
                    color: AppTheme.cobalt,
                    acidBadge: acidNumber != null && acidNumber!.isNotEmpty
                        ? '${l.draftBlSummaryAcidNo}: $acidNumber'
                        : null,
                  );

                  final notifyWidget = _buildPartyTile(
                    context,
                    title: l.draftBlSummaryNotifyParty,
                    name: notifyParty != null && notifyParty!.isNotEmpty ? notifyParty! : 'SAME AS CONSIGNEE',
                    icon: Icons.notifications_active_outlined,
                    color: AppTheme.cobalt,
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        shipperWidget,
                        const SizedBox(height: 10),
                        consigneeWidget,
                        const SizedBox(height: 10),
                        notifyWidget,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: shipperWidget),
                      const SizedBox(width: 12),
                      Expanded(child: consigneeWidget),
                      const SizedBox(width: 12),
                      Expanded(child: notifyWidget),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Cargo Description Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAltOf(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.idocAStandardField,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                        if (goodsDescription != null && goodsDescription!.isNotEmpty)
                          InkWell(
                            onTap: () => CopyHelper.copy(context, goodsDescription!),
                            child: Tooltip(
                              message: l.copy,
                              child: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    CopyableText(
                      goodsDescription != null && goodsDescription!.isNotEmpty
                          ? goodsDescription!
                          : l.unspecified,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Weights & Measures Metric Strip
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildMetricPill(
                    context,
                    label: l.draftBlSummaryPackages,
                    value: packagesCount != null && packagesCount! > 0 ? '$packagesCount' : l.unspecified,
                    icon: Icons.category,
                    color: AppTheme.wcagCobalt,
                  ),
                  _buildMetricPill(
                    context,
                    label: l.draftBlSummaryGrossWeight,
                    value: grossWeight != null && grossWeight! > 0 ? '${grossWeight!.toStringAsFixed(1)} kg' : l.unspecified,
                    icon: Icons.scale,
                    color: AppTheme.emerald,
                  ),
                  _buildMetricPill(
                    context,
                    label: l.draftBlSummaryNetWeight,
                    value: netWeight != null && netWeight! > 0 ? '${netWeight!.toStringAsFixed(1)} kg' : l.unspecified,
                    icon: Icons.fitness_center,
                    color: AppTheme.cobalt,
                  ),
                  _buildMetricPill(
                    context,
                    label: l.draftBlSummaryCbm,
                    value: cbm != null && cbm! > 0 ? '${cbm!.toStringAsFixed(2)} CBM' : l.unspecified,
                    icon: Icons.view_in_ar,
                    color: AppTheme.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartyTile(
    BuildContext context, {
    required String title,
    required String name,
    String? subDetail,
    String? acidBadge,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryOf(context)),
              ),
              const Spacer(),
              InkWell(
                onTap: () => CopyHelper.copy(context, name),
                child: const Icon(Icons.copy, size: 13, color: AppTheme.cobalt),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CopyableText(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          if (subDetail != null) ...[
            const SizedBox(height: 4),
            Text(
              subDetail,
              style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context), fontFamily: 'monospace'),
            ),
          ],
          if (acidBadge != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.crimson.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                acidBadge,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.crimson),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricPill(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
