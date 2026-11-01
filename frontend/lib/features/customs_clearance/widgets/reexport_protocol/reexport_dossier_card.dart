import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/reexport_protocol_model.dart';

class ReexportDossierCard extends StatelessWidget {
  final ReexportDossierModel item;
  final VoidCallback onBooking;
  final VoidCallback onSupervision;
  final VoidCallback onCreditNote;
  final VoidCallback onDrawback;
  final VoidCallback onAdvanceStatus;

  const ReexportDossierCard({
    super.key,
    required this.item,
    required this.onBooking,
    required this.onSupervision,
    required this.onCreditNote,
    required this.onDrawback,
    required this.onAdvanceStatus,
  });

  Color _alertColor(int days) {
    if (days <= 0) return AppTheme.crimson;
    if (days <= 7) return const Color(0xFFD32F2F);
    if (days <= 14) return AppTheme.orange;
    return AppTheme.emerald;
  }

  AppSeverity _statusSeverity(ReexportStatus status) {
    switch (status) {
      case ReexportStatus.mandated:
        return AppSeverity.danger;
      case ReexportStatus.bookingConfirmed:
      case ReexportStatus.customsInspected:
        return AppSeverity.warning;
      case ReexportStatus.ladenOnBoard:
      case ReexportStatus.completedClosed:
        return AppSeverity.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dColor = _alertColor(item.daysRemainingToDestruction);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Countdown Chip
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: dColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(
                  '${item.daysRemainingToDestruction}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dColor),
                ),
                Text(
                  item.daysRemainingToDestruction <= 0 ? 'مهلة منتهية!' : 'يوم للإعدام',
                  style: TextStyle(fontSize: 10, color: dColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Dossier Details
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.importFileCode,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cobalt),
                    ),
                    const SizedBox(width: 8),
                    AppStatusBadge(
                      label: item.status.labelAr,
                      severity: _statusSeverity(item.status),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'قرار: ${item.rejectionDecreeNumber}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'الجهة: ${item.rejectionAuthority} | تاريخ القرار: ${item.rejectionDate} | المهلة القانونية القصوى: ${item.legalReexportDeadline}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                ),
                Text(
                  'السبب: ${item.reexportReason}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.containerNumbers.isNotEmpty)
                  Text(
                    'الحاويات: ${item.containerNumbers.join(", ")}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (item.customsOutboundDeclarationNo != null) ...[
                      Icon(Icons.assignment_turned_in_outlined, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 3),
                      Text('مظهر الصادر: ${item.customsOutboundDeclarationNo}', style: TextStyle(fontSize: 11, color: Colors.green.shade900)),
                      const SizedBox(width: 10),
                    ],
                    if (item.returnBookingNumber != null) ...[
                      const Icon(Icons.directions_boat_outlined, size: 14, color: AppTheme.cobalt),
                      const SizedBox(width: 3),
                      Text('الحجز: ${item.returnBookingNumber}', style: const TextStyle(fontSize: 11, color: AppTheme.cobalt)),
                      const SizedBox(width: 10),
                    ],
                    if (item.creditNoteAmountUsd > 0) ...[
                      Icon(Icons.monetization_on_outlined, size: 14, color: Colors.purple.shade700),
                      const SizedBox(width: 3),
                      Text('خصم مورد: \$${item.creditNoteAmountUsd.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.purple.shade900)),
                      const SizedBox(width: 10),
                    ],
                    if (item.dutyAmountRefundableEgp > 0) ...[
                      Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.teal.shade700),
                      const SizedBox(width: 3),
                      Text('دروباك: ${item.dutyAmountRefundableEgp.toStringAsFixed(0)} ج.م', style: TextStyle(fontSize: 11, color: Colors.teal.shade900)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Operations Action Buttons
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'حجز الشحن',
                    icon: Icons.directions_boat_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: onBooking,
                  ),
                  const SizedBox(width: 6),
                  AppButton(
                    label: 'لجنة الإشراف',
                    icon: Icons.shield_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: onSupervision,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'خصم المورد',
                    icon: Icons.receipt_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: onCreditNote,
                  ),
                  const SizedBox(width: 6),
                  AppButton(
                    label: 'رد الرسوم (دروباك)',
                    icon: Icons.price_check_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: onDrawback,
                  ),
                  if (item.status != ReexportStatus.completedClosed) ...[
                    const SizedBox(width: 6),
                    AppButton(
                      label: 'تصعيد المرحلة ❯',
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.small,
                      onPressed: onAdvanceStatus,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
