import 'package:dio/dio.dart';
import '../models/customs_tariff_model.dart';
import '../../../../core/constants/api_constants.dart';

/// Evaluation result for HS Code Exemption and Origin Sensitivity
class ExemptionEvaluationResult {
  final String hsCode;
  final String originCountry;
  final double baseDutyRate;
  final double effectiveDutyRate;
  final double preferentialDutyRate;
  final bool hasMatchingAgreement;
  final bool isExemptionApplied;
  final String? appliedAgreementName;
  final String? publicationNotice;
  final String? requiredDocument;
  final String? conditionsNote;
  final String? warningNote;
  final String statusLabel;
  final String summaryAr;

  // Regulatory & import conditions
  final bool requiresCoo;
  final bool requiresInspection;
  final bool requiresAcid;
  final String? regulatoryAuthority;
  final String? priorApprovalNote;

  const ExemptionEvaluationResult({
    required this.hsCode,
    required this.originCountry,
    required this.baseDutyRate,
    required this.effectiveDutyRate,
    required this.preferentialDutyRate,
    required this.hasMatchingAgreement,
    required this.isExemptionApplied,
    this.appliedAgreementName,
    this.publicationNotice,
    this.requiredDocument,
    this.conditionsNote,
    this.warningNote,
    required this.statusLabel,
    required this.summaryAr,
    this.requiresCoo = false,
    this.requiresInspection = false,
    this.requiresAcid = true,
    this.regulatoryAuthority,
    this.priorApprovalNote,
  });

  /// Factory for a clean default / unassigned state
  factory ExemptionEvaluationResult.empty() {
    return const ExemptionEvaluationResult(
      hsCode: '',
      originCountry: '',
      baseDutyRate: 5.0,
      effectiveDutyRate: 5.0,
      preferentialDutyRate: 0.0,
      hasMatchingAgreement: false,
      isExemptionApplied: false,
      statusLabel: 'في انتظار تحديد الصنف ودولة المنشأ',
      summaryAr: 'يرجى تحديد البند الجمركي ودولة المنشأ لتقييم شروط الاستيراد والإعفاءات.',
    );
  }
}

/// Unified Customs Exemption & Origin Sensitivity Engine
/// Provides standardized evaluation across Customs Duty Calculator and Customs Consultation Workspace.
class CustomsExemptionEngine {
  final Dio _dio;

  CustomsExemptionEngine(this._dio);

  /// Extract 2-character ISO country code from string (e.g. 'BR - Brazil' -> 'BR')
  static String extractIsoOrigin(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final trimmed = raw.trim();
    if (trimmed.contains(' - ')) {
      return trimmed.split(' - ').first.trim().toUpperCase();
    }
    if (trimmed.length >= 2) {
      return trimmed.substring(0, 2).toUpperCase();
    }
    return trimmed.toUpperCase();
  }

  /// Evaluates an HS Code and Origin Country against Preferential Agreements & Import Rules
  Future<ExemptionEvaluationResult> evaluateLine({
    required String hsCode,
    required String originCountry,
    bool isExemptionApplied = false,
    DateTime? calculationDate,
    CustomsTariffModel? matchedTariff,
  }) async {
    final cleanHs = hsCode.trim();
    final originCode = extractIsoOrigin(originCountry);
    final baseDuty = matchedTariff?.customsDutyRate ?? 5.0;

    // Regulatory parameters from matched tariff
    final reqCoo = matchedTariff?.requiresCoo ?? false;
    final reqInsp = matchedTariff?.requiresInspection ?? false;
    final reqAcid = matchedTariff?.requiresAcid ?? true;
    final regAuth = matchedTariff?.regulatoryAuthority;
    final priorAppNote = matchedTariff?.priorApprovalNote;

    if (cleanHs.isEmpty) {
      return ExemptionEvaluationResult.empty();
    }

    if (originCode.isEmpty) {
      return ExemptionEvaluationResult(
        hsCode: cleanHs,
        originCountry: '',
        baseDutyRate: baseDuty,
        effectiveDutyRate: baseDuty,
        preferentialDutyRate: 0.0,
        hasMatchingAgreement: false,
        isExemptionApplied: false,
        statusLabel: 'يرجى تحديد بلد المنشأ',
        summaryAr: 'لم يتم تحديد دولة المنشأ — يتم احتساب التعريفة العامة بنسبة ${baseDuty.toStringAsFixed(1)}%.',
        requiresCoo: reqCoo,
        requiresInspection: reqInsp,
        requiresAcid: reqAcid,
        regulatoryAuthority: regAuth,
        priorApprovalNote: priorAppNote,
      );
    }

    try {
      final dateStr = calculationDate != null
          ? calculationDate.toIso8601String().substring(0, 10)
          : null;

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/check-duty-for-origin',
        data: {
          'hs_code': cleanHs,
          'origin_country': originCode,
          'has_preferential_document': isExemptionApplied,
          if (dateStr != null) 'check_date': dateStr,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final hasAgreement = data['has_matching_agreement'] == true;
      final agreementName = data['applied_agreement_name'] as String?;
      final pubNotice = data['publication_notice'] as String?;
      final reqDoc = data['required_document'] as String?;
      final warningNote = data['warning_note'] as String?;
      final statusLabel = data['status_label']?.toString() ?? '';
      final summaryAr = data['summary_ar']?.toString() ?? '';
      final returnedBaseRate = (data['base_duty_rate'] as num?)?.toDouble() ?? baseDuty;
      final returnedEffectiveRate = (data['effective_duty_rate'] as num?)?.toDouble() ?? baseDuty;

      double prefRate = 0.0;
      if (hasAgreement) {
        if (isExemptionApplied) {
          prefRate = returnedEffectiveRate;
        } else {
          // If exemption not applied, calculate what the preferential rate would be
          prefRate = 0.0;
        }
      }

      return ExemptionEvaluationResult(
        hsCode: cleanHs,
        originCountry: originCode,
        baseDutyRate: returnedBaseRate,
        effectiveDutyRate: returnedEffectiveRate,
        preferentialDutyRate: prefRate,
        hasMatchingAgreement: hasAgreement,
        isExemptionApplied: isExemptionApplied && hasAgreement,
        appliedAgreementName: agreementName,
        publicationNotice: pubNotice,
        requiredDocument: reqDoc,
        warningNote: warningNote,
        statusLabel: statusLabel,
        summaryAr: summaryAr,
        requiresCoo: reqCoo,
        requiresInspection: reqInsp,
        requiresAcid: reqAcid,
        regulatoryAuthority: regAuth,
        priorApprovalNote: priorAppNote,
      );
    } catch (_) {
      // Offline fallback: evaluate against matchedTariff if available
      return _evaluateLocally(
        cleanHs: cleanHs,
        originCode: originCode,
        baseDuty: baseDuty,
        isExemptionApplied: isExemptionApplied,
        matchedTariff: matchedTariff,
        reqCoo: reqCoo,
        reqInsp: reqInsp,
        reqAcid: reqAcid,
        regAuth: regAuth,
        priorAppNote: priorAppNote,
      );
    }
  }

  ExemptionEvaluationResult _evaluateLocally({
    required String cleanHs,
    required String originCode,
    required double baseDuty,
    required bool isExemptionApplied,
    CustomsTariffModel? matchedTariff,
    required bool reqCoo,
    required bool reqInsp,
    required bool reqAcid,
    String? regAuth,
    String? priorAppNote,
  }) {
    // Known Preferential Agreement Sets for local fallback
    const euCountries = {
      'DE', 'FR', 'IT', 'ES', 'NL', 'BE', 'AT', 'PL', 'SE', 'DK',
      'FI', 'IE', 'PT', 'GR', 'CZ', 'HU', 'RO', 'BG', 'SK', 'HR',
      'SI', 'LT', 'LV', 'EE', 'CY', 'MT', 'LU'
    };
    const mercosurCountries = {'BR', 'AR', 'UY', 'PY'};
    const gaftaCountries = {
      'SA', 'AE', 'JO', 'KW', 'OM', 'QA', 'BH', 'LB', 'IQ', 'SY',
      'YE', 'SD', 'LY', 'TN', 'DZ', 'MA', 'PS', 'EG'
    };

    String? agName;
    String? reqDoc;
    String? pubNotice;
    bool hasAgreement = false;

    if (euCountries.contains(originCode)) {
      hasAgreement = true;
      agName = 'اتفاقية المشاركة المصرية الأوروبية';
      reqDoc = 'شهادة يورو 1 (EUR.1) أو إعلان الفاتورة';
      pubNotice = 'منشور ر6668';
    } else if (mercosurCountries.contains(originCode)) {
      hasAgreement = true;
      agName = 'اتفاقية التجارة الحرة مع دول الميركسور';
      reqDoc = 'شهادة منشأ ميركسور مصدقة';
      pubNotice = 'منشور ر6722';
    } else if (gaftaCountries.contains(originCode)) {
      hasAgreement = true;
      agName = 'اتفاقية تيسير وتنمية التبادل التجاري العربي (GAFTA)';
      reqDoc = 'شهادة منشأ عربية معتمدة';
      pubNotice = 'منشور ر5420';
    } else if (originCode == 'TR') {
      hasAgreement = true;
      agName = 'اتفاقية التجارة الحرة مع تركيا';
      reqDoc = 'شهادة حركة EUR.1 تركية';
      pubNotice = 'منشور ر6110';
    } else if (originCode == 'GB' || originCode == 'UK') {
      hasAgreement = true;
      agName = 'اتفاقية الشراكة المصرية البريطانية';
      reqDoc = 'إعلان منشأ بريطاني / EUR.1';
      pubNotice = 'منشور ر6750';
    }

    if (!hasAgreement) {
      return ExemptionEvaluationResult(
        hsCode: cleanHs,
        originCountry: originCode,
        baseDutyRate: baseDuty,
        effectiveDutyRate: baseDuty,
        preferentialDutyRate: 0.0,
        hasMatchingAgreement: false,
        isExemptionApplied: false,
        statusLabel: 'لا ينطبق إعفاء تفضيلي',
        summaryAr: 'دولة المنشأ ($originCode) غير مشمولة بأي اتفاقية تفضيلية لهذا الصنف — تطبق التعريفة العامة بنسبة ${baseDuty.toStringAsFixed(1)}%.',
        requiresCoo: reqCoo,
        requiresInspection: reqInsp,
        requiresAcid: reqAcid,
        regulatoryAuthority: regAuth,
        priorApprovalNote: priorAppNote,
      );
    }

    final double effectiveRate = isExemptionApplied ? 0.0 : baseDuty;
    return ExemptionEvaluationResult(
      hsCode: cleanHs,
      originCountry: originCode,
      baseDutyRate: baseDuty,
      effectiveDutyRate: effectiveRate,
      preferentialDutyRate: 0.0,
      hasMatchingAgreement: true,
      isExemptionApplied: isExemptionApplied,
      appliedAgreementName: agName,
      publicationNotice: pubNotice,
      requiredDocument: reqDoc,
      warningNote: isExemptionApplied
          ? null
          : 'توجد اتفاقية تفضيلية ($agName) — يلزم تقديم ($reqDoc) لتطبيق الإعفاء.',
      statusLabel: isExemptionApplied
          ? 'مطبق إعفاء تفضيلي ($agName)'
          : 'مؤهل لإعفاء تفضيلي مشروط بتقديم المستند',
      summaryAr: isExemptionApplied
          ? 'تم تطبيق إعفاء ضريبة الوارد (0%) بموجب $agName. ⚠️ تنبيه: ضريبة القيمة المضافة (14%) وضريبة أ.ت.ص (1%) تظلان مستحقتين بالسداد بالكامل.'
          : 'الصنف مؤهل لإعفاء تفضيلي بموجب $agName ($pubNotice) — لم يتم تفعيل الإعفاء لعدم تأكيد المستند المطلوب ($reqDoc).',
      requiresCoo: reqCoo,
      requiresInspection: reqInsp,
      requiresAcid: reqAcid,
      regulatoryAuthority: regAuth,
      priorApprovalNote: priorAppNote,
    );
  }
}
