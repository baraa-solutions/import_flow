import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_requirements/models/import_requirement_model.dart';
import '../models/customs_clearance_model.dart';
import 'approval_status_row.dart';

/// Provider to fetch or refresh the active ImportRequirementAssessment for a given import file.
final releaseGateAssessmentProvider =
    FutureProvider.family<ImportRequirementModel?, int>((ref, fileId) async {
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get(
      '${ApiConstants.baseUrl}/import-requirements',
      queryParameters: {'import_file_id': fileId, 'include_inactive': false},
    );
    if (response.statusCode == 200 && response.data is List) {
      final list = response.data as List;
      if (list.isNotEmpty) {
        return ImportRequirementModel.fromJson(list.first as Map<String, dynamic>);
      }
    }
  } catch (_) {}
  return null;
});

/// Comprehensive evaluation card for Customs Final Release Gates (CL-04).
///
/// Verifies:
/// 1. Duty Payment (CL-03 / Sadad)
/// 2. Regulatory Permits (GOEIC, NFSA, etc.)
/// 3. Goods Inspection & Lab Quarantine
/// 4. ACID Expiry & Validity
///
/// Complies with `AppTheme`, `AppButton`, `SelectionArea`, and `ui-screen-standards`.
class ReleaseGateSummaryCard extends ConsumerWidget {
  final ImportFileModel? file;
  final CustomsClearanceModel? clearanceRecord;
  final ImportRequirementModel? assessment;
  final int? importFileId;
  final bool showActions;
  final VoidCallback? onIssueRelease;
  final VoidCallback? onRefresh;
  final VoidCallback? onViewRequirements;

  const ReleaseGateSummaryCard({
    super.key,
    this.file,
    this.clearanceRecord,
    this.assessment,
    this.importFileId,
    this.showActions = true,
    this.onIssueRelease,
    this.onRefresh,
    this.onViewRequirements,
  });

  int? get _resolvedFileId =>
      importFileId ?? file?.importFileId ?? clearanceRecord?.importFileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileId = _resolvedFileId;

    if (assessment != null || fileId == null) {
      return _buildCard(context, ref, assessment);
    }

    final asyncAssessment = ref.watch(releaseGateAssessmentProvider(fileId));
    return asyncAssessment.when(
      data: (loadedAssessment) => _buildCard(context, ref, loadedAssessment),
      loading: () => _buildCard(context, ref, null, isLoading: true),
      error: (_, __) => _buildCard(context, ref, null),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    ImportRequirementModel? effectiveAssessment, {
    bool isLoading = false,
  }) {
    final rec = clearanceRecord;
    final impFile = file;

    // ── Gate 1: Customs Duty Payment (CL-03) ──
    final bool isDutyPaid = _checkDutyPaid(rec, impFile);
    final String dutyStatus = isDutyPaid ? 'مسدد بالكامل' : 'غير مسدد';
    final String? sadadOrReceipt = rec?.sadadNumber ??
        impFile?.customsDutySadadNo ??
        rec?.bankReceiptNo ??
        impFile?.customsDutyReceiptNo;

    // ── Gate 2: Regulatory Approvals (GOEIC / NFSA / جهات العرض) ──
    final bool permitRequired = effectiveAssessment?.importPermitRequired ?? false;
    final String permitStatus =
        permitRequired ? (effectiveAssessment?.permitStatus ?? 'Pending') : 'Not Required';
    final bool isPermitApproved = !permitRequired ||
        permitStatus.trim().toLowerCase() == 'approved' ||
        permitStatus.trim() == 'معتمد';
    final String permitAuthority = effectiveAssessment?.permitIssuingAuthority ??
        'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)';
    final String? permitNo = effectiveAssessment?.permitNumber;

    // ── Gate 3: Inspection & Lab Quarantine ──
    final bool inspectionRequired = effectiveAssessment?.inspectionRequired ?? false;
    final String rawInspectionStatus =
        inspectionRequired ? (effectiveAssessment?.inspectionStatus ?? 'Pending') : 'Not Required';
    final bool isInspectionDone = !inspectionRequired ||
        ['completed', 'waived', 'مكتمل', 'معفى']
            .contains(rawInspectionStatus.trim().toLowerCase());
    final bool quarantineLock = rec?.quarantineLock ?? false;
    final bool isInspectionGatePassed = isInspectionDone && !quarantineLock;
    final String inspectionBody = effectiveAssessment?.inspectionBody ??
        'لجنة الفحص المشترك / المعامل المركزية';
    final String? inspectionReportNo =
        effectiveAssessment?.inspectionReportNo ?? rec?.samplingRecordNo;

    // ── Gate 4: ACID Expiry ──
    final bool isAcidExpired = _checkAcidExpired(impFile);
    final String acidNumber = impFile?.acidNumber ?? '—';
    final bool isAcidGatePassed = !isAcidExpired;

    // ── Overall Gate Status ──
    final bool isReadyForRelease =
        isDutyPaid && isPermitApproved && isInspectionGatePassed && isAcidGatePassed;

    // Blocking reasons list
    final List<String> blockingReasons = [];
    if (!isDutyPaid) {
      blockingReasons.add('سداد الرسوم والضرائب الجمركية غير مكتمل (CL-03).');
    }
    if (!isPermitApproved) {
      blockingReasons.add(
        'موافقة الجهات الرقابية ($permitAuthority) لم تعتمد بعد (الحالة: $permitStatus).',
      );
    }
    if (quarantineLock) {
      blockingReasons.add('الشحنة مقيدة تحت التحفظ المعملي - يلزم ورود نتيجة مطابقة وفك التحفظ.');
    } else if (!isInspectionDone) {
      blockingReasons.add(
        'شهادة/فحص البضاعة ($inspectionBody) غير مستوفى (الحالة: $rawInspectionStatus).',
      );
    }
    if (isAcidExpired) {
      blockingReasons.add(
        'رقم القيد الجمركي ACID منتهي الصلاحية - يلزم التمديد عبر نافذة قبل الإفراج.',
      );
    }

    return SelectionArea(
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: 16),
        decoration: AppTheme.cardDecorationOf(context).copyWith(
          border: Border.all(
            color: isReadyForRelease
                ? AppTheme.emeraldBorder
                : (blockingReasons.isNotEmpty
                    ? AppTheme.crimson.withValues(alpha: 0.35)
                    : AppTheme.borderOf(context)),
            width: isReadyForRelease ? 1.5 : 1.2,
          ),
        ),
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Card Header ──
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isReadyForRelease ? AppTheme.emerald : AppTheme.cobalt)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    isReadyForRelease
                        ? Icons.verified_user_rounded
                        : Icons.security_outlined,
                    color: isReadyForRelease ? AppTheme.emerald : AppTheme.cobalt,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بوابة التحقق من متطلبات الإفراج الجمركي (Release Gate)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'التحقق الإلزامي من سداد الرسوم وموافقات جهات العرض (GOEIC / سلامة الغذاء) والفحص',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppStatusBadge(
                  label: isReadyForRelease ? 'جاهز للإفراج النهائي' : 'الإفراج معلق / محظور',
                  severity: isReadyForRelease ? AppSeverity.success : AppSeverity.danger,
                  size: AppStatusBadgeSize.medium,
                  icon: isReadyForRelease ? Icons.check_circle_rounded : Icons.lock_clock,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Banner (Success or Warning) ──
            if (!isReadyForRelease && blockingReasons.isNotEmpty)
              Container(
                margin: const EdgeInsetsDirectional.only(bottom: 14),
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'حظر الإفراج الجمركي: لا يمكن إصدار إذن الإفراج النهائي قبل استيفاء المتطلبات التالية:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.crimson,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...blockingReasons.map(
                            (r) => Padding(
                              padding: const EdgeInsetsDirectional.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (isReadyForRelease)
              Container(
                margin: const EdgeInsetsDirectional.only(bottom: 14),
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.emeraldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'كافة متطلبات الإفراج الجمركي مستوفاة (الرسوم مسددة، موافقات جهات العرض معتمدة، الفحص مكتمل، ورقم ACID سارٍ). يمكن إصدار الإفراج النهائي بأمان.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Gate Rows ──
            // Gate 1: Duty Payment
            ApprovalStatusRow(
              title: 'سداد الرسوم والضرائب الجمركية (CL-03)',
              status: dutyStatus,
              authorityOrBody: 'منظومة سداد / مصلحة الجمارك المصرية',
              referenceNumber: sadadOrReceipt,
              isRequired: true,
              isSatisfied: isDutyPaid,
              notes: isDutyPaid
                  ? 'تم تأكيد السداد البنكي بنجاح'
                  : 'يجب تأكيد سداد كامل الرسوم لاجتياز بوابة الإفراج',
              customIcon: Icons.payments_outlined,
            ),

            // Gate 2: Regulatory Permits (GOEIC / NFSA)
            ApprovalStatusRow(
              title: 'موافقة جهات العرض والرقابة النوعية (GOEIC / سلامة الغذاء)',
              status: permitStatus,
              authorityOrBody: permitAuthority,
              referenceNumber: permitNo,
              isRequired: permitRequired,
              isSatisfied: isPermitApproved,
              notes: isPermitApproved
                  ? (permitRequired ? 'تم اعتماد تصريح الاستيراد رسمياً' : 'غير خاضعة لجهات عرض رقابية مسبقة')
                  : 'يلزم اعتماد موافقة جهة العرض قبل الإفراج الجمركي',
              customIcon: Icons.approval_outlined,
            ),

            // Gate 3: Inspection & Quarantine
            ApprovalStatusRow(
              title: 'معاينة وفحص البضاعة والتحفظ المعملي',
              status: quarantineLock
                  ? 'تحت التحفظ المعملي'
                  : (inspectionRequired ? rawInspectionStatus : 'غير مطلوب'),
              authorityOrBody: inspectionBody,
              referenceNumber: inspectionReportNo,
              isRequired: inspectionRequired || quarantineLock,
              isSatisfied: isInspectionGatePassed,
              notes: quarantineLock
                  ? 'الشحنة مقيدة تحت التحفظ المعملي - يلزم فك التحفظ وتقرير مطابقة'
                  : (isInspectionDone
                      ? (inspectionRequired ? 'تم استيفاء تقرير الفحص والمعاينة' : 'غير خاضعة لشهادة فحص مسبقة')
                      : 'يلزم استيفاء الفحص الفني للجنة المشتركة'),
              customIcon: Icons.biotech_outlined,
            ),

            // Gate 4: ACID Expiry
            ApprovalStatusRow(
              title: 'الرقم التعريفي المبدئي للشحنة (ACID Number)',
              status: isAcidExpired ? 'منتهي الصلاحية' : 'سارٍ',
              authorityOrBody: 'منظومة نافذة الجمركية (Nafeza)',
              referenceNumber: acidNumber,
              isRequired: true,
              isSatisfied: isAcidGatePassed,
              notes: isAcidExpired
                  ? 'رقم ACID منتهي الصلاحية - محظور إصدار الإفراج النهائي قانوناً'
                  : (impFile?.acidExpiryDate != null ? 'تاريخ الانتهاء: ${impFile!.acidExpiryDate}' : null),
              customIcon: Icons.verified_outlined,
            ),

            // ── Action Buttons ──
            if (showActions) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.borderOf(context)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton(
                    label: 'إصدار الإفراج الجمركي (CL-04)',
                    variant: AppButtonVariant.success,
                    icon: Icons.verified_user,
                    size: AppButtonSize.medium,
                    onPressed: isReadyForRelease ? onIssueRelease : null,
                    tooltip: isReadyForRelease
                        ? 'إصدار أمر الإفراج الجمركي النهائي والأخضر'
                        : 'معطل: يلزم استيفاء كافة بوابات الإفراج أولاً',
                  ),
                  if (onRefresh != null || _resolvedFileId != null)
                    AppButton(
                      label: 'تحديث بيانات الفحص',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.refresh,
                      size: AppButtonSize.medium,
                      isLoading: isLoading,
                      onPressed: () {
                        if (_resolvedFileId != null) {
                          ref.invalidate(releaseGateAssessmentProvider(_resolvedFileId!));
                        }
                        onRefresh?.call();
                      },
                    ),
                  if (onViewRequirements != null)
                    AppButton(
                      label: 'بطاقة الاشتراطات (BP-011)',
                      variant: AppButtonVariant.ghost,
                      icon: Icons.fact_check_outlined,
                      size: AppButtonSize.medium,
                      onPressed: onViewRequirements,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _checkDutyPaid(CustomsClearanceModel? rec, ImportFileModel? file) {
    if (rec != null) {
      if (rec.paymentStatus.trim().toLowerCase().contains('paid')) return true;
      final paid = rec.dutyPaidAmount ?? 0.0;
      final assessed = rec.effectiveDutyTotal ?? 0.0;
      if (assessed > 0 && paid >= assessed - 0.01) return true;
    }
    if (file != null) {
      final status = (file.customsDutyPaymentStatus ?? '').trim().toUpperCase();
      if (status == 'PAID' || status == 'DUTIES PAID') return true;
      if (file.customsDutyPaidAmount > 0) return true;
    }
    return false;
  }

  static bool _checkAcidExpired(ImportFileModel? file) {
    if (file == null || file.acidExpiryDate == null) return false;
    try {
      final exp = DateTime.parse(file.acidExpiryDate!);
      final now = DateTime.now();
      return DateTime(exp.year, exp.month, exp.day)
          .isBefore(DateTime(now.year, now.month, now.day));
    } catch (_) {
      return false;
    }
  }
}
