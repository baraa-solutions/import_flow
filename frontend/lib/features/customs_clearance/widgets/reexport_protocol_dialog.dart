import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/reexport_protocol_model.dart';
import '../services/reexport_protocol_service.dart';

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

  Color _alertColor(int days) {
    if (days <= 0) return AppTheme.crimson;
    if (days <= 7) return const Color(0xFFD32F2F);
    if (days <= 14) return AppTheme.orange;
    return AppTheme.emerald;
  }

  AppSeverity _statusSeverity(ReexportStatus status) {
    switch (status) {
      case ReexportStatus.mandated:
        return AppSeverity.danger;
      case ReexportStatus.bookingConfirmed:
      case ReexportStatus.customsInspected:
        return AppSeverity.warning;
      case ReexportStatus.ladenOnBoard:
      case ReexportStatus.completedClosed:
        return AppSeverity.success;
    }
  }

  void _showNewReexportDialog() {
    final fileIdController = TextEditingController(text: widget.initialImportFileId?.toString() ?? '');
    final fileCodeController = TextEditingController();
    final authorityController = TextEditingController(text: 'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)');
    final decreeController = TextEditingController();
    final dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    final reasonController = TextEditingController();
    final containersController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_late_outlined, color: AppTheme.crimson),
            SizedBox(width: 8),
            Text('تسجيل ملف إعادة تصدير لبضاعة مرفوضة رقابياً'),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'المادة 67 من قانون 207/2020: يبدأ سريان مهلة الـ 30 يوماً فور صدور قرار الرفض النهائي قبل الشروع في إجراءات الإعدام الجمركي.',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.crimson),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'معرف الملف الاستيرادي (ID)',
                        controller: fileIdController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        label: 'كود الملف (مثال: IMP-2026-001)',
                        controller: fileCodeController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'الجهة الرقابية الصادر عنها الرفض',
                  controller: authorityController,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'رقم قرار الرفض الرسمي',
                        controller: decreeController,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        label: 'تاريخ صدور القرار (YYYY-MM-DD)',
                        controller: dateController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'أسباب الرفض الفنية / المعملية بالتفصيل',
                  controller: reasonController,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'أرقام الحاويات المرفوضة (مفصولة بفواصل)',
                  controller: containersController,
                  hint: 'MSKU1234567, CMAU7654321',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'تأكيد وقيد الملف',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              final fid = int.tryParse(fileIdController.text.trim());
              if (fid == null || fileCodeController.text.trim().isEmpty || decreeController.text.trim().isEmpty) {
                AppTheme.snackBar(ctx, 'يرجى استيفاء الحقول الإلزامية ورقم الملف وقرار الرفض', severity: AppSeverity.warning);
                return;
              }
              final containers = containersController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              Navigator.of(ctx).pop();
              try {
                final service = ref.read(reexportProtocolServiceProvider);
                await service.createDossier(
                  importFileId: fid,
                  importFileCode: fileCodeController.text.trim(),
                  rejectionAuthority: authorityController.text.trim(),
                  rejectionDecreeNumber: decreeController.text.trim(),
                  rejectionDate: dateController.text.trim(),
                  reexportReason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'مرفوض لعدم مطابقة المواصفات القياسية',
                  containerNumbers: containers,
                );
                if (!mounted) return;
                AppTheme.snackBar(context, 'تم تسجيل ملف إعادة التصدير وبدء عداد المهلة القانونية بنجاح', severity: AppSeverity.success);
                _loadData();
              } catch (e) {
                if (!mounted) return;
                AppTheme.snackBar(context, 'فشل في حفظ ملف إعادة التصدير: $e', severity: AppSeverity.danger);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showBookingDialog(ReexportDossierModel item) {
    final bookingNoController = TextEditingController(text: item.returnBookingNumber ?? '');
    final podController = TextEditingController(text: item.returnPortOfDischarge ?? 'Port of Origin');
    final blNoController = TextEditingController(text: item.outboundBlNumber ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسجيل حجز الشحن العكسي — ${item.importFileCode}'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'رقم حجز الشحن العكسي (Booking No)',
                controller: bookingNoController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: 'ميناء الوصول النهائي لإعادة التصدير (POD)',
                controller: podController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: 'رقم بوليصة الشحن الصادر (Outbound B/L)',
                controller: blNoController,
                hint: 'اختياري في مرحلة الحجز المبدئي',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          AppButton(
            label: 'حفظ الحجز',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              if (bookingNoController.text.trim().isEmpty) {
                AppTheme.snackBar(ctx, 'يرجى إدخال رقم الحجز', severity: AppSeverity.warning);
                return;
              }
              Navigator.of(ctx).pop();
              try {
                final service = ref.read(reexportProtocolServiceProvider);
                await service.recordOutboundBooking(
                  item.reexportId,
                  returnBookingNumber: bookingNoController.text.trim(),
                  returnPortOfDischarge: podController.text.trim(),
                  outboundBlNumber: blNoController.text.trim().isNotEmpty ? blNoController.text.trim() : null,
                );
                if (!mounted) return;
                AppTheme.snackBar(context, 'تم حفظ تفاصيل حجز الشحن العكسي بنجاح', severity: AppSeverity.success);
                _loadData();
              } catch (e) {
                if (!mounted) return;
                AppTheme.snackBar(context, 'فشل في حفظ الحجز: $e', severity: AppSeverity.danger);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSupervisionCommitteeDialog(ReexportDossierModel item) {
    final officerController = TextEditingController(text: item.customsOfficerInCharge ?? '');
    final declNoController = TextEditingController(text: item.customsOutboundDeclarationNo ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تشكيل لجنة الإشراف ومظهر الصادر — ${item.importFileCode}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'اسم مأمور الجمرك المكلف بالإشراف والمعاينة',
                controller: officerController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: 'رقم مظهر الصادر الجمركي المعتمد',
                controller: declNoController,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          AppButton(
            label: 'اعتماد اللجنة',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              if (officerController.text.trim().isEmpty || declNoController.text.trim().isEmpty) {
                AppTheme.snackBar(ctx, 'يرجى إدخال اسم المأمور ورقم مظهر الصادر', severity: AppSeverity.warning);
                return;
              }
              Navigator.of(ctx).pop();
              try {
                final service = ref.read(reexportProtocolServiceProvider);
                await service.formSupervisionCommittee(
                  item.reexportId,
                  customsOfficerInCharge: officerController.text.trim(),
                  customsOutboundDeclarationNo: declNoController.text.trim(),
                );
                if (!mounted) return;
                AppTheme.snackBar(context, 'تم توثيق تشكيل لجنة الإشراف الجمركي ومظهر الصادر', severity: AppSeverity.success);
                _loadData();
              } catch (e) {
                if (!mounted) return;
                AppTheme.snackBar(context, 'خطأ أثناء تسجيل اللجنة: $e', severity: AppSeverity.danger);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showCreditNoteDialog(ReexportDossierModel item) {
    String selectedStatus = item.supplierCreditNoteStatus.name.toUpperCase();
    final amountController = TextEditingController(text: item.creditNoteAmountUsd > 0 ? item.creditNoteAmountUsd.toStringAsFixed(2) : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Text('إشعار الخصم الدائن للمورد (Credit Note) — ${item.importFileCode}'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('حالة إشعار الخصم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'REQUESTED', child: Text('تمت المطالبة وقيد المتابعة')),
                    DropdownMenuItem(value: 'RECEIVED', child: Text('تم استلام إشعار الخصم الدائن (Received)')),
                    DropdownMenuItem(value: 'ARBITRATION', child: Text('نزاع وتحكيم تجاري مع المورد')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'قيمة إشعار الخصم (\$ USD)',
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'حفظ الإشعار',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                Navigator.of(ctx).pop();
                try {
                  final service = ref.read(reexportProtocolServiceProvider);
                  await service.recordCreditNote(
                    item.reexportId,
                    supplierCreditNoteStatus: selectedStatus,
                    creditNoteAmountUsd: amt,
                  );
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'تم تحديث بيانات إشعار الخصم الدائن للمورد بنجاح', severity: AppSeverity.success);
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'فشل في حفظ إشعار الخصم: $e', severity: AppSeverity.danger);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDrawbackDialog(ReexportDossierModel item) {
    String selectedStatus = item.dutyDrawbackStatus.name.toUpperCase();
    if (selectedStatus == 'PENDINGAPPLICATION') selectedStatus = 'PENDING_APPLICATION';
    if (selectedStatus == 'APPROVEDREFUNDED') selectedStatus = 'APPROVED_REFUNDED';
    if (selectedStatus == 'EXEMPTIONSUSPENDED') selectedStatus = 'EXEMPTION_SUSPENDED';

    final amountController = TextEditingController(text: item.dutyAmountRefundableEgp > 0 ? item.dutyAmountRefundableEgp.toStringAsFixed(2) : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Text('استرداد الرسوم الجمركية (دروباك) — ${item.importFileCode}'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('حالة طلب رد الرسوم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'PENDING_APPLICATION', child: Text('قيد تقديم طلب الاسترداد')),
                    DropdownMenuItem(value: 'APPROVED_REFUNDED', child: Text('تمت الموافقة ورد الرسوم الجمركية')),
                    DropdownMenuItem(value: 'EXEMPTION_SUSPENDED', child: Text('موقوف ومعلق الإعفاء')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'قيمة الرسوم الجمركية القابلة للاسترداد (ج.م EGP)',
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'حفظ طلب الدروباك',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                Navigator.of(ctx).pop();
                try {
                  final service = ref.read(reexportProtocolServiceProvider);
                  await service.recordDutyDrawback(
                    item.reexportId,
                    dutyDrawbackStatus: selectedStatus,
                    dutyAmountRefundableEgp: amt,
                  );
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'تم تسجيل وتحديث ملف استرداد الرسوم (الدروباك)', severity: AppSeverity.success);
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'فشل في حفظ طلب الدروباك: $e', severity: AppSeverity.danger);
                }
              },
            ),
          ],
        ),
      ),
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
                          'بروتوكول البضائع المرفوضة وإعادة التصدير (Re-Export Protocol & Statutory Destruction)',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.grey.shade100,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMetricChip('إجمالي الملفات المرفوضة', '${_alertsOverview!.totalActiveDossiers}', Colors.blueGrey),
                      const SizedBox(width: 8),
                      _buildMetricChip('خطر الإعدام (مهلة منتهية) ⛔', '${_alertsOverview!.criticalCount}', AppTheme.crimson),
                      const SizedBox(width: 8),
                      _buildMetricChip('عاجل جداً (≤ 7 أيام) 🔴', '${_alertsOverview!.urgentCount}', const Color(0xFFD32F2F)),
                      const SizedBox(width: 8),
                      _buildMetricChip('إنذار (≤ 14 يوماً) 🟡', '${_alertsOverview!.warningCount}', AppTheme.orange),
                      const SizedBox(width: 8),
                      _buildMetricChip('آمن (> 14 يوماً) 🟢', '${_alertsOverview!.normalCount}', AppTheme.emerald),
                    ],
                  ),
                ),
              ),

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
                          : SelectionArea(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _dossiers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = _dossiers[idx];
                                  final dColor = _alertColor(item.daysRemainingToDestruction);

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: dColor.withValues(alpha: 0.4), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Countdown Chip
                                        Container(
                                          width: 90,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: dColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                '${item.daysRemainingToDestruction}',
                                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dColor),
                                              ),
                                              Text(
                                                item.daysRemainingToDestruction <= 0 ? 'مهلة منتهية!' : 'يوم للإعدام',
                                                style: TextStyle(fontSize: 10, color: dColor, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Dossier Details
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    item.importFileCode,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cobalt),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  AppStatusBadge(
                                                    label: item.status.labelAr,
                                                    severity: _statusSeverity(item.status),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'قرار: ${item.rejectionDecreeNumber}',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'الجهة: ${item.rejectionAuthority} | تاريخ القرار: ${item.rejectionDate} | المهلة القانونية القصوى: ${item.legalReexportDeadline}',
                                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                              ),
                                              Text(
                                                'السبب: ${item.reexportReason}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (item.containerNumbers.isNotEmpty)
                                                Text(
                                                  'الحاويات: ${item.containerNumbers.join(", ")}',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                                ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  if (item.customsOutboundDeclarationNo != null) ...[
                                                    Icon(Icons.assignment_turned_in_outlined, size: 14, color: Colors.green.shade700),
                                                    const SizedBox(width: 3),
                                                    Text('مظهر الصادر: ${item.customsOutboundDeclarationNo}', style: TextStyle(fontSize: 11, color: Colors.green.shade900)),
                                                    const SizedBox(width: 10),
                                                  ],
                                                  if (item.returnBookingNumber != null) ...[
                                                    const Icon(Icons.directions_boat_outlined, size: 14, color: AppTheme.cobalt),
                                                    const SizedBox(width: 3),
                                                    Text('الحجز: ${item.returnBookingNumber}', style: const TextStyle(fontSize: 11, color: AppTheme.cobalt)),
                                                    const SizedBox(width: 10),
                                                  ],
                                                  if (item.creditNoteAmountUsd > 0) ...[
                                                    Icon(Icons.monetization_on_outlined, size: 14, color: Colors.purple.shade700),
                                                    const SizedBox(width: 3),
                                                    Text('خصم مورد: \$${item.creditNoteAmountUsd.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.purple.shade900)),
                                                    const SizedBox(width: 10),
                                                  ],
                                                  if (item.dutyAmountRefundableEgp > 0) ...[
                                                    Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.teal.shade700),
                                                    const SizedBox(width: 3),
                                                    Text('دروباك: ${item.dutyAmountRefundableEgp.toStringAsFixed(0)} ج.م', style: TextStyle(fontSize: 11, color: Colors.teal.shade900)),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Operations Action Buttons
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AppButton(
                                                  label: 'حجز الشحن',
                                                  icon: Icons.directions_boat_outlined,
                                                  variant: AppButtonVariant.secondary,
                                                  size: AppButtonSize.small,
                                                  onPressed: () => _showBookingDialog(item),
                                                ),
                                                const SizedBox(width: 6),
                                                AppButton(
                                                  label: 'لجنة الإشراف',
                                                  icon: Icons.shield_outlined,
                                                  variant: AppButtonVariant.secondary,
                                                  size: AppButtonSize.small,
                                                  onPressed: () => _showSupervisionCommitteeDialog(item),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AppButton(
                                                  label: 'خصم المورد',
                                                  icon: Icons.receipt_outlined,
                                                  variant: AppButtonVariant.secondary,
                                                  size: AppButtonSize.small,
                                                  onPressed: () => _showCreditNoteDialog(item),
                                                ),
                                                const SizedBox(width: 6),
                                                AppButton(
                                                  label: 'رد الرسوم (دروباك)',
                                                  icon: Icons.price_check_outlined,
                                                  variant: AppButtonVariant.secondary,
                                                  size: AppButtonSize.small,
                                                  onPressed: () => _showDrawbackDialog(item),
                                                ),
                                                if (item.status != ReexportStatus.completedClosed) ...[
                                                  const SizedBox(width: 6),
                                                  AppButton(
                                                    label: 'تصعيد المرحلة ❯',
                                                    variant: AppButtonVariant.success,
                                                    size: AppButtonSize.small,
                                                    onPressed: () => _advanceStatus(item),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
