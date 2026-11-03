// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/import_file_model.dart';

/// 📌 Smart decoupled badge displaying ACID requirement & validity status.
///
/// Features:
/// - Universal Mouse Selection (`SelectionArea`)
/// - Pure View Separation (100% Arabic in Arabic mode, zero bilingual parentheticals)
/// - Visual states:
///   * `EXEMPT_POSTAL`: Emerald badge "طرد بريدي معفى من التسجيل المسبق" with legal exemption tooltip.
///   * `MANDATORY` + ACID present: Cobalt/Emerald badge showing ACID number with copy button via [CopyHelper.copy].
///   * `MANDATORY` + ACID missing: Crimson warning badge "تسجيل مسبق إلزامي (مطلوب قبل الشحن)".
class ShipmentAcidStatusBadge extends StatelessWidget {
  final String? acidRequirement;
  final String? acidExemptionReason;
  final String? acidNumber;
  final String? shipmentMode;
  final String? shipmentSubMode;
  final bool compact;

  const ShipmentAcidStatusBadge({
    super.key,
    this.acidRequirement,
    this.acidExemptionReason,
    this.acidNumber,
    this.shipmentMode,
    this.shipmentSubMode,
    this.compact = false,
  });

  factory ShipmentAcidStatusBadge.fromImportFile(
    ImportFileModel file, {
    Key? key,
    bool compact = false,
  }) {
    return ShipmentAcidStatusBadge(
      key: key,
      acidRequirement: file.acidRequirement,
      acidExemptionReason: file.acidExemptionReason,
      acidNumber: file.acidNumber,
      shipmentMode: file.shipmentMode,
      shipmentSubMode: file.shipmentSubMode,
      compact: compact,
    );
  }

  bool get _isExempt {
    final req = (acidRequirement ?? '').toUpperCase().trim();
    return req == 'EXEMPT_POSTAL' || req == 'EXEMPT';
  }

  bool get _hasAcid {
    return acidNumber != null &&
        acidNumber!.trim().isNotEmpty &&
        acidNumber!.trim().toUpperCase() != 'PENDING';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

    return SelectionArea(
      child: _buildBadgeContent(context, isDark: isDark, isAr: isAr),
    );
  }

  Widget _buildBadgeContent(
    BuildContext context, {
    required bool isDark,
    required bool isAr,
  }) {
    if (_isExempt) {
      return _buildExemptBadge(context, isDark: isDark, isAr: isAr);
    } else if (_hasAcid) {
      return _buildMandatoryFulfilledBadge(context, isDark: isDark, isAr: isAr);
    } else {
      return _buildMandatoryRequiredBadge(context, isDark: isDark, isAr: isAr);
    }
  }

  /// 🟢 Case 1: Exempt Postal Shipment
  Widget _buildExemptBadge(
    BuildContext context, {
    required bool isDark,
    required bool isAr,
  }) {
    final defaultReason = isAr
        ? 'المادة 1 من اللائحة التنفيذية لقانون الجمارك رقم 207 لسنة 2020: الطرود البريدية التي يقل وزنها عن 50 كجم وقيمتها عن 2000 دولار معفاة من التسجيل المسبق للشحنات'
        : 'Article 1, Customs Law 207/2020: Postal parcels under 50 kg and \$2,000 are exempt from Advance Cargo Information (ACID)';
    final tooltipText = (acidExemptionReason != null && acidExemptionReason!.trim().isNotEmpty)
        ? acidExemptionReason!.trim()
        : defaultReason;

    final label = isAr
        ? 'طرد بريدي معفى من التسجيل المسبق'
        : 'Postal Parcel Exempt from Advance Registration';

    return Tooltip(
      message: tooltipText,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.emerald.withValues(alpha: 0.22)
              : AppTheme.emerald.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? AppTheme.emerald.withValues(alpha: 0.8) : AppTheme.emerald,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 15,
              color: AppTheme.emerald,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.tealAccent : AppTheme.emerald,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: isDark ? Colors.tealAccent.withValues(alpha: 0.8) : AppTheme.emerald,
            ),
          ],
        ),
      ),
    );
  }

  /// 🔵 Case 2: Mandatory + ACID Issued
  Widget _buildMandatoryFulfilledBadge(
    BuildContext context, {
    required bool isDark,
    required bool isAr,
  }) {
    final cleanAcid = acidNumber!.trim();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cobalt.withValues(alpha: 0.22)
            : AppTheme.cobalt.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.tag_rounded,
            size: 15,
            color: AppTheme.cobalt,
          ),
          const SizedBox(width: 6),
          Text(
            isAr ? 'رقم القيد الجمركي المبدئي: ' : 'ACID: ',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
            ),
          ),
          Text(
            cleanAcid,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => CopyHelper.copy(
              context,
              cleanAcid,
              customMessage: isAr
                  ? 'تم نسخ رقم القيد الجمركي المبدئي'
                  : 'ACID number copied to clipboard',
            ),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Tooltip(
                message: isAr ? 'نسخ الرقم' : 'Copy Number',
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔴 Case 3: Mandatory + ACID Missing (Action Required)
  Widget _buildMandatoryRequiredBadge(
    BuildContext context, {
    required bool isDark,
    required bool isAr,
  }) {
    final defaultReason = isAr
        ? 'الوزن يتجاوز 50 كجم أو القيمة تتجاوز 2000 دولار — يلزم إصدار رقم القيد الجمركي المبدئي قبل الشحن'
        : 'Weight exceeds 50 kg or value exceeds \$2,000 — Advance cargo filing required prior to dispatch';
    final tooltipText = (acidExemptionReason != null && acidExemptionReason!.trim().isNotEmpty)
        ? acidExemptionReason!.trim()
        : defaultReason;

    final label = isAr
        ? 'تسجيل مسبق إلزامي (مطلوب قبل الشحن)'
        : 'Mandatory Advance Registration Required';

    return Tooltip(
      message: tooltipText,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.crimson.withValues(alpha: 0.22)
              : AppTheme.crimson.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? Colors.red.shade400 : AppTheme.crimson,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 15,
              color: AppTheme.crimson,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.red.shade300 : AppTheme.crimson,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: isDark ? Colors.red.shade300 : AppTheme.crimson,
            ),
          ],
        ),
      ),
    );
  }
}
