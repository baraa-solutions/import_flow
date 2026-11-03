import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';

/// Contact information fields for ImportCompanyFormDialog
class CompanyContactFields extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final TextEditingController mobileCtrl;
  final TextEditingController faxCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController secondaryEmailCtrl;
  final TextEditingController websiteCtrl;

  const CompanyContactFields({
    super.key,
    required this.phoneCtrl,
    required this.mobileCtrl,
    required this.faxCtrl,
    required this.emailCtrl,
    required this.secondaryEmailCtrl,
    required this.websiteCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: phoneCtrl,
                label: l10n.phoneNumberLabel,
                icon: Icons.phone,
                hint: l10n.phoneNumberHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, phoneCtrl.text),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: mobileCtrl,
                label: l10n.importCompaniesMobileLabel,
                icon: Icons.smartphone,
                hint: 'e.g. +20 100 123 4567',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, mobileCtrl.text),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: faxCtrl,
                label: l10n.importCompaniesFaxLabel,
                icon: Icons.print,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, faxCtrl.text),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: emailCtrl,
                label: l10n.importCompaniesPrimaryEmailLabel,
                icon: Icons.email,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, emailCtrl.text),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: secondaryEmailCtrl,
                label: l10n.importCompaniesSecondaryEmailLabel,
                icon: Icons.mark_email_read_outlined,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, secondaryEmailCtrl.text),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: websiteCtrl,
                label: l10n.importCompaniesWebsiteLabel,
                icon: Icons.language,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, websiteCtrl.text),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
