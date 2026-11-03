import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// 🛡️ Adaptive Pillar Compliance & Alert Banner — ImportFlow ERP
///
/// Reactively displays statutory rules, compliance alerts, and legal exemptions
/// depending on the selected active regulatory pillar and active HS code item.
class AdaptivePillarAlertBanner extends StatelessWidget {
  final int activePillarIndex;
  final String hsCode;
  final String commodityDescription;

  const AdaptivePillarAlertBanner({
    super.key,
    required this.activePillarIndex,
    required this.hsCode,
    required this.commodityDescription,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    String mandatoryText;
    String warningText;
    String exemptionText;

    switch (activePillarIndex) {
      case 0:
        // Pillar 1: Decree 43
        mandatoryText = l10n.compliancePillar1Mandatory;
        warningText = l10n.compliancePillar1Warning;
        exemptionText = l10n.compliancePillar1Exemption;
        break;
      case 1:
        // Pillar 2: Certificate of Origin
        mandatoryText = l10n.compliancePillar2Mandatory;
        warningText = l10n.compliancePillar2Warning;
        exemptionText = l10n.compliancePillar2Exemption;
        break;
      case 2:
        // Pillar 3: Pre-Shipment Inspection
        mandatoryText = l10n.compliancePillar3Mandatory;
        warningText = l10n.compliancePillar3Warning;
        exemptionText = l10n.compliancePillar3Exemption;
        break;
      case 3:
        // Pillar 4: Regulatory Permits
        mandatoryText = l10n.compliancePillar4Mandatory;
        warningText = l10n.compliancePillar4Warning;
        exemptionText = l10n.compliancePillar4Exemption;
        break;
      case 4:
      default:
        // Pillar 5: Technical Certificates & MSDS
        mandatoryText = l10n.compliancePillar5Mandatory;
        warningText = l10n.compliancePillar5Warning;
        exemptionText = l10n.compliancePillar5Exemption;
        break;
    }

    final trimmedHs = hsCode.trim();
    final trimmedDesc = commodityDescription.trim();

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.charcoalSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cloudWhite),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.cobalt, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.complianceBannerTitle(
                      trimmedHs.isNotEmpty ? trimmedHs : 'HS-Code',
                      trimmedDesc.isNotEmpty ? "($trimmedDesc)" : "",
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.charcoal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBannerSection(
              icon: Icons.verified_outlined,
              iconColor: AppTheme.cobalt,
              title: l10n.adaptivePillarMandatoryRequirements,
              content: mandatoryText,
              bgColor: AppTheme.cobaltLight,
              borderColor: AppTheme.cobaltBorder,
            ),
            const SizedBox(height: 6),
            _buildBannerSection(
              icon: Icons.warning_amber_rounded,
              iconColor: AppTheme.crimson,
              title: l10n.adaptivePillarComplianceAlert,
              content: warningText,
              bgColor: AppTheme.crimsonLight,
              borderColor: AppTheme.crimsonBorder,
            ),
            const SizedBox(height: 6),
            _buildBannerSection(
              icon: Icons.lightbulb_outline,
              iconColor: AppTheme.emerald,
              title: l10n.adaptivePillarLegalExemptions,
              content: exemptionText,
              bgColor: AppTheme.emeraldLight,
              borderColor: AppTheme.emeraldBorder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: iconColor),
                  ),
                  TextSpan(
                    text: content,
                    style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
