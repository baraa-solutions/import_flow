import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';

class BLContainerLockWidget extends ConsumerWidget {
  final int shipmentId;
  final String blNumber;
  final List<String> selectedContainerNumbers;
  final ValueChanged<List<String>> onContainersChanged;

  const BLContainerLockWidget({
    super.key,
    required this.shipmentId,
    required this.blNumber,
    required this.selectedContainerNumbers,
    required this.onContainersChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (blNumber.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final lockStatusAsync = ref.watch(
      containerLockStatusProvider((shipmentId: shipmentId, blNumber: blNumber)),
    );

    return lockStatusAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (err, _) => Text('Error loading container locks: $err', style: const TextStyle(color: Colors.red, fontSize: 11)),
      data: (data) => _buildWidget(context, data),
    );
  }

  Widget _buildWidget(BuildContext context, ContainerLockStatusModel data) {
    final isDark = AppTheme.isDark(context);

    if (data.containers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2630) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.blueGrey.shade400),
            const SizedBox(width: 8),
            const Text(
              'No registered containers for this B/L yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E28) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_clock_outlined, size: 16, color: AppTheme.cobalt),
              const SizedBox(width: 6),
              Text(
                'Container Billing Lock for B/L: $blNumber',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.white : AppTheme.charcoal,
                ),
              ),
              const Spacer(),
              Text(
                '${selectedContainerNumbers.length} / ${data.containers.length} Selected',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: data.containers.map((c) {
              final isAlreadyBilled = c.isBilled;
              final isSelected = selectedContainerNumbers.contains(c.containerNumber);

              Color chipBg;
              Color chipBorder;
              Color textColor;

              if (isAlreadyBilled) {
                chipBg = AppTheme.crimson.withValues(alpha: 0.1);
                chipBorder = AppTheme.crimson.withValues(alpha: 0.4);
                textColor = AppTheme.crimson;
              } else if (isSelected) {
                chipBg = AppTheme.cobalt.withValues(alpha: 0.15);
                chipBorder = AppTheme.cobalt;
                textColor = AppTheme.cobalt;
              } else {
                chipBg = isDark ? const Color(0xFF222C38) : Colors.white;
                chipBorder = Colors.grey.withValues(alpha: 0.3);
                textColor = isDark ? Colors.white70 : Colors.black87;
              }

              return InkWell(
                onTap: isAlreadyBilled
                    ? null
                    : () {
                        final current = List<String>.from(selectedContainerNumbers);
                        if (isSelected) {
                          current.remove(c.containerNumber);
                        } else {
                          current.add(c.containerNumber);
                        }
                        onContainersChanged(current);
                      },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: chipBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAlreadyBilled
                            ? Icons.lock
                            : isSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                        size: 14,
                        color: textColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        c.containerNumber,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          decoration: isAlreadyBilled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (c.sealNumber != null && c.sealNumber!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${c.sealNumber})',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                      if (isAlreadyBilled) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Billed by ${c.billedByPartnerName ?? 'Partner'} in Inv #${c.invoiceNumber ?? ''}',
                          child: const Icon(Icons.info_outline, size: 12, color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
