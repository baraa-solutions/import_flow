import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/paged_data_table/paged_data_table.dart';
import '../../../core/widgets/widgets.dart';
import '../models/transport_location_model.dart';
import '../providers/transport_locations_provider.dart';
import '../widgets/screen/transport_locations_table_columns.dart';
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters({String? type, String? search}) {
    final nextType = type ?? _selectedType;
    final nextSearch = search ?? _searchQuery;
    setState(() {
      _selectedType = nextType;
      _searchQuery = nextSearch;
    });

    final filters = <String, Object?>{};
    if (nextType.isNotEmpty && nextType != 'All') {
      filters['location_type'] = nextType;
    }

    final currentQuery = ref.read(transportLocationsPagedProvider).query;
    final notifier = ref.read(transportLocationsPagedProvider.notifier);
    notifier.setQuery(
      currentQuery.copyWith(
        page: 1,
        search: nextSearch,
        filters: filters,
      ),
    );
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

  void _showLocationDialog(BuildContext context, {TransportLocationModel? location}) {
    TransportLocationFormDialog.show(context, ref, location: location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final pagedState = ref.watch(transportLocationsPagedProvider);
    final notifier = ref.read(transportLocationsPagedProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationsList = pagedState.data?.items ?? <TransportLocationModel>[];

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey.shade100,
      appBar: PageHeader(
        icon: Icons.place_outlined,
        title: l10n.transportLocationsScreenTitle,
        subtitle: l10n.transportLocationsScreenSubtitle,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              minimumSize: Size(0, density.buttonHeight),
              padding: density.buttonPadding,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: Icon(Icons.add_location_alt, size: density.buttonIconSize),
            label: Text(
              l10n.addTransportLocationBtn,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
            ),
            onPressed: () => _showLocationDialog(context),
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Extracted Filter & Search Toolbar (Max height 40px)
              TransportLocationFilterToolbar(
                searchController: _searchController,
                selectedType: _selectedType,
                locationTypes: _locationTypes,
                hasData: locationsList.isNotEmpty,
                onAddLocation: () => _showLocationDialog(context),
                onRefresh: () => notifier.refresh(),
                onCopyTsv: () => _copyLocationsTsv(context, locationsList),
                onSearchChanged: (v) => _applyFilters(search: v),
                onTypeChanged: (type) => _applyFilters(type: type),
              ),
              const SizedBox(height: 8),

              // Paged Data Table (Server-paginated & virtualized)
              Expanded(
                child: PagedDataTable<TransportLocationModel>(
                  storageKey: 'transport_locations_paged_table',
                  columns: TransportLocationsTableColumns.build(context, ref),
                  state: pagedState,
                  onQueryChanged: notifier.setQuery,
                  rowActions: (loc) => TransportLocationsTableColumns.buildRowActions(
                    context,
                    ref,
                    loc,
                    (target) => _showLocationDialog(context, location: target),
                  ),
                  onOpen: (loc) => _showLocationDialog(context, location: loc),
                  rowKey: (loc) => loc.locationId ?? loc.unLocode,
                  emptyMessage: l10n.noTransportLocationsFound,
                  exportStageName: 'Transport Locations & Ports',
                  source: notifier.source,
                  onRefresh: () => notifier.refresh(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
