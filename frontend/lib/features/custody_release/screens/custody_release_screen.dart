import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/custody_release_model.dart';
import '../providers/custody_release_provider.dart';
import '../widgets/custody_release_data_table.dart';
import '../widgets/custody_release_dialog.dart';
import '../widgets/custody_settlement_summary_card.dart';

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

  void _showCreateDossierDialog() {
    CustodyReleaseDialog.showCreate(context, ref);
  }

  void _showFreezeDialog(CustodyReleaseDossierModel dossier) {
    CustodyReleaseDialog.showFreeze(context, ref, dossier);
  }

  void _showFinalClearanceDialog(CustodyReleaseDossierModel dossier) {
    CustodyReleaseDialog.showFinalClearance(context, ref, dossier);
  }

  void _showReportBreachDialog(CustodyReleaseDossierModel dossier) {
    CustodyReleaseDialog.showReportBreach(context, ref, dossier);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(custodyReleaseProvider);
    final isArabic = context.l10n.isArabic;

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
              // Metrics Strip using MetricCardStrip via CustodySettlementSummaryCard
              CustodySettlementSummaryCard(
                totalDossiers: totalDossiers,
                lockedCount: lockedCount,
                releasedCount: releasedCount,
                breachesCount: breachesCount,
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
                                child: Text(CustodyReleaseDataTable.statusLabel(s, isArabic), style: const TextStyle(fontSize: 12)),
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

              // Content List / Data Table
              Expanded(
                child: CustodyReleaseDataTable(
                  dossiers: state.dossiers,
                  isLoading: state.isLoading,
                  onFreeze: _showFreezeDialog,
                  onClearance: _showFinalClearanceDialog,
                  onBreach: _showReportBreachDialog,
                  onDelete: (item) =>
                      ref.read(custodyReleaseProvider.notifier).deleteDossier(item.custodyId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
