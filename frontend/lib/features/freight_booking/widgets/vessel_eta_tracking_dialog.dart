import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/freight_booking_model.dart';
import '../providers/freight_booking_provider.dart';

/// Modal dialog for periodic 3-day ETA vessel transit tracking and ATA arrival confirmation (TASK-BE-11).
class VesselEtaTrackingDialog extends ConsumerStatefulWidget {
  final ShipmentBookingModel booking;

  const VesselEtaTrackingDialog({
    super.key,
    required this.booking,
  });

  static Future<bool?> show(
    BuildContext context,
    ShipmentBookingModel booking,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VesselEtaTrackingDialog(booking: booking),
    );
  }

  @override
  ConsumerState<VesselEtaTrackingDialog> createState() => _VesselEtaTrackingDialogState();
}

class _VesselEtaTrackingDialogState extends ConsumerState<VesselEtaTrackingDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _trackingFormKey = GlobalKey<FormState>();
  final _ataFormKey = GlobalKey<FormState>();

  // New tracking log state
  late TextEditingController _locationController;
  late TextEditingController _trackingRemarksController;
  DateTime _currentEta = DateTime.now().add(const Duration(days: 7));
  bool _isSubmittingLog = false;

  // ATA confirmation state
  late TextEditingController _ataRemarksController;
  DateTime _confirmedAta = DateTime.now();
  bool _isSubmittingAta = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _locationController = TextEditingController();
    _trackingRemarksController = TextEditingController();
    _ataRemarksController = TextEditingController();

    if (widget.booking.eta != null) {
      final parsed = DateTime.tryParse(widget.booking.eta!);
      if (parsed != null) _currentEta = parsed;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationController.dispose();
    _trackingRemarksController.dispose();
    _ataRemarksController.dispose();
    super.dispose();
  }

  Future<void> _submitNewTrackingLog() async {
    if (!_trackingFormKey.currentState!.validate()) return;
    setState(() => _isSubmittingLog = true);
    try {
      final payload = {
        'booking_id': widget.booking.bookingId,
        'import_file_id': widget.booking.importFileId ?? 0,
        'tracking_date': DateTime.now().toUtc().toIso8601String(),
        'vessel_location': _locationController.text.trim(),
        'current_eta': _currentEta.toUtc().toIso8601String(),
        'remarks': _trackingRemarksController.text.trim().isNotEmpty
            ? _trackingRemarksController.text.trim()
            : null,
      };

      await ref.read(freightBookingProvider.notifier).createEtaTrackingLog(payload);
      ref.invalidate(etaTrackingLogsProvider(widget.booking.bookingId));

      if (mounted) {
        _locationController.clear();
        _trackingRemarksController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.isArabic
                ? 'تم تسجيل تحديث المسار الدوري واحتساب الانحراف الزمني بنجاح'
                : 'Transit tracking log recorded successfully',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.isArabic
                ? 'فشل تسجيل تحديث المسار: $e'
                : 'Failed to record tracking log: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingLog = false);
    }
  }

  Future<void> _submitConfirmAta() async {
    if (!_ataFormKey.currentState!.validate()) return;
    setState(() => _isSubmittingAta = true);
    try {
      final payload = {
        'confirmed_ata': _confirmedAta.toUtc().toIso8601String(),
        'remarks': _ataRemarksController.text.trim().isNotEmpty
            ? _ataRemarksController.text.trim()
            : 'Vessel berthed at destination port (ATA Confirmed)',
      };

      await ref.read(freightBookingProvider.notifier).confirmAta(widget.booking.bookingId, payload);
      ref.invalidate(etaTrackingLogsProvider(widget.booking.bookingId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.isArabic
                ? 'تم تأكيد الوصول الفعلي للميناء (ATA) وتحديث حالة الحجز والمخطط الزمني'
                : 'Actual Port Arrival (ATA) confirmed and timeline synchronized',
            severity: AppSeverity.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.isArabic
                ? 'فشل تأكيد الوصول الفعلي: $e'
                : 'Failed to confirm port arrival: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingAta = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = widget.booking;
    final isArrived = b.isAtaConfirmed || b.status == 'Arrived';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: AppTheme.surfaceOf(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.isArabic
                              ? 'متابعة مسار الرحلة البحرية وتأكيد الوصول (ATA)'
                              : 'Vessel Transit Tracking & Arrival (ATA)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${b.bookingCode} | ${b.vesselName ?? "-"} (${b.voyageNumber ?? "-"})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Top Status Summary Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isArrived
                      ? AppTheme.severityBackgroundOf(context, AppSeverity.success)
                      : AppTheme.severityBackgroundOf(context, AppSeverity.info),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isArrived
                        ? AppTheme.severityForegroundOf(context, AppSeverity.success).withValues(alpha: 0.3)
                        : AppTheme.cobalt.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isArrived ? Icons.anchor_rounded : Icons.sailing_rounded,
                      color: isArrived
                          ? AppTheme.severityForegroundOf(context, AppSeverity.success)
                          : AppTheme.cobalt,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isArrived
                                    ? (l.isArabic ? 'وصلت الميناء (ATA مؤكد)' : 'Arrived at Port (ATA Confirmed)')
                                    : (l.isArabic ? 'الشحنة مبحرة في الترانزيت' : 'Shipment in Sea Transit'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isArrived
                                      ? AppTheme.severityForegroundOf(context, AppSeverity.success)
                                      : AppTheme.cobalt,
                                ),
                              ),
                              const Spacer(),
                              if (b.ata != null)
                                Text(
                                  'ATA: ${b.ata!.substring(0, 10)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.severityForegroundOf(context, AppSeverity.success),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'POL: ${b.polName ?? "-"} ➔ POD: ${b.podName ?? "-"} | ETD: ${b.etd != null ? b.etd!.substring(0, 10) : "-"} | Current ETA: ${b.eta != null ? b.eta!.substring(0, 10) : "-"}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.cobalt,
              unselectedLabelColor: AppTheme.textSecondaryOf(context),
              indicatorColor: AppTheme.cobalt,
              tabs: [
                Tab(
                  icon: const Icon(Icons.history_rounded, size: 18),
                  text: l.isArabic ? 'سجل تحديثات المسار (كل 3 أيام)' : 'Tracking History (Every 3 Days)',
                ),
                Tab(
                  icon: Icon(isArrived ? Icons.verified_rounded : Icons.anchor_rounded, size: 18),
                  text: l.isArabic ? 'تأكيد وصول الميناء (Confirm ATA)' : 'Confirm Arrival (ATA)',
                ),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTrackingHistoryTab(l),
                  _buildAtaConfirmationTab(l, isArrived),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingHistoryTab(AppLocalizations l) {
    final logsAsync = ref.watch(etaTrackingLogsProvider(widget.booking.bookingId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Section 1: History List
          Expanded(
            child: logsAsync.when(
              loading: () => const AppLoadingState.section(),
              error: (err, _) => Center(
                child: AppErrorState(
                  error: err,
                  onRetry: () => ref.invalidate(etaTrackingLogsProvider(widget.booking.bookingId)),
                ),
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timeline_rounded, size: 40, color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          l.isArabic
                              ? 'لا توجد تحديثات مسار مسجلة بعد لهذه الشحنة.'
                              : 'No vessel tracking logs recorded yet.',
                          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isAta = log.isAtaConfirmed;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isAta
                            ? AppTheme.severityBackgroundOf(context, AppSeverity.success)
                            : AppTheme.severityBackgroundOf(context, AppSeverity.info),
                        child: Icon(
                          isAta ? Icons.anchor : Icons.navigation_rounded,
                          size: 16,
                          color: isAta
                              ? AppTheme.severityForegroundOf(context, AppSeverity.success)
                              : AppTheme.cobalt,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            log.vesselLocation ?? (l.isArabic ? 'موقع بالبحر' : 'At Sea'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          if (log.delayDays > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '+${log.delayDays} ${l.isArabic ? "أيام تأخير" : "days delay"}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.severityForegroundOf(context, AppSeverity.danger),
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            log.trackingDate.length >= 10 ? log.trackingDate.substring(0, 10) : log.trackingDate,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            'ETA: ${log.currentEta.length >= 10 ? log.currentEta.substring(0, 10) : log.currentEta}'
                            '${log.remarks != null ? " | ${log.remarks}" : ""}',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textPrimaryOf(context)),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 24),

          // Section 2: Form to add new 3-day ETA log
          Form(
            key: _trackingFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.isArabic ? 'تسجيل تحديث مسار جديد (كل 3 أيام):' : 'Record New 3-Day Transit Update:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: l.isArabic ? 'موقع السفينة الحالي *' : 'Current Vessel Location *',
                          hintText: l.isArabic ? 'مثال: مضيق باب المندب / البحر الأحمر' : 'e.g. Bab El-Mandeb / Red Sea',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? (l.isArabic ? 'مطلوب إدخال الموقع' : 'Location required')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _currentEta,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _currentEta = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l.isArabic ? 'تاريخ الـ ETA المحدث *' : 'Updated ETA Date *',
                            isDense: true,
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
                          ),
                          child: Text(
                            _currentEta.toIso8601String().substring(0, 10),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _trackingRemarksController,
                        decoration: InputDecoration(
                          labelText: l.isArabic ? 'ملاحظات المسار أو سبب التعديل' : 'Transit Remarks / Delay Reason',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: l.isArabic ? 'تسجيل التحديث' : 'Save Update',
                      icon: Icons.add_location_alt_rounded,
                      variant: AppButtonVariant.primary,
                      isLoading: _isSubmittingLog,
                      onPressed: _isSubmittingLog ? null : _submitNewTrackingLog,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtaConfirmationTab(AppLocalizations l, bool isArrived) {
    if (isArrived) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 56, color: AppTheme.severityForegroundOf(context, AppSeverity.success)),
              const SizedBox(height: 14),
              Text(
                l.isArabic ? 'تم تأكيد وصول السفينة ورسوها بالميناء بالكامل' : 'Vessel Port Arrival (ATA) Already Confirmed',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'ATA: ${widget.booking.ata ?? "-"}',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Text(
                  l.isArabic
                      ? 'الشحنة جاهزة الآن للبدء في إجراءات الفحص والتخليص الجمركي واستلام إذن التسليم.'
                      : 'Shipment is ready for port delivery order and customs clearance inspections.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _ataFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.isArabic
                          ? 'تأكيد الـ ATA ينقل حالة الشحنة إلى "Arrived" ويطلق المزامنة الفورية للمراحل التشغيلية الـ 25.'
                          : 'Confirming ATA sets booking status to "Arrived" and triggers 25-stage operational timeline sync.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.isArabic ? 'بيانات الوصول الفعلي والرسو بالميناء:' : 'Actual Time of Arrival (ATA) Details:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _confirmedAta,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  setState(() => _confirmedAta = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.isArabic ? 'تاريخ ووقت الوصول الفعلي (Confirmed ATA) *' : 'Confirmed ATA Date & Time *',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.event_available_rounded),
                ),
                child: Text(
                  _confirmedAta.toIso8601String().substring(0, 10),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ataRemarksController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l.isArabic ? 'بيانات الرصيف أو ملاحظات الميناء' : 'Berth Details / Port Notes',
                hintText: l.isArabic ? 'مثال: رسو السفينة على رصيف 42 بميناء الإسكندرية وبدء تفريغ الحاويات' : 'e.g. Berthed at berth 42, discharge started',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: AppButton(
                label: l.isArabic ? 'تأكيد وصول السفينة ورسوها (Confirm ATA)' : 'Confirm Vessel Port Arrival (ATA)',
                icon: Icons.anchor_rounded,
                variant: AppButtonVariant.success,
                size: AppButtonSize.large,
                isLoading: _isSubmittingAta,
                onPressed: _isSubmittingAta ? null : _submitConfirmAta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
