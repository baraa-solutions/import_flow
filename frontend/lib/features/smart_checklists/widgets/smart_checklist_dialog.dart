import 'package:frontend/core/theme/app_theme.dart';
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../import_files/models/import_file_model.dart';
import '../providers/smart_checklists_provider.dart';
import 'checklist_item_card.dart';

class SmartChecklistDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final String? initialPhase;

  const SmartChecklistDialog({
    super.key,
    required this.file,
    this.initialPhase,
  });

  static void show(BuildContext context, ImportFileModel file, {String? initialPhase}) {
    showDialog(
      context: context,
      builder: (ctx) => SmartChecklistDialog(file: file, initialPhase: initialPhase),
    );
  }

  @override
  ConsumerState<SmartChecklistDialog> createState() => _SmartChecklistDialogState();
}

class _SmartChecklistDialogState extends ConsumerState<SmartChecklistDialog> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(smartChecklistProvider.notifier).fetchChecklist(widget.file.importFileId);
      if (widget.initialPhase != null) {
        ref.read(smartChecklistProvider.notifier).setPhaseFilter(widget.initialPhase!);
      }
    });
  }

  Widget _buildPhaseTab(String phaseKey, String label, String count, String activePhase, bool isDark) {
    final isSelected = activePhase == phaseKey;
    return InkWell(
      onTap: () {
        ref.read(smartChecklistProvider.notifier).setPhaseFilter(phaseKey);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cobalt : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.cobalt : (isDark ? Colors.grey.shade700 : Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextSecondary : null),
              ),
            ),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : (isDark ? Colors.grey.shade800 : Colors.grey.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextPrimary : null),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final state = ref.watch(smartChecklistProvider);
    final summary = state.summary;
    final filteredItems = state.filteredItems;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.all(24),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.charcoal,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.playlist_add_check_circle, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr
                        ? 'قائمة التحقق التشغيلية الذكية'
                        : 'Smart Import Operational Checklist',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    isAr
                        ? 'ملف: ${widget.file.importFileCode} | ACID: ${widget.file.acidNumber ?? "غير مسجل"} | المورد: ${widget.file.supplierName} (${widget.file.incotermCode})'
                        : 'File: ${widget.file.importFileCode} | ACID: ${widget.file.acidNumber ?? "N/A"} | Supplier: ${widget.file.supplierName} (${widget.file.incotermCode})',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Readiness Score Badge
            if (summary != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: summary.isGateBlocked ? Colors.red.shade900 : AppTheme.emerald,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: summary.isGateBlocked ? Colors.red.shade400 : Colors.green.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.readinessScorePct}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'مؤشر الجاهزية' : 'Readiness Index',
                          style: const TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                        Text(
                          summary.isGateBlocked
                              ? (isAr ? 'معلق مانع [Gate]' : 'Gate Blocked')
                              : (isAr ? 'مستوفى للشحن' : 'Ready for Shipment'),
                          style: TextStyle(
                            color: summary.isGateBlocked ? Colors.amberAccent : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],

            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      content: SelectionArea(
        child: SizedBox(
          width: 980,
          height: 650,
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Top Control Bar: Gatekeeper Notice & Sync Action
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Gatekeeper status message
                            Expanded(
                              child: summary != null && summary.isGateBlocked
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.red.shade900.withOpacity(0.35)
                                            : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark ? Colors.red.shade700 : Colors.red.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.block, size: 16, color: isDark ? Colors.red.shade300 : Colors.red),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              isAr
                                                  ? 'تنبيه بوابات الحظر: يوجد ${summary.mandatoryPendingItems} بند إلزامي معلق يمنع الانتقال الآلي للمرحلة التالية.'
                                                  : 'Gatekeeper Alert: ${summary.mandatoryPendingItems} mandatory pending item(s) block automatic stage progression.',
                                              style: TextStyle(
                                                color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.green.shade900.withOpacity(0.35)
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark ? Colors.green.shade700 : Colors.green.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle, size: 16, color: isDark ? Colors.green.shade300 : Colors.green),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              isAr
                                                  ? 'بوابات العبور واضحة: كافة البنود الإلزامية للمرحلة مستوفاة بالكامل.'
                                                  : 'Gatekeeper Clear: All mandatory stage requirements are fully satisfied.',
                                              style: TextStyle(
                                                color: isDark ? Colors.green.shade200 : Colors.green.shade900,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),

                            // Auto-Sync Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.cobalt,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: state.isSyncing
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.sync, size: 16),
                              label: Text(
                                isAr ? 'فحص آلي مع الداتابيز' : 'Auto-Check with DB',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: state.isSyncing
                                  ? null
                                  : () async {
                                      await ref.read(smartChecklistProvider.notifier).autoSync(widget.file.importFileId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          AppTheme.snackBar(context, isAr
                                                  ? 'تم الفحص الآلي ومزامنة كافة بنود الشحنة مع قاعدة البيانات'
                                                  : 'Automated check completed and synchronized with database',),
                                        );
                                      }
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Phase Filter Tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPhaseTab('ALL', isAr ? 'كل المراحل' : 'All Phases', '${summary?.totalItems ?? ""}', state.selectedPhase, isDark),
                              const SizedBox(width: 6),
                              _buildPhaseTab('PRE_SHIPMENT', isAr ? '1️⃣ قبل الشحن' : '1️⃣ Pre-Shipment', '8', state.selectedPhase, isDark),
                              const SizedBox(width: 6),
                              _buildPhaseTab('IN_TRANSIT', isAr ? '2️⃣ أثناء الشحن' : '2️⃣ In-Transit', '5', state.selectedPhase, isDark),
                              const SizedBox(width: 6),
                              _buildPhaseTab('PORT_ARRIVAL', isAr ? '3️⃣ وصول الميناء' : '3️⃣ Port Arrival', '4', state.selectedPhase, isDark),
                              const SizedBox(width: 6),
                              _buildPhaseTab('CLEARANCE', isAr ? '4️⃣ التخليص الجمركي' : '4️⃣ Customs Clearance', '4', state.selectedPhase, isDark),
                              const SizedBox(width: 6),
                              _buildPhaseTab('POST_CLEARANCE', isAr ? '5️⃣ ما بعد التخليص' : '5️⃣ Post-Clearance', '2', state.selectedPhase, isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Role Filters
                        Row(
                          children: [
                            Text(
                              isAr ? 'تصفية المسؤول: ' : 'Filter by Role: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                ChoiceChip(
                                  label: Text(isAr ? 'الجميع' : 'All', style: const TextStyle(fontSize: 11)),
                                  selected: state.selectedRole == 'ALL',
                                  onSelected: (val) => ref.read(smartChecklistProvider.notifier).setRoleFilter('ALL'),
                                ),
                                ChoiceChip(
                                  label: Text(isAr ? '👤 المنسق' : '👤 Coordinator', style: const TextStyle(fontSize: 11)),
                                  selected: state.selectedRole == 'COORDINATOR',
                                  onSelected: (val) => ref.read(smartChecklistProvider.notifier).setRoleFilter('COORDINATOR'),
                                ),
                                ChoiceChip(
                                  label: Text(isAr ? '🏭 المورد' : '🏭 Supplier', style: const TextStyle(fontSize: 11)),
                                  selected: state.selectedRole == 'SUPPLIER',
                                  onSelected: (val) => ref.read(smartChecklistProvider.notifier).setRoleFilter('SUPPLIER'),
                                ),
                                ChoiceChip(
                                  label: Text(isAr ? '🛃 المخلص الجمركي' : '🛃 Broker', style: const TextStyle(fontSize: 11)),
                                  selected: state.selectedRole == 'CUSTOMS_BROKER',
                                  onSelected: (val) => ref.read(smartChecklistProvider.notifier).setRoleFilter('CUSTOMS_BROKER'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Checklist Items List
                  Expanded(
                    child: filteredItems.isEmpty
                        ? Center(
                            child: Text(
                              isAr ? 'لا توجد بنود تطابق الفلتر المحدد' : 'No items match the selected filter',
                              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            itemCount: filteredItems.length,
                            itemBuilder: (ctx, idx) {
                              final itm = filteredItems[idx];
                              return ChecklistItemCard(
                                item: itm,
                                fileId: widget.file.importFileId,
                              );
                            },
                          ),
                  ),
                ],
              ),
        ),
      ),
      actions: [
        if (summary != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              isAr
                  ? 'المستوفى: ${summary.passedItems + summary.waivedItems} من ${summary.totalItems} بنداً'
                  : 'Satisfied: ${summary.passedItems + summary.waivedItems} of ${summary.totalItems} items',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
              ),
            ),
          ),
        ],
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.charcoal, foregroundColor: Colors.white),
          child: Text(isAr ? 'إغلاق' : 'Close'),
        ),
      ],
    );
  }
}
