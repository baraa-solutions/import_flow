import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../models/freight_booking_model.dart';
import '../providers/freight_booking_provider.dart';

class DepartureConfirmationDialog extends ConsumerStatefulWidget {
  final ShipmentBookingModel booking;

  const DepartureConfirmationDialog({
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
      builder: (context) => DepartureConfirmationDialog(booking: booking),
    );
  }

  @override
  ConsumerState<DepartureConfirmationDialog> createState() => _DepartureConfirmationDialogState();
}

class _DepartureConfirmationDialogState extends ConsumerState<DepartureConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bolController;
  late TextEditingController _vesselController;
  late TextEditingController _voyageController;
  late TextEditingController _notesController;

  DateTime _actualDepartureDate = DateTime.now();
  DateTime? _revisedEta;
  DateTime? _shippedOnBoardDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    _bolController = TextEditingController(text: b.billOfLadingNo ?? '');
    _vesselController = TextEditingController(text: b.vesselName ?? '');
    _voyageController = TextEditingController(text: b.voyageNumber ?? '');
    _notesController = TextEditingController();

    if (b.atd != null) {
      final parsed = DateTime.tryParse(b.atd!);
      if (parsed != null) _actualDepartureDate = parsed;
    } else if (b.etd != null) {
      final parsed = DateTime.tryParse(b.etd!);
      if (parsed != null) _actualDepartureDate = parsed;
    }

    if (b.eta != null) {
      _revisedEta = DateTime.tryParse(b.eta!);
    } else {
      _revisedEta = _actualDepartureDate.add(Duration(days: b.transitTimeDays > 0 ? b.transitTimeDays : 15));
    }
  }

  @override
  void dispose() {
    _bolController.dispose();
    _vesselController.dispose();
    _voyageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _calculatedDelayDays {
    if (widget.booking.etd == null) return 0;
    final etdDate = DateTime.tryParse(widget.booking.etd!);
    if (etdDate == null) return 0;
    final diff = _actualDepartureDate.difference(etdDate).inDays;
    return diff > 0 ? diff : 0;
  }

  int get _calculatedTransitDays {
    if (_revisedEta == null) return widget.booking.transitTimeDays;
    final diff = _revisedEta!.difference(_actualDepartureDate).inDays;
    return diff > 0 ? diff : 0;
  }

  Future<void> _selectDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.cobalt,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final payload = <String, dynamic>{
        'actual_departure_date': _actualDepartureDate.toIso8601String(),
        'bill_of_lading_no': _bolController.text.trim(),
        if (_revisedEta != null) 'revised_eta': _revisedEta!.toIso8601String(),
        if (_vesselController.text.trim().isNotEmpty) 'vessel_name': _vesselController.text.trim(),
        if (_voyageController.text.trim().isNotEmpty) 'voyage_number': _voyageController.text.trim(),
        if (_shippedOnBoardDate != null)
          'shipped_on_board_date': _shippedOnBoardDate!.toIso8601String().substring(0, 10),
        if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
      };

      await ref.read(freightBookingProvider.notifier).confirmDepartureAndBol(
            widget.booking.bookingId,
            payload,
          );

      ref.invalidate(importFilesProvider);
      ref.invalidate(smartTasksProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم تأكيد الإبحار الفعلي بنجاح وتسجيل بوليصة الشحن رقم (${_bolController.text.trim()}) وانتقال الشحنة لحالة In-Transit',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تأكيد الإبحار: ${e.toString().replaceAll('Exception:', '')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final isDark = AppTheme.isDark(context);
    final delayDays = _calculatedDelayDays;
    final transitDays = _calculatedTransitDays;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 780),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sailing_rounded, color: AppTheme.cobalt, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تأكيد الإبحار الفعلي وإصدار بوليصة الشحن (SH-01)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'حجز: ${b.bookingConfirmationNo ?? b.bookingCode} | ملف: ${b.importFileCode ?? (b.importFileId != null ? "IMP-${b.importFileId}" : "غير مرتبط")}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Operational Context & Delay Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الخط الملاحي: ${b.shippingLineName ?? "MSC"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المسار: ${b.polName ?? "POL"} ➔ ${b.podName ?? "POD"}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (delayDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.orange.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.orange),
                            const SizedBox(width: 4),
                            Text(
                              'تأخر إبحار: $delayDays يوم',
                              style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 14, color: AppTheme.emerald),
                            SizedBox(width: 4),
                            Text(
                              'إبحار في الموعد (On Schedule)',
                              style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Scrollable Inputs Form
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Row 1: Bill of Lading Number (Required)
                      TextFormField(
                        controller: _bolController,
                        decoration: InputDecoration(
                          labelText: 'رقم بوليصة الشحن (Bill of Lading No / Master B/L) *',
                          hintText: 'مثال: MSCU1234567 / COSU62001122',
                          prefixIcon: const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'يرجى إدخال رقم بوليصة الشحن B/L';
                          }
                          if (v.trim().length < 3) {
                            return 'رقم البوليصة يجب ألا يقل عن 3 أحرف/أرقام';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Row 2: Actual Departure Date (ATD) & Revised ETA
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(
                                initialDate: _actualDepartureDate,
                                onSelected: (d) => _actualDepartureDate = d,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ الإبحار الفعلي (ATD) *',
                                  prefixIcon: const Icon(Icons.event_available, color: AppTheme.cobalt, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                child: Text(
                                  _actualDepartureDate.toIso8601String().substring(0, 10),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(
                                initialDate: _revisedEta ?? _actualDepartureDate.add(const Duration(days: 15)),
                                firstDate: _actualDepartureDate,
                                onSelected: (d) => _revisedEta = d,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'موعد الوصول المحدث (Revised ETA)',
                                  prefixIcon: const Icon(Icons.pin_drop_outlined, color: AppTheme.emerald, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                child: Text(
                                  _revisedEta != null ? _revisedEta!.toIso8601String().substring(0, 10) : 'تلقائي',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 3: Vessel & Voyage
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _vesselController,
                              decoration: InputDecoration(
                                labelText: 'اسم الباخرة (Vessel Name)',
                                hintText: 'مثال: MSC OSCAR',
                                prefixIcon: const Icon(Icons.directions_boat_filled_outlined, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _voyageController,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'رقم الرحلة (Voyage Number)',
                                hintText: 'مثال: 2608W / 042E',
                                prefixIcon: const Icon(Icons.tag, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 4: Shipped on Board Date
                      InkWell(
                        onTap: () => _selectDate(
                          initialDate: _shippedOnBoardDate ?? _actualDepartureDate,
                          onSelected: (d) => _shippedOnBoardDate = d,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'تاريخ الشحن على ظهر السفينة (Shipped On Board Date)',
                            hintText: 'تاريخ ختم On Board الرسمي على البوليصة',
                            prefixIcon: const Icon(Icons.fact_check_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          child: Text(
                            _shippedOnBoardDate != null
                                ? _shippedOnBoardDate!.toIso8601String().substring(0, 10)
                                : 'نفس تاريخ الإبحار الفعلي (${_actualDepartureDate.toIso8601String().substring(0, 10)})',
                            style: TextStyle(
                              color: _shippedOnBoardDate != null ? null : Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Row 5: Notes & Observations
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات خط الملاحة ومحطات الترانزيت (اختياري)',
                          hintText: 'مثال: الشحنة أبحرت مباشرة، الترانزيت المتوقع $transitDays يوم بدون تأخير...',
                          prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Live Automation Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 16, color: AppTheme.cobalt),
                                SizedBox(width: 6),
                                Text(
                                  'المعالجة الآلية الفورية عند الحفظ:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• تحويل حالة الشحنة إلى In-Transit / On Water بنسبة إنجاز 60%+\n'
                              '• تحديث رادار غرامات الحاويات (Demurrage) برقم بوليصة الشحن\n'
                              '• إغلاق مهام الإبحار وإطلاق مهمة (SH-02): المراجعة المزدوجة لمسودة البوليصة\n'
                              '• بث إشعار تشغيلي رسمي لغرفة العمليات بموعد الوصول المحدث',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _onSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(
                      _isSubmitting ? 'جاري توثيق الإبحار...' : 'تأكيد الإبحار وإصدار البوليصة',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
