import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Header bar displaying Draft Bill of Lading core transport identifiers:
/// - B/L number with copy & edit capability
/// - Shipping line
/// - Vessel name & voyage number
/// - Port of loading (POL) and port of discharge (POD)
/// - Match status badge / discrepancies indicator
class DraftBlHeaderBar extends StatelessWidget {
  final String blNumber;
  final String? shippingLine;
  final String? vesselName;
  final String? voyageNumber;
  final String? pol;
  final String? pod;
  final bool hasBlockingMismatch;
  final int openDiscrepanciesCount;
  final bool isCertified;
  final VoidCallback? onEditBlNumber;
  final VoidCallback? onSearchAndClone;

  const DraftBlHeaderBar({
    super.key,
    required this.blNumber,
    this.shippingLine,
    this.vesselName,
    this.voyageNumber,
    this.pol,
    this.pod,
    this.hasBlockingMismatch = false,
    this.openDiscrepanciesCount = 0,
    this.isCertified = false,
    this.onEditBlNumber,
    this.onSearchAndClone,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final vesselVoyageText = (vesselName != null && vesselName!.isNotEmpty)
        ? (voyageNumber != null && voyageNumber!.isNotEmpty
            ? '$vesselName - $voyageNumber'
            : vesselName!)
        : l.unspecified;

    final portsText = (pol != null && pol!.isNotEmpty) || (pod != null && pod!.isNotEmpty)
        ? '${pol ?? l.unspecified} ➔ ${pod ?? l.unspecified}'
        : l.unspecified;

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
              // Top line: B/L Number chip + Status Badges + Search&Clone Action
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: isDark ? 0.2 : 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.confirmation_number_outlined, color: AppTheme.cobalt, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              blNumber.isNotEmpty ? blNumber : l.unspecified,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (blNumber.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => CopyHelper.copy(
                                  context,
                                  blNumber,
                                  customMessage: l.draftBlCopiedBlNumberSnackbar(blNumber),
                                ),
                                child: Tooltip(
                                  message: l.draftBlCopyBlNumberTooltip,
                                  child: Icon(Icons.copy, size: 14, color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (onEditBlNumber != null)
                        AppButton(
                          label: l.edit,
                          icon: Icons.edit,
                          variant: AppButtonVariant.ghost,
                          size: AppButtonSize.small,
                          onPressed: onEditBlNumber,
                        ),
                    ],
                  ),

                  // Status and Clone
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppStatusBadge(
                        label: isCertified ? l.idocACertified : l.idocADraft,
                        severity: isCertified ? AppSeverity.success : AppSeverity.warning,
                        size: AppStatusBadgeSize.small,
                      ),
                      AppStatusBadge(
                        label: hasBlockingMismatch
                            ? l.draftBlMismatchesFound(openDiscrepanciesCount)
                            : l.draftBlPerfectMatchReady,
                        severity: hasBlockingMismatch ? AppSeverity.danger : AppSeverity.success,
                        size: AppStatusBadgeSize.small,
                      ),
                      if (onSearchAndClone != null)
                        AppButton(
                          key: const Key('stage1SearchAndCloneBtn'),
                          label: l.searchAndCloneDraftBlBtn,
                          icon: Icons.copy_all,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: onSearchAndClone,
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),

              // Transport Route & Vessel details row
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _buildItem(
                    context,
                    icon: Icons.directions_boat,
                    label: l.draftBlRegistryColShippingLine,
                    value: shippingLine != null && shippingLine!.isNotEmpty ? shippingLine! : l.unspecified,
                  ),
                  _buildItem(
                    context,
                    icon: Icons.directions_boat_outlined,
                    label: l.draftBlRegistryColVesselVoyage,
                    value: vesselVoyageText,
                  ),
                  _buildItem(
                    context,
                    icon: Icons.anchor,
                    label: l.draftBlSummaryPorts,
                    value: portsText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          backgroundColor: AppTheme.cobalt.withValues(alpha: 0.1),
          radius: 14,
          child: Icon(icon, color: AppTheme.cobalt, size: 16),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              CopyableText(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
