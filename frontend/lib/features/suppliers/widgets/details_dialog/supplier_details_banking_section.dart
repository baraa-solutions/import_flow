import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/supplier_model.dart';

class SupplierDetailsBankingSection extends StatelessWidget {
  final SupplierModel supplier;

  const SupplierDetailsBankingSection({super.key, required this.supplier});

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.account_balance_rounded, l10n.bankingSwiftSectionHeader),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCopyableInfoField(
                      context: context,
                      label: l10n.beneficiaryBankFieldLabel,
                      value: supplier.bankName ?? '-',
                      icon: Icons.account_balance,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCopyableInfoField(
                      context: context,
                      label: l10n.swiftCodeFieldLabel,
                      value: supplier.swiftCode ?? '-',
                      icon: Icons.flash_on_rounded,
                      highlightColor: AppTheme.cobalt,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildCopyableInfoField(
                      context: context,
                      label: l10n.accountNumberFieldLabel,
                      value: supplier.accountNumber ?? '-',
                      icon: Icons.pin_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCopyableInfoField(
                      context: context,
                      label: l10n.ibanFieldLabel,
                      value: supplier.iban ?? '-',
                      icon: Icons.credit_card_outlined,
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
}
