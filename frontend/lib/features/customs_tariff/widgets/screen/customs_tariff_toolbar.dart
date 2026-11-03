import 'package:flutter/material.dart';
import '../../../../core/helpers/master_data_action_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/action_toolbar.dart';

class CustomsTariffToolbar extends StatelessWidget {
  final DisplayDensityMode density;
  final TextEditingController searchController;
  final bool showInactive;
  final bool hasTariffs;
  final VoidCallback onAddManual;
  final VoidCallback onSmartNafeza;
  final VoidCallback onDutyCalculator;
  final ValueChanged<String> onMoreActionSelected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onToggleShowInactive;
  final VoidCallback onRefresh;
  final VoidCallback onCopyTsv;

  const CustomsTariffToolbar({
    super.key,
    required this.density,
    required this.searchController,
    required this.showInactive,
    required this.hasTariffs,
    required this.onAddManual,
    required this.onSmartNafeza,
    required this.onDutyCalculator,
    required this.onMoreActionSelected,
    required this.onSearchChanged,
    required this.onToggleShowInactive,
    required this.onRefresh,
    required this.onCopyTsv,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          icon: Icon(Icons.add, size: density.buttonIconSize),
          label: Text(
            l10n.addTariffManualBtn,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
          onPressed: onAddManual,
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.orange,
            foregroundColor: Colors.white,
            minimumSize: Size(0, density.buttonHeight),
            padding: density.buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: Icon(Icons.auto_fix_high, size: density.buttonIconSize),
          label: Text(
            l10n.smartNafezaDiffEngineBtn,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
          onPressed: onSmartNafeza,
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            minimumSize: Size(0, density.buttonHeight),
            padding: density.buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: Icon(Icons.calculate, size: density.buttonIconSize),
          label: Text(
            l10n.dutyCalculatorBtn,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
          onPressed: onDutyCalculator,
        ),
      ],
      moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
        context: context,
        includeTsv: hasTariffs,
      ),
      onMoreActionSelected: onMoreActionSelected,
      searchController: searchController,
      searchHint: l10n.searchTariffsHint,
      onSearchChanged: onSearchChanged,
      filters: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.showInactiveTariffsLabel,
              style: TextStyle(
                fontSize: density.buttonFontSize - 1,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(width: 4),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: showInactive,
                activeThumbColor: AppTheme.cobalt,
                onChanged: onToggleShowInactive,
              ),
            ),
          ],
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
        if (hasTariffs)
          IconButton(
            icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
            tooltip: l10n.customsTariffExportTsvBtn,
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
