import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/network/api_client.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../models/shipment_audit_timeline_model.dart';

void showShipmentAuditTimelineDialog(BuildContext context, {required int importFileId}) {
  showDialog(
    context: context,
    builder: (ctx) => ShipmentAuditTimelineDialog(importFileId: importFileId),
  );
}

class ShipmentAuditTimelineDialog extends ConsumerStatefulWidget {
  final int importFileId;

  const ShipmentAuditTimelineDialog({
    super.key,
    required this.importFileId,
  });

  @override
  ConsumerState<ShipmentAuditTimelineDialog> createState() => _ShipmentAuditTimelineDialogState();
}

class _ShipmentAuditTimelineDialogState extends ConsumerState<ShipmentAuditTimelineDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _directivesController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  ShipmentAuditTimelineModel? _data;
  bool _isSavingDirectives = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTimelineData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _directivesController.dispose();
    super.dispose();
  }

  Future<void> _loadTimelineData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/v1/file-closure/audit-timeline/${widget.importFileId}');
      final model = ShipmentAuditTimelineModel.fromJson(response.data as Map<String, dynamic>);

      if (mounted) {
        setState(() {
          _data = model;
          _directivesController.text = model.meetingDirectives ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveDirectives() async {
    if (_data == null) return;
    setState(() => _isSavingDirectives = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/api/v1/file-closure/audit-timeline/${widget.importFileId}/directives',
        data: {'meeting_directives': _directivesController.text},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ توجيهات ومحضر اجتماع الشحنة بنجاح في قاعدة البيانات.'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ تعذر حفظ التوجيهات: $e'),
            backgroundColor: AppTheme.wcagCrimson,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDirectives = false);
      }
    }
  }

  Future<void> _exportExcelCsv() async {
    if (_data == null) return;
    final sb = StringBuffer();

    // UTF-8 BOM
    sb.write('\uFEFF');

    sb.writeln('محضر ورادار التتبع الزمني الشامل للشحنة (36 محطة وسجل تتبع الباخرة)');
    sb.writeln('كود الشحنة,${_data!.importFileCode},رقم الملف,${_data!.customFileNumber ?? "-"}');
    sb.writeln('الشركة المستوردة,${_data!.companyName},المورد الأجنبي,${_data!.supplierName}');
    sb.writeln('الخط الملاحي,${_data!.shippingLineName ?? "-"},رقم البوليصة,${_data!.billOfLadingNo ?? "-"}');
    sb.writeln('ميناء الشحن,${_data!.portOfLoading ?? "-"},ميناء الوصول,${_data!.portOfDischarge ?? "-"}');
    sb.writeln('تاريخ بدء أرضيات الميناء,${_data!.financialRadar.portStorageStartDate ?? "-"},سماح الميناء,${_data!.financialRadar.portStorageFreeDays} أيام');
    sb.writeln('تاريخ بدء غرامات الحاوية,${_data!.financialRadar.demurrageStartDate ?? "-"},سماح الخط,${_data!.financialRadar.demurrageFreeDays} يوما');
    sb.writeln('التاريخ المتوقع لوصول المخزن,${_data!.financialRadar.expectedWarehouseDeliveryDate ?? "-"},التاريخ الفعلي للمخزن,${_data!.financialRadar.actualWarehouseDeliveryDate ?? "-"}');
    sb.writeln();

    sb.writeln('--- مصفوفة الـ 36 محطة زمنية والملاحظات التشغيلية ---');
    sb.writeln('#,كود المحطة,اسم المحطة والحدث الزمني,المرحلة,التاريخ المخطط,التاريخ الفعلي,الفارق (أيام),مدة الإنجاز,الحالة,الملاحظات والتوجيهات التشغيلية');

    for (final m in _data!.milestones) {
      final safeName = m.nameAr.replaceAll(',', ' - ');
      final safeNotes = (m.notes ?? '').replaceAll(',', ' - ').replaceAll('\n', ' ');
      sb.writeln('${m.seq},${m.code},"$safeName",Phase ${m.phaseNumber},${m.plannedDate ?? "-"},${m.actualDate ?? "-"},${m.varianceDays},${m.tatDisplay ?? "-"},${m.status},"$safeNotes"');
    }

    sb.writeln();
    sb.writeln('--- سجل نبضات تتبع الباخرة كل 3 أيام ---');
    sb.writeln('رقم التحديث,تاريخ التحديث,الموقع الجغرافي للباخرة,الـ ETA في هذا اليوم,أيام الانحراف,الملاحظات المكتوبة');

    for (final p in _data!.vesselTrackingPulse) {
      final safeLoc = p.vesselLocation.replaceAll(',', ' - ');
      final safeRem = (p.remarks ?? '').replaceAll(',', ' - ');
      sb.writeln('تحديث ${p.updateSeq},${p.trackingDate},"$safeLoc",${p.currentEta},+${p.delayDays} يوم,"$safeRem"');
    }

    sb.writeln();
    sb.writeln('--- محضر وتوجيهات الاجتماع التشغيلي ---');
    sb.writeln('"${_directivesController.text.replaceAll('"', '""')}"');

    final csvBytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(sb.toString())];
    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: csvBytes,
      stageName: 'Timeline-Audit-36-Milestones',
      importFileNameOrCode: _data!.importFileCode,
      extension: 'csv',
    );
  }

  void _copyAllTable() {
    if (_data == null) return;
    final sb = StringBuffer();
    sb.writeln('محضر التتبع الزمني للشحنة: ${_data!.importFileCode} (${_data!.customFileNumber ?? ""})');
    sb.writeln('أرضيات الميناء تبدأ: ${_data!.financialRadar.portStorageStartDate} | غرامات الحاوية تبدأ: ${_data!.financialRadar.demurrageStartDate}');
    sb.writeln('المتوقع للمخزن: ${_data!.financialRadar.expectedWarehouseDeliveryDate} | الفعلي: ${_data!.financialRadar.actualWarehouseDeliveryDate ?? "جاري"}');
    sb.writeln('------------------------------------------------------------');
    for (final m in _data!.milestones) {
      sb.writeln('#${m.seq} | ${m.nameAr} | مخطط: ${m.plannedDate ?? "-"} | فعلي: ${m.actualDate ?? "-"} | فارق: ${m.varianceDays} يوم | مدة: ${m.tatDisplay ?? "-"} | حالة: ${m.status} | ملاحظات: ${m.notes ?? ""}');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 تم نسخ جدول الـ 36 محطة والملاحظات بالكامل إلى الحافظة!'), backgroundColor: AppTheme.cobalt),
    );
  }

  Future<void> _printOrExportPdf() async {
    if (_data == null) return;
    try {
      final doc = pw.Document();
      final font = await PdfGoogleFonts.cairoRegular();
      final fontBold = await PdfGoogleFonts.cairoBold();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('تقرير ومحضر التتبع الزمني والرقابي الشامل للشحنة', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  pw.Text('${_data!.importFileCode} | ${_data!.customFileNumber ?? ""}', style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المورد: ${_data!.supplierName}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('الخط الملاحي: ${_data!.shippingLineName ?? "-"}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('البوليصة: ${_data!.billOfLadingNo ?? "-"}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('أرضيات الميناء: ${_data!.financialRadar.portStorageStartDate}', style: pw.TextStyle(fontSize: 10, font: fontBold, color: PdfColors.red900)),
                  pw.Text('غرامات الحاوية: ${_data!.financialRadar.demurrageStartDate}', style: pw.TextStyle(fontSize: 10, font: fontBold, color: PdfColors.red900)),
                  pw.Text('المتوقع للمخزن: ${_data!.financialRadar.expectedWarehouseDeliveryDate}', style: pw.TextStyle(fontSize: 10, font: fontBold, color: PdfColors.green900)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('مصفوفة الـ 36 محطة زمنية والملاحظات:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['#', 'المحطة والحدث الزمني', 'المخطط', 'الفعلي', 'الفارق', 'المدة', 'الحالة', 'الملاحظات التشغيلية والتوجيهات'],
              data: _data!.milestones.map((m) => [
                '${m.seq}',
                m.nameAr,
                m.plannedDate ?? '-',
                m.actualDate ?? '-',
                '${m.varianceDays}',
                m.tatDisplay ?? '-',
                m.status,
                m.notes ?? '-',
              ]).toList(),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 12),
            pw.Text('توجيهات ومحضر الاجتماع:', style: pw.TextStyle(font: fontBold, fontSize: 11)),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text(_directivesController.text.isNotEmpty ? _directivesController.text : 'لا توجد ملاحظات إضافية.', style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء ملف الطباعة: $e'), backgroundColor: AppTheme.wcagCrimson),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.92,
        padding: const EdgeInsets.all(18),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.wcagCrimson),
                        const SizedBox(height: 12),
                        Text('حدث خطأ أثناء تحميل بيانات الجدول الزمني:\n$_errorMessage', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadTimelineData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      _buildHeader(isDark),
                      const Divider(height: 16),

                      // Top Financial & Transit Radar Strip
                      _buildRadarStrip(isDark),
                      const SizedBox(height: 10),

                      // Tab Bar
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: AppTheme.cobalt,
                          labelColor: AppTheme.cobalt,
                          unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          tabs: [
                            Tab(
                              icon: const Icon(Icons.table_chart, size: 18),
                              text: 'مصفوفة الـ 36 محطة زمنية والملاحظات (${_data!.milestones.length})',
                            ),
                            Tab(
                              icon: const Icon(Icons.radar, size: 18),
                              text: 'سجل نبضات تتبع الباخرة كل 3 أيام (${_data!.vesselTrackingPulse.length} تحديثات)',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildMilestonesTableTab(isDark),
                            _buildVesselTrackingTab(isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom Meeting Directives Editor
                      _buildMeetingDirectivesSection(isDark),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.history_toggle_off, color: AppTheme.cobalt, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'محضر ورادار التتبع الزمني الشامل للشحنة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _data!.importFileCode,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  if (_data!.customFileNumber != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${_data!.customFileNumber})',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'المورد: ${_data!.supplierName} │ الخط: ${_data!.shippingLineName ?? "-"} │ البوليصة: ${_data!.billOfLadingNo ?? "-"} │ ميناء الوصول: ${_data!.portOfDischarge ?? "-"} │ الحاويات: ${_data!.containersSummary ?? "-"}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('نسخ الجدول'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cobalt,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _copyAllTable,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_download, size: 16),
              label: const Text('تصدير Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _exportExcelCsv,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: const Text('طباعة / PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.charcoal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _printOrExportPdf,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRadarStrip(bool isDark) {
    final r = _data!.financialRadar;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // 1. Storage Radar
          Expanded(
            child: _buildRadarCardItem(
              title: 'أرضيات الميناء (Storage)',
              icon: Icons.domain,
              dateStr: r.portStorageStartDate ?? 'غير محدد',
              subtitle: 'سماح: ${r.portStorageFreeDays} أيام │ متبقي: ${r.portStorageDaysRemaining ?? "-"} أيام',
              statusBadge: r.portStorageStatus,
              badgeColor: r.portStorageStatus == 'SAFE' ? AppTheme.emerald : AppTheme.wcagCrimson,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // 2. Demurrage Radar
          Expanded(
            child: _buildRadarCardItem(
              title: 'غرامات الحاوية (Demurrage)',
              icon: Icons.directions_boat,
              dateStr: r.demurrageStartDate ?? 'غير محدد',
              subtitle: 'سماح: ${r.demurrageFreeDays} يوماً │ متبقي: ${r.demurrageDaysRemaining ?? "-"} أيام',
              statusBadge: r.demurrageStatus,
              badgeColor: r.demurrageStatus == 'SAFE' ? AppTheme.emerald : AppTheme.wcagCrimson,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // 3. Dynamic Warehouse Delivery ETA
          Expanded(
            child: _buildRadarCardItem(
              title: 'المتوقع لوصول المخزن (ديناميكي)',
              icon: Icons.schedule,
              dateStr: r.expectedWarehouseDeliveryDate ?? 'غير محدد',
              subtitle: 'محسوب آلياً بناءً على تتبع الباخرة',
              statusBadge: 'هدف استرشادي',
              badgeColor: AppTheme.cobalt,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // 4. Actual Warehouse Intake
          Expanded(
            child: _buildRadarCardItem(
              title: 'الوصول الفعلي للمخزن (GRN)',
              icon: Icons.inventory_2,
              dateStr: r.actualWarehouseDeliveryDate ?? '⏳ جاري الإبحار والتخليص',
              subtitle: r.warehouseVarianceDays != null
                  ? (r.warehouseVarianceDays == 0 ? 'في الموعد المحدد' : 'انحراف: +${r.warehouseVarianceDays} يوم')
                  : 'بانتظار التفريغ',
              statusBadge: r.actualWarehouseDeliveryDate != null ? '✅ تم الاستلام' : 'قيد المتابعة',
              badgeColor: r.actualWarehouseDeliveryDate != null ? AppTheme.emerald : Colors.blueGrey,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarCardItem({
    required String title,
    required IconData icon,
    required String dateStr,
    required String subtitle,
    required String statusBadge,
    required Color badgeColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.cobalt),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LtrText(
            dateStr,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesTableTab(bool isDark) {
    final milestones = _data!.milestones;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1150),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
              ),
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
              dataRowMinHeight: 38,
              dataRowMaxHeight: 52,
              horizontalMargin: 12,
              columnSpacing: 14,
              columns: const [
                DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('المحطة والحدث الزمني')),
                DataColumn(label: Text('المرحلة')),
                DataColumn(label: Text('المخطط')),
                DataColumn(label: Text('الفعلي')),
                DataColumn(label: Text('الفارق')),
                DataColumn(label: Text('مدة الإنجاز')),
                DataColumn(label: Text('الحالة')),
                DataColumn(label: Text('الملاحظات والتوجيهات التشغيلية')),
              ],
              rows: milestones.map((m) {
                final isCrit = m.isCriticalWatchpoint;
                final isOverdue = m.varianceDays > 0;

                Color rowBgColor = Colors.transparent;
                if (isCrit) {
                  rowBgColor = AppTheme.cobalt.withValues(alpha: isDark ? 0.15 : 0.08);
                } else if (isOverdue && m.status != 'COMPLETED') {
                  rowBgColor = AppTheme.wcagCrimson.withValues(alpha: isDark ? 0.15 : 0.06);
                }

                return DataRow(
                  color: WidgetStateProperty.all(rowBgColor),
                  cells: [
                    DataCell(
                      Text(
                        '${m.seq}',
                        style: TextStyle(
                          fontWeight: isCrit ? FontWeight.bold : FontWeight.normal,
                          color: isCrit ? AppTheme.cobalt : null,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCrit) ...[
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            m.nameAr,
                            style: TextStyle(
                              fontWeight: isCrit ? FontWeight.bold : FontWeight.w600,
                              fontSize: 12,
                              color: isCrit ? (isDark ? Colors.lightBlueAccent : AppTheme.cobalt) : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('P${m.phaseNumber}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                      LtrText(
                        m.plannedDate ?? '-',
                        style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                      ),
                    ),
                    DataCell(
                      LtrText(
                        m.actualDate ?? '-',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: m.actualDate != null ? FontWeight.bold : FontWeight.normal,
                          color: m.actualDate != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                        ),
                      ),
                    ),
                    DataCell(
                      m.varianceDays == 0
                          ? const Text('0', style: TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold))
                          : Text(
                              '+${m.varianceDays} يوم',
                              style: const TextStyle(fontSize: 11, color: AppTheme.wcagCrimson, fontWeight: FontWeight.bold),
                            ),
                    ),
                    DataCell(
                      Text(
                        m.tatDisplay ?? '-',
                        style: const TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(_buildStatusBadge(m.status)),
                    DataCell(
                      SizedBox(
                        width: 320,
                        child: CopyableTableCell(
                          value: m.notes ?? '',
                          rowSummary: '${m.seq} - ${m.nameAr}',
                          child: Text(
                            m.notes ?? '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVesselTrackingTab(bool isDark) {
    final pulses = _data!.vesselTrackingPulse;

    if (pulses.isEmpty) {
      return const Center(child: Text('لا توجد نبضات تتبع مسجلة لهذه الشحنة حتى الآن.'));
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1050),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
              ),
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
              dataRowMinHeight: 40,
              dataRowMaxHeight: 52,
              horizontalMargin: 12,
              columnSpacing: 14,
              columns: const [
                DataColumn(label: Text('# التحديث')),
                DataColumn(label: Text('تاريخ ووقت التحديث')),
                DataColumn(label: Text('الموقع الجغرافي للباخرة')),
                DataColumn(label: Text('الـ ETA المعلن')),
                DataColumn(label: Text('أيام الانحراف')),
                DataColumn(label: Text('حالة الرسو')),
                DataColumn(label: Text('الملاحظات المكتوبة من مسؤول الشحن والخط')),
              ],
              rows: pulses.map((p) {
                final isAta = p.isAtaConfirmed;
                return DataRow(
                  color: WidgetStateProperty.all(
                    isAta ? AppTheme.emerald.withValues(alpha: isDark ? 0.15 : 0.08) : Colors.transparent,
                  ),
                  cells: [
                    DataCell(
                      Text(
                        'تحديث ${p.updateSeq}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                    DataCell(
                      LtrText(p.trackingDate, style: const TextStyle(fontSize: 11)),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isAta ? Icons.anchor : Icons.navigation, size: 14, color: isAta ? AppTheme.emerald : AppTheme.cobalt),
                          const SizedBox(width: 6),
                          Text(p.vesselLocation, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    DataCell(
                      LtrText(p.currentEta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.cobalt)),
                    ),
                    DataCell(
                      p.delayDays == 0
                          ? const Text('0 يوم', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 11))
                          : Text('+${p.delayDays} يوم تأخير', style: const TextStyle(color: AppTheme.wcagCrimson, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    DataCell(
                      isAta
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(4)),
                              child: const Text('⚓ رسو مؤكد (ATA)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          : const Text('إبحار نشط', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    ),
                    DataCell(
                      SizedBox(
                        width: 320,
                        child: CopyableTableCell(
                          value: p.remarks ?? '',
                          rowSummary: 'تحديث ${p.updateSeq} - ${p.vesselLocation}',
                          child: Text(
                            p.remarks ?? '-',
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingDirectivesSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rate_review, color: AppTheme.cobalt, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'محضر مناقشة وتوجيهات الشحنة التشغيلية (Meeting Action Directives)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _directivesController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: InputDecoration(
                    hintText: 'اكتب هنا القرارات التشغيلية ومحضر اجتماع الشحنة ليتم حفظها وتضمينها في ملفات التصدير...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            icon: _isSavingDirectives
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 16),
            label: const Text('حفظ التوجيهات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            onPressed: _isSavingDirectives ? null : _saveDirectives,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg = Colors.white;
    String label;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = AppTheme.emerald;
        label = 'منجز';
        break;
      case 'IN_PROGRESS':
        bg = AppTheme.cobalt;
        label = 'جاري';
        break;
      case 'WATCHPOINT':
        bg = Colors.amber.shade800;
        label = '🚨 رادار مالي';
        break;
      case 'TARGET':
        bg = Colors.purple.shade700;
        label = '🎯 هدف';
        break;
      case 'OVERDUE':
        bg = AppTheme.wcagCrimson;
        label = 'متأخر';
        break;
      default:
        bg = Colors.grey.shade600;
        label = 'قيد الانتظار';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
