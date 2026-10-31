import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../models/cbm_calculator_model.dart';

class CbmExportHelper {
  static Future<void> exportQuickItemsToExcel(
    BuildContext context, {
    required List<CBMItemModel> items,
    required String shipmentMode,
    String? activeSessionCode,
  }) async {
    final l = context.l10n;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.cbmNoPackageLinesToExport,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      l.cargoShippingColUnitNumber,
      l.packageTypeCol,
      l.unitCol,
      l.qtyCol,
      l.lengthCol,
      l.widthCol,
      l.heightCol,
      l.cbmStackable,
      if (shipmentMode == 'air') l.cbmGrossWtUnitKg,
      l.cbmTotalCBM,
      if (shipmentMode == 'air') l.cbmVolumetricWtKg,
      if (shipmentMode == 'air') l.cbmChargeableWtKg,
    ];

    final rows = items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;
      final totalCbm = item.lengthM * item.widthM * item.heightM * item.quantity;
      final totalVol = item.lengthM * item.widthM * item.heightM * item.quantity * kAirVolumetricKgPerCbm;
      final totalGross = item.grossWeightPerUnitKg * item.quantity;
      final chargeable = math.max(totalVol, totalGross);

      return [
        '$idx',
        item.packageType,
        item.unit,
        '${item.quantity}',
        '${item.length}',
        '${item.width}',
        '${item.height}',
        item.isStackable ? l.projectMultiShipmentYes : l.projectMultiShipmentNo,
        if (shipmentMode == 'air') '${item.grossWeightPerUnitKg}',
        totalCbm.toStringAsFixed(3),
        if (shipmentMode == 'air') totalVol.toStringAsFixed(1),
        if (shipmentMode == 'air') chargeable.toStringAsFixed(1),
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.cbmPackageMeasurements,
      importFileNameOrCode: activeSessionCode ?? 'Quick_CBM',
    );
  }

  static Future<void> exportQuickItemsToPdf(
    BuildContext context, {
    required List<CBMItemModel> items,
    required String shipmentMode,
    String? activeSessionCode,
    String? activeSessionTitle,
  }) async {
    final l = context.l10n;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.cbmNoPackageLinesToExport,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      '#',
      l.cooRegistryColType,
      l.qtyCol,
      l.cbmDimensions,
      l.cbmRowLineCbm,
      if (shipmentMode == 'air') l.cbmVolWt,
      if (shipmentMode == 'air') l.cbmChargeable,
    ];

    final rows = items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;
      final totalCbm = item.lengthM * item.widthM * item.heightM * item.quantity;
      final totalVol = item.lengthM * item.widthM * item.heightM * item.quantity * kAirVolumetricKgPerCbm;
      final totalGross = item.grossWeightPerUnitKg * item.quantity;
      final chargeable = math.max(totalVol, totalGross);

      return [
        '$idx',
        item.packageType,
        '${item.quantity}',
        '${item.length}x${item.width}x${item.height} ${item.unit}',
        totalCbm.toStringAsFixed(3),
        if (shipmentMode == 'air') totalVol.toStringAsFixed(1),
        if (shipmentMode == 'air') chargeable.toStringAsFixed(1),
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.cbmCBMCalculator,
      importFileNameOrCode: activeSessionCode ?? 'Quick_CBM',
      headerContext: TableExportHeaderContext(
        title: l.cbmPackageMeasurementsSpecification,
        subtitle: 'Sorour Logistics ERP — ${activeSessionTitle ?? "Quick CBM"}',
        metadata: {
          l.cbmShipmentMode: shipmentMode == 'air' ? l.cbmAir : l.cbmSea,
          l.cbmPackageLines: '${items.length}',
          l.date: DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  static void copyQuickItemsAsTsv(
    BuildContext context, {
    required List<CBMItemModel> items,
    required String shipmentMode,
  }) {
    final l = context.l10n;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.cbmNoPackageLinesToCopy,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      l.cargoShippingColUnitNumber,
      l.packageTypeCol,
      l.unitCol,
      l.qtyCol,
      l.lengthCol,
      l.widthCol,
      l.heightCol,
      l.cbmStackable,
      if (shipmentMode == 'air') l.cbmGrossWtUnitKg,
      l.cbmTotalCBM,
      if (shipmentMode == 'air') l.cbmVolumetricWtKg,
      if (shipmentMode == 'air') l.cbmChargeableWtKg,
    ];

    final rows = items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;
      final totalCbm = item.lengthM * item.widthM * item.heightM * item.quantity;
      final totalVol = item.lengthM * item.widthM * item.heightM * item.quantity * kAirVolumetricKgPerCbm;
      final totalGross = item.grossWeightPerUnitKg * item.quantity;
      final chargeable = math.max(totalVol, totalGross);

      return [
        '$idx',
        item.packageType,
        item.unit,
        '${item.quantity}',
        '${item.length}',
        '${item.width}',
        '${item.height}',
        item.isStackable ? l.projectMultiShipmentYes : l.projectMultiShipmentNo,
        if (shipmentMode == 'air') '${item.grossWeightPerUnitKg}',
        totalCbm.toStringAsFixed(3),
        if (shipmentMode == 'air') totalVol.toStringAsFixed(1),
        if (shipmentMode == 'air') chargeable.toStringAsFixed(1),
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l.cbmPackagesTableCopiedToClipboard,
    );
  }

  static void copyTechnicalFreightSummary(
    BuildContext context, {
    required List<CBMItemModel> items,
    required bool isStackable,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    double totalCbm = 0.0;
    double totalGrossWt = 0.0;
    double totalVolumetricWt = 0.0;
    double totalFloorAreaM2 = 0.0;
    int totalPackagesCount = 0;

    for (var item in items) {
      final lM = item.lengthM;
      final wM = item.widthM;
      final hM = item.heightM;
      final cbm = item.quantity * lM * wM * hM;
      final volWt = item.quantity * lM * wM * hM * kAirVolumetricKgPerCbm;
      final gross = item.quantity * item.grossWeightPerUnitKg;
      final floorArea = ContainerRequirementEngine.calculateFloorAreaM2(lengthM: lM, widthM: wM, quantity: item.quantity);

      totalCbm += cbm;
      totalVolumetricWt += volWt;
      totalGrossWt += gross;
      totalFloorAreaM2 += floorArea;
      totalPackagesCount += item.quantity;
    }

    final totalLdm = ContainerRequirementEngine.calculateLdm(floorAreaM2: totalFloorAreaM2);
    final totalChargeableCbm = ContainerRequirementEngine.calculateLclChargeableCbm(
      physicalCbm: totalCbm,
      floorAreaM2: totalFloorAreaM2,
      isStackable: isStackable,
    );
    final totalRevenueTon = ContainerRequirementEngine.calculateOceanRevenueTon(
      chargeableCbm: totalChargeableCbm,
      totalGrossWeightKg: totalGrossWt,
    );
    final airChargeableWt = totalGrossWt > totalVolumetricWt ? totalGrossWt : totalVolumetricWt;
    final dualRec = ContainerRequirementEngine.calculateBoth(totalCbm: totalCbm, totalWeightKg: totalGrossWt);
    final containerRec = isStackable ? dualRec.stackableResult : dualRec.nonStackableResult;

    final buffer = StringBuffer();
    if (isArabic) {
      buffer.writeln('### تقرير دراسة قياسات وحسابات الشحن');
      buffer.writeln('---');
      buffer.writeln('#### 1. ملخص القياسات والأوزان:');
      buffer.writeln('* **إجمالي الطرود:** $totalPackagesCount طرد (${items.length} بنود)');
      buffer.writeln('* **المساحة الأرضية المشغولة:** ${totalFloorAreaM2.toStringAsFixed(2)} م²');
      buffer.writeln('* **الحجم الفعلي الصافي:** ${totalCbm.toStringAsFixed(4)} م³');
      buffer.writeln('* **إجمالي الوزن القائم:** ${totalGrossWt.toStringAsFixed(1)} كجم (${(totalGrossWt / 1000.0).toStringAsFixed(3)} طن متري)');
      buffer.writeln('* **قابلية الرص:** ${isStackable ? "قابل للرص" : "غير قابل للرص أرضي فقط"}');
      buffer.writeln('');
      buffer.writeln('#### 2. الحسابات المحاسبية حسب وسيلة الشحن:');
      buffer.writeln('* **الشحن البحري LCL (طن الإيراد):** ${totalRevenueTon.toStringAsFixed(3)} RT');
      if (!isStackable) {
        buffer.writeln('* **الحجم المحاسبي البحري (فاقد الارتفاع):** ${totalChargeableCbm.toStringAsFixed(3)} م³ (فرق فراغ رأسي: +${(totalChargeableCbm - totalCbm).toStringAsFixed(3)} م³)');
      }
      buffer.writeln('* **الشحن الجوي (الوزن المحاسبي الخاضع للرسوم):** ${airChargeableWt.toStringAsFixed(1)} كجم (الوزن الحجمي: ${totalVolumetricWt.toStringAsFixed(1)} كجم)');
      buffer.writeln('* **الشحن البري (أمتار التحميل):** ${totalLdm.toStringAsFixed(2)} LDM (من أصل 13.6 LDM للتريلا القياسية)');
      buffer.writeln('');
      buffer.writeln('#### 3. التوصية التشغيلية للمعدات والحاويات:');
      buffer.writeln('* **الوسيلة المقترحة:** ${dualRec.modeRecommendation.recommendedModeAr}');
      buffer.writeln('* **المعدات والحاويات:** ${containerRec.recommendationSummary}');
    } else {
      buffer.writeln('### Freight & CBM Study Technical Report');
      buffer.writeln('---');
      buffer.writeln('#### 1. Cargo Summary Metrics:');
      buffer.writeln('* **Total Packages:** $totalPackagesCount units (${items.length} line items)');
      buffer.writeln('* **Floor Footprint:** ${totalFloorAreaM2.toStringAsFixed(2)} m²');
      buffer.writeln('* **Physical Volume:** ${totalCbm.toStringAsFixed(4)} CBM');
      buffer.writeln('* **Total Gross Weight:** ${totalGrossWt.toStringAsFixed(1)} kg (${(totalGrossWt / 1000.0).toStringAsFixed(3)} Metric Tons)');
      buffer.writeln('* **Stackability:** ${isStackable ? "Stackable" : "Non-Stackable (Floor only)"}');
      buffer.writeln('');
      buffer.writeln('#### 2. Freight Mode Chargeable Metrics:');
      buffer.writeln('* **Ocean LCL Revenue Ton (W/M applied):** ${totalRevenueTon.toStringAsFixed(3)} RT');
      if (!isStackable) {
        buffer.writeln('* **Ocean LCL Billed CBM (Loss of Height @ 2.20m):** ${totalChargeableCbm.toStringAsFixed(3)} CBM (+${(totalChargeableCbm - totalCbm).toStringAsFixed(3)} CBM lost clearance)');
      }
      buffer.writeln('* **Air Chargeable Weight:** ${airChargeableWt.toStringAsFixed(1)} kg (Volumetric Wt: ${totalVolumetricWt.toStringAsFixed(1)} kg)');
      buffer.writeln('* **Road Freight (LDM):** ${totalLdm.toStringAsFixed(2)} LDM (out of 13.6m standard trailer)');
      buffer.writeln('');
      buffer.writeln('#### 3. Equipment & Container Allocation:');
      buffer.writeln('* **Recommended Mode:** ${dualRec.modeRecommendation.recommendedMode}');
      buffer.writeln('* **Container Spec:** ${containerRec.recommendationSummaryEn}');
    }

    CopyHelper.copy(context, buffer.toString());
    AppTheme.snackBar(
      context,
      isArabic ? 'تم نسخ التقرير الفني للشحنة بنجاح' : 'Freight study summary copied to clipboard',
      severity: AppSeverity.success,
    );
  }
}
