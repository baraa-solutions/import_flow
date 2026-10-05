import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/compact_table_pagination_footer.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../models/transport_location_model.dart';
import '../providers/transport_locations_provider.dart';

class TransportLocationsScreen extends ConsumerStatefulWidget {
  const TransportLocationsScreen({super.key});

  @override
  ConsumerState<TransportLocationsScreen> createState() => _TransportLocationsScreenState();
}

class _TransportLocationsScreenState extends ConsumerState<TransportLocationsScreen> {
  String _selectedType = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _pageSize = 50;

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
        SnackBar(content: Text(l10n.noTransportLocationsFound), backgroundColor: AppTheme.crimson),
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
        _getLocationTypeLabel(loc.locationType, l10n),
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
    final typeStr = _getLocationTypeLabel(loc.locationType, l10n);
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

  String _getLocationTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'All':
        return l10n.locationTypeAll;
      case 'Sea Port':
        return l10n.locationTypeSeaPort;
      case 'Airport':
        return l10n.locationTypeAirport;
      case 'Dry Port':
        return l10n.locationTypeDryPort;
      case 'Land Border':
        return l10n.locationTypeLandBorder;
      case 'ICD':
        return l10n.locationTypeIcd;
      case 'Rail Terminal':
        return l10n.locationTypeRailTerminal;
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locationsAsync = ref.watch(transportLocationsProvider);

    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              ActionToolbar(
                primaryActions: [
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
                ],
                moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
                  context: context,
                  includeTsv: (locationsAsync.asData?.value ?? []).isNotEmpty,
                ),
                onMoreActionSelected: (val) {
                  switch (val) {
                    case 'export_excel':
                      final list = locationsAsync.asData?.value ?? [];
                      MasterDataExportService.exportLocationsToExcel(context, list);
                      break;
                    case 'export_pdf':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'transport-locations',
                        actionEndpoint: 'export-pdf',
                        defaultFileName: 'Transport_Locations_Report.pdf',
                        dialogTitle: 'تصدير الموانئ والمواقع اللوجستية PDF',
                      );
                      break;
                    case 'copy_tsv':
                      _copyLocationsTsv(context, locationsAsync.asData?.value ?? []);
                      break;
                    case 'download_template':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'transport-locations',
                        actionEndpoint: 'excel-template',
                        defaultFileName: 'Transport_Locations_Template.xlsx',
                        dialogTitle: 'تنزيل نموذج الموانئ والمواقع',
                      );
                      break;
                    case 'import_excel':
                      _handleExcelImport(context, ref);
                      break;
                  }
                },
                searchController: _searchController,
                searchHint: l10n.searchTransportLocationsHint,
                onSearchChanged: (v) {
                  setState(() {
                    _searchQuery = v;
                    _currentPage = 1;
                  });
                  ref.read(transportLocationsProvider.notifier).fetchLocations(
                        locationType: _selectedType,
                        search: v,
                      );
                },
                filters: [
                  SizedBox(
                    width: 145,
                    height: density.buttonHeight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.black26, width: 0.8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          isExpanded: true,
                          style: TextStyle(
                            fontSize: density.buttonFontSize - 1,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                          items: _locationTypes.map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(_getLocationTypeLabel(type, l10n)),
                          )).toList(),
                          onChanged: (type) {
                            if (type != null) {
                              setState(() {
                                _selectedType = type;
                                _currentPage = 1;
                              });
                              ref.read(transportLocationsProvider.notifier).fetchLocations(
                                    locationType: type,
                                    search: _searchQuery,
                                  );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                quickDataActions: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
                    tooltip: l10n.liveRefresh,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () => ref.read(transportLocationsProvider.notifier).fetchLocations(
                          locationType: _selectedType,
                          search: _searchQuery,
                        ),
                  ),
                  if ((locationsAsync.asData?.value ?? []).isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                      tooltip: l10n.locationsExportTsvBtn,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: density.buttonHeight,
                        minHeight: density.buttonHeight,
                      ),
                      onPressed: () => _copyLocationsTsv(context, locationsAsync.asData?.value ?? []),
                    ),
                ],
              ),
              const SizedBox(height: 8),

            // Table Content
            Expanded(
              child: locationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.cobalt)),
                error: (err, stack) => Center(
                  child: Text(l10n.locationsFetchError(err.toString()), style: const TextStyle(color: AppTheme.crimson)),
                ),
                data: (locations) {
                  if (locations.isEmpty) {
                    return Center(
                      child: Text(l10n.noTransportLocationsFound, style: const TextStyle(color: Colors.grey, fontSize: 15)),
                    );
                  }

                  final totalItems = locations.length;
                  final totalPages = (totalItems / _pageSize).ceil();
                  final safeCurrentPage = _currentPage > totalPages && totalPages > 0 ? totalPages : _currentPage;
                  final startIndex = (safeCurrentPage - 1) * _pageSize;
                  final endIndex = (startIndex + _pageSize < totalItems) ? startIndex + _pageSize : totalItems;
                  final pagedLocations = totalItems > 0 && startIndex < totalItems
                      ? locations.sublist(startIndex, endIndex)
                      : <TransportLocationModel>[];

                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBackground : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final tableWidth = constraints.maxWidth < 1180 ? 1180.0 : constraints.maxWidth;

                                return SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      child: Table(
                                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                        columnWidths: const {
                                          0: FixedColumnWidth(210),
                                          1: FixedColumnWidth(140),
                                          2: FlexColumnWidth(3),
                                          3: FixedColumnWidth(140),
                                          4: FlexColumnWidth(2),
                                          5: FlexColumnWidth(2),
                                          6: FixedColumnWidth(95),
                                        },
                                        children: [
                                          // Table Header
                                          TableRow(
                                            decoration: const BoxDecoration(color: AppTheme.charcoal),
                                            children: [
                                              l10n.actionsCol,
                                              l10n.unLocodeCol,
                                              l10n.locationNameCol,
                                              l10n.locationTypeCol,
                                              l10n.countryCol,
                                              l10n.cityCol,
                                              l10n.statusCol,
                                            ]
                                                .map((h) => Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                      child: Text(
                                                        h,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ))
                                                .toList(),
                                          ),

                                // Table Data Rows
                                ...pagedLocations.asMap().entries.map((entry) {
                                  final loc = entry.value;
                                  final isEven = entry.key % 2 == 0;
                                  final isActive = loc.isActive;
                                  final rowSummary = _buildLocationRowSummary(l10n, loc);

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: isEven ? Colors.white : Colors.grey.shade50,
                                    ),
                                    children: [
                                      // Actions: Quick Copy Summary, View, Edit, Print, Delete
                                      _cell(
                                        value: loc.unLocode,
                                        rowSummary: rowSummary,
                                        child: Row(
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
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: Text(l10n.confirmActionTitle),
                                                    content: Text(isActive
                                                        ? l10n.confirmDeactivateLocation(loc.locationName)
                                                        : l10n.confirmActivateLocation(loc.locationName)),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                                                      ElevatedButton(
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                        style: ElevatedButton.styleFrom(backgroundColor: isActive ? AppTheme.crimson : AppTheme.emerald),
                                                        child: Text(isActive ? l10n.deactivateBtn : l10n.activateBtn, style: const TextStyle(color: Colors.white)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true && loc.locationId != null) {
                                                  ref.read(transportLocationsProvider.notifier).toggleActive(loc.locationId!, isActive);
                                                }
                                              },
                                              deleteTooltip: isActive ? l10n.deactivateLocationTooltip : l10n.activateLocationTooltip,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // UN/LOCODE
                                      _cell(
                                        value: loc.unLocode,
                                        rowSummary: rowSummary,
                                        child: InkWell(
                                          onTap: () => _showLocationDialog(context, location: loc),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.cobalt.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
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

                                      // Location Name & Notes
                                      _cell(
                                        value: '${loc.locationName}${loc.notes != null ? " - ${loc.notes}" : ""}',
                                        rowSummary: rowSummary,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              loc.locationName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isActive ? AppTheme.charcoal : Colors.grey.shade700,
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
                                        ),
                                      ),

                                      // Type Badge
                                      _cell(
                                        value: _getLocationTypeLabel(loc.locationType, l10n),
                                        rowSummary: rowSummary,
                                        child: _typeBadge(loc.locationType, l10n),
                                      ),

                                      // Country
                                      _cell(
                                        value: loc.country,
                                        rowSummary: rowSummary,
                                        child: Text(
                                          loc.country,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ),

                                      // City
                                      _cell(
                                        value: loc.city,
                                        rowSummary: rowSummary,
                                        child: Text(
                                          loc.city,
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        ),
                                      ),

                                      // Status
                                      _cell(
                                        value: isActive ? l10n.statusActive : l10n.statusInactive,
                                        rowSummary: rowSummary,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: (isActive ? AppTheme.emerald : AppTheme.crimson).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isActive ? l10n.statusActive : l10n.statusInactive,
                                            style: TextStyle(
                                              color: isActive ? AppTheme.emerald : AppTheme.crimson,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),

                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Integrated Compact Pagination Footer
                CompactTablePaginationFooter(
                  currentPage: safeCurrentPage,
                  totalPages: totalPages == 0 ? 1 : totalPages,
                  totalCount: totalItems,
                  pageSize: _pageSize,
                  isMobile: MediaQuery.sizeOf(context).width < 768,
                  onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                ),
              ],
            ),
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

  Widget _typeBadge(String type, AppLocalizations l10n) {
    Color bg;
    Color fg;
    IconData icon;

    switch (type) {
      case 'Sea Port':
        bg = AppTheme.cobalt.withOpacity(0.1);
        fg = AppTheme.cobalt;
        icon = Icons.directions_boat;
        break;
      case 'Airport':
        bg = AppTheme.orange.withOpacity(0.1);
        fg = AppTheme.orange;
        icon = Icons.flight;
        break;
      case 'Dry Port':
        bg = Colors.purple.withOpacity(0.1);
        fg = Colors.purple;
        icon = Icons.warehouse;
        break;
      case 'Land Border':
        bg = AppTheme.emerald.withOpacity(0.1);
        fg = AppTheme.emerald;
        icon = Icons.border_outer;
        break;
      default:
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey.shade700;
        icon = Icons.place;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            _getLocationTypeLabel(type, l10n),
            style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _cell({
    required Widget child,
    required String value,
    String? rowSummary,
  }) =>
      CopyableTableCell(
        value: value,
        rowSummary: rowSummary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Align(alignment: AlignmentDirectional.centerStart, child: child),
        ),
      );

  void _showLocationDialog(BuildContext context, {TransportLocationModel? location}) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final locodeCtrl = TextEditingController(text: location?.unLocode ?? '');
    final nameCtrl = TextEditingController(text: location?.locationName ?? '');
    String selectedType = location?.locationType ?? 'Sea Port';
    final countryCtrl = TextEditingController(text: location?.country ?? '');
    final cityCtrl = TextEditingController(text: location?.city ?? '');
    final notesCtrl = TextEditingController(text: location?.notes ?? '');

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(location == null
              ? l10n.addLocationDialogTitle
              : l10n.editLocationDialogTitle(location.unLocode)),
          content: SelectionArea(
            child: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: locodeCtrl,
                              enabled: location == null,
                              decoration: InputDecoration(
                                labelText: l10n.unLocodeLabel,
                                hintText: l10n.unLocodeHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.locationCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, locodeCtrl.text),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? l10n.requiredField
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: selectedType,
                              labelText: l10n.locationTypeLabel,
                              items: [
                                'Sea Port',
                                'Airport',
                                'Dry Port',
                                'Land Border',
                                'ICD',
                                'Rail Terminal'
                              ]
                                  .map((t) => SearchableDropdownItem<String>(
                                      value: t,
                                      label: _getLocationTypeLabel(t, l10n)))
                                  .toList(),
                              onChanged: (v) => selectedType = v ?? 'Sea Port',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.locationNameLabel,
                          hintText: l10n.locationNameHint,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.locationCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, nameCtrl.text),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? l10n.requiredField
                                : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: countryCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.countryLabelRequired,
                                hintText: l10n.countryHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.locationCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, countryCtrl.text),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? l10n.requiredField
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: cityCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.cityLabelRequired,
                                hintText: l10n.cityHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.locationCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, cityCtrl.text),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? l10n.requiredField
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l10n.locationNotesLabel,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.locationCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, notesCtrl.text),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            if (location != null)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                tooltip: l10n.exportLocationPdfBtn,
                onPressed: () => MasterDataExportService.printOrSaveLocationPdf(location),
              ),
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        try {
                          if (location == null) {
                            final newModel = TransportLocationModel(
                              unLocode: locodeCtrl.text.trim().toUpperCase(),
                              locationName: nameCtrl.text.trim(),
                              locationType: selectedType,
                              country: countryCtrl.text.trim(),
                              city: cityCtrl.text.trim(),
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            );
                            final ok = await ref
                                .read(transportLocationsProvider.notifier)
                                .createLocation(newModel);
                            if (ok && context.mounted) Navigator.pop(dialogCtx);
                          } else {
                            final updateData = {
                              'location_name': nameCtrl.text.trim(),
                              'location_type': selectedType,
                              'country': countryCtrl.text.trim(),
                              'city': cityCtrl.text.trim(),
                              'notes': notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            };
                            final ok = await ref
                                .read(transportLocationsProvider.notifier)
                                .updateLocation(
                                    location.locationId!, updateData);
                            if (ok && context.mounted) Navigator.pop(dialogCtx);
                          }
                        } finally {
                          if (context.mounted) {
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(location == null
                      ? l10n.createLocationSubmitBtn
                      : l10n.saveChangesSubmitBtn),
            ),
          ],
        ),
      ),
    ).then((_) {
      locodeCtrl.dispose();
      nameCtrl.dispose();
      countryCtrl.dispose();
      cityCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  Future<void> _handleExcelImport(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.importingLocationsDataset), backgroundColor: AppTheme.cobalt),
    );

    try {
      final res = await ref.read(transportLocationsProvider.notifier).uploadExcelLocations(file.bytes!, file.name);
      if (!context.mounted) return;
      final errors = (res?['errors'] as List?)?.cast<String>() ?? [];
      if (errors.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.importWarningsTitle),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: errors.map((e) => Text('• $e', style: const TextStyle(color: AppTheme.crimson, fontSize: 13))).toList(),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok))],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? l10n.locationsImportSuccess), backgroundColor: AppTheme.emerald),
        );
      }
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString()), backgroundColor: AppTheme.crimson),
      );
    }
  }
}
