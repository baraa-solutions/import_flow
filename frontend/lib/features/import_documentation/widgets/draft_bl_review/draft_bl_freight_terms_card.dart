import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Card displaying freight, delivery, and commercial maritime terms:
/// - Freight payment mode (Freight Prepaid / Freight Collect)
/// - Demurrage & detention free days
/// - Issue date & place of issue
/// - Place of delivery
/// - Booking number
class DraftBlFreightTermsCard extends StatelessWidget {
  final String? freightTerms;
  final String? bookingNumber;
  final String? placeOfDelivery;
  final int? demurrageFreeDays;
  final String? issueDate;
  final String? placeOfIssue;

  const DraftBlFreightTermsCard({
    super.key,
    this.freightTerms,
    this.bookingNumber,
    this.placeOfDelivery,
    this.demurrageFreeDays,
    this.issueDate,
    this.placeOfIssue,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isPrepaid = (freightTerms ?? '').toLowerCase().contains('prepaid');

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.borderOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payment, color: AppTheme.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l.draftBlSummaryFreightTerms,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  AppStatusBadge(
                    label: freightTerms != null && freightTerms!.isNotEmpty
                        ? freightTerms!
                        : 'Freight Prepaid',
                    severity: isPrepaid ? AppSeverity.success : AppSeverity.warning,
                    size: AppStatusBadgeSize.small,
                  ),
                ],
              ),
              const Divider(height: 18),

              // Key-value pairs
              Wrap(
                spacing: 24,
                runSpacing: 14,
                children: [
                  _buildTermItem(
                    context,
                    label: l.draftBlSummaryBookingNo,
                    value: bookingNumber != null && bookingNumber!.isNotEmpty ? bookingNumber! : l.unspecified,
                    icon: Icons.confirmation_number_outlined,
                  ),
                  _buildTermItem(
                    context,
                    label: l.idocAPortOfLoadingArrival,
                    value: placeOfDelivery != null && placeOfDelivery!.isNotEmpty ? placeOfDelivery! : l.unspecified,
                    icon: Icons.location_on_outlined,
                  ),
                  _buildTermItem(
                    context,
                    label: l.demurrageDetention,
                    value: l.customsClearanceFreeDaysLabel(demurrageFreeDays ?? 14),
                    icon: Icons.timer_outlined,
                    badgeColor: AppTheme.cobalt,
                  ),
                  _buildTermItem(
                    context,
                    label: l.date,
                    value: issueDate != null && issueDate!.isNotEmpty ? issueDate! : l.unspecified,
                    icon: Icons.calendar_today_outlined,
                  ),
                  _buildTermItem(
                    context,
                    label: l.idocAPortOfLoadingArrival,
                    value: placeOfIssue != null && placeOfIssue!.isNotEmpty ? placeOfIssue! : (placeOfDelivery ?? l.unspecified),
                    icon: Icons.apartment_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? badgeColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: badgeColor ?? AppTheme.textMutedOf(context)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: AppTheme.textSecondaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CopyableText(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => CopyHelper.copy(context, value),
                  child: const Icon(Icons.copy, size: 12, color: AppTheme.cobalt),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
