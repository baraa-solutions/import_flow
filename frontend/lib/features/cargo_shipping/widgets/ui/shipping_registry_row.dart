import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/cargo_shipping_model.dart';
import 'shipping_format_helper.dart';

/// One row of the saved-shipments registry: file / company title, code and
/// type chips, supplier + containers line, status chips and the row actions.
class ShippingRegistryRow extends StatelessWidget {
  const ShippingRegistryRow({
    super.key,
    required this.rec,
    required this.displayName,
    required this.supplierName,
    required this.onOpen,
    required this.onCopyRow,
    required this.onClone,
    required this.onRestore,
    required this.onDelete,
  });

  final CargoShippingModel rec;
  final String displayName;
  final String supplierName;
  final VoidCallback onOpen;
  final VoidCallback onCopyRow;
  final VoidCallback onClone;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasBreach =
        rec.containersLoadingData.any((c) => c.isSlaBreached) || (rec.lclTrackingData?.isSlaBreached ?? false);
    final gatedCount = rec.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
    final statusLabel = rec.status == 'Completed'
        ? l.cargoShippingStatusCompleted
        : (rec.status == 'Cargo Ready' ? l.cargoShippingStatusCargoReady : rec.status);
    final accent = hasBreach
        ? AppTheme.severityForegroundOf(context, AppSeverity.danger)
        : (rec.isActive ? AppTheme.cobalt : AppTheme.textMutedOf(context));

    return InkWell(
      onTap: onOpen,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: rec.isActive ? AppTheme.cobalt.withValues(alpha: 0.12) : AppTheme.borderOf(context),
                  child: Icon(
                    rec.isActive ? Icons.folder_special : Icons.delete_outline,
                    color: rec.isActive ? AppTheme.cobalt : AppTheme.textMutedOf(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _details(context, l, statusLabel, gatedCount, hasBreach)),
                const SizedBox(width: 8),
                _actions(context, l),
              ],
            ),
          ),
          PositionedDirectional(start: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: accent)),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, AppLocalizations l, String statusLabel, int gatedCount, bool hasBreach) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              displayName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context)),
            ),
            AppStatusBadge(label: rec.cargoShippingCode, severity: AppSeverity.info, size: AppStatusBadgeSize.small),
            AppStatusBadge(
              label: rec.shipmentType,
              severity: rec.shipmentType == 'FCL' ? AppSeverity.info : AppSeverity.warning,
              size: AppStatusBadgeSize.small,
            ),
            if (!rec.isActive)
              AppStatusBadge(label: l.cargoShippingSoftDeletedBadge, severity: AppSeverity.danger, icon: Icons.delete_outline, size: AppStatusBadgeSize.small),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${supplierName.isNotEmpty ? "${l.cargoShippingSupplierLabel} $supplierName | " : ""}${l.cargoShippingContainersHeader} ${rec.containersLoadingData.map((c) => "${c.containerNo} (${c.sealNo})").join(", ")}',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            AppStatusBadge(
              label: '${l.status}: $statusLabel',
              severity: ShippingFormat.statusSeverity(rec.status),
              size: AppStatusBadgeSize.small,
            ),
            if (rec.shipmentType == 'FCL')
              AppStatusBadge(
                label: l.cargoShippingGatedCountBadge(gatedCount, rec.containersLoadingData.length),
                severity: AppSeverity.success,
                icon: Icons.login,
                size: AppStatusBadgeSize.small,
              ),
            if (hasBreach)
              AppStatusBadge(label: l.cargoShippingSlaBreached, severity: AppSeverity.danger, icon: Icons.alarm_off, size: AppStatusBadgeSize.small)
            else
              AppStatusBadge(label: l.cargoShippingSlaOnTime, severity: AppSeverity.success, icon: Icons.alarm_on, size: AppStatusBadgeSize.small),
          ],
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, AppLocalizations l) {
    if (!rec.isActive) {
      return RowActionsPill(
        viewTooltip: l.cargoShippingEditTooltip,
        onView: onOpen,
        cloneTooltip: l.copyCargoShippingRowSuccess,
        onClone: onCopyRow,
        deleteTooltip: l.cargoShippingRestoreTooltip,
        onDelete: onRestore,
      );
    }

    return RowActionsPill(
      viewTooltip: l.cargoShippingEditTooltip,
      onView: onOpen,
      editTooltip: l.cargoShippingEditTooltip,
      onEdit: onOpen,
      cloneTooltip: l.cloneCargoShippingTooltip,
      onClone: onClone,
      printTooltip: l.copyCargoShippingRowSuccess,
      onPrint: onCopyRow,
      deleteTooltip: l.delete,
      onDelete: onDelete,
    );
  }
}
