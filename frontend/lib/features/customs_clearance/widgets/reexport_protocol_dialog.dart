import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/reexport_protocol_model.dart';
import '../services/reexport_protocol_service.dart';
import 'reexport_protocol/new_reexport_dossier_dialog.dart';
import 'reexport_protocol/reexport_dossier_card.dart';
import 'reexport_protocol/reexport_metrics_strip.dart';
import 'reexport_protocol/reexport_sub_dialogs.dart';

class ReexportProtocolDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const ReexportProtocolDialog({super.key, this.initialImportFileId});

  static Future<void> show(BuildContext context, {int? initialImportFileId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ReexportProtocolDialog(initialImportFileId: initialImportFileId),
    );
  }

  @override
  ConsumerState<ReexportProtocolDialog> createState() => _ReexportProtocolDialogState();
}

class _ReexportProtocolDialogState extends ConsumerState<ReexportProtocolDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<ReexportDossierModel> _dossiers = [];
  DestructionAlertOverviewModel? _alertsOverview;
  bool _isLoading = false;
  String _selectedStatus = 'All';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(reexportProtocolServiceProvider);
      final list = await service.listDossiers(
        importFileId: widget.initialImportFileId,
        status: _selectedStatus,
        search: _searchController.text.trim(),
      );
      final alerts = await service.getDestructionAlerts();

      if (mounted) {
        setState(() {
          _dossiers = list;
          _alertsOverview = alerts;
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

  void _showNewReexportDialog() {
    NewReexportDossierDialog.show(
      context,
      initialImportFileId: widget.initialImportFileId,
      onDossierCreated: () {
        if (!mounted) return;
        AppTheme.snackBar(context, 'تم تسجيل ملف إعادة التصدير وبدء عداد المهلة القانونية بنجاح', severity: AppSeverity.success);
        _loadData();
      },
    );
  }

  void _showBookingDialog(ReexportDossierModel item) {
    ReexportBookingDialog.show(
      context,
      item: item,
      onSaved: () {
        if (!mounted) return;
        AppTheme.snackBar(context, 'تم حفظ تفاصيل حجز الشحن العكسي بنجاح', severity: AppSeverity.success);
        _loadData();
      },
    );
  }

  void _showSupervisionCommitteeDialog(ReexportDossierModel item) {
    SupervisionCommitteeDialog.show(
      context,
      item: item,
      onSaved: () {
        if (!mounted) return;
        AppTheme.snackBar(context, 'تم توثيق تشكيل لجنة الإشراف الجمركي ومظهر الصادر', severity: AppSeverity.success);
        _loadData();
      },
    );
  }

  void _showCreditNoteDialog(ReexportDossierModel item) {
    ReexportCreditNoteDialog.show(
      context,
      item: item,
      onSaved: () {
        if (!mounted) return;
        AppTheme.snackBar(context, 'تم تحديث بيانات إشعار الخصم الدائن للمورد بنجاح', severity: AppSeverity.success);
        _loadData();
      },
    );
  }

  void _showDrawbackDialog(ReexportDossierModel item) {
    DutyDrawbackDialog.show(
      context,
      item: item,
      onSaved: () {
        if (!mounted) return;
        AppTheme.snackBar(context, 'تم تسجيل وتحديث ملف استرداد الرسوم (الدروباك)', severity: AppSeverity.success);
        _loadData();
      },
    );
  }

  void _advanceStatus(ReexportDossierModel item) async {
    String? nextStatus;
    switch (item.status) {
      case ReexportStatus.mandated:
        nextStatus = 'BOOKING_CONFIRMED';
        break;
      case ReexportStatus.bookingConfirmed:
        nextStatus = 'CUSTOMS_INSPECTED';
        break;
      case ReexportStatus.customsInspected:
        nextStatus = 'LADEN_ON_BOARD';
        break;
      case ReexportStatus.ladenOnBoard:
        nextStatus = 'COMPLETED_CLOSED';
        break;
      case ReexportStatus.completedClosed:
        return;
    }

    try {
      final service = ref.read(reexportProtocolServiceProvider);
      await service.transitionStatus(item.reexportId, nextStatus);
      if (!mounted) return;
      AppTheme.snackBar(context, 'تم تصعيد مرحلة إعادة التصدير إلى المرحلة التالية بنجاح', severity: AppSeverity.success);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      AppTheme.snackBar(context, 'فشل في تصعيد الحالة: $e', severity: AppSeverity.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 1150,
        height: 760,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SelectionArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.outbox_rounded, color: AppTheme.crimson, size: 26),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بروتوكول البضائع المرفوضة وإعادة التصدير',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'المادة 67 و 70 من قانون الجمارك 207/2020: مهلة الـ 30 يوماً لإعادة التصدير لحماية المستورد من الغرامات والإعدام الجمركي',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      label: 'تسجيل رفض جمركي جديد',
                      icon: Icons.add_circle_outline,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: _showNewReexportDialog,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Metrics Strip
              if (_alertsOverview != null)
                ReexportMetricsStrip(alertsOverview: _alertsOverview!),

              // Filter Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child: AppSearchField(
                        controller: _searchController,
                        hint: 'بحث برقم الملف، القرار، أو البوليصة...',
                        onChanged: (_) => _loadData(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text('مرحلة إعادة التصدير: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    DropdownButton<String>(
                      value: _selectedStatus,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('كافة المراحل')),
                        DropdownMenuItem(value: 'MANDATED', child: Text('صدر قرار إعادة التصدير')),
                        DropdownMenuItem(value: 'BOOKING_CONFIRMED', child: Text('تم تأكيد حجز الشحن')),
                        DropdownMenuItem(value: 'CUSTOMS_INSPECTED', child: Text('تمت معاينة لجنة الإشراف')),
                        DropdownMenuItem(value: 'LADEN_ON_BOARD', child: Text('تم الشحن على السفينة')),
                        DropdownMenuItem(value: 'COMPLETED_CLOSED', child: Text('مكتمل ومغلق')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                          _loadData();
                        }
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'تحديث القائمة',
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Dossiers List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text('خطأ: $_errorMessage', style: const TextStyle(color: AppTheme.crimson)))
                        : _dossiers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 10),
                                    const Text('لا توجد ملفات بضائع مرفوضة مسجلة حالياً', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _dossiers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = _dossiers[idx];
                                  return ReexportDossierCard(
                                    item: item,
                                    onBooking: () => _showBookingDialog(item),
                                    onSupervision: () => _showSupervisionCommitteeDialog(item),
                                    onCreditNote: () => _showCreditNoteDialog(item),
                                    onDrawback: () => _showDrawbackDialog(item),
                                    onAdvanceStatus: () => _advanceStatus(item),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
