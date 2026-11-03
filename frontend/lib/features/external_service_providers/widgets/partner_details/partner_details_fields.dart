import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class PartnerDetailsFields {
  PartnerDetailsFields._();

  static Widget buildSectionHeader(
      BuildContext context, IconData icon, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.cobalt),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
      ],
    );
  }

  static Widget buildCategoryChip(BuildContext context, String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.cobalt.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        getCategoryLabel(context, category),
        style: const TextStyle(
            fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  static String getCategoryLabel(BuildContext context, String cat) {
    final l10n = context.l10n;
    switch (cat) {
      case 'All':
        return l10n.partnerCatAll;
      case 'Bank':
        return l10n.partnerCatBank;
      case 'Shipping Line':
        return l10n.partnerCatShippingLine;
      case 'Customs Broker':
        return l10n.partnerCatCustomsBroker;
      case 'Freight Forwarder':
        return l10n.partnerCatFreightForwarder;
      case 'Inland Transport':
        return l10n.partnerCatInlandTransport;
      case 'Inspection Agency':
        return l10n.partnerCatInspectionAgency;
      case 'Insurance Company':
        return l10n.partnerCatInsuranceCompany;
      default:
        return cat;
    }
  }

  static Widget buildCopyableInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? highlightColor,
  }) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: highlightColor ?? Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: highlightColor ??
                            (isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.charcoal),
                      ),
                    ),
                  ),
                  if (value != '-' && value != 'غير مسجل')
                    Tooltip(
                      message: l10n.partnersCopyFieldTooltip,
                      child: InkWell(
                        onTap: () => CopyHelper.copy(
                          context,
                          value,
                          customMessage: l10n.copiedToClipboard(value),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.copy, size: 13, color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget buildSimpleInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
