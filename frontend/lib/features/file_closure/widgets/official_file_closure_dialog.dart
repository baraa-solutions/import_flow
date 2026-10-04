import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/file_save_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/file_closure_model.dart';
import '../providers/file_closure_provider.dart';
import '../../experience_guide/widgets/add_guide_entry_dialog.dart';

/// Desktop-oriented modal dialog for CLO-04 Official File Closure & Digital Archive.
/// Conducts 6-pillar pre-closure audit checks, allows archival vault registration,
/// generates official closure certificate (CLR-YYYY-XXXX), and locks file at 100% Closed.
class OfficialFileClosureDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const OfficialFileClosureDialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ImportFileModel file,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OfficialFileClosureDialog(file: file),
    );
  }

  @override
  ConsumerState<OfficialFileClosureDialog> createState() =>
      _OfficialFileClosureDialogState();
}

class _OfficialFileClosureDialogState
    extends ConsumerState<OfficialFileClosureDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _auditorController;
  late final TextEditingController _archiveLocationController;
  late final TextEditingController _notesController;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  ClosurePrecheckResponseModel? _precheck;

  // Checklist states
  bool _docsVerified = true;
  bool _customsCleared = true;
  bool _warehouseReceived = true;
  bool _landedCostSettled = true;
  bool _dossierExported = true;
  bool _emptyContainersReturned = true;
  bool _tasksClosed = true;

  @override
  void initState() {
    super.initState();
    _auditorController = TextEditingController(
      text: widget.file.owner.isNotEmpty ? widget.file.owner : 'Kamal (Internal Auditor)',
    );
    _archiveLocationController = TextEditingController(
      text: 'Central Secure Digital Archive Vault - 2026/Volume-A',
    );
    _notesController = TextEditingController();
    _loadPrecheck();
  }

  @override
  void dispose() {
    _auditorController.dispose();
    _archiveLocationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPrecheck() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final precheck = await ref
          .read(fileClosureProvider.notifier)
          .fetchClosurePrecheck(widget.file.importFileId);

      if (mounted) {
        setState(() {
          _precheck = precheck;
          _isLoading = false;
          _docsVerified = precheck.checklistStatus['docs_verified'] ?? true;
          _customsCleared =
              precheck.checklistStatus['customs_cleared'] ?? true;
          _warehouseReceived =
              precheck.checklistStatus['warehouse_received'] ?? true;
          _landedCostSettled =
              precheck.checklistStatus['landed_cost_settled'] ?? true;
          _dossierExported =
              precheck.checklistStatus['dossier_exported'] ??
                  (widget.file.dossierExportedAt != null);
          _emptyContainersReturned =
              precheck.checklistStatus['empty_containers_returned'] ?? true;
          _tasksClosed = precheck.checklistStatus['tasks_closed'] ?? true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'فشل جلب نتائج الفحص والتدقيق المسبق: $e';
        });
      }
    }
  }

  Future<void> _handleExportCertificate() async {
    if (_precheck == null) return;
    final certCode = _precheck!.certificateCodePreview;

    final certificateText = StringBuffer()
      ..writeln('================================================================================')
      ..writeln('               شهادة الإغلاق الرسمي والأرشفة الرقمية المكتملة')
      ..writeln('               OFFICIAL IMPORT FILE CLOSURE & ARCHIVAL CERTIFICATE')
      ..writeln('================================================================================')
      ..writeln('رقم الشهادة المعتمد: $certCode')
      ..writeln('تاريخ وتوقيت الإصدار: ${DateTime.now().toIso8601String()}')
      ..writeln('رمز ملف الاستيراد: ${widget.file.importFileCode}')
      ..writeln('الشركة المستوردة: ${_precheck!.companyName}')
      ..writeln('المورد الأجنبي: ${_precheck!.supplierName}')
      ..writeln('مدقق الإغلاق المعتمد: ${_auditorController.text.trim()}')
      ..writeln('موقع ومسار الأرشفة الرقمية: ${_archiveLocationController.text.trim()}')
      ..writeln('--------------------------------------------------------------------------------')
      ..writeln('ركائز التدقيق الختامي (Final Audit Verification Pillars):')
      ..writeln('1. الإفراج الجمركي النهائي: ${_customsCleared ? "معتمد ومستوفى" : "غير مستوفى"}')
      ..writeln('2. إذن استلام المستودع (GRN): ${_warehouseReceived ? "معتمد ومستوفى" : "غير مستوفى"}')
      ..writeln('3. تسوية تكلفة الوصول الفعلية: ${_landedCostSettled ? "معتمدة ومطابقة" : "غير مستوفاة"}')
      ..writeln('   - إجمالي التكلفة الفعلية: ${_precheck!.actualLandedCostEgp.toStringAsFixed(2)} EGP')
      ..writeln('   - معامل تكلفة الوصول: ${_precheck!.actualMarkupFactor.toStringAsFixed(3)}x')
      ..writeln('4. تصدير الملف الشامل (CLO-03): ${_dossierExported ? "معتمد ومصدر" : "غير مصدر"}')
      ..writeln('5. تسليم الحاويات الفارغة (EIR): ${_emptyContainersReturned ? "معتمد ومكتمل" : "معلق"}')
      ..writeln('6. المهام التشغيلية للملف: ${_tasksClosed ? "مغلقة بالكامل" : "معلقة"}')
      ..writeln('--------------------------------------------------------------------------------')
      ..writeln('ملاحظات الأرشفة والتدقيق:')
      ..writeln(_notesController.text.trim().isNotEmpty ? _notesController.text.trim() : 'لا توجد ملاحظات إضافية')
      ..writeln('================================================================================')
      ..writeln('حالة الملف: Closed & Settled (Archived - Read-Only Historical State - 100%)');

    final bytes = utf8.encode(certificateText.toString());

    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: bytes,
      stageName: 'Closure Certificate',
      importFileNameOrCode: widget.file.importFileCode,
      extension: 'txt',
      customDialogTitle: 'حفظ شهادة الإغلاق والأرشفة الرقمية',
      showNotification: true,
    );
  }

  Future<void> _handleConfirmClosure() async {
    if (!_formKey.currentState!.validate()) return;
    if (_precheck != null && !_precheck!.canClose) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إتمام الإغلاق الرسمي لوجود متطلبات معلقة!'),
          backgroundColor: AppTheme.flatCrimson,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'import_file_id': widget.file.importFileId,
        'auditor_name': _auditorController.text.trim(),
        'archive_location': _archiveLocationController.text.trim(),
        'archival_notes': _notesController.text.trim(),
        'closure_checklist': {
          'docs_verified': _docsVerified,
          'customs_cleared': _customsCleared,
          'warehouse_received': _warehouseReceived,
          'landed_cost_settled': _landedCostSettled,
          'dossier_exported': _dossierExported,
          'empty_containers_returned': _emptyContainersReturned,
          'tasks_closed': _tasksClosed,
        },
        'is_draft': false,
      };

      final certificate = await ref
          .read(fileClosureProvider.notifier)
          .officialCloseImportFile(payload);

      // Invalidate global import files and closures to ensure live screen update
      ref.invalidate(importFilesProvider);
      ref.invalidate(fileClosureProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تهانينا! تم إغلاق الملف ${certificate.importFileCode} رسمياً بنسبة 100% بموجب الشهادة ${certificate.closureCode}.',
            ),
            backgroundColor: AppTheme.flatEmerald,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop(true);

        // Prompt for Experience Guide Knowledge Capture
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.psychology_outlined, color: AppTheme.flatCobalt),
                SizedBox(width: 8),
                Text('توثيق الخبرة المؤسسية للشحنة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'تهانينا على إغلاق الشحنة بنجاح!\n\nهل واجهتك أي عقبات تشغيلية، تأخيرات، أو دروس مستفادة ترغب في توثيقها في بنك المعرفة لتفادي تكرارها مستقبلاً؟',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('لاحقاً (تخطي)'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCobalt,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_comment_outlined, size: 16),
                label: const Text('نعم، وثّق درساً مستفاداً'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: context,
                    builder: (dCtx) => AddGuideEntryDialog(
                      initialSupplier: widget.file.supplierName,
                      initialHsCode: widget.file.hsCode,
                      initialCategory: widget.file.productCategory,
                      initialDestinationPort: widget.file.portOfDischarge,
                      initialIncoterm: widget.file.incotermCode,
                      initialImportFileReference: widget.file.importFileCode,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإغلاق الرسمي للملف: $e'),
            backgroundColor: AppTheme.flatCrimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            _buildHeader(isDark),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 2. Content Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('جاري فحص وتدقيق ركائز الإغلاق الستة...'),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _buildMainContent(isDark),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 3. Actions Row
            _buildActionsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.flatEmerald.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_rounded,
            color: AppTheme.flatEmerald,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الإغلاق الرسمي والأرشفة الرقمية (CLO-04)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'رمز الملف: ${widget.file.importFileCode} | المورد: ${widget.file.supplierName.isNotEmpty ? widget.file.supplierName : "-"} | حالة الملف: ${widget.file.status}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close),
          tooltip: 'إغلاق النافذة',
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.flatCrimson, size: 44),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.flatCrimson, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadPrecheck,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    final precheck = _precheck!;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Six Pillars Audit Badges Strip
            _buildSixPillarsStrip(precheck),
            const SizedBox(height: 14),

            // 2. Blocking Reasons / Warnings
            if (precheck.blockingReasons.isNotEmpty) ...[
              _buildAlertBox(
                title: 'متطلبات إغلاق إلزامية معلقة (يجب استيفاؤها أولاً):',
                items: precheck.blockingReasons,
                isError: true,
              ),
              const SizedBox(height: 12),
            ],

            if (precheck.warnings.isNotEmpty) ...[
              _buildAlertBox(
                title: 'تنبيهات تدقيقية قبل الأرشفة الرقمية:',
                items: precheck.warnings,
                isError: false,
              ),
              const SizedBox(height: 12),
            ],

            // 3. Digital Certificate Preview & Metrics
            _buildCertificateSummaryCard(precheck, isDark),
            const SizedBox(height: 14),

            // 4. Archival Vault Registration Fields
            _buildArchivalFormFields(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSixPillarsStrip(ClosurePrecheckResponseModel precheck) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.flatCharcoal.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, size: 18, color: AppTheme.flatCobalt),
              SizedBox(width: 6),
              Text(
                'ركائز التدقيق الختامي المعتمدة (6 Core Pillars)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillarBadge(
                '1. الإفراج الجمركي',
                _customsCleared,
                Icons.local_police_outlined,
              ),
              _pillarBadge(
                '2. إضافة المخزن (GRN)',
                _warehouseReceived,
                Icons.warehouse_outlined,
              ),
              _pillarBadge(
                '3. تسوية التكلفة الفعلية',
                _landedCostSettled,
                Icons.account_balance_wallet_outlined,
              ),
              _pillarBadge(
                '4. تصدير الملف الشامل',
                _dossierExported,
                Icons.description_outlined,
              ),
              _pillarBadge(
                '5. تسليم الحاويات (EIR)',
                _emptyContainersReturned,
                Icons.directions_boat_outlined,
              ),
              _pillarBadge(
                '6. إغلاق المهام',
                _tasksClosed,
                Icons.task_alt_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillarBadge(String label, bool isOk, IconData icon) {
    final color = isOk ? AppTheme.flatEmerald : AppTheme.flatCrimson;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBox({
    required String title,
    required List<String> items,
    required bool isError,
  }) {
    final color = isError ? AppTheme.flatCrimson : AppTheme.flatOrange;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 18, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      it,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isError ? AppTheme.flatCrimson : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateSummaryCard(
    ClosurePrecheckResponseModel precheck,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.flatCobalt.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.flatCobalt.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Icon(Icons.card_membership_rounded, size: 18, color: AppTheme.flatCobalt),
                    const Text(
                      'معاينة شهادة الإغلاق الرقمية:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.flatCobalt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        precheck.certificateCodePreview,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تكلفة الوصول الفعلية المعتمدة: ${precheck.actualLandedCostEgp.toStringAsFixed(2)} EGP  |  معامل الوصول: ${precheck.actualMarkupFactor.toStringAsFixed(3)}x',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            key: const Key('exportClosureCertificateBtn'),
            onPressed: _handleExportCertificate,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('تصدير الشهادة (TXT)', style: TextStyle(fontSize: 11.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.flatCobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivalFormFields(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'بيانات التوثيق والمدقق المسؤول:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('closureAuditorNameField'),
                controller: _auditorController,
                decoration: const InputDecoration(
                  labelText: 'اسم المدقق / المسؤول المعتمد *',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'يرجى إدخال اسم المدقق' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: const Key('closureArchiveLocationField'),
                controller: _archiveLocationController,
                decoration: const InputDecoration(
                  labelText: 'موقع وخزينة الأرشفة الرقمية *',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'يرجى تحديد موقع الأرشفة' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: const Key('closureArchivalNotesField'),
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'ملاحظات الأرشفة والتدقيق الختامي (اختياري)',
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildActionsRow() {
    final canClose = _precheck?.canClose ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          key: const Key('cancelClosureBtn'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close),
          label: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          key: const Key('confirmOfficialClosureBtn'),
          onPressed: (_isSubmitting || !canClose) ? null : _handleConfirmClosure,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.lock_person_rounded),
          label: Text(
            _isSubmitting
                ? 'جاري إغلاق الملف وأرشفته...'
                : canClose
                    ? 'اعتماد الإغلاق الرسمي والأرشفة الرقمية (100%)'
                    : 'الإغلاق غير متاح (متطلبات معلقة)',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: canClose ? AppTheme.flatEmerald : Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
