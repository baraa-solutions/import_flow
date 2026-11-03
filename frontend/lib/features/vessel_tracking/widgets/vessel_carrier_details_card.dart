import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/vessel_tracking_model.dart';
import 'vessel_eta_table.dart';
import 'vessel_tracking_map_card.dart';

/// 🚢 Vessel Carrier Details Card
///
/// Comprehensive operational card displaying vessel identity, carrier line details,
/// ETA schedule, live telemetry map data, and port arrival automation actions.
class VesselCarrierDetailsCard extends StatelessWidget {
  final ShipmentTrackingModel shipment;
  final bool isSimulating;
  final Future<void> Function(int importFileId)? onSimulateAdvance;
  final Future<void> Function(int importFileId)? onConfirmArrival;
  final VoidCallback? onNavigateDemurrage;
  final VoidCallback? onNavigateClearance;

  const VesselCarrierDetailsCard({
    super.key,
    required this.shipment,
    this.isSimulating = false,
    this.onSimulateAdvance,
    this.onConfirmArrival,
    this.onNavigateDemurrage,
    this.onNavigateClearance,
  });

  AppSeverity _delaySeverity(String severity) {
    return switch (severity.toUpperCase()) {
      'CRITICAL_DELAY' => AppSeverity.danger,
      'MINOR_DELAY' => AppSeverity.warning,
      _ => AppSeverity.success,
    };
  }

  String _delayLabel(ShipmentTrackingModel s) {
    if (s.delaySeverity == 'CRITICAL_DELAY') {
      return 'تأخير حرج (+${s.delayHours.toStringAsFixed(1)} ساعة)';
    } else if (s.delaySeverity == 'MINOR_DELAY') {
      return 'تأخير طفيف (+${s.delayHours.toStringAsFixed(1)} ساعة)';
    }
    return 'في الموعد المحدد';
  }

  @override
  Widget build(BuildContext context) {
    final s = shipment;
    final isArrived = s.trackingMilestone.contains('In Port') ||
        s.trackingMilestone.contains('Berthed') ||
        s.voyageProgressPct >= 100.0;

    final delayBadgeSeverity = _delaySeverity(s.delaySeverity);
    final delayText = _delayLabel(s);

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
                  child: const Icon(
                    Icons.directions_boat,
                    color: AppTheme.flatCobalt,
                    size: 24,
                  ),
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
                                border: Border.all(color: Colors.blueGrey.shade200),
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
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14),
                            tooltip: 'نسخ كود التتبع',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => CopyHelper.copy(context, s.trackingCode),
                          ),
                          if (s.vesselImo != null) ...[
                            Text(
                              'IMO: ${s.vesselImo}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14),
                              tooltip: 'نسخ رقم IMO',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => CopyHelper.copy(context, s.vesselImo!),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Canonical Status Badge for Schedule Variance
                AppStatusBadge(
                  label: delayText,
                  severity: delayBadgeSeverity,
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Route & ETA Table ───────────────────────────────────────────
            VesselEtaTable(shipment: s),
            const SizedBox(height: 16),

            // ── Telemetry & Waypoints Map Card ──────────────────────────────
            VesselTrackingMapCard(shipment: s),

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
                        '• المرحلة الحالية: ${VesselTrackingMapCard.translateMilestone(s.trackingMilestone)}\n'
                        '• المسافة المتبقية: ${s.distanceRemainingNm?.toStringAsFixed(1) ?? "-"} ميل بحري\n'
                        '• الوصول المتوقع: ${VesselEtaTable.formatDate(s.estimatedArrival)}\n'
                        '• الحالة: $delayText';
                    CopyHelper.copy(
                      context,
                      summary,
                      customMessage: 'تم نسخ تقرير التتبع بنجاح',
                    );
                  },
                ),
                if (!isArrived) ...[
                  if (onSimulateAdvance != null)
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
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.fast_forward, size: 18),
                      label: const Text('محاكاة تقدم السفينة (+4 ساعات)'),
                      onPressed: isSimulating
                          ? null
                          : () => onSimulateAdvance!(s.importFileId),
                    ),
                  if (onConfirmArrival != null)
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
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.anchor, size: 18),
                      label: const Text('تأكيد رسو السفينة وتفعيل إجراءات الوصول'),
                      onPressed: isSimulating
                          ? null
                          : () => _showConfirmArrivalDialog(context, s),
                    ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.flatEmerald),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.anchor, size: 16, color: AppTheme.flatEmerald),
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
                  if (s.demurrageClockStarted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFA000)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFE65100)),
                          const SizedBox(width: 6),
                          Text(
                            'عداد الغرامات نشط: ${s.demurrageStatus ?? "فترات السماح سارية"} (${s.demurrageDischargeDate ?? ""})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (onNavigateDemurrage != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE65100),
                        side: const BorderSide(color: Color(0xFFFFA000)),
                      ),
                      icon: const Icon(Icons.speed, size: 16),
                      label: const Text('رادار الغرامات'),
                      onPressed: onNavigateDemurrage,
                    ),
                  if (onNavigateClearance != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.flatCobalt,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.assignment_turned_in, size: 16),
                      label: const Text('الانتقال للتخليص الجمركي وإذن التسليم'),
                      onPressed: onNavigateClearance,
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showConfirmArrivalDialog(
      BuildContext context, ShipmentTrackingModel s) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'تأكيد رسو السفينة بالميناء',
      message: 'هل ترغب في تأكيد رسو السفينة (${s.vesselName ?? "السفينة"}) في ${s.podPortName}؟\n\n'
          'سيؤدي هذا الإجراء تلقائياً إلى:\n'
          '• تسجيل تاريخ وتوقيت الوصول الفعلي للشحنة.\n'
          '• بدء سريان فترة السماح للحاويات (Free Days) ومتابعة الغرامات.\n'
          '• استيفاء شرط وصول الشحنة بقائمة الفحص الذكية (CHK_PRT_01).\n'
          '• إنشاء مهمة فورية وإشعار عاجل لسداد رسوم التوكيل الملاحي واستلام إذن التسليم (D.O.).',
      confirmLabel: 'تأكيد الرسو والأتمتة',
      cancelLabel: 'إلغاء',
      confirmVariant: AppButtonVariant.success,
      icon: Icons.anchor,
    );

    if (confirm == true && onConfirmArrival != null) {
      await onConfirmArrival!(s.importFileId);
    }
  }
}
