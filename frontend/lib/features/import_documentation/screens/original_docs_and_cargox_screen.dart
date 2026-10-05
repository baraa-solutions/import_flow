import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../cargox/screens/cargox_hub_screen.dart';
import '../../import_documentation/providers/import_documentation_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../widgets/original_documents_collection_tab.dart';

/// Phase 4 — Original Documents Collection & CargoX Blockchain Hub
///
/// شاشة مستقلة تجمع بين:
///   - Tab 0: تحصيل أصول المستندات وتتبع الكورير (Original Docs Collection)
///   - Tab 1: منظومة CargoX البلوك تشين والمانيفست الرقمي (CargoX & ACI Hub)
class OriginalDocsAndCargoXScreen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;

  const OriginalDocsAndCargoXScreen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<OriginalDocsAndCargoXScreen> createState() =>
      _OriginalDocsAndCargoXScreenState();
}

class _OriginalDocsAndCargoXScreenState
    extends ConsumerState<OriginalDocsAndCargoXScreen> {
  // 0 = Original Docs Collection & Courier
  // 1 = CargoX Blockchain & ACI Hub
  int _selectedSubTab = 0;
  int? _selectedImportFileId;

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(_refreshData);
  }

  @override
  void didUpdateWidget(covariant OriginalDocsAndCargoXScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() => _selectedSubTab = widget.initialSubTab);
    }
  }

  Future<void> _refreshData() async {
    if (!ref.read(importFilesProvider).isLoading) {
      await ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    if (!ref.read(shipmentDocumentsProvider).isLoading) {
      ref.read(shipmentDocumentsProvider.notifier).fetchShipmentDocuments();
    }
    if (_selectedImportFileId == null && files.isNotEmpty && mounted) {
      setState(() => _selectedImportFileId = files.first.importFileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final shipmentDocs = ref.watch(shipmentDocumentsProvider).valueOrNull ?? [];

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.markunread_mailbox_outlined,
        titleEn: 'Original Docs Collection & Courier',
        titleAr: 'تحصيل أصول المستندات وتتبع الكورير',
      ),
      VerticalNavTabItem(
        icon: Icons.hub_outlined,
        titleEn: 'CargoX Blockchain & ACI Hub',
        titleAr: 'منظومة كارجو إكس والمانيفست الرقمي',
        badge: shipmentDocs.isNotEmpty
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${shipmentDocs.length}',
                  style: TextStyle(
                    color: AppTheme.cobalt,
                    fontSize: DisplayDensityMode.clampFontSize(11.0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    ];

    return SelectionArea(
      child: VerticalStageScaffold(
        stageCode: 'PHASE-4',
        titleEn: 'Original Docs Collection & CargoX Hub — Phase 4',
        titleAr: 'تحصيل المستندات وكارجو إكس — المرحلة 4',
        headerIcon: Icons.cloud_upload_outlined,
        headerColor: AppTheme.crimson,
        tabs: tabs,
        selectedIndex: _selectedSubTab,
        onTabSelected: (index) {
          setState(() => _selectedSubTab = index);
          if (index == 1) {
            if (!ref.read(shipmentDocumentsProvider).isLoading) {
              ref
                  .read(shipmentDocumentsProvider.notifier)
                  .fetchShipmentDocuments();
            }
          }
        },
        selectedImportFileId: _selectedImportFileId,
        onShipmentStatusChanged: _refreshData,
        headerActions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.white, size: density.buttonIconSize),
            tooltip: l.refreshDataTooltip,
            onPressed: _refreshData,
          ),
        ],
        body: _buildCurrentTabContent(),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return OriginalDocumentsCollectionTab(
          initialImportFileId: _selectedImportFileId,
        );
      case 1:
        return CargoXHubScreen(
          initialImportFileId: _selectedImportFileId,
          isEmbedded: true,
        );
      default:
        return OriginalDocumentsCollectionTab(
          initialImportFileId: _selectedImportFileId,
        );
    }
  }
}
