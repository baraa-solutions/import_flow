import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_shimmer_skeleton.dart';
import '../../lifecycle_board/models/lifecycle_board_model.dart';
import 'operational_format_helper.dart';

/// Static definition of the 6 operational lifecycle phases and their sub-steps.
const List<Map<String, dynamic>> kLifecyclePhases = [
  {
    'phase_id': 1,
    'name_ar': 'المرحلة 1: التخطيط والدراسات',
    'name_en': 'Phase 1: Planning & Studies',
    'color': Color(0xFF2980B9),
    'steps': [
      {'code': 'STEP_01', 'name_ar': 'دراسات ومفاضلة النولون', 'name_en': 'Freight Studies'},
      {'code': 'STEP_02', 'name_ar': 'الدراسات والاستشارات الجمركية', 'name_en': 'Customs Studies'},
      {'code': 'STEP_03', 'name_ar': 'اشتراطات ومتطلبات الاستيراد', 'name_en': 'Import Requirements'},
    ],
  },
  {
    'phase_id': 2,
    'name_ar': 'المرحلة 2: الاعتمادات ونافذة التسجيل المسبق',
    'name_en': 'Phase 2: Approvals & ACID',
    'color': Color(0xFF27AE60),
    'steps': [
      {'code': 'STEP_04', 'name_ar': 'اعتماد الميزانية وصرف الدفعة', 'name_en': 'Budget Approval'},
      {'code': 'STEP_05', 'name_ar': 'إصدار رقم التسجيل المسبق نافذة', 'name_en': 'Nafeza ACID Issue'},
    ],
  },
  {
    'phase_id': 3,
    'name_ar': 'المرحلة 3: الحجز وتدقيق المستندات',
    'name_en': 'Phase 3: Booking & Docs',
    'color': Color(0xFFE67E22),
    'steps': [
      {'code': 'STEP_06', 'name_ar': 'تأكيد الحجز الملاحي', 'name_en': 'Booking Confirmation'},
      {'code': 'STEP_07', 'name_ar': 'تخصيص وتوزيع الحاويات والبضائع', 'name_en': 'Container Allocation'},
      {'code': 'STEP_08_PO', 'name_ar': 'مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء', 'name_en': 'PO & Packing Reconciliation'},
      {'code': 'STEP_08_BL', 'name_ar': 'مراجعة مسودة بوليصة الشحن (B/L)', 'name_en': 'Draft B/L Review & Approval'},
      {'code': 'STEP_08_MATCH', 'name_ar': 'المطابقة الذكية بين الفاتورة والبوليصة', 'name_en': 'Smart Invoice vs B/L Match'},
      {'code': 'STEP_08_COO', 'name_ar': 'مسودة شهادة المنشأ و EUR.1', 'name_en': 'Draft COO & EUR.1 Review'},
      {'code': 'STEP_08_COC', 'name_ar': 'شهادات الفحص والتفتيش والمطابقة (COC)', 'name_en': 'Inspection Review & COC'},
      {'code': 'STEP_09', 'name_ar': 'مركز اعتماد المستندات وتعديلات المورد', 'name_en': 'Docs Customs Approval Hub'},
    ],
  },
  {
    'phase_id': 4,
    'name_ar': 'المرحلة 4: التوثيق الإلكتروني والنموذج البنكي',
    'name_en': 'Phase 4: CargoX & Banking',
    'color': Color(0xFF8E44AD),
    'steps': [
      {'code': 'STEP_10', 'name_ar': 'رفع التوثيق الإلكتروني للشاحن', 'name_en': 'CargoX Upload'},
      {'code': 'STEP_11', 'name_ar': 'استلام وتدقيق أصول المستندات', 'name_en': 'Original Docs'},
      {'code': 'STEP_12', 'name_ar': 'استخراج نموذج 4 البنكي', 'name_en': 'Bank Form 4'},
    ],
  },
  {
    'phase_id': 5,
    'name_ar': 'المرحلة 5: التخليص الجمركي والإفراج',
    'name_en': 'Phase 5: Clearance & Release',
    'color': Color(0xFFC0392B),
    'steps': [
      {'code': 'STEP_13', 'name_ar': 'قيد إقرار 46 ك.م جمركي', 'name_en': 'Form 46 KM'},
      {'code': 'STEP_14', 'name_ar': 'الكشف والمعاينة والتثمين', 'name_en': 'Inspection & Valuation'},
      {'code': 'STEP_15', 'name_ar': 'سحب العينات للجهات الرقابية', 'name_en': 'Sample Drawing'},
      {'code': 'STEP_16', 'name_ar': 'تحرير محضر المعاينة الجمركية', 'name_en': 'Inspection Report'},
      {'code': 'STEP_17', 'name_ar': 'سداد الضرائب والرسوم الجمركية', 'name_en': 'Duty Payment'},
      {'code': 'STEP_18', 'name_ar': 'تسوية الأرضيات والحراسات', 'name_en': 'Demurrage & Guard'},
    ],
  },
  {
    'phase_id': 6,
    'name_ar': 'المرحلة 6: المخازن والتسوية النهائية',
    'name_en': 'Phase 6: Storage & Settlement',
    'color': Color(0xFF16A085),
    'steps': [
      {'code': 'STEP_19', 'name_ar': 'إذن الاستلام وتكليف النقل', 'name_en': 'Delivery Order & Haulage'},
      {'code': 'STEP_20', 'name_ar': 'الاستلام المخزني وإذن الإضافة GRN', 'name_en': 'Warehouse GRN'},
      {'code': 'STEP_21', 'name_ar': 'تسوية وحصر فواتير الخدمات', 'name_en': 'Invoices Reconciliation'},
      {'code': 'STEP_22', 'name_ar': 'حساب التكلفة الاستيرادية النهائية', 'name_en': 'Landed Cost Final'},
      {'code': 'STEP_23', 'name_ar': 'إغلاق الملف وأرشفة المستندات', 'name_en': 'File Close & Archive'},
    ],
  },
];

/// Standalone Lifecycle Operations Board Summary Card displaying all 6 phases and 25 sub-steps.
class OperationalLifecycleBoardSummaryCard extends StatelessWidget {
  final LifecycleBoardSummaryModel? boardData;
  final bool isLoading;
  final String? selectedPhase;
  final bool isArabic;
  final ValueChanged<String>? onTogglePhase;
  final VoidCallback? onClearFilter;
  final VoidCallback? onOpenFullBoard;

  const OperationalLifecycleBoardSummaryCard({
    super.key,
    this.boardData,
    this.isLoading = false,
    this.selectedPhase,
    this.isArabic = true,
    this.onTogglePhase,
    this.onClearFilter,
    this.onOpenFullBoard,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar (Responsive)
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isCompact = headerConstraints.maxWidth < 650;
                final headerInfo = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.view_kanban_outlined, color: AppTheme.wcagCobalt, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.lifecycleBoardSummaryTitle,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                          Text(
                            l.lifecycleBoardSummaryDesc,
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (selectedPhase != null && onClearFilter != null)
                      OutlinedButton.icon(
                        onPressed: onClearFilter,
                        icon: const Icon(Icons.clear, size: 14, color: AppTheme.crimson),
                        label: Text(
                          '${l.clearFilter} (${OperationalFormatHelper.formatStageName(selectedPhase, isArabic: isArabic)})',
                          style: const TextStyle(color: AppTheme.crimson, fontSize: 11.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.crimson),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    if (onOpenFullBoard != null)
                      ElevatedButton.icon(
                        onPressed: onOpenFullBoard,
                        icon: const Icon(Icons.open_in_new, size: 15, color: Colors.white),
                        label: Text(l.fullOperationsBoardButton, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerInfo,
                      const SizedBox(height: 10),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: headerInfo),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            if (isLoading)
              const LifecycleSummaryShimmerSkeleton()
            else
              _buildDynamicLifecyclePhases(context, isDark, l),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicLifecyclePhases(BuildContext context, bool isDark, AppLocalizations l) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth;
        if (constraints.maxWidth < 650) {
          cardWidth = constraints.maxWidth; // 1 column on mobile (<650px)
        } else if (constraints.maxWidth < 1100) {
          cardWidth = (constraints.maxWidth - 12) / 2; // 2 columns on tablet
        } else {
          cardWidth = (constraints.maxWidth - 24) / 3; // 3 columns on desktop
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kLifecyclePhases.map((phaseMeta) {
            final int phaseId = phaseMeta['phase_id'];
            final String phaseName = isArabic ? phaseMeta['name_ar'] : phaseMeta['name_en'];
            final Color phaseColor = phaseMeta['color'];
            final List<Map<String, String>> steps = List<Map<String, String>>.from(phaseMeta['steps']);

            final matchingPhase = boardData?.phases.where((p) => p.phaseId == phaseId).firstOrNull;
            final int phaseActiveCount = matchingPhase?.totalActiveShipments ?? 0;
            final Map<String, int> stepCounts = matchingPhase?.stepCounts ?? {};

            final bool isPhaseSelected = selectedPhase == 'Phase $phaseId' || selectedPhase == 'P$phaseId';

            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPhaseSelected ? phaseColor.withValues(alpha: isDark ? 0.18 : 0.08) : (isDark ? AppTheme.darkCardBackground : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPhaseSelected ? phaseColor : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                  width: isPhaseSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phase Header
                  InkWell(
                    onTap: () => onTogglePhase?.call('Phase $phaseId'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: phaseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    phaseName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: isPhaseSelected ? phaseColor : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: phaseColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$phaseActiveCount ${l.shipmentCountUnit}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: phaseColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 8),

                  // Steps Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: steps.map((step) {
                      final String stepCode = step['code']!;
                      final String stepName = isArabic ? (step['name_ar'] ?? step['name'] ?? '') : (step['name_en'] ?? step['name'] ?? '');
                      final int count = stepCounts[stepCode] ?? 0;
                      final bool isStepSelected = selectedPhase == stepCode;

                      return InkWell(
                        onTap: () => onTogglePhase?.call(stepCode),
                        borderRadius: BorderRadius.circular(6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isStepSelected
                                ? phaseColor
                                : (count > 0 ? phaseColor.withValues(alpha: isDark ? 0.22 : 0.12) : (isDark ? AppTheme.darkSurface : Colors.grey.shade100)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isStepSelected
                                  ? phaseColor
                                  : (count > 0 ? phaseColor.withValues(alpha: isDark ? 0.6 : 0.4) : (isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  stepName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isStepSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isStepSelected
                                        ? Colors.white
                                        : (count > 0 ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal) : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isStepSelected
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : (count > 0 ? phaseColor : Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
