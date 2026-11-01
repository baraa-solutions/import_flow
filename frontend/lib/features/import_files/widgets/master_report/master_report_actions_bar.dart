import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/import_file_model.dart';

/// Actions bar at the bottom of the Master Import Report dialog.
class MasterReportActionsBar extends StatelessWidget {
  final List<ImportFileModel> reportFiles;
  final VoidCallback onClose;

  const MasterReportActionsBar({
    super.key,
    required this.reportFiles,
    required this.onClose,
  });

  Future<void> _exportCsv(BuildContext context) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    if (isAr) {
      buffer.writeln('المسؤول,كود الملف,اسم الشحنة,المورد الأجنبي,المشروع,قيمة الفاتورة المبدئية,طريقة الشحن,شرط التسليم,التكلفة التقديرية,تاريخ الجاهزية,موعد الوصول المستهدف,ميناء الشحن,ميناء الوصول,الخط الملاحي والسفينة,رقم الحجز / بوليصة الشحن,المرحلة التشغيلية,نسبة الإنجاز,الإجراء التالي,رقم ACID,نموذج 4,سويفت,إقرار 46,تصريح الإفراج,حالة الملف');
    } else {
      buffer.writeln('Owner,File Code,Shipment Title,Supplier Name,Project,PI Value,Shipping Mode,Incoterm,Estimated Cost,Cargo Ready Date,Target ETA,Port of Loading,Port of Discharge,Carrier & Vessel,Booking / B/L No,Operational Stage,Progress %,Next Action,ACID Number,Form 4,SWIFT,Form 46,Release Permit,Status');
    }

    for (final f in reportFiles) {
      final double piVal = f.invoicesData.isNotEmpty
          ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
          : f.estimatedCost;
      final shipName = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
      final stg = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
      final act = f.displayNextAction(context.l10n, forExport: true);
      final carrierVessel = f.vesselName != null
          ? '${f.vesselName} (${f.bookingNo ?? ""})'.trim()
          : (f.selectedScenario ?? '—');
      final bookingBl = f.blNumber ?? f.bookingNo ?? '—';
      final acid = f.acidNumber ?? '—';
      final f4 = f.form4No ?? '—';
      final swift = f.swiftNo ?? '—';
      final f46 = f.form46No ?? '—';
      final rel = f.customsReleasePermitNo ?? '—';

      buffer.writeln('"${f.owner}","${f.importFileCode}","$shipName","${f.supplierName}","${f.projectNames ?? '—'}",$piVal,"${f.shipmentMode}","${f.incotermCode}",${f.estimatedCost},"${f.cargoReadyDate ?? '—'}","${f.requiredEta ?? '—'}","${f.portOfLoading ?? '—'}","${f.portOfDischarge ?? '—'}","$carrierVessel","$bookingBl","$stg",${f.progressPercent.toInt()}," $act","$acid","$f4","$swift","$f46","$rel","${f.status}"');
    }

    final filename = 'Reports_Import_Files_Master_Summary_${DateTime.now().millisecondsSinceEpoch}.csv';
    onClose();
    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: l.saveComprehensiveReportDialogTitle,
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppButton(
          label: l.close,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.medium,
          onPressed: onClose,
        ),
        const SizedBox(width: 12),
        AppButton(
          label: l.exportReportExcelPdf,
          icon: Icons.download,
          variant: AppButtonVariant.success,
          size: AppButtonSize.medium,
          onPressed: () => _exportCsv(context),
        ),
      ],
    );
  }
}
