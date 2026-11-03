import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/cargox_model.dart';

/// ACI Digital Manifest JSON inspector view.
class CargoXManifestViewer extends StatelessWidget {
  final DigitalManifestModel? activeDigitalManifest;
  final bool isLoadingManifest;
  final List<CargoXEnvelopeModel> envelopes;
  final ValueChanged<CargoXEnvelopeModel> onViewManifest;

  const CargoXManifestViewer({
    super.key,
    required this.activeDigitalManifest,
    required this.isLoadingManifest,
    required this.envelopes,
    required this.onViewManifest,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingManifest) {
      return const AppLoadingState();
    }

    if (activeDigitalManifest == null && envelopes.isNotEmpty) {
      if (!isLoadingManifest) {
        Future.microtask(() => onViewManifest(envelopes.first));
      }
      return const AppLoadingState();
    }

    if (activeDigitalManifest == null) {
      return Center(
        child: Text(context.l10n.cargoxSelectEnvelopeForManifestPrompt),
      );
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(activeDigitalManifest!.manifestJson);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Control Bar
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.cargoxManifestTitle(
                        activeDigitalManifest!.envelopeCode,
                        activeDigitalManifest!.acidNumber,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.charcoal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: context.l10n.cargoxCopyJsonBtn,
                    icon: Icons.copy,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: () {
                      CopyHelper.copy(
                        context,
                        jsonStr,
                        customMessage: context.l10n.cargoxManifestCopiedToast,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // JSON Code Viewer Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: SelectableText(
              jsonStr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF9CDCFE),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
