import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

/// Status chip shown in the draft-vs-system comparison matrices
/// (COO review and inspection review tabs).
///
/// [severity] is the raw `severity` value from the backend row; it is
/// compared by equality only, so any type is accepted.
class ExtractionMatchStatusChip extends StatelessWidget {
  const ExtractionMatchStatusChip({
    super.key,
    required this.matchStatus,
    required this.severity,
  });

  final String matchStatus;
  final Object? severity;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        matchStatus == 'EXTRACTION_FAILED'
            ? context.l10n.idocBNotExtracted
            : (matchStatus == 'MATCH' ? context.l10n.idocBMatched : matchStatus),
        style: const TextStyle(fontSize: 11, color: AppTheme.white),
      ),
      backgroundColor: matchStatus == 'EXTRACTION_FAILED'
          ? AppTheme.charcoal
          : (severity == 'BLOCKING'
              ? AppTheme.crimson
              : (severity == 'WARNING' ? AppTheme.orange : AppTheme.emerald)),
    );
  }
}
