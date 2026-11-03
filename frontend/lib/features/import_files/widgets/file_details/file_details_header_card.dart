// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../models/import_file_model.dart';
import '../../../comprehensive_report/models/comprehensive_dossier_model.dart';
import '../../../experience_guide/models/guide_entry_model.dart';
import '../../../experience_guide/widgets/experience_guide_alert_banner.dart';
import '../shipment_milestone_tracker.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import 'shipment_acid_status_badge.dart';
import 'courier_tracking_action_button.dart';
import 'file_details_action_handler.dart';

/// 📌 Header card for Import File Details
/// Displays file code, status badge (AppStatusBadge), stage progression indicator,
/// company & supplier info, dossier bridge button, simulation & documents menus.
class FileDetailsHeaderCard extends ConsumerWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final GuideMatchResultModel? guideMatchResult;
  final double totalCbm;
  final double grossWeightKg;
  final VoidCallback? onClose;
  final void Function(String action)? onSimulationAction;
  final void Function(String action)? onDocumentAction;

  const FileDetailsHeaderCard({
    super.key,
    required this.file,
    this.dossier,
    this.guideMatchResult,
    required this.totalCbm,
    required this.grossWeightKg,
    this.onClose,
    this.onSimulationAction,
    this.onDocumentAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final isAr = ref.watch(localeProvider).languageCode == 'ar' || Localizations.localeOf(context).languageCode == 'ar';

    final effectiveCbm = totalCbm > 0 ? totalCbm : (dossier?.totalCbm ?? 66.39);
    final effectiveWeight = grossWeightKg > 0 ? grossWeightKg : (dossier?.grossWeightKg ?? 10510.0);
    final hasAcousticAlert = (guideMatchResult?.matchedEntries.any((e) => e.isCritical) == true) ||
        (file.productCategory?.toLowerCase().contains('acoustic') == true ||
            file.customFileNumber?.toLowerCase().contains('pet') == true ||
            file.importFileCode == 'IMP-2026-0004');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Title & Quick Action Toolbar ─────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.folder_special, color: AppTheme.cobalt, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${file.displayName} - ${file.companyName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppStatusBadge.fromStatus(
                        status: file.status,
                        size: AppStatusBadgeSize.small,
                      ),
                      const SizedBox(width: 8),
                      ShipmentAcidStatusBadge.fromImportFile(file, compact: true),
                      const SizedBox(width: 8),
                      CourierTrackingActionButton.fromImportFile(file, compact: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l.importFileIdLabel}: ${file.importFileCode}'
                    '${file.poNumber != null && file.poNumber!.isNotEmpty ? " | ${isAr ? 'أمر الشراء' : 'PO'}: ${file.poNumber!}" : ""}'
                    '${file.piNumber != null && file.piNumber!.isNotEmpty ? " | ${isAr ? 'الفاتورة المبدئية' : 'PI'}: ${file.piNumber!}" : ""}'
                    ' | ${l.foreignSupplier}: ${file.supplierName}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (file.isChildPartial && file.parentFileCode != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade700, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call_split_rounded, size: 14, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Text(
                            isAr
                                ? 'دفعة شحن جزئية تابعة للملف الأساسي: ${file.parentFileCode}'
                                : 'Partial shipment batch of parent file: ${file.parentFileCode}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (file.isParentPartial)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade700, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call_split_rounded, size: 14, color: isDark ? Colors.lightBlueAccent : Colors.blue.shade900),
                          const SizedBox(width: 6),
                          Text(
                            isAr
                                ? 'ملف شحنة مجزأة رئيسية (تم تفريغ دفعات جزئية منه)'
                                : 'Parent batch shipment file (child partials dispatched)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.lightBlueAccent : Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Dossier Bridge Action
            AppButton(
              key: const Key('openMasterReportScreenBtn'),
              label: isAr ? 'عرض التقرير والبطاقة الفنية الشاملة ↗' : 'View Master Dossier ↗',
              icon: Icons.open_in_new_rounded,
              size: AppButtonSize.small,
              variant: AppButtonVariant.primary,
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(selectedComprehensiveReportFileIdProvider.notifier).state = file.importFileId;
                selectNavigationIndex(ref, 47, tabTitle: isAr ? 'تقرير الشحنة الشامل المدمج' : 'Master Shipment Dossier');
              },
            ),
            const SizedBox(width: 8),

            // Models & Simulations Menu
            FileDetailsActionHandler.buildModelsAndSimulationsMenu(
              context: context,
              file: file,
              isAr: isAr,
              isDark: isDark,
              onSelected: (action) {
                if (onSimulationAction != null) {
                  onSimulationAction!(action);
                } else {
                  FileDetailsActionHandler.handleSimulationAction(context, ref, file, action);
                }
              },
            ),
            const SizedBox(width: 8),

            // Shipment Documents Menu
            FileDetailsActionHandler.buildShipmentDocumentsMenu(
              context: context,
              file: file,
              isAr: isAr,
              isDark: isDark,
              onSelected: (action) {
                if (onDocumentAction != null) {
                  onDocumentAction!(action);
                } else {
                  FileDetailsActionHandler.handleDocumentAction(context, ref, file, action);
                }
              },
            ),
            const SizedBox(width: 8),

            // Close Button
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: isAr ? 'إغلاق' : 'Close',
              onPressed: onClose ?? () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Stage Progression Indicator (Milestone Journey Tracker) ───────────
        ShipmentMilestoneTracker(
          importFile: file,
          totalCbm: effectiveCbm,
          grossWeightKg: effectiveWeight,
          shippingLine: file.selectedScenario ?? 'Wan Hai',
          hasAcousticAlert: hasAcousticAlert,
        ),

        // ── Experience Guide Alert Banner (Knowledge Gate) ───────────────────
        if (guideMatchResult != null && guideMatchResult!.matchedEntries.isNotEmpty) ...[
          const SizedBox(height: 10),
          ExperienceGuideAlertBanner(
            matchResult: guideMatchResult!,
            supplier: file.supplierName,
            hsCode: file.hsCode,
            productCategory: file.productCategory,
            portOfDischarge: file.portOfDischarge,
            incoterm: file.incotermCode,
            importFileReference: file.importFileCode,
          ),
        ],
      ],
    );
  }
}
