import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../models/import_file_model.dart';

/// Header widget for the Master Import Report dialog, including title, quick actions, and shipment filter.
class MasterReportHeader extends StatelessWidget {
  final int? selectedFileId;
  final List<ImportFileModel> displayFiles;
  final List<ImportFileModel> allFiles;
  final List<PurchaseOrderModel> allPOs;
  final int totalFiles;
  final int openFiles;
  final int inProgressFiles;
  final double totalCost;
  final bool isDark;
  final ValueChanged<int?> onShipmentChanged;
  final VoidCallback onClose;
  final VoidCallback? onTimelineRadar;

  const MasterReportHeader({
    super.key,
    required this.selectedFileId,
    required this.displayFiles,
    required this.allFiles,
    required this.allPOs,
    required this.totalFiles,
    required this.openFiles,
    required this.inProgressFiles,
    required this.totalCost,
    required this.isDark,
    required this.onShipmentChanged,
    required this.onClose,
    this.onTimelineRadar,
  });

  void _copyTextReport(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final buffer = StringBuffer();

    if (isAr) {
      buffer.writeln('=====================================================');
      buffer.writeln('نظام إدارة العمليات اللوجستية - سرور للخدمات اللوجستية');
      buffer.writeln('التقرير الشامل الرئيسي لملفات الشحنات الاستيرادية');
      buffer.writeln('التاريخ: ${DateTime.now().toString().substring(0, 10)}');
      buffer.writeln('إجمالي الملفات: $totalFiles | قيد التشغيل: $openFiles | جارية: $inProgressFiles | التكلفة التقديرية: \$$totalCost');
      buffer.writeln('=====================================================\n');

      buffer.writeln('--- 1. مصفوفة المتابعة التشغيلية للشحنات ---');
      buffer.writeln('المسؤول,رقم الملف,اسم الشحنة,المورد الأجنبي,المشروع,قيمة الفاتورة,طريقة الشحن,شرط التسليم,التكلفة التقديرية,تاريخ الجاهزية,موعد الوصول المستهدف,ميناء الشحن,ميناء الوصول,الخط الملاحي والسفينة,رقم الحجز / البوليصة,المرحلة التشغيلية,الإجراء التالي,رقم ACID,نموذج 4,سويفت,إقرار 46,تصريح الإفراج,حالة الملف');
    } else {
      buffer.writeln('=====================================================');
      buffer.writeln('Sorour Logistics ERP - Master Import Report');
      buffer.writeln('Date: ${DateTime.now().toString().substring(0, 10)}');
      buffer.writeln('Total Import Files: $totalFiles | Open: $openFiles | In Progress: $inProgressFiles | Total Cost: \$$totalCost');
      buffer.writeln('=====================================================\n');

      buffer.writeln('--- 1. OPERATIONAL TRACKING MATRIX ---');
      buffer.writeln('Owner,File Code,Shipment Title,Supplier Name,Project,PI Value,Shipping Mode,Incoterm,Estimated Cost,Cargo Ready Date,Target ETA,Port of Loading,Port of Discharge,Carrier & Vessel,Booking / B/L No,Operational Stage,Next Action,ACID Number,Form 4,SWIFT,Form 46,Release Permit,Status');
    }

    for (final f in displayFiles) {
      final double piVal = f.invoicesData.isNotEmpty
          ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
          : f.estimatedCost;

      final shipName = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
      final stg = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
      final act = f.displayNextAction(context.l10n, forExport: true);
      final carrierVessel = f.vesselName != null ? '${f.vesselName} (${f.bookingNo ?? ""})'.trim() : (f.selectedScenario ?? '—');
      final bookingBl = f.blNumber ?? f.bookingNo ?? '—';
      final acid = f.acidNumber ?? '—';
      final f4 = f.form4No ?? '—';
      final swift = f.swiftNo ?? '—';
      final f46 = f.form46No ?? '—';
      final rel = f.customsReleasePermitNo ?? '—';

      buffer.writeln('"${f.owner}","${f.importFileCode}","$shipName","${f.supplierName}","${f.projectNames ?? '—'}",$piVal,"${f.shipmentMode}","${f.incotermCode}",${f.estimatedCost},"${f.cargoReadyDate ?? '—'}","${f.requiredEta ?? '—'}","${f.portOfLoading ?? '—'}","${f.portOfDischarge ?? '—'}","$carrierVessel","$bookingBl","$stg (${f.progressPercent.toInt()}%)","$act","$acid","$f4","$swift","$f46","$rel","${f.status}"');
    }

    if (isAr) {
      buffer.writeln('\n--- 2. التفاصيل الحجمية والطرود لأوامر الشراء المرتبطة ---');
    } else {
      buffer.writeln('\n--- 2. DETAILED POs & CARGO VOLUMES BREAKDOWN ---');
    }
    for (final f in displayFiles) {
      final linkedPOs = allPOs.where((p) => p.importFileId == f.importFileId || (p.importFileCode != null && p.importFileCode == f.importFileCode)).toList();
      double fileCbm = 0.0;
      double fileWt = 0.0;
      for (var po in linkedPOs) {
        final double palletCbm = po.palletPlanItems.isNotEmpty
            ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount))
            : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
                ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
                : 0.0);
        final double palletGross = po.palletPlanItems.isNotEmpty
            ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.grossWeightPerPalletKg * p.palletCount))
            : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);

        if (palletCbm > 0) {
          fileCbm += palletCbm;
          fileWt += palletGross > 0 ? palletGross : (po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
        } else if (po.totalCbm > 0 && po.packingListItems.isEmpty) {
          fileCbm += po.totalCbm;
          fileWt += po.totalGrossWeightKg;
        } else if (po.packingListItems.isNotEmpty) {
          for (var pl in po.packingListItems) {
            fileCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
            fileWt += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
          }
        } else {
          fileCbm += po.totalCbm;
          fileWt += po.totalGrossWeightKg;
        }
      }
      if (isAr) {
        buffer.writeln('الملف: ${f.customFileNumber ?? f.importFileCode} | الشركة: ${f.companyName} | إجمالي CBM: ${fileCbm.toStringAsFixed(3)} م³ | الوزن القائم: ${fileWt.toStringAsFixed(0)} كجم | أوامر الشراء: ${linkedPOs.length}');
        for (var po in linkedPOs) {
          buffer.writeln('   - أمر شراء: ${po.poNumber} | فاتورة مبدئية: ${po.proformaInvoiceNumber ?? "-"} | المورد: ${po.supplierName} | القيمة: ${po.currencyCode ?? "USD"} ${po.totalAmountFob} | الحجم: ${po.totalCbm} م³ | الحالة: ${po.statusLabel(context.l10n)}');
        }
      } else {
        buffer.writeln('File: ${f.customFileNumber ?? f.importFileCode} | Company: ${f.companyName} | Total CBM: ${fileCbm.toStringAsFixed(3)} m3 | Total Wt: ${fileWt.toStringAsFixed(0)} kg | POs Count: ${linkedPOs.length}');
        for (var po in linkedPOs) {
          buffer.writeln('   - PO: ${po.poNumber} | PI: ${po.proformaInvoiceNumber ?? "-"} | Supplier: ${po.supplierName} | Amount: ${po.currencyCode ?? "USD"} ${po.totalAmountFob} | CBM: ${po.totalCbm} m3 | Status: ${po.statusLabel(context.l10n)}');
        }
      }
    }

    CopyHelper.copy(context, buffer.toString(), customMessage: l.reportCopiedToClipboard);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header Row with Actions
        Row(
          children: [
            const Icon(Icons.summarize, color: AppTheme.cobalt, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.masterImportReportTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  if (selectedFileId != null && displayFiles.isNotEmpty)
                    Text(
                      '${l.filteredForShipment} ${DisplayNameResolver.resolveShipmentTitle(displayFiles.first, isArabic: isAr)}',
                      style: const TextStyle(
                        color: AppTheme.cobalt,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            AppButton(
              label: l.printReport,
              icon: Icons.print,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: () => _copyTextReport(context),
            ),
            if (selectedFileId != null && onTimelineRadar != null) ...[
              const SizedBox(width: 8),
              AppButton(
                label: isAr ? 'رادار التتبع الزمني - 36 محطة' : 'Timeline Radar - 36 Stations',
                icon: Icons.history_toggle_off_rounded,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: onTimelineRadar,
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filter Bar inside Dialog Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_alt, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                l.filterReportByShipment,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SearchableDropdownField<int?>(
                  value: selectedFileId,
                  labelText: '',
                  items: [
                    SearchableDropdownItem<int?>(
                      value: null,
                      label: '🌐 ${l.allShipmentFiles}',
                    ),
                    ...allFiles.map((f) => SearchableDropdownItem<int?>(
                          value: f.importFileId,
                          label: '📦 ${f.primaryNameWithCode} - ${f.supplierName} (${f.companyName})',
                        )),
                  ],
                  onChanged: onShipmentChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
