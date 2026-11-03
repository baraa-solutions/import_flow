import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';

/// Unified compact toolbar for Import Files screen (Desktop & Mobile modes).
/// Follows Type B List screen compact toolbar standard (Max 40px height on desktop).
class ImportFilesCompactToolbar extends ConsumerWidget {
  final TextEditingController searchController;
  final String? selectedStatusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddNew;
  final VoidCallback onSearchAndClone;
  final VoidCallback onShowNotes;
  final VoidCallback onGenerateMasterReport;
  final VoidCallback onOpenSmartExtractor;
  final VoidCallback onOpenSimulator;
  final VoidCallback onImportExcel;
  final VoidCallback onCopyTsv;
  final VoidCallback onRefresh;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final bool isMobile;

  const ImportFilesCompactToolbar({
    super.key,
    required this.searchController,
    this.selectedStatusFilter,
    required this.onStatusFilterChanged,
    required this.onSearchChanged,
    required this.onAddNew,
    required this.onSearchAndClone,
    required this.onShowNotes,
    required this.onGenerateMasterReport,
    required this.onOpenSmartExtractor,
    required this.onOpenSimulator,
    required this.onImportExcel,
    required this.onCopyTsv,
    required this.onRefresh,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);

    if (isMobile) {
      return _buildMobileToolbar(context, ref, isDark, l);
    }
    return _buildDesktopCompactToolbar(context, ref, isDark, l);
  }

  Widget _buildDesktopCompactToolbar(BuildContext context, WidgetRef ref, bool isDark, AppLocalizations l) {
    final density = ref.watch(displayDensityProvider);
    return ActionToolbar(
      primaryActions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.wcagCobalt,
            foregroundColor: Colors.white,
            minimumSize: Size(0, density.buttonHeight),
            padding: density.buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: onAddNew,
          icon: Icon(Icons.add_box, size: density.buttonIconSize, color: Colors.white),
          label: Text(
            l.addNewImportFile,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
            side: BorderSide(color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt),
            minimumSize: Size(0, density.buttonHeight),
            padding: density.buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: onSearchAndClone,
          icon: Icon(Icons.control_point_duplicate_rounded, size: density.buttonIconSize),
          label: Text(
            l.searchAndCloneImportFileBtn,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
        ),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
              side: BorderSide(color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt),
              minimumSize: Size(0, density.buttonHeight),
              padding: density.buttonPadding,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: onShowNotes,
            icon: Icon(Icons.rate_review_outlined, size: density.buttonIconSize),
            label: Text(
              Localizations.localeOf(context).languageCode == 'ar' ? 'الملاحظات' : 'Notes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
            ),
          ),
          const SizedBox(width: 6),
          _buildMoreActionsMenu(context, ref, isDark, l),
          const SizedBox(width: 6),
          _buildQuickDataActions(context, isDark, l),
        ],
      ),
      searchController: searchController,
      searchHint: l.searchByShipmentOrCompany,
      onSearchChanged: onSearchChanged,
      filters: [
        SizedBox(
          width: 125,
          height: density.buttonHeight,
          child: SearchableDropdownField<String>(
            value: selectedStatusFilter ?? 'All',
            labelText: '',
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
            ),
            items: [
              SearchableDropdownItem(value: 'All', label: l.statusAll),
              SearchableDropdownItem(value: 'Open', label: l.statusOpen),
              SearchableDropdownItem(value: 'In Progress', label: l.statusInProgress),
              SearchableDropdownItem(value: 'Closed', label: l.statusClosed),
            ],
            onChanged: (val) {
              if (val != null) {
                onStatusFilterChanged(val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileToolbar(BuildContext context, WidgetRef ref, bool isDark, AppLocalizations l) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.wcagCobalt,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: onAddNew,
          icon: const Icon(Icons.add_box, size: 16, color: Colors.white),
          label: Text(l.addNewImportFile, style: const TextStyle(fontSize: 12)),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
            side: BorderSide(color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt),
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: onSearchAndClone,
          icon: const Icon(Icons.control_point_duplicate_rounded, size: 16),
          label: Text(l.searchAndCloneImportFileBtn, style: const TextStyle(fontSize: 12)),
        ),
        _buildMoreActionsMenu(context, ref, isDark, l),
        _buildQuickDataActions(context, isDark, l),
        SizedBox(
          width: 170,
          height: 32,
          child: TextField(
            controller: searchController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: l.searchByShipmentOrCompany,
              hintStyle: const TextStyle(fontSize: 11),
              prefixIcon: const Icon(Icons.search, size: 16),
              prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        SizedBox(
          width: 115,
          height: 32,
          child: SearchableDropdownField<String>(
            value: selectedStatusFilter ?? 'All',
            labelText: '',
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            items: [
              SearchableDropdownItem(value: 'All', label: l.statusAll),
              SearchableDropdownItem(value: 'Open', label: l.statusOpen),
              SearchableDropdownItem(value: 'In Progress', label: l.statusInProgress),
              SearchableDropdownItem(value: 'Closed', label: l.statusClosed),
            ],
            onChanged: (val) {
              if (val != null) {
                onStatusFilterChanged(val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMoreActionsMenu(BuildContext context, WidgetRef ref, bool isDark, AppLocalizations l) {
    final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
    return PopupMenuButton<int>(
      tooltip: l.moreToolsTooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      elevation: 6,
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 320),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
      ),
      onSelected: (val) {
        if (val == 1) onGenerateMasterReport();
        if (val == 2) onOpenSmartExtractor();
        if (val == 3) onOpenSimulator();
        if (val == 4) onImportExcel();
        if (val == 5) onCopyTsv();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 1,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.summarize, size: 18, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.generateComprehensiveReport,
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.smartInvoiceBlExtractorButton,
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 3,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 18, color: AppTheme.charcoal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.whatIfSimulatorButton,
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 4,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.upload_file, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'استيراد من إكسل' : 'Import Excel',
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 5,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.content_copy, size: 18, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'نسخ الجدول (TSV)' : 'Copy Table (TSV)',
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic ? 'إجراءات إضافية' : 'More actions',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.more_vert,
              size: 16,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDataActions(BuildContext context, bool isDark, AppLocalizations l) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.refresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.refresh, size: 17, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
            onPressed: onRefresh,
          ),
          VerticalDivider(width: 1, thickness: 1, indent: 6, endIndent: 6, color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير إكسل' : 'Export Excel',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.table_chart, size: 17, color: Colors.green.shade700),
            onPressed: onExportExcel,
          ),
          VerticalDivider(width: 1, thickness: 1, indent: 6, endIndent: 6, color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير بي دي إف' : 'Export PDF',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.picture_as_pdf, size: 17, color: AppTheme.crimson),
            onPressed: onExportPdf,
          ),
        ],
      ),
    );
  }
}
