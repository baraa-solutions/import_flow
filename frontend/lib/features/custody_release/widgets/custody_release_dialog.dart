import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/custody_release_model.dart';
import '../providers/custody_release_provider.dart';

/// Modal dialogs for managing Customs Custody dossiers and status transitions.
class CustodyReleaseDialog {
  /// Displays the create custody release dossier dialog.
  static Future<void> showCreate(BuildContext context, WidgetRef ref) async {
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

    await showDialog(
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
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, isArabic ? 'تم تسجيل ملف الإفراج تحت التحفظ وتفعيل حظر الصرف' : 'Custody release dossier created with active lock', severity: AppSeverity.success));
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

  /// Displays the confirm warehouse arrival and freeze cargo dialog.
  static Future<void> showFreeze(
    BuildContext context,
    WidgetRef ref,
    CustodyReleaseDossierModel dossier,
  ) async {
    final notesController = TextEditingController();
    final addressController = TextEditingController(text: dossier.warehouseAddress ?? '');
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    await showDialog(
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
        content: SelectionArea(
          child: SizedBox(
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
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, isArabic ? 'تم تأكيد وصول المخزن وتجميد الشحنة' : 'Arrival confirmed & cargo frozen', severity: AppSeverity.success));
              }
            },
            child: Text(isArabic ? 'تأكيد التجميد بالمخزن' : 'Confirm Freeze'),
          ),
        ],
      ),
    );
  }

  /// Displays the final laboratory clearance and lock lifting dialog.
  static Future<void> showFinalClearance(
    BuildContext context,
    WidgetRef ref,
    CustodyReleaseDossierModel dossier,
  ) async {
    final letterNoController = TextEditingController();
    final notesController = TextEditingController();
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    await showDialog(
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
        content: SelectionArea(
          child: SizedBox(
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
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, isArabic ? 'تم اعتماد المطابقة وفك حظر الصرف عن الشحنة بنجاح' : 'Final release approved and custody lock lifted', severity: AppSeverity.success));
              }
            },
            child: Text(isArabic ? 'اعتماد الإفراج وفك الحظر 🔓' : 'Lift Lock & Release'),
          ),
        ],
      ),
    );
  }

  /// Displays the report seal tampering / custody breach dialog.
  static Future<void> showReportBreach(
    BuildContext context,
    WidgetRef ref,
    CustodyReleaseDossierModel dossier,
  ) async {
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    await showDialog(
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
        content: SelectionArea(
          child: SizedBox(
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
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, isArabic ? 'تم تسجيل الإبلاغ عن المخالفة' : 'Breach reported successfully', severity: AppSeverity.danger));
              }
            },
            child: Text(isArabic ? 'تسجيل البلاغ ⚠️' : 'Report Breach'),
          ),
        ],
      ),
    );
  }
}
