import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/supplier_model.dart';

class SupplierDetailsContactCertsSection extends StatelessWidget {
  final SupplierModel supplier;

  const SupplierDetailsContactCertsSection({super.key, required this.supplier});

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.cobalt),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? highlightColor,
  }) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: highlightColor ?? Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: highlightColor ?? AppTheme.charcoal,
                      ),
                    ),
                  ),
                  if (value != '-' && value != l10n.notRegisteredCargoX)
                    InkWell(
                      onTap: () => CopyHelper.copy(context, value),
                      child: const Icon(Icons.copy, size: 13, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleInfoField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isArabic = l10n.isArabic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 3: Contact & Address & Brands
        _buildSectionHeader(Icons.contact_mail_outlined, l10n.contactAddressBrandsHeader),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildCopyableInfoField(
                context: context,
                label: l10n.fullAddressFieldLabel,
                value: supplier.address,
                icon: Icons.location_on_outlined,
              ),
              const Divider(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildCopyableInfoField(
                      context: context,
                      label: l10n.phoneFieldLabel,
                      value: supplier.phone ?? supplier.mobile ?? '-',
                      icon: Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCopyableInfoField(
                      context: context,
                      label: l10n.emailFieldLabel,
                      value: supplier.email ?? '-',
                      icon: Icons.email_outlined,
                    ),
                  ),
                ],
              ),
              if (supplier.website != null && supplier.website!.isNotEmpty) ...[
                const Divider(height: 14),
                _buildCopyableInfoField(
                  context: context,
                  label: l10n.websiteFieldLabel,
                  value: supplier.website!,
                  icon: Icons.language_outlined,
                ),
              ],
              if (supplier.brands != null && supplier.brands!.isNotEmpty) ...[
                const Divider(height: 14),
                _buildCopyableInfoField(
                  context: context,
                  label: l10n.brandsFieldLabel,
                  value: supplier.brands!,
                  icon: Icons.sell_outlined,
                  highlightColor: AppTheme.orange,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section 4: Trademark Certificates & ISO 9001
        _buildSectionHeader(Icons.verified_user_outlined, isArabic ? 'شهادات العلامة التجارية والجودة' : 'Trademark & Quality Certificates'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleInfoField(
                      icon: Icons.verified_outlined,
                      label: 'WIPO Madrid Monitor',
                      value: supplier.hasWipo
                          ? (supplier.wipoNumber != null && supplier.wipoNumber!.isNotEmpty
                              ? (isArabic ? 'مسجل (#${supplier.wipoNumber})' : 'Registered (#${supplier.wipoNumber})')
                              : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                          : (isArabic ? 'غير مسجل' : 'Not Registered'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSimpleInfoField(
                      icon: Icons.verified_outlined,
                      label: isArabic ? 'مكتب الملكية الفكرية الأوروبي (EUIPO)' : 'EUIPO',
                      value: supplier.hasEuipo
                          ? (supplier.euipoNumber != null && supplier.euipoNumber!.isNotEmpty
                              ? (isArabic ? 'مسجل (#${supplier.euipoNumber})' : 'Registered (#${supplier.euipoNumber})')
                              : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                          : (isArabic ? 'غير مسجل' : 'Not Registered'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleInfoField(
                      icon: Icons.public,
                      label: 'Global Brand Database',
                      value: supplier.hasGlobalBrand
                          ? (supplier.globalBrandNumber != null && supplier.globalBrandNumber!.isNotEmpty
                              ? (isArabic ? 'مسجل (#${supplier.globalBrandNumber})' : 'Registered (#${supplier.globalBrandNumber})')
                              : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                          : (isArabic ? 'غير مسجل' : 'Not Registered'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSimpleInfoField(
                      icon: Icons.workspace_premium_outlined,
                      label: isArabic ? 'شهادة آيزو 9001' : 'ISO 9001 Certificate',
                      value: supplier.hasIso9001
                          ? (supplier.iso9001Number != null && supplier.iso9001Number!.isNotEmpty
                              ? (isArabic ? 'معتمد (#${supplier.iso9001Number})' : 'Certified (#${supplier.iso9001Number})')
                              : (isArabic ? 'نعم (معتمد)' : 'Yes (Certified)'))
                          : (isArabic ? 'غير معتمد' : 'Not Certified'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionHeader(Icons.notes_rounded, l10n.additionalNotesHeader),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              supplier.notes!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ],
    );
  }
}
