import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/original_documents_collection_model.dart';
import '../../providers/original_documents_collection_provider.dart';
import 'original_docs_courier_registry_table.dart';
import 'original_docs_sessions_table.dart';

/// Registry section containing the switchable tabs for Sessions Registry and Courier Tracking.
/// Wrapped in [SelectionArea] with reactive Riverpod invalidation.
class OriginalDocsRegistrySection extends ConsumerStatefulWidget {
  final AsyncValue<List<OriginalDocumentsCollectionSessionModel>> sessionsAsync;
  final ValueChanged<int> onLoadFile;
  final void Function({
    required int importFileId,
    required String courierNo,
    required String courierCompany,
    String? trackingNo,
    required String importFileCode,
  }) onShowDeliveryProof;

  const OriginalDocsRegistrySection({
    super.key,
    required this.sessionsAsync,
    required this.onLoadFile,
    required this.onShowDeliveryProof,
  });

  @override
  ConsumerState<OriginalDocsRegistrySection> createState() => _OriginalDocsRegistrySectionState();
}

class _OriginalDocsRegistrySectionState extends ConsumerState<OriginalDocsRegistrySection> {
  int _registryTabMode = 0; // 0 = Sessions, 1 = Courier Tracking

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_edu_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          l.sessionsRegistryTab,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    selected: _registryTabMode == 0,
                    selectedColor: AppTheme.cobalt.withValues(alpha: 0.15),
                    onSelected: (val) {
                      if (val) setState(() => _registryTabMode = 0);
                    },
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          l.courierTrackingRegistryTab,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    selected: _registryTabMode == 1,
                    selectedColor: AppTheme.cobalt.withValues(alpha: 0.15),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _registryTabMode = 1);
                        ref.invalidate(allCouriersProvider);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_registryTabMode == 0)
              OriginalDocsSessionsTable(
                sessionsAsync: widget.sessionsAsync,
                onLoadFile: widget.onLoadFile,
              )
            else
              OriginalDocsCourierRegistryTable(
                onLoadFile: widget.onLoadFile,
                onShowDeliveryProof: widget.onShowDeliveryProof,
              ),
          ],
        ),
      ),
    );
  }
}
