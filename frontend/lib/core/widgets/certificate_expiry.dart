import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/certificate_expiry.dart';
import 'app_status_badge.dart';

export '../utils/certificate_expiry.dart';

/// Badge colour of a renewal state.
AppSeverity certificateExpirySeverity(CertificateExpiryState s) {
  switch (s) {
    case CertificateExpiryState.expired:
      return AppSeverity.danger;
    case CertificateExpiryState.expiringSoon:
      return AppSeverity.warning;
    case CertificateExpiryState.valid:
      return AppSeverity.success;
    case CertificateExpiryState.notSet:
      return AppSeverity.info;
  }
}

/// Colour-coded remaining-days badge for one expiry date.
class CertificateExpiryBadge extends StatelessWidget {
  final DateTime? expiry;
  final bool isArabic;
  final String? prefix;

  const CertificateExpiryBadge({super.key, required this.expiry, required this.isArabic, this.prefix});

  @override
  Widget build(BuildContext context) {
    final text = CertificateExpiry.label(expiry, isArabic: isArabic);
    return AppStatusBadge(
      label: prefix == null ? text : '$prefix: $text',
      severity: certificateExpirySeverity(CertificateExpiry.state(expiry)),
      size: AppStatusBadgeSize.small,
    );
  }
}

/// Date picker field for a certificate expiry with the live remaining-days badge under it.
class CertificateExpiryField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final bool isArabic;

  const CertificateExpiryField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final text = CertificateExpiry.toJsonDate(value) ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) onChanged(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              prefixIcon: const Icon(Icons.event, size: 18, color: AppTheme.cobalt),
              suffixIcon: value == null
                  ? null
                  : IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => onChanged(null)),
            ),
            child: Text(text.isEmpty ? 'YYYY-MM-DD' : text, textDirection: TextDirection.ltr),
          ),
        ),
        const SizedBox(height: 4),
        CertificateExpiryBadge(expiry: value, isArabic: isArabic),
      ],
    );
  }
}
