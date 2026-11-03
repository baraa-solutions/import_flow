import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/models/customs_clearance_model.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../../shipment_updates/widgets/shipment_update_dialog.dart';
import '../../../warehouse_receiving/models/warehouse_receiving_model.dart';
import '../../models/comprehensive_dossier_model.dart';
import '../../services/comprehensive_report_export_service.dart';

/// Top App Bar / PageHeader Coordinator for Comprehensive Import File Report.
/// Adheres to Canonical PageHeader (Type C) design system.
class ComprehensiveReportHeader extends StatelessWidget implements PreferredSizeWidget {
  final ImportFileModel? selectedFile;
  final ComprehensiveShipmentDossierModel? dossier;
  final ShipmentUpdatesState updatesState;
  final CustomsClearanceModel? clearance;
  final WarehouseReceivingModel? warehouse;
  final VoidCallback onBackPressed;

  const ComprehensiveReportHeader({
    super.key,
    required this.selectedFile,
    required this.dossier,
    required this.updatesState,
    required this.clearance,
    required this.warehouse,
    required this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(54.0);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return PageHeader(
      leading: IconButton(
        key: const Key('backToOperationsBtn'),
        icon: const Icon(Icons.arrow_back, color: AppTheme.white),
        tooltip: isAr ? 'العودة إلى العمليات التشغيلية' : 'Back to Operational Details',
        onPressed: onBackPressed,
      ),
      icon: Icons.summarize_outlined,
      iconColor: AppTheme.cobalt,
      title: l.compReportScreenTitle,
      actions: [
        if (selectedFile != null) ...[
          IconButton(
            icon: const Icon(Icons.copy_all, color: AppTheme.white, size: 20),
            tooltip: l.compReportCopyDossierBtn,
            onPressed: () {
              final dossierText = ComprehensiveReportExportService.buildDossierText(
                context: context,
                file: selectedFile!,
                dossier: dossier,
                logs: updatesState.logs,
                clearance: clearance,
                warehouse: warehouse,
              );
              CopyHelper.copy(
                context,
                dossierText,
                customMessage: l.compReportCopyDossierSuccess,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined, color: AppTheme.white, size: 20),
            tooltip: l.compReportExportTsvBtn,
            onPressed: () => ComprehensiveReportExportService.exportToTsv(
              context: context,
              file: selectedFile!,
              dossier: dossier,
              logs: updatesState.logs,
              clearance: clearance,
              warehouse: warehouse,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: AppTheme.white, size: 20),
            tooltip: l.compReportExportExcelBtn,
            onPressed: () => ComprehensiveReportExportService.exportToExcel(
              context: context,
              file: selectedFile!,
              dossier: dossier,
              logs: updatesState.logs,
              clearance: clearance,
              warehouse: warehouse,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.white, size: 20),
            tooltip: l.compReportPrintPdfBtn,
            onPressed: () => ComprehensiveReportExportService.printOrSavePdf(
              context: context,
              file: selectedFile!,
              dossier: dossier,
              logs: updatesState.logs,
              clearance: clearance,
              warehouse: warehouse,
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.cobalt.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.published_with_changes, color: AppTheme.white, size: 16),
              label: Text(
                l.compReportAddUpdateBtn,
                style: const TextStyle(color: AppTheme.white, fontSize: 12),
              ),
              onPressed: () => ShipmentUpdateDialog.show(
                context,
                initialFileId: selectedFile!.importFileId,
                initialFileCode: selectedFile!.displayName,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        const BackToDashboardButton(),
        const SizedBox(width: 8),
      ],
    );
  }
}
