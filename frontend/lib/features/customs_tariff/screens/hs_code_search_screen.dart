import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';
import '../widgets/hs_code_detailed_explorer.dart';
import '../widgets/hs_code_results_list.dart';
import '../widgets/hs_code_search_toolbar.dart';

class HsCodeSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final bool isEmbedded;
  const HsCodeSearchScreen({super.key, this.initialQuery, this.isEmbedded = false});

  @override
  ConsumerState<HsCodeSearchScreen> createState() => _HsCodeSearchScreenState();
}

class _HsCodeSearchScreenState extends ConsumerState<HsCodeSearchScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _searchCtrl;
  CustomsTariffModel? _selectedTariff;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery ?? '');
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tariffsAsync = ref.watch(customsTariffProvider);
    final allTariffs = tariffsAsync.valueOrNull ?? [];

    final query = _searchCtrl.text.trim().toLowerCase().replaceAll('.', '');
    final filtered = query.isEmpty
        ? allTariffs
        : allTariffs.where((t) {
            final hsClean = t.hsCode.toLowerCase().replaceAll('.', '');
            final desc = t.hsDescription.toLowerCase();
            final cat = t.categorySearchText;
            final auth = (t.regulatoryAuthority ?? '').toLowerCase();
            final note = (t.priorApprovalNote ?? '').toLowerCase();
            return hsClean.contains(query) ||
                desc.contains(query) ||
                cat.contains(query) ||
                auth.contains(query) ||
                note.contains(query);
          }).toList();

    // Auto-select first item if current selection is not in filtered list
    if (_selectedTariff == null && filtered.isNotEmpty) {
      _selectedTariff = filtered.first;
    } else if (_selectedTariff != null && !filtered.any((t) => t.tariffId == _selectedTariff!.tariffId)) {
      _selectedTariff = filtered.isNotEmpty ? filtered.first : null;
    }

    final bodyContent = SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HsCodeSearchToolbar(
              searchController: _searchCtrl,
              filteredItems: filtered,
              onQueryChanged: (val) => setState(() {}),
              onQuickQuerySelected: (q) {
                _searchCtrl.text = q;
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HsCodeResultsList(
                    filtered: filtered,
                    selectedTariff: _selectedTariff,
                    searchQuery: _searchCtrl.text,
                    onSelectTariff: (tariff) {
                      setState(() {
                        _selectedTariff = tariff;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _selectedTariff == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.touch_app_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(l.hsSelectFromListPrompt),
                              ],
                            ),
                          )
                        : HsCodeDetailedExplorer(
                            tariff: _selectedTariff!,
                            tabController: _tabController,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: bodyContent,
    );
  }
}
