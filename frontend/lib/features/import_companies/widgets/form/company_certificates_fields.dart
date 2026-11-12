import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_company_model.dart';

/// Nafeza token and international certificates section for ImportCompanyFormDialog
class CompanyCertificatesFields extends StatelessWidget {
  final ImportCompanyModel? companyToEdit;
  final TextEditingController nafezaTokenCtrl;
  final bool obscureToken;
  final VoidCallback onToggleObscure;
  final bool hasWipo;
  final TextEditingController wipoCtrl;
  final ValueChanged<bool?> onWipoChanged;
  final bool hasEuipo;
  final TextEditingController euipoCtrl;
  final ValueChanged<bool?> onEuipoChanged;
  final bool hasGlobalBrand;
  final TextEditingController globalBrandCtrl;
  final ValueChanged<bool?> onGlobalBrandChanged;
  final bool hasIso9001;
  final TextEditingController iso9001Ctrl;
  final ValueChanged<bool?> onIso9001Changed;

  /// Expiry dates keyed by 'nafeza_token', 'wipo', 'euipo', 'global_brand', 'iso_9001'.
  final Map<String, DateTime?> expiries;
  final void Function(String key, DateTime? value) onExpiryChanged;

  const CompanyCertificatesFields({
    super.key,
    required this.companyToEdit,
    required this.nafezaTokenCtrl,
    required this.obscureToken,
    required this.onToggleObscure,
    required this.hasWipo,
    required this.wipoCtrl,
    required this.onWipoChanged,
    required this.hasEuipo,
    required this.euipoCtrl,
    required this.onEuipoChanged,
    required this.hasGlobalBrand,
    required this.globalBrandCtrl,
    required this.onGlobalBrandChanged,
    required this.hasIso9001,
    required this.iso9001Ctrl,
    required this.onIso9001Changed,
    required this.expiries,
    required this.onExpiryChanged,
  });

  Widget _expiry(String key, bool isAr) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: CertificateExpiryField(
          key: ValueKey('expiry_$key'),
          value: expiries[key],
          isArabic: isAr,
          label: isAr ? 'تاريخ الانتهاء' : 'Expiry Date',
          onChanged: (v) => onExpiryChanged(key, v),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, size: 16, color: AppTheme.cobalt),
                  const SizedBox(width: 6),
                  Text(
                    l10n.importCompaniesNafezaTokenSection,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: nafezaTokenCtrl,
                label: l10n.importCompaniesNafezaTokenLabel,
                icon: Icons.lock_outline,
                obscureText: obscureToken,
                hint: (companyToEdit?.hasNafezaToken == true)
                    ? (companyToEdit?.maskedNafezaToken ?? '****')
                    : 'NFZ-TK-xxxxxxxx',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        obscureToken ? Icons.visibility_off : Icons.visibility,
                        size: 16,
                        color: Colors.grey,
                      ),
                      tooltip: obscureToken
                          ? l10n.importCompaniesShowTokenTooltip
                          : l10n.importCompaniesHideTokenTooltip,
                      onPressed: onToggleObscure,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                      tooltip: l10n.importCompaniesCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        nafezaTokenCtrl.text.isNotEmpty
                            ? nafezaTokenCtrl.text
                            : (companyToEdit?.maskedNafezaToken ?? ''),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _expiry('nafeza_token', isAr),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Text(
                    l10n.importCompaniesCertificatesSection,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.importCompaniesWipoTitle),
                value: hasWipo,
                activeColor: AppTheme.cobalt,
                onChanged: onWipoChanged,
              ),
              if (hasWipo) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: CustomTextField(
                    controller: wipoCtrl,
                    label: l10n.importCompaniesWipoRegLabel,
                    icon: Icons.numbers,
                    hint: 'e.g. 1234567',
                  ),
                ),
                _expiry('wipo', isAr),
              ],
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.importCompaniesEuipoTitle),
                value: hasEuipo,
                activeColor: AppTheme.cobalt,
                onChanged: onEuipoChanged,
              ),
              if (hasEuipo) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: CustomTextField(
                    controller: euipoCtrl,
                    label: l10n.importCompaniesEuipoRegLabel,
                    icon: Icons.numbers,
                    hint: 'e.g. 018345678',
                  ),
                ),
                _expiry('euipo', isAr),
              ],
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(isAr ? 'قاعدة بيانات العلامات العالمية' : 'Global Brand Database'),
                value: hasGlobalBrand,
                activeColor: AppTheme.cobalt,
                onChanged: onGlobalBrandChanged,
              ),
              if (hasGlobalBrand) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: CustomTextField(
                    controller: globalBrandCtrl,
                    label: isAr
                        ? 'معرف العلامة في قاعدة بيانات العلامات العالمية'
                        : 'Global Brand DB Identifier',
                    icon: Icons.numbers,
                    hint: 'e.g. GBD-987654',
                  ),
                ),
                _expiry('global_brand', isAr),
              ],
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(isAr ? 'شهادة نظام إدارة الجودة (ISO 9001)' : 'ISO 9001 Certificate'),
                value: hasIso9001,
                activeColor: AppTheme.cobalt,
                onChanged: onIso9001Changed,
              ),
              if (hasIso9001) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: CustomTextField(
                    controller: iso9001Ctrl,
                    label: isAr ? 'رقم شهادة ISO 9001' : 'ISO 9001 Certificate No.',
                    icon: Icons.verified_user_outlined,
                    hint: 'e.g. ISO-9001-2015-XYZ',
                  ),
                ),
                _expiry('iso_9001', isAr),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
