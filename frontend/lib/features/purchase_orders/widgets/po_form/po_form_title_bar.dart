import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/smart_upload_button.dart';

/// Clean title bar and tab bar for the PO Form Dialog.
class POFormTitleBar extends StatelessWidget {
  final String title;
  final DateTime? lastDraftSavedAt;
  final ValueChanged<Map<String, dynamic>> onDataExtracted;
  final VoidCallback onClose;
  final int itemsCount;
  final int packingItemsCount;

  const POFormTitleBar({
    super.key,
    required this.title,
    required this.lastDraftSavedAt,
    required this.onDataExtracted,
    required this.onClose,
    required this.itemsCount,
    required this.packingItemsCount,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: AppTheme.white, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (lastDraftSavedAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_done_outlined, size: 14, color: AppTheme.emerald),
                        const SizedBox(width: 4),
                        Text(
                          l.poDraftSaved,
                          style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                SmartUploadButton(
                  module: SmartUploadModule.purchaseOrder,
                  label: l.poSmartExtractPIPL,
                  compact: MediaQuery.sizeOf(context).width < 700,
                  onDataExtracted: (res) => onDataExtracted(res.extractedFields),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: l.close,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          TabBar(
            labelColor: AppTheme.emerald,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppTheme.emerald,
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: const Icon(Icons.list_alt, size: 18),
                text: '${l.poLineItemsTab} ($itemsCount)',
              ),
              Tab(
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                text: '${l.reviewPackingListTab} ($packingItemsCount)',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
