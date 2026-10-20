import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/providers/navigation_provider.dart';
import '../models/vessel_tracking_model.dart';
import '../providers/vessel_tracking_provider.dart';

class VesselTrackingRadarScreen extends ConsumerStatefulWidget {
  const VesselTrackingRadarScreen({super.key});

  @override
  ConsumerState<VesselTrackingRadarScreen> createState() =>
      _VesselTrackingRadarScreenState();
}

class _VesselTrackingRadarScreenState
    extends ConsumerState<VesselTrackingRadarScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filterQuery = '';
  final Set<int> _simulatingFileIds = {};

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _filterQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(vesselTrackingRadarProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'رادار التتبع الحي لخطوط الملاحة والسفن',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.flatCharcoal,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'مراقبة فورية لمواقع الأساطيل ومواقيت الوصول الديناميكية',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات الفورية',
            icon: const Icon(Icons.refresh, color: AppTheme.flatCobalt),
            onPressed: () =>
                ref.read(vesselTrackingRadarProvider.notifier).fetchRadarOverview(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: radarState.when(
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.flatCobalt),
                SizedBox(height: 16),
                Text(
                  'جاري استقبال إشارات الرادار والبيانات الملاحية...',
                  style: TextStyle(color: AppTheme.flatCharcoal, fontSize: 14),
                ),
              ],
            ),
          ),
          error: (err, _) => Center(
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.flatCrimson, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'تعذر الاتصال بخدمة الرادار الملاحي: $err',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppTheme.flatCharcoal),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.flatCobalt,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => ref
                          .read(vesselTrackingRadarProvider.notifier)
                          .fetchRadarOverview(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (overview) => _buildRadarContent(overview),
        ),
      ),
    );
  }

  Widget _buildRadarContent(LiveRadarOverviewModel overview) {
    final filteredShipments = overview.shipments.where((s) {
      if (_filterQuery.isEmpty) return true;
      final matchVessel = (s.vesselName ?? '').toLowerCase().contains(_filterQuery);
      final matchCode = s.trackingCode.toLowerCase().contains(_filterQuery);
      final matchLine = (s.shippingLineName ?? '').toLowerCase().contains(_filterQuery);
      final matchPol = s.polPortName.toLowerCase().contains(_filterQuery);
      final matchPod = s.podPortName.toLowerCase().contains(_filterQuery);
      return matchVessel || matchCode || matchLine || matchPol || matchPod;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI Summary Cards ─────────────────────────────────────────────
          _buildKpiMetrics(overview),
          const SizedBox(height: 16),

          // ── Search & Filter Bar ───────────────────────────────────────────
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.black45),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'البحث باسم السفينة، الخط الملاحي، كود التتبع، أو الميناء...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.black45),
                      onPressed: () => _searchCtrl.clear(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Vessel Tracking Cards List ────────────────────────────────────
          if (filteredShipments.isEmpty)
            Card(
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.directions_boat_outlined,
                          size: 48, color: Colors.black26),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد شحنات بحرية مطابقة لخيارات البحث الحالية',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredShipments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildVesselCard(filteredShipments[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiMetrics(LiveRadarOverviewModel overview) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final cardWidth = isDesktop
            ? (constraints.maxWidth - (5 * 12)) / 6
            : (constraints.maxWidth - 12) / 2;

        final items = [
          _KpiItem('إجمالي الأسطول', '${overview.totalActiveShipments}',
              Icons.directions_boat, AppTheme.flatCobalt),
          _KpiItem('في عرض البحر', '${overview.underwayCount}',
              Icons.waves, AppTheme.flatCobalt),
          _KpiItem('تقترب من الميناء', '${overview.approachingPortCount}',
              Icons.anchor, AppTheme.flatEmerald),
          _KpiItem('راسي بالميناء', '${overview.inPortCount}',
              Icons.location_city, AppTheme.flatCharcoal),
          _KpiItem('في الموعد المحدد', '${overview.onTimeCount}',
              Icons.check_circle, AppTheme.flatEmerald),
          _KpiItem('تأخير مسجل', '${overview.delayedCount}',
              Icons.warning_amber_rounded,
              overview.delayedCount > 0 ? AppTheme.flatCrimson : Colors.grey),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(item),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiItem item) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                  Text(
                    item.label,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVesselCard(ShipmentTrackingModel s) {
    final isSimulating = _simulatingFileIds.contains(s.importFileId);
    final isArrived = s.trackingMilestone.contains('In Port') ||
        s.trackingMilestone.contains('Berthed') ||
        s.voyageProgressPct >= 100.0;

    // Delay Badge Color & Label
    Color delayColor = AppTheme.flatEmerald;
    String delayLabel = 'في الموعد المحدد';
    if (s.delaySeverity == 'CRITICAL_DELAY') {
      delayColor = AppTheme.flatCrimson;
      delayLabel = 'تأخير حرج (+${s.delayHours.toStringAsFixed(1)} ساعة)';
    } else if (s.delaySeverity == 'MINOR_DELAY') {
      delayColor = AppTheme.flatOrange;
      delayLabel = 'تأخير طفيف (+${s.delayHours.toStringAsFixed(1)} ساعة)';
    }

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card Header: Vessel, Carrier, Status ────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.flatCobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_boat,
                      color: AppTheme.flatCobalt, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s.vesselName ?? 'سفينة غير محددة',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.flatCharcoal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (s.shippingLineName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: Colors.blueGrey.shade200),
                              ),
                              child: Text(
                                s.shippingLineName!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'كود التتبع: ${s.trackingCode}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14),
                            tooltip: 'نسخ كود التتبع',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                CopyHelper.copy(context, s.trackingCode),
                          ),
                          if (s.vesselImo != null) ...[
                            Text(
                              'IMO: ${s.vesselImo}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14),
                              tooltip: 'نسخ رقم IMO',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  CopyHelper.copy(context, s.vesselImo!),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Delay Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: delayColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: delayColor),
                  ),
                  child: Text(
                    delayLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: delayColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Route & Voyage Progress ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ميناء الشحن (POL)',
                          style: TextStyle(fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text(
                        '${s.polPortName} (${s.polPortCode})',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.flatCharcoal),
                      ),
                      if (s.scheduledDeparture != null)
                        Text(
                          'المغادرة: ${_formatDate(s.scheduledDeparture)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.black38, size: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('ميناء الوصول (POD)',
                          style: TextStyle(fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text(
                        '${s.podPortName} (${s.podPortCode})',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.flatCharcoal),
                      ),
                      if (s.estimatedArrival != null)
                        Text(
                          'الوصول المتوقع: ${_formatDate(s.estimatedArrival)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: delayColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Telemetry Grid ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildTelemetryCell(
                    'الإحداثيات الحية',
                    s.currentLatitude != null && s.currentLongitude != null
                        ? '${s.currentLatitude!.toStringAsFixed(4)}°, ${s.currentLongitude!.toStringAsFixed(4)}°'
                        : 'غير متوفرة',
                    Icons.my_location,
                  ),
                  _buildTelemetryCell(
                    'السرعة الملاحية',
                    s.currentSpeedKnots != null
                        ? '${s.currentSpeedKnots!.toStringAsFixed(1)} عقدة'
                        : 'غير متوفرة',
                    Icons.speed,
                  ),
                  _buildTelemetryCell(
                    'خط السير (الاتجاه)',
                    s.currentCourseDegrees != null
                        ? '${s.currentCourseDegrees!.toStringAsFixed(0)}°'
                        : 'غير متوفرة',
                    Icons.explore,
                  ),
                  _buildTelemetryCell(
                    'المسافة المتبقية',
                    s.distanceRemainingNm != null
                        ? '${s.distanceRemainingNm!.toStringAsFixed(1)} ميل بحري'
                        : 'غير متوفرة',
                    Icons.route,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Waypoints Route Bar ─────────────────────────────────────────
            if (s.routeWaypoints.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المرحلة الملاحية: ${s.trackingMilestone}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.flatCharcoal),
                  ),
                  Text(
                    'نسبة التقدم: ${s.voyageProgressPct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.flatCobalt),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (s.voyageProgressPct / 100.0).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.flatCobalt),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              _buildWaypointsList(s.routeWaypoints),
            ],

            const Divider(height: 24),

            // ── Card Action Buttons ─────────────────────────────────────────
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.flatCharcoal,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('نسخ تقرير التتبع للواتساب'),
                  onPressed: () {
                    final summary = '🚢 *تتبع الشحنة البحرية*\n'
                        '• السفينة: ${s.vesselName ?? "-"}\n'
                        '• الخط الملاحي: ${s.shippingLineName ?? "-"}\n'
                        '• المسار: ${s.polPortName} ⬅ ${s.podPortName}\n'
                        '• المرحلة الحالية: ${s.trackingMilestone}\n'
                        '• المسافة المتبقية: ${s.distanceRemainingNm?.toStringAsFixed(1) ?? "-"} ميل بحري\n'
                        '• الوصول المتوقع: ${_formatDate(s.estimatedArrival)}\n'
                        '• الحالة: $delayLabel';
                    CopyHelper.copy(context, summary,
                        customMessage: 'تم نسخ تقرير التتبع بنجاح');
                  },
                ),
                if (!isArrived) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.flatCobalt,
                      foregroundColor: Colors.white,
                    ),
                    icon: isSimulating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.fast_forward, size: 18),
                    label: const Text('محاكاة تقدم السفينة (+4 ساعات)'),
                    onPressed: isSimulating
                        ? null
                        : () async {
                            setState(() {
                              _simulatingFileIds.add(s.importFileId);
                            });
                            try {
                              await ref
                                  .read(vesselTrackingRadarProvider.notifier)
                                  .simulateStep(
                                      importFileId: s.importFileId,
                                      hoursAdvance: 4.0);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'تم تحديث موقع السفينة واحتساب زمن الوصول الجديد بنجاح'),
                                    backgroundColor: AppTheme.flatEmerald,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('فشلت عملية المحاكاة: $e'),
                                    backgroundColor: AppTheme.flatCrimson,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _simulatingFileIds.remove(s.importFileId);
                                });
                              }
                            }
                          },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.flatEmerald,
                      foregroundColor: Colors.white,
                    ),
                    icon: isSimulating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.anchor, size: 18),
                    label: const Text('تأكيد رسو السفينة وتفعيل إجراءات الوصول'),
                    onPressed: isSimulating
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                title: const Row(
                                  children: [
                                    Icon(Icons.anchor,
                                        color: AppTheme.flatEmerald),
                                    SizedBox(width: 8),
                                    Text(
                                      'تأكيد رسو السفينة بالميناء',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'هل ترغب في تأكيد رسو السفينة (${s.vesselName ?? "السفينة"}) في ${s.podPortName}؟',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'سيؤدي هذا الإجراء تلقائياً إلى:',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            '• تسجيل تاريخ وتوقيت الوصول الفعلي للشحنة.',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          Text(
                                            '• بدء سريان فترة السماح للحاويات (Free Days) ومتابعة الغرامات.',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          Text(
                                            '• استيفاء شرط وصول الشحنة بقائمة الفحص الذكية (CHK_PRT_01).',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          Text(
                                            '• إنشاء مهمة فورية وإشعار عاجل لسداد رسوم التوكيل الملاحي واستلام إذن التسليم (D.O.).',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('إلغاء'),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.flatEmerald,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 16),
                                    label: const Text('تأكيد الرسو والأتمتة'),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                  ),
                                ],
                              ),
                            );

                            if (confirm != true) return;

                            setState(() {
                              _simulatingFileIds.add(s.importFileId);
                            });
                            try {
                              await ref
                                  .read(vesselTrackingRadarProvider.notifier)
                                  .confirmArrival(
                                      importFileId: s.importFileId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.flatEmerald,
                                    duration: const Duration(seconds: 6),
                                    content: const Text(
                                      'تم تأكيد رسو السفينة بنجاح، وتفعيل بدء احتساب السماح (Free Days)، وإنشاء مهمة سداد إذن التسليم.',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    action: SnackBarAction(
                                      label: 'الانتقال للتخليص',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        ref
                                            .read(navigationIndexProvider
                                                .notifier)
                                            .state = 27;
                                      },
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('فشل تأكيد رسو السفينة: $e'),
                                    backgroundColor: AppTheme.flatCrimson,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _simulatingFileIds.remove(s.importFileId);
                                });
                              }
                            }
                          },
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.flatEmerald),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.anchor,
                            size: 16, color: AppTheme.flatEmerald),
                        SizedBox(width: 6),
                        Text(
                          'السفينة راسية بالميناء - الإجراءات مفعلة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.flatEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.flatCobalt,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.assignment_turned_in, size: 16),
                    label: const Text('الانتقال للتخليص الجمركي وإذن التسليم'),
                    onPressed: () {
                      ref.read(navigationIndexProvider.notifier).state = 27;
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCell(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.flatCharcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointsList(List<WaypointModel> waypoints) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: waypoints.asMap().entries.map((entry) {
          final index = entry.key;
          final wp = entry.value;
          final isPassed = wp.passed;
          final isLast = index == waypoints.length - 1;

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPassed
                      ? AppTheme.flatEmerald.withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPassed
                        ? AppTheme.flatEmerald
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPassed ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 14,
                      color: isPassed ? AppTheme.flatEmerald : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      wp.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isPassed ? FontWeight.bold : FontWeight.normal,
                        color: isPassed
                            ? AppTheme.flatEmerald
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 16,
                  height: 2,
                  color: isPassed ? AppTheme.flatEmerald : Colors.grey.shade300,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _KpiItem(this.label, this.value, this.icon, this.color);
}
