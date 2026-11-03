import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_tariff_model.dart';

class HsCodeRegulatoryTab extends StatelessWidget {
  final CustomsTariffModel tariff;

  const HsCodeRegulatoryTab({super.key, required this.tariff});

  Widget _reqChip(String label, bool isRequired) {
    return Chip(
      avatar: Icon(
        isRequired ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: isRequired ? AppTheme.emerald : Colors.grey,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isRequired ? FontWeight.bold : FontWeight.normal,
          color: isRequired ? AppTheme.charcoal : Colors.grey.shade600,
        ),
      ),
      backgroundColor: isRequired ? AppTheme.emerald.withValues(alpha: 0.1) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.hsRegulatorySectionHeader,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _reqChip(l.hsReqAcidSystem, tariff.requiresAcid),
              const SizedBox(width: 8),
              _reqChip(l.hsReqCertificateOfOrigin, tariff.requiresCoo),
              const SizedBox(width: 8),
              _reqChip(l.hsReqQualityInspection, tariff.requiresInspection),
            ],
          ),
          const SizedBox(height: 16),
          if (tariff.regulatoryAuthority != null && tariff.regulatoryAuthority!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.hsRegulatoryAuthorityPrefix(tariff.regulatoryAuthority!),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.purple),
                    tooltip: l.hsExplorerCopyCardRateTooltip,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => CopyHelper.copy(context, tariff.regulatoryAuthority!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (tariff.priorApprovalNote != null && tariff.priorApprovalNote!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rule, color: AppTheme.orange, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.hsDecreesAndNotesHeader,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.orange),
                        tooltip: l.hsExplorerCopyCardRateTooltip,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: () => CopyHelper.copy(context, tariff.priorApprovalNote!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tariff.priorApprovalNote!,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
