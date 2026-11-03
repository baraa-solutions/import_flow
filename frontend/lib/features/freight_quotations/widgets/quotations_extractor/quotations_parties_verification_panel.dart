import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'extracted_quotation_option_model.dart';
import 'quotations_option_card.dart';

/// Panel verifying forwarder, shipping line, and ports against local database records.
class QuotationsPartiesVerificationPanel extends StatelessWidget {
  final Map<String, dynamic>? primaryMetadata;
  final List<ExtractedQuotationOption> options;
  final List<dynamic> partners;
  final List<dynamic> portsList;
  final VoidCallback onRegisterPartner;

  const QuotationsPartiesVerificationPanel({
    super.key,
    required this.primaryMetadata,
    required this.options,
    required this.partners,
    required this.portsList,
    required this.onRegisterPartner,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final rawForwarder = primaryMetadata?['forwarder_name']?.toString() ??
        options.firstOrNull?.forwarderName ??
        '';
    final rawCarrier = primaryMetadata?['carrier_name']?.toString() ??
        options.firstOrNull?.carrierName ??
        '';
    final rawPol = primaryMetadata?['origin_port']?.toString() ??
        options.firstOrNull?.originPort ??
        '';
    final rawPod = primaryMetadata?['destination_port']?.toString() ??
        options.firstOrNull?.destinationPort ??
        '';

    // Verify Forwarder in partners
    final matchedForwarder = rawForwarder.isNotEmpty
        ? partners.where((p) {
            final pName = (p.partnerName as String).toLowerCase();
            final rf = rawForwarder.toLowerCase();
            return pName.contains(rf) || rf.contains(pName);
          }).firstOrNull
        : null;

    // Verify Carrier in partners
    final matchedCarrier = rawCarrier.isNotEmpty
        ? partners.where((p) {
            final pName = (p.partnerName as String).toLowerCase();
            final rc = rawCarrier.toLowerCase();
            final scac = (p.scacCode ?? '').toString().toLowerCase();
            return pName.contains(rc) || rc.contains(pName) || (scac.isNotEmpty && rc.contains(scac));
          }).firstOrNull
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.charcoal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.charcoal.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, size: 16, color: AppTheme.charcoal),
              const SizedBox(width: 6),
              Text(
                isArabic
                    ? 'التحقق من أطراف الشحن والموانئ في قاعدة البيانات'
                    : 'Verify Shipping Parties and Ports in Database',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Forwarder Verification Row
          if (rawForwarder.isNotEmpty) ...[
            PartyVerificationRow(
              icon: Icons.business_rounded,
              title: isArabic ? 'وكيل الشحن أو الناقل' : 'Freight Forwarder',
              name: rawForwarder,
              isVerified: matchedForwarder != null,
              code: matchedForwarder?.partnerCode ?? (matchedForwarder != null ? 'PRV-${matchedForwarder.providerId}' : null),
              onRegister: onRegisterPartner,
            ),
            const SizedBox(height: 6),
          ],

          // Shipping Line Verification Row
          if (rawCarrier.isNotEmpty) ...[
            PartyVerificationRow(
              icon: Icons.directions_boat_rounded,
              title: isArabic ? 'الخط الملاحي' : 'Shipping Line',
              name: rawCarrier,
              isVerified: matchedCarrier != null,
              code: matchedCarrier?.partnerCode ?? (matchedCarrier != null ? 'PRV-${matchedCarrier.providerId}' : null),
              onRegister: onRegisterPartner,
            ),
            const SizedBox(height: 6),
          ],

          // Ports Row
          Row(
            children: [
              if (rawPol.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flight_takeoff, size: 14, color: AppTheme.cobalt),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isArabic ? 'ميناء الشحن: $rawPol' : 'Port of Loading: $rawPol',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (rawPol.isNotEmpty && rawPod.isNotEmpty) const SizedBox(width: 8),
              if (rawPod.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flight_land, size: 14, color: AppTheme.emerald),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isArabic ? 'ميناء الوصول: $rawPod' : 'Port of Discharge: $rawPod',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
