import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../external_service_providers/providers/partners_provider.dart';
import '../import_file_form_dialog.dart';

/// 🚢 Tab 3: Customs & Regulatory Compliance for [ImportFileFormDialog].
///
/// Houses customs broker selection, HS code entries with real-time Experience Guide
/// matching and risk alerts, product category classification, and official regulatory
/// reference tracking (Bank Form 4, SWIFT MT103 reference, and Customs Declaration 46).
class ImportFileFormCustomsTab extends ConsumerStatefulWidget {
  final ImportFileFormDialogState dialog;

  const ImportFileFormCustomsTab({super.key, required this.dialog});

  @override
  ConsumerState<ImportFileFormCustomsTab> createState() => _ImportFileFormCustomsTabState();
}

class _ImportFileFormCustomsTabState extends ConsumerState<ImportFileFormCustomsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _showAddHsCodeDialog(BuildContext context, bool isArabic) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: Text(isArabic ? 'إضافة بند جمركي إضافي' : 'Add Additional HS Code'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: isArabic ? 'كود البند الجمركي' : 'HS Code',
              hintText: isArabic ? 'مثال: 84158200' : 'e.g. 84158200',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newCode = ctrl.text.trim();
                if (newCode.isNotEmpty) {
                  widget.dialog.addHsCode(newCode);
                }
                Navigator.pop(ctx);
              },
              child: Text(isArabic ? 'إضافة' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dialog = widget.dialog;
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final partners = ref.watch(partnersProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Customs Clearance Broker ──────────────────────────────────
          SearchableDropdownField<int?>(
            value: dialog.selectedBrokerId,
            labelText: l.customsClearanceBroker,
            searchHintText: l.customsClearanceBroker,
            items: [
              SearchableDropdownItem<int?>(value: null, label: '-- ${l.customsClearanceBroker} --'),
              ...partners
                  .where((p) => p.partnerType.toUpperCase().contains('BROKER') || p.partnerType.toUpperCase().contains('CUSTOMS'))
                  .map((b) => SearchableDropdownItem<int?>(
                        value: b.providerId,
                        label: b.partnerName,
                        subtitle: b.partnerType,
                      )),
            ],
            onChanged: (val) {
              if (val != null) {
                final b = partners.firstWhere((p) => p.providerId == val);
                dialog.setState(() {
                  dialog.selectedBrokerId = val;
                  dialog.brokerName = b.partnerName;
                });
              } else {
                dialog.setState(() {
                  dialog.selectedBrokerId = null;
                  dialog.brokerName = '';
                });
              }
              dialog.markDirty();
            },
          ),
          const SizedBox(height: 12),

          // ── HS Code & Product Category Classification ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dialog.hsCodeController,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: l.guideHsCode,
                              hintText: isArabic ? 'مثال: 8520, 8415' : 'e.g. 8520, 8415',
                              prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppTheme.cobalt, size: 20),
                              border: const OutlineInputBorder(),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (dialog.isMatchingGuide)
                                    const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                    )
                                  else ...[
                                    IconButton(
                                      icon: const Icon(Icons.search, color: AppTheme.cobalt, size: 18),
                                      tooltip: l.guideMatchButton,
                                      onPressed: dialog.matchGuide,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, color: Colors.grey, size: 18),
                                      tooltip: isArabic ? 'نسخ البند الجمركي' : 'Copy HS Code',
                                      onPressed: () => CopyHelper.copy(context, dialog.hsCodeController.text),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            onFieldSubmitted: (_) => dialog.matchGuide(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                            foregroundColor: AppTheme.cobalt,
                            side: const BorderSide(color: AppTheme.cobalt),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            isArabic ? '+ بند جمركي' : '+ HS Code',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: () => _showAddHsCodeDialog(context, isArabic),
                        ),
                      ],
                    ),
                    if (dialog.currentHsCodes.length > 1) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: dialog.currentHsCodes.map((code) => Chip(
                          label: Text(code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => dialog.removeHsCode(code),
                          backgroundColor: AppTheme.cobalt.withValues(alpha: 0.08),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: dialog.productCategoryController,
                  decoration: InputDecoration(
                    labelText: l.guideProductCategory,
                    hintText: isArabic ? 'مثال: إلكترونيات صوتية' : 'e.g. Audio Electronics',
                    prefixIcon: const Icon(Icons.category_outlined, color: AppTheme.cobalt, size: 20),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: isArabic ? 'نسخ التصنيف' : 'Copy Category',
                      onPressed: () => CopyHelper.copy(context, dialog.productCategoryController.text),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Guide Alert Banner ─────────────────────────────────────────
          if (dialog.matchedGuidance != null && dialog.matchedGuidance!.matchedEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dialog.matchedGuidance!.matchedEntries.any((e) => e.severity == 'critical')
                    ? AppTheme.crimson.withValues(alpha: 0.08)
                    : AppTheme.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: dialog.matchedGuidance!.matchedEntries.any((e) => e.severity == 'critical')
                      ? AppTheme.crimson
                      : AppTheme.orange,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        dialog.matchedGuidance!.matchedEntries.any((e) => e.severity == 'critical')
                            ? Icons.error_outline
                            : Icons.warning_amber_outlined,
                        color: dialog.matchedGuidance!.matchedEntries.any((e) => e.severity == 'critical')
                            ? AppTheme.crimson
                            : AppTheme.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${l.guideMatchResultLabel} (${dialog.matchedGuidance!.matchedEntries.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: dialog.matchedGuidance!.matchedEntries.any((e) => e.severity == 'critical')
                              ? AppTheme.crimson
                              : AppTheme.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...(dialog.matchedGuidance!.matchedEntries.take(3).map((e) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            e.title,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── Official Stage Auto-Populated Reference Numbers ────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: AppTheme.cobalt, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'المراجع الرسمية للمراحل (تلقائي)' : 'Official Stage Regulatory References (Auto)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: dialog.form4Controller,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'رقم نموذج 4 البنكي' : 'Form 4 No',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: isArabic ? 'نسخ رقم نموذج 4' : 'Copy Form 4 No',
                            onPressed: () => CopyHelper.copy(context, dialog.form4Controller.text),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: dialog.swiftController,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'رقم التحويل البنكي سويفت' : 'Swift No',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: isArabic ? 'نسخ رقم السويفت' : 'Copy Swift No',
                            onPressed: () => CopyHelper.copy(context, dialog.swiftController.text),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: dialog.form46Controller,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'رقم الشهادة الجمركية 46' : 'Form 46 No',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: isArabic ? 'نسخ رقم إقرار 46' : 'Copy Form 46 No',
                            onPressed: () => CopyHelper.copy(context, dialog.form46Controller.text),
                          ),
                        ),
                      ),
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
}
