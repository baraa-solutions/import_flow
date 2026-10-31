import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/incoterms_provider.dart';
import 'incoterms_data_table.dart';

/// تبويب قواعد الشروط الدولية (Incoterms Rules)
class IncotermsTab extends ConsumerWidget {
  final String searchQuery;
  const IncotermsTab({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final incotermsAsync = ref.watch(incotermsProvider);

    return SelectionArea(
      child: incotermsAsync.when(
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.read(incotermsProvider.notifier).fetchIncoterms(),
        ),
        data: (incoterms) {
          final filtered = searchQuery.isEmpty
              ? incoterms
              : incoterms
                  .where((i) =>
                      i.incotermCode.toLowerCase().contains(searchQuery) ||
                      i.incotermName.toLowerCase().contains(searchQuery))
                  .toList();
          if (filtered.isEmpty) {
            return AppEmptyState(
              icon: Icons.handshake_outlined,
              message: l10n.noIncotermsFound,
            );
          }
          return IncotermsDataTable(incoterms: filtered);
        },
      ),
    );
  }
}
