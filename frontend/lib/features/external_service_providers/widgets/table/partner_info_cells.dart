import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/partner_model.dart';

String getPartnerCategoryLabel(BuildContext context, String cat) {
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

class PartnerCategoryBadge extends StatelessWidget {
  final String category;

  const PartnerCategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (category) {
      case 'Bank':
        color = AppTheme.emerald;
        break;
      case 'Shipping Line':
        color = AppTheme.cobalt;
        break;
      case 'Customs Broker':
        color = AppTheme.orange;
        break;
      case 'Freight Forwarder':
        color = AppTheme.charcoal;
        break;
      default:
        color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        getPartnerCategoryLabel(context, category),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class PartnerCodeCell extends StatelessWidget {
  final String partnerCode;

  const PartnerCodeCell({super.key, required this.partnerCode});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Tooltip(
        message: '${l10n.partnerCodeBadgeLabel}$partnerCode (${l10n.partnersCopyFieldTooltip})',
        child: InkWell(
          onTap: () => CopyHelper.copy(
            context,
            partnerCode,
            customMessage: l10n.copiedToClipboard(partnerCode),
          ),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  partnerCode,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.3,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.copy_rounded,
                  size: 11,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PartnerNameCategoryCell extends StatelessWidget {
  final PartnerModel partner;

  const PartnerNameCategoryCell({super.key, required this.partner});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = partner.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                partner.partnerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isActive
                      ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)
                      : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                  decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: l10n.partnersCopyFieldTooltip,
              child: InkWell(
                onTap: () => CopyHelper.copy(
                  context,
                  partner.partnerName,
                  customMessage: l10n.copiedToClipboard(partner.partnerName),
                ),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.copy_rounded, size: 13, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: partner.categoriesList.map((cat) => PartnerCategoryBadge(category: cat)).toList(),
        ),
      ],
    );
  }
}

class PartnerContactCell extends StatelessWidget {
  final PartnerModel partner;

  const PartnerContactCell({super.key, required this.partner});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (partner.email != null && partner.email!.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  partner.email!,
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (partner.phone != null && partner.phone!.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  partner.phone!,
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        else
          Text(l10n.noPhoneLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
