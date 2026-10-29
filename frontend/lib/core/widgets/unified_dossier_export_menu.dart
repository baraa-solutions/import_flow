import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../widgets/copyable_data_helper.dart';
import '../../features/import_files/models/import_file_model.dart';
import '../../features/comprehensive_report/models/comprehensive_dossier_model.dart';
import '../../features/comprehensive_report/services/comprehensive_dossier_service.dart';
import '../../features/comprehensive_report/services/comprehensive_report_export_service.dart';
import '../../features/comprehensive_report/widgets/comprehensive_dossier_export_dialog.dart';
import '../../features/shipment_updates/models/shipment_update_model.dart';
import '../../features/customs_clearance/models/customs_clearance_model.dart';
import '../../features/warehouse_receiving/models/warehouse_receiving_model.dart';

/// Presentation modes for [UnifiedDossierExportMenu].
enum UnifiedExportDisplayMode {
  /// Renders a single compact PopupMenuButton / dropdown with all export options.
  dropdown,

  /// Renders a horizontal row/wrap of individual styled action buttons.
  row,

  /// Renders compact icon buttons suitable for an AppBar or Toolbar.
  appBarActions,
}

/// Unified Dossier Export Component (UnifiedDossierExportMenu)
///
/// Single source of truth for dossier export tools:
/// - Excel Export (.xlsx / .csv)
/// - PDF Export & Print
/// - TSV Raw Data Export
/// - Copy Dossier Summary to Clipboard
/// - CLO-03 Official Dossier Export Modal
class UnifiedDossierExportMenu extends ConsumerWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final List<ShipmentUpdateLogModel>? logs;
  final CustomsClearanceModel? clearance;
  final WarehouseReceivingModel? warehouse;
  final UnifiedExportDisplayMode displayMode;
  final bool showModalOption;
  final bool isDark;

  const UnifiedDossierExportMenu({
    super.key,
    required this.file,
    this.dossier,
    this.logs,
    this.clearance,
    this.warehouse,
    this.displayMode = UnifiedExportDisplayMode.dropdown,
    this.showModalOption = true,
    this.isDark = false,
  });

  const UnifiedDossierExportMenu.row({
    super.key,
    required this.file,
    this.dossier,
    this.logs,
    this.clearance,
    this.warehouse,
    this.showModalOption = true,
    this.isDark = false,
  }) : displayMode = UnifiedExportDisplayMode.row;

  const UnifiedDossierExportMenu.appBarActions({
    super.key,
    required this.file,
    this.dossier,
    this.logs,
    this.clearance,
    this.warehouse,
    this.showModalOption = true,
    this.isDark = false,
  }) : displayMode = UnifiedExportDisplayMode.appBarActions;

  ComprehensiveShipmentDossierModel? _resolveDossier(WidgetRef ref) {
    if (dossier != null) return dossier;
    final asyncVal = ref.watch(comprehensiveDossierProvider(file.importFileId));
    return asyncVal.valueOrNull;
  }

  void _copyDossier(BuildContext context, ComprehensiveShipmentDossierModel? effDossier) {
    final text = ComprehensiveReportExportService.buildDossierText(
      context: context,
      file: file,
      dossier: effDossier,
      logs: logs,
      clearance: clearance,
      warehouse: warehouse,
    );
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    CopyHelper.copy(
      context,
      text,
      customMessage: isAr ? 'تم نسخ ملخص الشحنة الشامل بنجاح' : 'Shipment dossier copied to clipboard',
    );
  }

  void _exportExcel(BuildContext context, ComprehensiveShipmentDossierModel? effDossier) {
    ComprehensiveReportExportService.exportToExcel(
      context: context,
      file: file,
      dossier: effDossier,
      logs: logs,
      clearance: clearance,
      warehouse: warehouse,
    );
  }

  void _exportPdf(BuildContext context, ComprehensiveShipmentDossierModel? effDossier) {
    ComprehensiveReportExportService.printOrSavePdf(
      context: context,
      file: file,
      dossier: effDossier,
      logs: logs,
      clearance: clearance,
      warehouse: warehouse,
    );
  }

  void _exportTsv(BuildContext context, ComprehensiveShipmentDossierModel? effDossier) {
    ComprehensiveReportExportService.exportToTsv(
      context: context,
      file: file,
      dossier: effDossier,
      logs: logs,
      clearance: clearance,
      warehouse: warehouse,
    );
  }

  void _openFullModal(BuildContext context) {
    ComprehensiveDossierExportDialog.show(context, file: file);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effDossier = _resolveDossier(ref);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final l = context.l10n;

    switch (displayMode) {
      case UnifiedExportDisplayMode.dropdown:
        return _buildDropdownMenu(context, effDossier, isAr, l);
      case UnifiedExportDisplayMode.row:
        return _buildActionRow(context, effDossier, isAr, l);
      case UnifiedExportDisplayMode.appBarActions:
        return _buildAppBarActions(context, effDossier, isAr, l);
    }
  }

  Widget _buildDropdownMenu(
    BuildContext context,
    ComprehensiveShipmentDossierModel? effDossier,
    bool isAr,
    AppLocalizations l,
  ) {
    return PopupMenuButton<String>(
      key: const Key('unifiedExportMenuDropdown'),
      tooltip: isAr ? 'أدوات التصدير ومشاركة الملف' : 'Export & Share Dossier',
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cobalt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ios_share_outlined, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              isAr ? 'تصدير الملف' : 'Export Dossier',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
          ],
        ),
      ),
      onSelected: (val) {
        switch (val) {
          case 'copy':
            _copyDossier(context, effDossier);
            break;
          case 'excel':
            _exportExcel(context, effDossier);
            break;
          case 'pdf':
            _exportPdf(context, effDossier);
            break;
          case 'tsv':
            _exportTsv(context, effDossier);
            break;
          case 'modal':
            _openFullModal(context);
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          key: const Key('unifiedCopyDossierItem'),
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy_all_outlined, size: 17, color: AppTheme.cobalt),
              const SizedBox(width: 10),
              Text(
                isAr ? 'نسخ ملخص الشحنة (Copy Dossier)' : 'Copy Dossier Summary',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          key: const Key('unifiedExportExcelItem'),
          value: 'excel',
          child: Row(
            children: [
              const Icon(Icons.table_chart_outlined, size: 17, color: AppTheme.emerald),
              const SizedBox(width: 10),
              Text(
                isAr ? 'تصدير جدول إكسيل (Excel)' : 'Export Excel Ledger',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          key: const Key('unifiedExportPdfItem'),
          value: 'pdf',
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 17, color: AppTheme.charcoal),
              const SizedBox(width: 10),
              Text(
                isAr ? 'طباعة وحفظ PDF' : 'Print & Save PDF',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          key: const Key('unifiedExportTsvItem'),
          value: 'tsv',
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 17, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              Text(
                isAr ? 'تصدير نصي (TSV)' : 'Export Raw TSV',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        if (showModalOption) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            key: const Key('unifiedExportModalItem'),
            value: 'modal',
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 17, color: Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                Text(
                  isAr ? 'تصدير الملف المعتمد (CLO-03)' : 'Official Dossier Bundle (CLO-03)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    ComprehensiveShipmentDossierModel? effDossier,
    bool isAr,
    AppLocalizations l,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 1. Copy Dossier
        ElevatedButton.icon(
          key: const Key('unifiedCopyDossierBtn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.copy_all_outlined, size: 13),
          label: Text(
            isAr ? 'نسخ ملخص الشحنة' : 'Copy Dossier',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _copyDossier(context, effDossier),
        ),

        // 2. Export Excel
        ElevatedButton.icon(
          key: const Key('unifiedExportExcelBtn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.table_chart_outlined, size: 13),
          label: const Text(
            'Excel',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _exportExcel(context, effDossier),
        ),

        // 3. Export PDF
        ElevatedButton.icon(
          key: const Key('unifiedExportPdfBtn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.charcoal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 13),
          label: const Text(
            'PDF',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _exportPdf(context, effDossier),
        ),

        // 4. Export TSV
        ElevatedButton.icon(
          key: const Key('unifiedExportTsvBtn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.description_outlined, size: 13),
          label: const Text(
            'TSV',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _exportTsv(context, effDossier),
        ),

        // 5. Full Official Dossier Modal
        if (showModalOption) ...[
          ElevatedButton.icon(
            key: const Key('unifiedExportModalBtn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.inventory_2_outlined, size: 13),
            label: Text(
              isAr ? 'تصدير الملف المعتمد (CLO-03)' : 'Official Dossier (CLO-03)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _openFullModal(context),
          ),
        ],
      ],
    );
  }

  Widget _buildAppBarActions(
    BuildContext context,
    ComprehensiveShipmentDossierModel? effDossier,
    bool isAr,
    AppLocalizations l,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('appBarCopyDossierBtn'),
          icon: const Icon(Icons.copy_all, color: Colors.white, size: 20),
          tooltip: l.compReportCopyDossierBtn,
          onPressed: () => _copyDossier(context, effDossier),
        ),
        IconButton(
          key: const Key('appBarExportTsvBtn'),
          icon: const Icon(Icons.description_outlined, color: Colors.white, size: 20),
          tooltip: l.compReportExportTsvBtn,
          onPressed: () => _exportTsv(context, effDossier),
        ),
        IconButton(
          key: const Key('appBarExportExcelBtn'),
          icon: const Icon(Icons.table_chart_outlined, color: Colors.white, size: 20),
          tooltip: l.compReportExportExcelBtn,
          onPressed: () => _exportExcel(context, effDossier),
        ),
        IconButton(
          key: const Key('appBarExportPdfBtn'),
          icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
          tooltip: l.compReportPrintPdfBtn,
          onPressed: () => _exportPdf(context, effDossier),
        ),
        if (showModalOption)
          IconButton(
            key: const Key('appBarExportModalBtn'),
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
            tooltip: isAr ? 'تصدير الملف الشامل (CLO-03)' : 'Official Dossier (CLO-03)',
            onPressed: () => _openFullModal(context),
          ),
      ],
    );
  }
}
