import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/import_company_model.dart';
import 'details/import_company_details_sections.dart';
import 'details/import_company_details_toolbar.dart';

class ImportCompanyDetailsDialog extends StatelessWidget {
  final ImportCompanyModel company;
  final VoidCallback? onEdit;

  const ImportCompanyDetailsDialog({
    super.key,
    required this.company,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    ImportCompanyModel company, {
    VoidCallback? onEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ImportCompanyDetailsDialog(company: company, onEdit: onEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isActive = company.isActive;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 760),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              // ── Top Header Banner ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: SelectableText(
                                  company.importerName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: l10n.importCompaniesCopyFieldTooltip,
                                child: InkWell(
                                  onTap: () => CopyHelper.copy(context, company.importerName),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.copy_rounded, size: 15, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isActive ? AppTheme.emerald : AppTheme.crimson).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isActive ? AppTheme.emerald : AppTheme.crimson,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isActive ? l10n.statusActive : l10n.statusInactive,
                                  style: TextStyle(
                                    color: isActive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            l10n.importerProfileSubtitle,
                            style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                      tooltip: l10n.close,
                    ),
                  ],
                ),
              ),

              // ── Scrollable Body ────────────────────────────────────────────
              Flexible(
                child: ImportCompanyDetailsSections(company: company),
              ),

              // ── Action Toolbar ────────────────────────────────────────────
              ImportCompanyDetailsToolbar(
                company: company,
                onEdit: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
