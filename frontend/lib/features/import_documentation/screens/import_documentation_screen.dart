import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bank_form4_screen.dart';
import 'customs_declaration46_screen.dart';
import 'nafeza_acid_screen.dart';
import 'shipment_draft_docs_screen.dart';

export 'bank_form4_screen.dart';
export 'customs_declaration46_screen.dart';
export 'nafeza_acid_screen.dart';
export 'shipment_draft_docs_screen.dart';

/// Legacy facade wrapper for backward compatibility.
/// Routes automatically to the clean, dedicated stage screens.
class ImportDocumentationScreen extends ConsumerWidget {
  final int initialIndex;
  final int? initialImportFileId;

  const ImportDocumentationScreen({
    super.key,
    this.initialIndex = 0,
    this.initialImportFileId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = () {
      switch (initialIndex) {
      case 0:
        return NafezaAcidScreen(
          initialSubTab: 0,
          initialImportFileId: initialImportFileId,
        );
      case 1:
        return BankForm4Screen(
          initialSubTab: 0,
          initialImportFileId: initialImportFileId,
        );
      case 2:
        return ShipmentDraftDocsScreen(
          initialSubTab: 0,
          initialImportFileId: initialImportFileId,
        );
      case 3:
        return CustomsDeclaration46Screen(
          initialSubTab: 0,
          initialImportFileId: initialImportFileId,
        );
      default:
        return NafezaAcidScreen(
          initialSubTab: 0,
          initialImportFileId: initialImportFileId,
        );
      }
    }();
    return SelectionArea(child: child);
  }
}
