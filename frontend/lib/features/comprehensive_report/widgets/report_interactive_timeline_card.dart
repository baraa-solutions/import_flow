import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_card_container.dart';
import 'shipment_audit_timeline_dialog.dart';

/// Interactive operational timeline, 36-station tracking audit bridge, and SLA card.
class ReportInteractiveTimelineCard extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final ShipmentUpdatesState updatesState;
  final ValueChanged<String>? onNavigateToStage;

  const ReportInteractiveTimelineCard({
    super.key,
    required this.file,
    this.dossier,
    required this.updatesState,
    this.onNavigateToStage,
  });

  @override
  Widget build(BuildContext context) {
    final timeline = dossier?.timelineEvents ?? [];

    return ReportCardContainer(
      title: 'الجدول الزمني التفاعلي وتتبع الحركات ودقة الـ SLA (Timeline & Stage Hub)',
      icon: Icons.timeline_outlined,
      iconColor: AppTheme.cobalt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tracking revision notification bar if ETA changed
          if (file.requiredEta != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.track_changes, color: AppTheme.cobalt, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('ETA المخطط: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                SelectableText(file.requiredEta ?? '—',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('الوصول الفعلي / المحدث: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                SelectableText(dossier?.inlandActualArrivalDate ?? file.inlandActualArrivalDate ?? '—',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'يتم تحديث الجدول الزمني وحساب الفروق اللحظية فور رصد أي حركة جديدة بالميناء أو تعديل بوليصة الشحن.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Action banner to open full 36-station timeline audit dialog
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F766E).withValues(alpha: 0.12),
                  const Color(0xFF0D9488).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_toggle_off_rounded, color: Color(0xFF0F766E), size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رادار ومحضر التتبع الزمني للشحنة (36 محطة ومصفوفة نبض السفينة)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'يعرض المقارنة الكاملة بين التواريخ المخططة والفعلية، ونبض التتبع كل 3 أيام للسفينة، ورادار احتساب الأرضيات والغرامات والوصول الديناميكي للمخزن.',
                        style: TextStyle(fontSize: 11, color: AppTheme.charcoal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.launch_rounded, size: 16),
                  label: const Text('فتح الرادار (36 محطة)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => showShipmentAuditTimelineDialog(
                    context,
                    importFileId: file.importFileId,
                  ),
                ),
              ],
            ),
          ),

          // Operational Turnaround SLAs Strip
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blueGrey.shade100),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _slaSummaryItem(
                    icon: Icons.account_balance_outlined,
                    label: 'معدل استخراج نموذج 4:',
                    value: '2 يوم عمل (قياسي)',
                    color: AppTheme.cobalt,
                  ),
                  const SizedBox(width: 24),
                  _slaSummaryItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'إذن التسليم D/O:',
                    value: '18 ساعة (طبيعي)',
                    color: AppTheme.emerald,
                  ),
                  const SizedBox(width: 24),
                  _slaSummaryItem(
                    icon: Icons.cloud_done_outlined,
                    label: 'تحويل CargoX المعتمد:',
                    value: dossier?.cargoxTransferredAt != null ? dossier!.cargoxTransferredAt!.split('T').first : 'بانتظار الإرسال',
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),
            ),
          ),

          // ETA Tracking Revisions History Log
          if (dossier != null && dossier!.etaRevisionsLog.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'سجل تعديلات وانحرافات موعد الوصول الفعلي (ETA Drift Revisions):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                      ),
                      const Spacer(),
                      Text(
                        '${dossier!.etaRevisionsLog.length} تعديلات مسجلة',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...dossier!.etaRevisionsLog.map((rev) {
                    final cDate = rev['change_date']?.toString() ?? '—';
                    final oldEta = rev['old_eta']?.toString() ?? '—';
                    final newEta = rev['new_eta']?.toString() ?? '—';
                    final drift = rev['drift_days'] ?? 0;
                    final reason = rev['reason']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right, size: 16, color: Color(0xFFD97706)),
                            SelectableText(
                              'بتاريخ $cDate: ',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                            ),
                            SelectableText(
                              'تم تعديل ETA من $oldEta إلى $newEta',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                            ),
                            if (drift != 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (drift as num) > 0 ? Colors.red.shade100 : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'انحراف: ${drift > 0 ? "+" : ""}$drift يوم',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: drift > 0 ? Colors.red.shade900 : Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                            if (reason.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '[$reason]',
                                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          if (timeline.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('جاري تحميل محطات الجدول الزمني للشحنة...')))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timeline.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final ev = timeline[idx];
                final code = ev['stage_code']?.toString() ?? 'STEP_01';
                final nameAr = ev['stage_name_ar']?.toString() ?? '';
                final nameEn = ev['stage_name_en']?.toString() ?? '';
                final status = ev['status']?.toString() ?? 'PENDING';
                final isDone = status == 'COMPLETED';
                final isInProgress = status == 'IN_TRANSIT' || status == 'IN_PROGRESS';
                final planned = ev['planned_date']?.toString();
                final actual = ev['actual_date']?.toString();
                final details = ev['details']?.toString() ?? '';
                final slaLabel = ev['sla_label']?.toString();

                Color statusColor = isDone
                    ? AppTheme.emerald
                    : (isInProgress ? AppTheme.cobalt : Colors.grey.shade400);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Status Icon
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        child: Icon(
                          isDone
                              ? Icons.check
                              : (isInProgress ? Icons.sailing : Icons.access_time),
                          color: statusColor,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Stage Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  nameAr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '($nameEn)',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (planned != null && planned.isNotEmpty) ...[
                                  Text('المخطط: $planned', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  const SizedBox(width: 12),
                                ],
                                if (actual != null && actual.isNotEmpty) ...[
                                  Text('الفعلي: $actual', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
                                  const SizedBox(width: 12),
                                ],
                                if (details.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      details,
                                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            if (slaLabel != null && slaLabel.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '⏱️ $slaLabel',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (onNavigateToStage != null) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt.withValues(alpha: 0.08),
                            foregroundColor: AppTheme.cobalt,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: AppTheme.cobalt, width: 0.8),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 13),
                          label: const Text('الانتقال للمرحلة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => onNavigateToStage!(code),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  static Widget _slaSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade700)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
