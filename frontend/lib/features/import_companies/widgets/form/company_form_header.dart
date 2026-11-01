import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Header banner for ImportCompanyFormDialog
class CompanyFormHeader extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onClose;

  const CompanyFormHeader({
    super.key,
    required this.isEditing,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(16),
          topEnd: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isEditing ? Icons.edit : Icons.add_business, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(
                isEditing ? l10n.editImporterCompanyTitle : l10n.addImporterCompanyTitle,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: l10n.closeDialogTooltip,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
