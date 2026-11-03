import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/partner_model.dart';
import 'partner_details/partner_actions_toolbar.dart';
import 'partner_details/partner_contact_section.dart';
import 'partner_details/partner_details_header.dart';
import 'partner_details/partner_financial_terms_section.dart';
import 'partner_details/partner_licenses_section.dart';

class PartnerDetailsDialog extends StatelessWidget {
  final PartnerModel partner;
  final VoidCallback? onEdit;

  const PartnerDetailsDialog({
    super.key,
    required this.partner,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    PartnerModel partner, {
    VoidCallback? onEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PartnerDetailsDialog(partner: partner, onEdit: onEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
          width: 780,
          constraints: const BoxConstraints(maxHeight: 800),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.transparent),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header Banner
              PartnerDetailsHeader(
                partner: partner,
                onClose: () => Navigator.pop(context),
              ),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PartnerLicensesSection(partner: partner),
                      const SizedBox(height: 18),
                      PartnerFinancialTermsSection(partner: partner),
                      const SizedBox(height: 18),
                      PartnerContactSection(partner: partner),
                    ],
                  ),
                ),
              ),

              // Bottom Actions Toolbar
              PartnerActionsToolbar(
                partner: partner,
                onEdit: onEdit,
                onClose: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
