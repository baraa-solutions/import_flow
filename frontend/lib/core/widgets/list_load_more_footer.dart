import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'buttons/app_button.dart';

/// "Load more" bar for paginated registries: shows "loaded X of Y" and fetches the next page.
/// Renders nothing when the server holds no more rows than are loaded.
class ListLoadMoreFooter extends StatefulWidget {
  final int loaded;
  final int? total;
  final bool hasMore;
  final Future<void> Function() onLoadMore;

  const ListLoadMoreFooter({
    super.key,
    required this.loaded,
    required this.total,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  State<ListLoadMoreFooter> createState() => _ListLoadMoreFooterState();
}

class _ListLoadMoreFooterState extends State<ListLoadMoreFooter> {
  bool _isLoading = false;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await widget.onLoadMore();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasMore || widget.total == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surfaceOf(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              l.listLoadedOfTotal(widget.loaded, widget.total!),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          AppButton(
            key: const Key('listLoadMoreBtn'),
            label: l.listLoadMoreBtn,
            icon: Icons.expand_more_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
    );
  }
}
