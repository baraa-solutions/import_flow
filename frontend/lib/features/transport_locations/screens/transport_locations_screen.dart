import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/transport_location_model.dart';
import '../providers/transport_locations_provider.dart';
import '../widgets/transport_location_filter_toolbar.dart';
import '../widgets/transport_location_form_dialog.dart';

class TransportLocationsScreen extends ConsumerStatefulWidget {
  const TransportLocationsScreen({super.key});

  @override
  ConsumerState<TransportLocationsScreen> createState() => _TransportLocationsScreenState();
}

class _TransportLocationsScreenState extends ConsumerState<TransportLocationsScreen> {
  String _selectedType = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _locationTypes = ['All', 'Sea Port', 'Airport', 'Dry Port', 'Land Border'];

  @override
  void initState() {
    super.initState();
    if (!ref.read(transportLocationsProvider).isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(transportLocationsProvider.notifier).fetchLocations();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyLocationsTsv(BuildContext context, List<TransportLocationModel> locations) {
    final l10n = context.l10n;
    if (locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l10n.noTransportLocationsFound,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln([
      l10n.locationsTsvHeaderUnLocode,
      l10n.locationsTsvHeaderName,
      l10n.locationsTsvHeaderType,
      l10n.locationsTsvHeaderCountry,
      l10n.locationsTsvHeaderCity,
      l10n.locationsTsvHeaderStatus,
      l10n.locationsTsvHeaderNotes,
    ].join('\t'));

    for (final loc in locations) {
      final statusStr = loc.isActive ? l10n.statusActive : l10n.statusInactive;
      buffer.writeln([
        loc.unLocode,
        loc.locationName,
        TransportLocationFilterToolbar.getLocationTypeLabel(loc.locationType, l10n),
        loc.country,
        loc.city,
        statusStr,
        loc.notes ?? '',
      ].join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.locationsExportTsvSuccess,
    );
  }

  String _buildLocationRowSummary(AppLocalizations l10n, TransportLocationModel loc) {
    final statusStr = loc.isActive ? l10n.statusActive : l10n.statusInactive;
    final typeStr = TransportLocationFilterToolbar.getLocationTypeLabel(loc.locationType, l10n);
    return '${loc.unLocode}\t${loc.locationName}\t$typeStr\t${loc.country}\t${loc.city}\t$statusStr\t${loc.notes ?? ""}';
  }

  void _copySingleLocationSummary(BuildContext context, TransportLocationModel loc) {
    final l10n = context.l10n;
    final summary = _buildLocationRowSummary(l10n, loc);
    CopyHelper.copy(
      context,
      summary,
      customMessage: l10n.locationCopySummarySuccess,
    );
  }

  void _showLocationDialog(BuildContext context, {TransportLocationModel? location}) {
    TransportLocationFormDialog.show(context, ref, location: location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locationsAsync = ref.watch(transportLocationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationsList = locationsAsync.asData?.value ?? [];

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey.shade100,
      appBar: PageHeader(
        icon: Icons.place_outlined,
        title: l10n.transportLocationsScreenTitle,
        subtitle: l10n.transportLocationsScreenSubtitle,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Extracted Filter & Search Toolbar
              TransportLocationFilterToolbar(
                searchController: _searchController,
                selectedType: _selectedType,
                locationTypes: _locationTypes,
                hasData: locationsList.isNotEmpty,
                onAddLocation: () => _showLocationDialog(context),
                onRefresh: () => ref.read(transportLocationsProvider.notifier).fetchLocations(
                      locationType: _selectedType,
                      search: _searchQuery,
                    ),
                onCopyTsv: () => _copyLocationsTsv(context, locationsList),
                onSearchChanged: (v) {
                  setState(() {
                    _searchQuery = v;
                  });
                  ref.read(transportLocationsProvider.notifier).fetchLocations(
                        locationType: _selectedType,
                        search: v,
                      );
                },
                onTypeChanged: (type) {
                  setState(() {
                    _selectedType = type;
                  });
                  ref.read(transportLocationsProvider.notifier).fetchLocations(
                        locationType: type,
                        search: _searchQuery,
                      );
                },
              ),
              const SizedBox(height: 8),

              // Table Content
              Expanded(
                child: locationsAsync.when(
                  loading: () => const AppLoadingState(),
                  error: (err, stack) => AppErrorState(
                    message: l10n.locationsFetchError(err.toString()),
                    onRetry: () => ref.read(transportLocationsProvider.notifier).fetchLocations(
                          locationType: _selectedType,
                          search: _searchQuery,
                        ),
                  ),
                  data: (locations) {
                    return EnterpriseDataTable<TransportLocationModel>(
                      storageKey: 'transport_locations_enterprise_table',
                      data: locations,
                      minWidth: 1180,
                      isScrollable: true,
                      showHeaderToolbar: false,
                      showPagination: true,
                      initialPageSize: 50,
                      emptyMessage: l10n.noTransportLocationsFound,
                      emptyIcon: Icons.place_outlined,
                      columns: _buildLocationColumns(context, l10n),
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

  List<EnterpriseColumn<TransportLocationModel>> _buildLocationColumns(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      EnterpriseColumn<TransportLocationModel>(
        id: 'actions',
        title: l10n.actionsCol,
        width: 210,
        isSortable: false,
        isSearchable: false,
        isLocked: true,
        cellBuilder: (ctx, loc, _) {
          final isActive = loc.isActive;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
                tooltip: l10n.locationCopySummaryBtn,
                onPressed: () => _copySingleLocationSummary(context, loc),
                visualDensity: VisualDensity.compact,
              ),
              RowActionsPill(
                onView: () => _showLocationDialog(context, location: loc),
                onEdit: () => _showLocationDialog(context, location: loc),
                onPrint: () => MasterDataExportService.printOrSaveLocationPdf(loc),
                onDelete: () async {
                  final confirm = await AppConfirmDialog.showToggleActive(
                    context,
                    isCurrentlyActive: isActive,
                    message: isActive
                        ? l10n.confirmDeactivateLocation(loc.locationName)
                        : l10n.confirmActivateLocation(loc.locationName),
                    confirmLabel: isActive ? l10n.deactivateBtn : l10n.activateBtn,
                    cancelLabel: l10n.cancel,
                  );
                  if (confirm == true && loc.locationId != null) {
                    ref.read(transportLocationsProvider.notifier).toggleActive(loc.locationId!, isActive);
                  }
                },
                deleteTooltip: isActive ? l10n.deactivateLocationTooltip : l10n.activateLocationTooltip,
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<TransportLocationModel>(
        id: 'un_locode',
        title: l10n.unLocodeCol,
        width: 140,
        sortComparator: (a, b) => a.unLocode.compareTo(b.unLocode),
        searchValue: (loc) => loc.unLocode,
        exportValue: (loc) => loc.unLocode,
        cellBuilder: (ctx, loc, _) => InkWell(
          onTap: () => _showLocationDialog(context, location: loc),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.unLocode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.cobalt,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => CopyHelper.copy(context, loc.unLocode),
                  child: const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
                ),
              ],
            ),
          ),
        ),
      ),
      EnterpriseColumn<TransportLocationModel>(
        id: 'location_name',
        title: l10n.locationNameCol,
        flex: 3,
        sortComparator: (a, b) => a.locationName.compareTo(b.locationName),
        searchValue: (loc) => '${loc.locationName} ${loc.notes ?? ""}',
        exportValue: (loc) => loc.locationName,
        cellBuilder: (ctx, loc, _) {
          final isActive = loc.isActive;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.locationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isActive ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal) : Colors.grey.shade700,
                  decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                ),
              ),
              if (loc.notes != null && loc.notes!.isNotEmpty)
                Text(
                  loc.notes!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          );
        },
      ),
      EnterpriseColumn<TransportLocationModel>(
        id: 'location_type',
        title: l10n.locationTypeCol,
        width: 140,
        sortComparator: (a, b) => a.locationType.compareTo(b.locationType),
        searchValue: (loc) => TransportLocationFilterToolbar.getLocationTypeLabel(loc.locationType, l10n),
        exportValue: (loc) => TransportLocationFilterToolbar.getLocationTypeLabel(loc.locationType, l10n),
        cellBuilder: (ctx, loc, _) => _typeBadge(loc.locationType, l10n),
      ),
      EnterpriseColumn<TransportLocationModel>(
        id: 'country',
        title: l10n.countryCol,
        flex: 2,
        sortComparator: (a, b) => a.country.compareTo(b.country),
        searchValue: (loc) => loc.country,
        exportValue: (loc) => loc.country,
        cellBuilder: (ctx, loc, _) => Text(
          loc.country,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      EnterpriseColumn<TransportLocationModel>(
        id: 'city',
        title: l10n.cityCol,
        flex: 2,
        sortComparator: (a, b) => a.city.compareTo(b.city),
        searchValue: (loc) => loc.city,
        exportValue: (loc) => loc.city,
        cellBuilder: (ctx, loc, _) => Text(
          loc.city,
          style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : Colors.black87),
        ),
      ),
      EnterpriseColumn<TransportLocationModel>(
        id: 'status',
        title: l10n.statusCol,
        width: 95,
        sortComparator: (a, b) => (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
        searchValue: (loc) => loc.isActive ? l10n.statusActive : l10n.statusInactive,
        exportValue: (loc) => loc.isActive ? l10n.statusActive : l10n.statusInactive,
        cellBuilder: (ctx, loc, _) {
          final isActive = loc.isActive;
          return AppStatusBadge(
            label: isActive ? l10n.statusActive : l10n.statusInactive,
            severity: isActive ? AppSeverity.success : AppSeverity.danger,
            size: AppStatusBadgeSize.small,
          );
        },
      ),
    ];
  }

  Widget _typeBadge(String type, AppLocalizations l10n) {
    final (severity, icon) = switch (type) {
      'Sea Port' => (AppSeverity.info, Icons.directions_boat),
      'Airport' => (AppSeverity.warning, Icons.flight),
      'Dry Port' => (AppSeverity.info, Icons.warehouse),
      'Land Border' => (AppSeverity.success, Icons.border_outer),
      _ => (AppSeverity.info, Icons.place),
    };

    return AppStatusBadge(
      label: TransportLocationFilterToolbar.getLocationTypeLabel(type, l10n),
      severity: severity,
      icon: icon,
      size: AppStatusBadgeSize.small,
    );
  }
}
