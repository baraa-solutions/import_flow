// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/paged_data_table/paged_table_column.dart';
import '../../../../core/widgets/paged_data_table/row_action.dart';
import '../../models/transport_location_model.dart';
import '../../providers/transport_locations_provider.dart';
import '../transport_location_filter_toolbar.dart';

class TransportLocationsTableColumns {
  const TransportLocationsTableColumns._();

  static List<PagedTableColumn<TransportLocationModel>> build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      PagedTableColumn<TransportLocationModel>(
        id: 'un_locode',
        label: (loc) => loc.unLocodeCol,
        width: 140,
        pinned: true,
        numeric: true,
        sortKey: 'un_locode',
        cell: (ctx, loc) => InkWell(
          onTap: () => CopyHelper.copy(
            context,
            loc.unLocode,
            customMessage: l10n.locationLocodeBadgeLabel,
          ),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copy_rounded, size: 11, color: AppTheme.cobalt),
                const SizedBox(width: 4),
                Text(
                  loc.unLocode,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        exportValue: (loc) => loc.unLocode,
      ),
      PagedTableColumn<TransportLocationModel>(
        id: 'location_name',
        label: (loc) => loc.locationNameCol,
        width: 220,
        sortKey: 'location_name',
        cell: (ctx, loc) => Text(
          loc.locationName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        exportValue: (loc) => loc.locationName,
      ),
      PagedTableColumn<TransportLocationModel>(
        id: 'location_type',
        label: (loc) => loc.locationTypeCol,
        width: 140,
        sortKey: 'location_type',
        cell: (ctx, loc) {
          final typeLabel = TransportLocationFilterToolbar.getLocationTypeLabel(loc.locationType, l10n);
          return Chip(
            visualDensity: VisualDensity.compact,
            label: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
              ),
            ),
            backgroundColor: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
          );
        },
        exportValue: (loc) => loc.locationType,
      ),
      PagedTableColumn<TransportLocationModel>(
        id: 'country',
        label: (loc) => loc.countryCol,
        width: 140,
        sortKey: 'country',
        cell: (ctx, loc) => Text(
          loc.country,
          style: const TextStyle(fontSize: 11.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        exportValue: (loc) => loc.country,
      ),
      PagedTableColumn<TransportLocationModel>(
        id: 'city',
        label: (loc) => loc.cityCol,
        width: 140,
        sortKey: 'city',
        cell: (ctx, loc) => Text(
          loc.city,
          style: const TextStyle(fontSize: 11.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        exportValue: (loc) => loc.city,
      ),
      PagedTableColumn<TransportLocationModel>(
        id: 'status',
        label: (loc) => loc.statusCol,
        width: 110,
        sortKey: 'is_active',
        cell: (ctx, loc) {
          final isActive = loc.isActive;
          return Chip(
            visualDensity: VisualDensity.compact,
            label: Text(
              isActive ? l10n.statusActive : l10n.statusInactive,
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: isActive ? AppTheme.emerald : Colors.grey.shade600,
          );
        },
        exportValue: (loc) => loc.isActive ? 'Active' : 'Inactive',
      ),
      PagedTableColumn<TransportLocationModel>(
        id: 'notes',
        label: (loc) => loc.locationNotesLabel,
        width: 220,
        cell: (ctx, loc) => Text(
          loc.notes ?? '-',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        exportValue: (loc) => loc.notes ?? '',
      ),
    ];
  }

  static List<RowAction<TransportLocationModel>> buildRowActions(
    BuildContext context,
    WidgetRef ref,
    TransportLocationModel item,
    void Function(TransportLocationModel) onEdit,
  ) {
    return [
      RowAction<TransportLocationModel>(
        kind: RowActionKind.view,
        icon: Icons.edit_outlined,
        label: (l) => l.editLocationDialogTitle(item.unLocode),
        color: AppTheme.cobalt,
        run: (_) => onEdit(item),
      ),
      RowAction<TransportLocationModel>(
        kind: RowActionKind.print,
        icon: Icons.print_outlined,
        label: (l) => l.printLocationSnack(item.locationName, item.unLocode),
        run: (_) => MasterDataExportService.printOrSaveLocationPdf(item),
      ),
      RowAction<TransportLocationModel>(
        kind: RowActionKind.delete,
        icon: Icons.power_settings_new_rounded,
        label: (l) => item.isActive ? l.deactivateLocationTooltip : l.activateLocationTooltip,
        color: AppTheme.crimson,
        isDestructive: true,
        run: (_) async {
          final confirm = await AppConfirmDialog.showToggleActive(
            context,
            isCurrentlyActive: item.isActive,
            entityName: item.locationName,
          );
          if (confirm == true && item.locationId != null) {
            await ref.read(transportLocationsProvider.notifier).toggleActive(item.locationId!, item.isActive);
            ref.read(transportLocationsPagedProvider.notifier).refresh();
          }
        },
      ),
    ];
  }
}
