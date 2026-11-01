import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_text_field.dart';
import 'partner_registration_copy_suffix.dart';

class PartnerTransportCustomsFields extends StatelessWidget {
  final bool isDarkDialog;
  final bool isShippingLine;
  final bool isCustomsBroker;
  final bool isFreightForwarder;
  final bool isInlandTransport;

  final TextEditingController scacCtrl;
  final TextEditingController defaultFreeDaysCtrl;
  final TextEditingController trackingCtrl;
  final TextEditingController licenseCtrl;
  final TextEditingController authorizedPortsCtrl;
  final TextEditingController fiataCtrl;
  final TextEditingController supportedCurrenciesCtrl;
  final TextEditingController shippingModesCtrl;
  final TextEditingController creditLimitCtrl;
  final TextEditingController transportLicenseCtrl;
  final TextEditingController fleetTypesCtrl;
  final TextEditingController coverageAreasCtrl;

  const PartnerTransportCustomsFields({
    super.key,
    required this.isDarkDialog,
    required this.isShippingLine,
    required this.isCustomsBroker,
    required this.isFreightForwarder,
    required this.isInlandTransport,
    required this.scacCtrl,
    required this.defaultFreeDaysCtrl,
    required this.trackingCtrl,
    required this.licenseCtrl,
    required this.authorizedPortsCtrl,
    required this.fiataCtrl,
    required this.supportedCurrenciesCtrl,
    required this.shippingModesCtrl,
    required this.creditLimitCtrl,
    required this.transportLicenseCtrl,
    required this.fleetTypesCtrl,
    required this.coverageAreasCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isShippingLine) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🚢 ${l10n.shippingLineDetailsHeader}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: scacCtrl,
                        suffixIcon:
                            PartnerRegistrationCopySuffix(controller: scacCtrl),
                        label: l10n.scacCarrierCodeLabel,
                        icon: Icons.code,
                        isRequired: true,
                        hint: l10n.scacCarrierCodeHint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: defaultFreeDaysCtrl,
                        suffixIcon: PartnerRegistrationCopySuffix(
                            controller: defaultFreeDaysCtrl),
                        label: l10n.defaultFreeDaysLabel,
                        icon: Icons.timer_outlined,
                        isRequired: true,
                        keyboardType: TextInputType.number,
                        hint: l10n.defaultFreeDaysHint,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return l10n.fieldRequired;
                          }
                          final parsed = int.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return l10n.defaultFreeDaysHint;
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: trackingCtrl,
                  suffixIcon:
                      PartnerRegistrationCopySuffix(controller: trackingCtrl),
                  label: l10n.trackingWebUrlLabel,
                  icon: Icons.link,
                  hint: l10n.trackingWebUrlHint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (isCustomsBroker) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.orange.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🛂 ${l10n.customsBrokerLicenseHeader}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.orange)),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: licenseCtrl,
                  suffixIcon:
                      PartnerRegistrationCopySuffix(controller: licenseCtrl),
                  label: l10n.customsClearanceLicenseNumLabel,
                  icon: Icons.assignment_ind,
                  isRequired: true,
                  hint: l10n.customsClearanceLicenseNumHint,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: authorizedPortsCtrl,
                  suffixIcon: PartnerRegistrationCopySuffix(
                      controller: authorizedPortsCtrl),
                  label: l10n.authorizedPortsLabel,
                  icon: Icons.anchor_outlined,
                  hint: l10n.authorizedPortsHint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (isFreightForwarder) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.charcoal.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.charcoal.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📦 ${l10n.freightForwarderDetailsHeader}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkDialog
                        ? AppTheme.darkTextPrimary
                        : AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: fiataCtrl,
                        suffixIcon:
                            PartnerRegistrationCopySuffix(controller: fiataCtrl),
                        label: l10n.fiataLicenseLabel,
                        icon: Icons.badge_outlined,
                        hint: l10n.fiataLicenseHint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: supportedCurrenciesCtrl,
                        suffixIcon: PartnerRegistrationCopySuffix(
                            controller: supportedCurrenciesCtrl),
                        label: l10n.supportedCurrenciesLabel,
                        icon: Icons.monetization_on_outlined,
                        hint: l10n.supportedCurrenciesHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: shippingModesCtrl,
                  suffixIcon: PartnerRegistrationCopySuffix(
                      controller: shippingModesCtrl),
                  label: l10n.shippingModesLabel,
                  icon: Icons.alt_route_rounded,
                  hint: l10n.shippingModesHint,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: defaultFreeDaysCtrl,
                        suffixIcon: PartnerRegistrationCopySuffix(
                            controller: defaultFreeDaysCtrl),
                        label: '${l10n.defaultFreeDaysLabel} (إلزامي)',
                        icon: Icons.timer_outlined,
                        isRequired: true,
                        keyboardType: TextInputType.number,
                        hint: l10n.defaultFreeDaysHint,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return l10n.fieldRequired;
                          }
                          final parsed = int.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return l10n.defaultFreeDaysHint;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: creditLimitCtrl,
                        suffixIcon: PartnerRegistrationCopySuffix(
                            controller: creditLimitCtrl),
                        label: l10n.creditLimitDetailLabel,
                        icon: Icons.account_balance_wallet_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        hint: '0.00',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (isInlandTransport) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🚛 ${l10n.inlandTransportDetailsHeader}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: transportLicenseCtrl,
                  suffixIcon: PartnerRegistrationCopySuffix(
                      controller: transportLicenseCtrl),
                  label: l10n.transportLicenseNumLabel,
                  icon: Icons.local_shipping_outlined,
                  isRequired: true,
                  hint: l10n.transportLicenseNumHint,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: fleetTypesCtrl,
                        suffixIcon: PartnerRegistrationCopySuffix(
                            controller: fleetTypesCtrl),
                        label: l10n.fleetTypesLabel,
                        icon: Icons.fire_truck_outlined,
                        hint: l10n.fleetTypesHint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: coverageAreasCtrl,
                        suffixIcon: PartnerRegistrationCopySuffix(
                            controller: coverageAreasCtrl),
                        label: l10n.coverageAreasLabel,
                        icon: Icons.map_outlined,
                        hint: l10n.coverageAreasHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
