import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../models/shipment_audit_timeline_model.dart';
import 'timeline/meeting_directives_section.dart';
import 'timeline/milestones_table_tab.dart';
import 'timeline/timeline_export_helper.dart';
import 'timeline/timeline_header_strip.dart';
import 'timeline/timeline_radar_strip.dart';
import 'timeline/vessel_tracking_tab.dart';

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

class _ShipmentAuditTimelineDialogState extends ConsumerState<ShipmentAuditTimelineDialog>
    with SingleTickerProviderStateMixin {
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
    if (widget.importFileId <= 0) {
      setState(() {
        _errorMessage = 'رقم ملف الشحنة غير صالح (${widget.importFileId}).';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/file-closure/audit-timeline/${widget.importFileId}');
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
        final errText = ApiError.message(e);
        setState(() {
          _errorMessage = errText.isNotEmpty ? errText : e.toString();
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
      await dio.put('/file-closure/audit-timeline/${widget.importFileId}/directives', data: {
        'directives': _directivesController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, 'تم حفظ محضر وتوجيهات الاجتماع بنجاح.', severity: AppSeverity.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, 'تعذر حفظ التوجيهات: ${ApiError.message(e)}', severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDirectives = false);
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
      child: SelectionArea(
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
                        TimelineHeaderStrip(
                          data: _data!,
                          isDark: isDark,
                          onCopyAllTable: () => TimelineExportHelper.copyAllTable(context, _data!),
                          onExportExcel: () =>
                              TimelineExportHelper.exportExcelCsv(context, _data!, _directivesController.text),
                          onPrintPdf: () =>
                              TimelineExportHelper.printOrExportPdf(context, _data!, _directivesController.text),
                        ),
                        const Divider(height: 16),

                        // Top Financial & Transit Radar Strip
                        TimelineRadarStrip(radar: _data!.financialRadar, isDark: isDark),
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
                              MilestonesTableTab(milestones: _data!.milestones, isDark: isDark),
                              VesselTrackingTab(pulses: _data!.vesselTrackingPulse, isDark: isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Bottom Meeting Directives Editor
                        MeetingDirectivesSection(
                          controller: _directivesController,
                          isSaving: _isSavingDirectives,
                          isDark: isDark,
                          onSave: _saveDirectives,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
