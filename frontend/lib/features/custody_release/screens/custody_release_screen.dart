import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/custody_release_model.dart';
import '../providers/custody_release_provider.dart';

class CustodyReleaseScreen extends ConsumerStatefulWidget {
  const CustodyReleaseScreen({super.key});

  @override
  ConsumerState<CustodyReleaseScreen> createState() => _CustodyReleaseScreenState();
}

class _CustodyReleaseScreenState extends ConsumerState<CustodyReleaseScreen> {
  final List<String> _statuses = [
    'RELEASED_UNDER_CUSTODY',
    'FROZEN_IN_WAREHOUSE',
    'SAMPLE_CLEAR_FINAL_RELEASE',
    'BREACH_REPORTED',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(custodyReleaseProvider.notifier).fetchDossiers();
    });
  }

  String _statusLabelAr(String status) {
    switch (status) {
      case 'RELEASED_UNDER_CUSTODY':
        return 'إفراج مؤقت تحت التحفظ';
      case 'FROZEN_IN_WAREHOUSE':
        return 'مجمدة بالمخزن (قيد الفحص)';
      case 'SAMPLE_CLEAR_FINAL_RELEASE':
        return 'مطابقة وإفراج نهائي';
      case 'BREACH_REPORTED':
        return 'إبلاغ عن فض أحراز / مخالفة';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RELEASED_UNDER_CUSTODY':
        return Colors.orange;
      case 'FROZEN_IN_WAREHOUSE':
        return AppTheme.cobalt;
      case 'SAMPLE_CLEAR_FINAL_RELEASE':
        return AppTheme.emerald;
      case 'BREACH_REPORTED':
        return AppTheme.crimson;
      default:
        return Colors.grey;
    }
  }

  void _showCreateDossierDialog() {
    final fileItems = ref.read(importFilesProvider).value ?? [];
    int? selectedFileId;
    final undertakingController = TextEditingController();
    final warehouseAddressController = TextEditingController();
    final officerController = TextEditingController();
    final sealsCountController = TextEditingController(text: '1');
    final sealNumbersController = TextEditingController();
    final transportPermitController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (sbContext, setDlgState) {
          final isArabic = sbContext.l10n.isArabic;
          final isDark = AppTheme.isDark(sbContext);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'تسجيل تعهد إفراج تحت التحفظ الجمركي' : 'Register Custody Undertaking',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SelectionArea(
              child: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'ملف الشحنة *' : 'Import File *',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        SearchableDropdownField<int>(
                          items: fileItems
                              .map((f) => SearchableDropdownItem(
                                    value: f.importFileId,
                                    label: '${f.importFileCode} — ${f.companyName}',
                                  ))
                              .toList(),
                          value: selectedFileId,
                          hintText: isArabic ? 'اختر ملف الشحنة...' : 'Select file...',
                          onChanged: (v) => setDlgState(() => selectedFileId = v),
                          validator: (v) => v == null
                              ? (isArabic ? 'الملف إلزامي' : 'File is required')
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isArabic ? 'رقم التعهد / المحضر الجمركي *' : 'Undertaking Number *',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: undertakingController,
                          decoration: InputDecoration(
                            hintText: isArabic ? 'مثال: تعهد رقم 458/2026' : 'Undertaking ref no.',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (isArabic ? 'رقم التعهد مطلوب' : 'Undertaking number required')
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isArabic ? 'عنوان المخزن / مكان التحفظ' : 'Warehouse Storage Address',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: warehouseAddressController,
                          decoration: InputDecoration(
                            hintText: isArabic ? 'مخزن الشركة - المنطقة الصناعية' : 'Storage address',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'اسم مأمور الضبط القضائي' : 'Judicial Officer Name',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: officerController,
                                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'تصريح النقل' : 'Transport Permit No.',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: transportPermitController,
                                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'عدد السيل' : 'Seals Count',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: sealsCountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'أرقام السيل (مفصولة بفواصل)' : 'Seal Numbers (comma-separated)',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: sealNumbersController,
                                    decoration: const InputDecoration(
                                      hintText: 'SEAL-01, SEAL-02',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isArabic ? 'ملاحظات وتوجيهات الحراسة' : 'Notes & Instructions',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final sealList = sealNumbersController.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();

                  final payload = {
                    'import_file_id': selectedFileId,
                    'custody_undertaking_number': undertakingController.text.trim(),
                    'warehouse_address': warehouseAddressController.text.trim().isEmpty
                        ? null
                        : warehouseAddressController.text.trim(),
                    'judicial_officer_name':
                        officerController.text.trim().isEmpty ? null : officerController.text.trim(),
                    'lead_seals_count': int.tryParse(sealsCountController.text.trim()) ?? 0,
                    'lead_seal_numbers': sealList,
                    'transport_permit_number': transportPermitController.text.trim().isEmpty
                        ? null
                        : transportPermitController.text.trim(),
                    'status': 'RELEASED_UNDER_CUSTODY',
                    'lock_active': true,
                    'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  };

                  final success =
                      await ref.read(custodyReleaseProvider.notifier).createDossier(payload);
                  if (ctx.mounted && success) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? 'تم تسجيل ملف الإفراج تحت التحفظ وتفعيل حظر الصرف 🔒'
                              : 'Custody release dossier created with active lock 🔒',
                        ),
                        backgroundColor: AppTheme.emerald,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: Text(isArabic ? 'حفظ وتفعيل التحفظ' : 'Save & Lock'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFreezeDialog(CustodyReleaseDossierModel dossier) {
    final notesController = TextEditingController();
    final addressController = TextEditingController(text: dossier.warehouseAddress ?? '');
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warehouse_rounded, color: AppTheme.cobalt, size: 22),
            const SizedBox(width: 8),
            Text(isArabic ? 'تأكيد وصول المخزن وتجميد الشحنة' : 'Confirm Warehouse Arrival & Freeze'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isArabic ? 'الملف:' : 'File:'} ${dossier.custodyCode} (${dossier.custodyUndertakingNumber})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
              ),
              const SizedBox(height: 12),
              Text(isArabic ? 'عنوان المخزن المؤكد' : 'Confirmed Warehouse Address', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              TextField(controller: addressController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              Text(isArabic ? 'ملاحظات فحص السيل واستلام البضاعة' : 'Seal check and receipt notes', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
            onPressed: () async {
              final payload = {
                'warehouse_address': addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
              };
              final success = await ref
                  .read(custodyReleaseProvider.notifier)
                  .freezeInWarehouse(dossier.custodyId, payload);
              if (ctx.mounted && success) {
                Navigator.of(ctx).pop();
              }
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic ? 'تم تأكيد وصول المخزن وتجميد الشحنة' : 'Arrival confirmed & cargo frozen'),
                    backgroundColor: AppTheme.emerald,
                  ),
                );
              }
            },
            child: Text(isArabic ? 'تأكيد التجميد بالمخزن' : 'Confirm Freeze'),
          ),
        ],
      ),
    );
  }

  void _showFinalClearanceDialog(CustodyReleaseDossierModel dossier) {
    final letterNoController = TextEditingController();
    final notesController = TextEditingController();
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: AppTheme.emerald, size: 22),
            const SizedBox(width: 8),
            Text(isArabic ? 'المطابقة المعملية والإفراج النهائي (فك الحظر)' : 'Approve Final Clearance & Lift Lock'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isArabic ? 'الملف:' : 'File:'} ${dossier.custodyCode}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
              ),
              const SizedBox(height: 12),
              Text(
                isArabic ? 'رقم خطاب الإفراج النهائي / شهادة المطابقة *' : 'Final Clearance Letter / Certificate No. *',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: letterNoController,
                decoration: InputDecoration(
                  hintText: isArabic ? 'مثال: خطاب معامل سلامة الغذاء رقم 8872' : 'Clearance letter reference',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Text(isArabic ? 'ملاحظات الإفراج والاعتماد' : 'Authorization Remarks', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
            onPressed: () async {
              final letterNo = letterNoController.text.trim();
              if (letterNo.isEmpty) return;
              final payload = {
                'final_clearance_letter_number': letterNo,
                'release_approved_at': DateTime.now().toIso8601String(),
                'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
              };
              final success = await ref
                  .read(custodyReleaseProvider.notifier)
                  .approveFinalClearance(dossier.custodyId, payload);
              if (ctx.mounted && success) {
                Navigator.of(ctx).pop();
              }
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isArabic
                          ? 'تم اعتماد المطابقة وفك حظر الصرف عن الشحنة بنجاح 🔓'
                          : 'Final release approved and custody lock lifted 🔓',
                    ),
                    backgroundColor: AppTheme.emerald,
                  ),
                );
              }
            },
            child: Text(isArabic ? 'اعتماد الإفراج وفك الحظر 🔓' : 'Lift Lock & Release'),
          ),
        ],
      ),
    );
  }

  void _showReportBreachDialog(CustodyReleaseDossierModel dossier) {
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 22),
            const SizedBox(width: 8),
            Text(isArabic ? 'إبلاغ عن فض أحراز أو كسر سيل جمركي' : 'Report Custody Breach / Seal Tampering'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isArabic ? 'الملف:' : 'File:'} ${dossier.custodyCode}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.crimson),
              ),
              const SizedBox(height: 12),
              Text(
                isArabic ? 'سبب الإبلاغ وتفاصيل كسر السيل / الفض *' : 'Breach Reason & Details *',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: isArabic
                      ? 'توضيح تفاصيل كسر السيل، الصرف بدون إذن، أو أي مخالفة جمركية...'
                      : 'Detailed report of seal breach or tampering...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Text(isArabic ? 'إجراءات الإخطار الجمركي / القضائي' : 'Judicial Notification Remarks', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              TextField(controller: notesController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.length < 5) return;
              final payload = {
                'breach_reason': reason,
                'reported_at': DateTime.now().toIso8601String(),
                'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
              };
              final success =
                  await ref.read(custodyReleaseProvider.notifier).reportBreach(dossier.custodyId, payload);
              if (ctx.mounted && success) {
                Navigator.of(ctx).pop();
              }
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic ? 'تم تسجيل الإبلاغ عن المخالفة' : 'Breach reported successfully'),
                    backgroundColor: AppTheme.crimson,
                  ),
                );
              }
            },
            child: Text(isArabic ? 'تسجيل البلاغ ⚠️' : 'Report Breach'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(custodyReleaseProvider);
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    final totalDossiers = state.dossiers.length;
    final lockedCount = state.dossiers.where((d) => d.lockActive).length;
    final releasedCount = state.dossiers.where((d) => !d.lockActive).length;
    final breachesCount = state.dossiers.where((d) => d.status == 'BREACH_REPORTED').length;

    return Scaffold(
      appBar: PageHeader(
        title: isArabic
            ? 'إدارة الإفراج تحت التحفظ الجمركي وتعهدات البضائع'
            : 'Customs Warehouse Custody & Under-Bond Release',
        subtitle: isArabic
            ? 'متابعة بضائع التحفظ، تأكيد وصول المخازن، سلامة السيل الجمركي، وإذن الإفراج النهائي'
            : 'Cargo under custody tracking, warehouse seals check, and final conformity release',
        icon: Icons.shield_outlined,
        actions: const [
          BackToDashboardButton(),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Metrics Strip
              Row(
                children: [
                  _buildMetric(
                    label: isArabic ? 'إجمالي الملفات' : 'Total Dossiers',
                    value: '$totalDossiers',
                    icon: Icons.folder_outlined,
                    color: AppTheme.cobalt,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildMetric(
                    label: isArabic ? 'محظور الصرف بالمخزن 🔒' : 'Locked Under Custody 🔒',
                    value: '$lockedCount',
                    icon: Icons.lock_clock_rounded,
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildMetric(
                    label: isArabic ? 'مفرج نهائياً 🔓' : 'Final Released 🔓',
                    value: '$releasedCount',
                    icon: Icons.verified_rounded,
                    color: AppTheme.emerald,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildMetric(
                    label: isArabic ? 'بلاغات خرق الأحراز ⚠️' : 'Breach Reports ⚠️',
                    value: '$breachesCount',
                    icon: Icons.warning_rounded,
                    color: AppTheme.crimson,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Toolbar
              Row(
                children: [
                  // Status Filter
                  Container(
                    width: 220,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: state.statusFilter,
                        isDense: true,
                        isExpanded: true,
                        hint: Text(isArabic ? 'كل الحالات' : 'All Statuses', style: const TextStyle(fontSize: 12)),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(isArabic ? 'كل الحالات' : 'All Statuses', style: const TextStyle(fontSize: 12)),
                          ),
                          ..._statuses.map((s) => DropdownMenuItem<String?>(
                                value: s,
                                child: Text(_statusLabelAr(s), style: const TextStyle(fontSize: 12)),
                              )),
                        ],
                        onChanged: (v) => ref.read(custodyReleaseProvider.notifier).setFilter(status: v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Lock Filter
                  Container(
                    width: 170,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<bool?>(
                        value: state.lockActiveFilter,
                        isDense: true,
                        isExpanded: true,
                        hint: Text(isArabic ? 'قفل الصرف: الكل' : 'Lock: All', style: const TextStyle(fontSize: 12)),
                        items: [
                          DropdownMenuItem<bool?>(
                            value: null,
                            child: Text(isArabic ? 'قفل الصرف: الكل' : 'Lock: All', style: const TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem<bool?>(
                            value: true,
                            child: Text(isArabic ? '🔒 محظور الصرف' : '🔒 Locked', style: const TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem<bool?>(
                            value: false,
                            child: Text(isArabic ? '🔓 مفرج' : '🔓 Unlocked', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                        onChanged: (v) => ref.read(custodyReleaseProvider.notifier).setFilter(lockActive: v),
                      ),
                    ),
                  ),
                  const Spacer(),

                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: isArabic ? 'تحديث' : 'Refresh',
                    onPressed: () => ref.read(custodyReleaseProvider.notifier).fetchDossiers(),
                  ),
                  const SizedBox(width: 8),

                  AppButton(
                    label: isArabic ? 'تسجيل تعهد إفراج جديد' : 'New Custody Undertaking',
                    icon: Icons.add_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: _showCreateDossierDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content List
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.dossiers.isEmpty
                        ? Center(
                            child: Text(
                              isArabic
                                  ? 'لا توجد ملفات إفراج تحت التحفظ مطابقة'
                                  : 'No custody dossiers found',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: state.dossiers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = state.dossiers[index];
                              return Card(
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Lock badge
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: item.lockActive
                                              ? Colors.orange.withValues(alpha: 0.15)
                                              : AppTheme.emerald.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          item.lockActive
                                              ? Icons.lock_rounded
                                              : Icons.lock_open_rounded,
                                          color: item.lockActive ? Colors.orange : AppTheme.emerald,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Main details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                InkWell(
                                                  onTap: () => CopyHelper.copy(context, item.custodyCode),
                                                  child: Text(
                                                    item.custodyCode,
                                                    style: const TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: AppTheme.cobalt,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${isArabic ? 'تعهد رقم:' : 'Undertaking:'} ${item.custodyUndertakingNumber}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(item.status).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    _statusLabelAr(item.status),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: _statusColor(item.status),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                if (item.warehouseAddress != null)
                                                  Text(
                                                    '${isArabic ? 'المخزن:' : 'Warehouse:'} ${item.warehouseAddress}',
                                                    style: const TextStyle(fontSize: 11.5),
                                                  ),
                                                Text(
                                                  '${isArabic ? 'عدد السيل:' : 'Seals:'} ${item.leadSealsCount} ${item.leadSealNumbers.isNotEmpty ? "(${item.leadSealNumbers.join(', ')})" : ""}',
                                                  style: const TextStyle(fontSize: 11.5),
                                                ),
                                                if (item.transportPermitNumber != null)
                                                  Text(
                                                    '${isArabic ? 'تصريح نقل:' : 'Permit:'} ${item.transportPermitNumber}',
                                                    style: const TextStyle(fontSize: 11.5),
                                                  ),
                                                if (item.judicialOfficerName != null)
                                                  Text(
                                                    '${isArabic ? 'مأمور الضبط:' : 'Officer:'} ${item.judicialOfficerName}',
                                                    style: const TextStyle(fontSize: 11.5),
                                                  ),
                                              ],
                                            ),
                                            if (item.finalClearanceLetterNumber != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                '${isArabic ? 'إذن الإفراج النهائي:' : 'Final release letter:'} ${item.finalClearanceLetterNumber}',
                                                style: const TextStyle(fontSize: 11.5, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                            if (item.breachReason != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                '${isArabic ? 'بلاغ الخرق:' : 'Breach details:'} ${item.breachReason}',
                                                style: const TextStyle(fontSize: 11.5, color: AppTheme.crimson, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Actions Menu
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 20),
                                        onSelected: (action) {
                                          if (action == 'freeze') {
                                            _showFreezeDialog(item);
                                          } else if (action == 'clearance') {
                                            _showFinalClearanceDialog(item);
                                          } else if (action == 'breach') {
                                            _showReportBreachDialog(item);
                                          } else if (action == 'delete') {
                                            ref.read(custodyReleaseProvider.notifier).deleteDossier(item.custodyId);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          PopupMenuItem(
                                            value: 'freeze',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.warehouse_rounded, color: AppTheme.cobalt, size: 18),
                                                const SizedBox(width: 8),
                                                Text(isArabic ? 'تأكيد وصول وتجميد المخزن' : 'Freeze in Warehouse'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'clearance',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.lock_open_rounded, color: AppTheme.emerald, size: 18),
                                                const SizedBox(width: 8),
                                                Text(isArabic ? 'إفراج نهائي وفك الحظر 🔓' : 'Final Clearance'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'breach',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 18),
                                                const SizedBox(width: 8),
                                                Text(isArabic ? 'إبلاغ عن فض أحراز ⚠️' : 'Report Breach'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuDivider(),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                                                const SizedBox(width: 8),
                                                Text(isArabic ? 'حذف السجل' : 'Delete'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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

  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2631) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
