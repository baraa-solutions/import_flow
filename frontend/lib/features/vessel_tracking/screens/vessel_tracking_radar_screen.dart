import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/vessel_tracking_model.dart';
import '../providers/vessel_tracking_provider.dart';
import '../widgets/vessel_carrier_details_card.dart';

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

  Future<void> _handleSimulateStep(int importFileId) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    setState(() {
      _simulatingFileIds.add(importFileId);
    });
    try {
      await ref
          .read(vesselTrackingRadarProvider.notifier)
          .simulateStep(importFileId: importFileId, hoursAdvance: 4.0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            isArabic
                ? 'تم تحديث موقع السفينة واحتساب زمن الوصول الجديد بنجاح'
                : 'Vessel location updated and new ETA calculated successfully',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            isArabic ? 'فشلت عملية المحاكاة: $e' : 'Simulation failed: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _simulatingFileIds.remove(importFileId);
        });
      }
    }
  }

  Future<void> _handleConfirmArrival(int importFileId) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    setState(() {
      _simulatingFileIds.add(importFileId);
    });
    try {
      await ref
          .read(vesselTrackingRadarProvider.notifier)
          .confirmArrival(importFileId: importFileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            isArabic
                ? 'تم تأكيد رسو السفينة بنجاح، وتفعيل بدء احتساب السماح (Free Days)، وإنشاء مهمة سداد إذن التسليم.'
                : 'Vessel berthing confirmed successfully, free days countdown initiated, and delivery order payment task created.',
            severity: AppSeverity.success,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: isArabic ? 'الانتقال للتخليص' : 'Go to Clearance',
              textColor: Colors.white,
              onPressed: () {
                ref.read(navigationIndexProvider.notifier).state = 27;
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            isArabic
                ? 'فشل تأكيد رسو السفينة: $e'
                : 'Failed to confirm vessel arrival: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _simulatingFileIds.remove(importFileId);
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(vesselTrackingRadarProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PageHeader(
        icon: Icons.radar_outlined,
        title: isArabic
            ? 'رادار التتبع الحي لخطوط الملاحة والسفن'
            : 'Live Vessel & Carrier Tracking Radar',
        subtitle: isArabic
            ? 'مراقبة فورية لمواقع الأساطيل ومواقيت الوصول الديناميكية'
            : 'Real-time Fleet Tracking & Dynamic ETA Predictions',
        actions: [
          IconButton(
            tooltip: isArabic ? 'تحديث البيانات الفورية' : 'Refresh Live Telemetry',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () =>
                ref.read(vesselTrackingRadarProvider.notifier).fetchRadarOverview(),
          ),
          const SizedBox(width: 4),
          const BackToDashboardButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: radarState.when(
          loading: () => AppLoadingState(
            message: isArabic
                ? 'جاري استقبال إشارات الرادار والبيانات الملاحية...'
                : 'Receiving radar signals and navigational data...',
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
                      isArabic
                          ? 'تعذر الاتصال بخدمة الرادار الملاحي: $err'
                          : 'Unable to connect to marine radar service: $err',
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
                      label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (overview) => _buildRadarContent(overview, isArabic),
        ),
      ),
    );
  }

  Widget _buildRadarContent(LiveRadarOverviewModel overview, bool isArabic) {
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
          _buildKpiMetrics(overview, isArabic),
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
                      decoration: InputDecoration(
                        hintText: isArabic
                            ? 'البحث باسم السفينة، الخط الملاحي، كود التتبع، أو الميناء...'
                            : 'Search by vessel, shipping line, tracking code, or port...',
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
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.directions_boat_outlined,
                          size: 48, color: Colors.black26),
                      const SizedBox(height: 12),
                      Text(
                        isArabic
                            ? 'لا توجد شحنات بحرية مطابقة لخيارات البحث الحالية'
                            : 'No ocean shipments match current search criteria',
                        style: const TextStyle(color: Colors.black54, fontSize: 14),
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
                final s = filteredShipments[index];
                return VesselCarrierDetailsCard(
                  shipment: s,
                  isSimulating: _simulatingFileIds.contains(s.importFileId),
                  onSimulateAdvance: _handleSimulateStep,
                  onConfirmArrival: _handleConfirmArrival,
                  onNavigateDemurrage: () {
                    ref.read(navigationIndexProvider.notifier).state = 44;
                  },
                  onNavigateClearance: () {
                    ref.read(navigationIndexProvider.notifier).state = 27;
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiMetrics(LiveRadarOverviewModel overview, bool isArabic) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final cardWidth = isDesktop
            ? (constraints.maxWidth - (5 * 12)) / 6
            : (constraints.maxWidth - 12) / 2;

        final items = [
          _KpiItem(
            isArabic ? 'إجمالي الأسطول' : 'Total Fleet',
            '${overview.totalActiveShipments}',
            Icons.directions_boat,
            AppTheme.flatCobalt,
          ),
          _KpiItem(
            isArabic ? 'في عرض البحر' : 'Underway at Sea',
            '${overview.underwayCount}',
            Icons.waves,
            AppTheme.flatCobalt,
          ),
          _KpiItem(
            isArabic ? 'تقترب من الميناء' : 'Approaching Port',
            '${overview.approachingPortCount}',
            Icons.anchor,
            AppTheme.flatEmerald,
          ),
          _KpiItem(
            isArabic ? 'راسي بالميناء' : 'Berthed in Port',
            '${overview.inPortCount}',
            Icons.location_city,
            AppTheme.flatCharcoal,
          ),
          _KpiItem(
            isArabic ? 'في الموعد المحدد' : 'On Schedule',
            '${overview.onTimeCount}',
            Icons.check_circle,
            AppTheme.flatEmerald,
          ),
          _KpiItem(
            isArabic ? 'تأخير مسجل' : 'Delayed',
            '${overview.delayedCount}',
            Icons.warning_amber_rounded,
            overview.delayedCount > 0 ? AppTheme.flatCrimson : Colors.grey,
          ),
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
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _KpiItem(this.label, this.value, this.icon, this.color);
}
