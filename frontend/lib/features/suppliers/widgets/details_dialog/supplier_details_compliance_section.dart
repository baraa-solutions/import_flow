import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/supplier_model.dart';

class SupplierDetailsComplianceSection extends StatelessWidget {
  final SupplierModel supplier;

  const SupplierDetailsComplianceSection({super.key, required this.supplier});

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

  Widget _buildComplianceTag(String label, bool isCompliant, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isCompliant ? AppTheme.emerald : Colors.grey).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: (isCompliant ? AppTheme.emerald : Colors.grey).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isCompliant ? AppTheme.emerald : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isCompliant ? AppTheme.emerald : Colors.grey.shade600,
            ),
          ),
        ],
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.hub_outlined, l10n.nafezaCargoXComplianceHeader),
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
                    child: _buildCopyableInfoField(
                      context: context,
                      label: l10n.foreignExporterIdFieldLabel,
                      value: supplier.foreignExporterId,
                      icon: Icons.fingerprint_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCopyableInfoField(
                      context: context,
                      label: l10n.cargoxPlatformIdFieldLabel,
                      value: supplier.cargoxPlatformId ?? l10n.notRegisteredCargoX,
                      icon: Icons.cloud_done_outlined,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleInfoField(
                      label: l10n.supplierTypeFieldLabel,
                      value: '${supplier.supplierType} (${supplier.registrationType})',
                      icon: Icons.category_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSimpleInfoField(
                      label: l10n.supplierOriginCountryFieldLabel,
                      value: '${supplier.foreignExporterCountry} (${supplier.foreignExporterCountryCode.toUpperCase()})',
                      icon: Icons.public,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              // Compliance Badges
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  Text(l10n.complianceCertificatesLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                  _buildComplianceTag(l10n.isoCertifiedTag, supplier.hasIso, Icons.verified_outlined),
                  _buildComplianceTag(l10n.decree43Tag, supplier.registeredDecree43, Icons.policy_outlined),
                  _buildComplianceTag(l10n.whiteListTag, supplier.whiteListRegistered, Icons.shield_outlined),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
