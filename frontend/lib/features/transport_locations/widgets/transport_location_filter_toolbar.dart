import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/transport_locations_provider.dart';

/// Filter, search and action toolbar for Ports & Transport Locations.
class TransportLocationFilterToolbar extends ConsumerWidget {
  final TextEditingController searchController;
  final String selectedType;
  final List<String> locationTypes;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddLocation;
  final VoidCallback onRefresh;
  final VoidCallback onCopyTsv;
  final bool hasData;

  const TransportLocationFilterToolbar({
    super.key,
    required this.searchController,
    required this.selectedType,
    required this.locationTypes,
    required this.onTypeChanged,
    required this.onSearchChanged,
    required this.onAddLocation,
    required this.onRefresh,
    required this.onCopyTsv,
    required this.hasData,
  });

  static String getLocationTypeLabel(String type, AppLocalizations l10n) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ActionToolbar(
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
          onPressed: onAddLocation,
        ),
      ],
      moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
        context: context,
        includeTsv: hasData,
      ),
      onMoreActionSelected: (val) => MasterDataActionHelper.handleStandardAction(
        context: context,
        ref: ref,
        actionValue: val,
        moduleEndpoint: 'transport-locations',
        entityNameAr: 'الموانئ ومواقع النقل',
        entityNameEn: 'Transport Locations & Ports',
        entityFilePrefix: 'Transport_Locations',
        onImportSuccess: () => ref.read(transportLocationsProvider.notifier).fetchLocations(),
        onCopyTsv: onCopyTsv,
      ),
      searchController: searchController,
      searchHint: l10n.searchTransportLocationsHint,
      onSearchChanged: onSearchChanged,
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
                value: selectedType,
                isExpanded: true,
                style: TextStyle(
                  fontSize: density.buttonFontSize - 1,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
                items: locationTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(getLocationTypeLabel(type, l10n)),
                )).toList(),
                onChanged: (type) {
                  if (type != null) {
                    onTypeChanged(type);
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
          onPressed: onRefresh,
        ),
        if (hasData)
          IconButton(
            icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
            tooltip: l10n.locationsExportTsvBtn,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: density.buttonHeight,
              minHeight: density.buttonHeight,
            ),
            onPressed: onCopyTsv,
          ),
      ],
    );
  }
}
