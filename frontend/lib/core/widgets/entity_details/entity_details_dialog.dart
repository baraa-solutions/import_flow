import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/current_permissions_provider.dart';
import '../../localization/app_localizations.dart';
import '../../network/api_error.dart';
import '../../theme/app_theme.dart';
import '../app_shimmer_skeleton.dart';
import '../paged_data_table/row_action.dart';

/// Central entity details viewer dialog and side-sheet for ImportFlow ERP.
///
/// Pattern for features:
/// Each feature adds `final xByIdProvider = FutureProvider.autoDispose.family<XModel, int>((ref, id) async => XModel.fromJson((await ref.watch(dioProvider).get('${ApiConstants.x}/$id')).data));`
///
/// - Width ≥ 1200px: renders as a side-sheet anchored to the start edge (560px width, full height).
///   In RTL (Arabic), the sheet opens from the right. In LTR (English), it opens from the left.
/// - Width < 1200px: renders as a centered dialog (max width 720px).
/// - Displays states: Loading (shimmer), 404 ("record not found or deleted"), Error (ApiError.message + Retry), and Data.
/// - Footer actions respect current-user permissions and standard confirmation flows.
class EntityDetailsDialog<T> extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final String? code;
  final Widget? statusBadge;
  final Widget? statusChip;
  final AsyncValue<T>? value;
  final ProviderListenable<AsyncValue<T>>? provider;
  final Widget Function(T data) body;
  final List<RowAction<T>>? footerActions;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  const EntityDetailsDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.code,
    this.statusBadge,
    this.statusChip,
    this.value,
    this.provider,
    required this.body,
    this.footerActions,
    this.onRetry,
    this.onClose,
  }) : assert(
          value != null || provider != null,
          'Either value or provider must be provided to EntityDetailsDialog',
        );

  /// Opens the entity details viewer as a modal dialog or side-sheet.
  static Future<R?> show<T, R>(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? code,
    Widget? statusBadge,
    Widget? statusChip,
    AsyncValue<T>? value,
    ProviderListenable<AsyncValue<T>>? provider,
    required Widget Function(T data) body,
    List<RowAction<T>>? footerActions,
    VoidCallback? onRetry,
    VoidCallback? onClose,
  }) {
    return showDialog<R>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => EntityDetailsDialog<T>(
        title: title,
        subtitle: subtitle,
        code: code,
        statusBadge: statusBadge,
        statusChip: statusChip,
        value: value,
        provider: provider,
        body: body,
        footerActions: footerActions,
        onRetry: onRetry,
        onClose: onClose ?? () => Navigator.of(dialogContext, rootNavigator: true).maybePop(),
      ),
    );
  }

  void _handleClose(BuildContext context) {
    if (onClose != null) {
      onClose!();
    } else {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  bool _isNotFound(Object? error) {
    if (error is DioException) {
      if (error.response?.statusCode == 404) return true;
    }
    final s = error.toString().toLowerCase();
    return s.contains('404') || s.contains('not found') || s.contains('not_found');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final AsyncValue<T> resolvedValue = provider != null ? ref.watch(provider!) : value!;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isWide = screenWidth >= AppTheme.desktopBreakpoint;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheetBorderRadius = isWide
        ? const BorderRadiusDirectional.horizontal(end: Radius.circular(16))
            .resolve(Directionality.of(context))
        : BorderRadius.circular(16);

    Widget sheetContent = Material(
      color: isDark ? AppTheme.surfaceOf(context) : Colors.white,
      elevation: isWide ? 8 : 16,
      borderRadius: sheetBorderRadius,
      clipBehavior: Clip.antiAlias,
      child: SelectionArea(
        child: SizedBox(
        width: isWide ? 560.0 : math.min(screenWidth - 32, 720.0),
        height: isWide ? double.infinity : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: isWide ? double.infinity : screenHeight * 0.9,
          ),
          child: Column(
            mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(context, l),
              Divider(height: 1, thickness: 1, color: AppTheme.borderOf(context)),

              // Content Body (Loading / 404 / Error / Data)
              Expanded(
                child: _buildBody(context, ref, l, resolvedValue),
              ),

              // Footer
              _buildFooter(context, ref, l, resolvedValue),
            ],
          ),
        ),
      ),
    ),
  );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: isWide
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Align(
        alignment: isWide ? AlignmentDirectional.centerStart : AlignmentDirectional.center,
        child: sheetContent,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l) {
    final effectiveSubtitle = code ?? subtitle;
    final effectiveBadge = statusChip ?? statusBadge;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (effectiveBadge != null) ...[
                      const SizedBox(width: 10),
                      effectiveBadge,
                    ],
                  ],
                ),
                if (effectiveSubtitle != null && effectiveSubtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    effectiveSubtitle.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMutedOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            splashRadius: 18,
            tooltip: l.closeBtn,
            color: AppTheme.textMutedOf(context),
            onPressed: () => _handleClose(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    AsyncValue<T> resolvedValue,
  ) {
    // 1. Loading State -> Shimmer Skeleton
    if (resolvedValue.isLoading) {
      return const Padding(
        padding: EdgeInsetsDirectional.all(20),
        child: EntityDetailsShimmerSkeleton(),
      );
    }

    // 2. Error State (404 vs other errors)
    if (resolvedValue.hasError) {
      final error = resolvedValue.error;
      final notFound = _isNotFound(error);

      if (notFound) {
        return Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: AppTheme.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  l.recordNotFoundOrDeleted,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => _handleClose(context),
                  child: Text(l.closeBtn),
                ),
              ],
            ),
          ),
        );
      }

      // Other backend or connection error
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: AppTheme.crimson,
              ),
              const SizedBox(height: 16),
              Text(
                ApiError.message(error, fallback: l.genericErrorMessage),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryOf(context),
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.cobalt),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(l.tableRetry),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 3. Data State -> body widget inside SingleChildScrollView
    if (resolvedValue.hasValue) {
      return SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(20),
        child: body(resolvedValue.value as T),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFooter(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    AsyncValue<T> resolvedValue,
  ) {
    final permissions =
        ref.watch(currentPermissionsProvider).asData?.value ?? const PermissionSet();

    final data = resolvedValue.valueOrNull;

    // Filter permitted footer actions
    final List<RowAction<T>> actionsToRender = [];
    if (data != null && footerActions != null) {
      for (final action in footerActions!) {
        if (action.permission != null && !permissions.can(action.permission!)) {
          continue;
        }
        actionsToRender.add(action);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.surfaceAltOf(context)
            : const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Close button
          OutlinedButton(
            onPressed: () => _handleClose(context),
            child: Text(l.closeBtn),
          ),
          const Spacer(),

          // Permitted actions
          if (data != null)
            for (int i = 0; i < actionsToRender.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _buildActionButton(context, l, actionsToRender[i], data),
            ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    AppLocalizations l,
    RowAction<T> action,
    T data,
  ) {
    final label = action.label?.call(l) ?? _defaultActionLabel(action.kind, l);
    final icon = action.icon ?? _defaultActionIcon(action.kind);

    VoidCallback? onPressed;
    if (action.enabled && action.disabledReason == null) {
      onPressed = () async {
        if (action.confirm) {
          final confirmTitle = action.confirmTitle?.call(l) ?? l.confirmDeleteTitle;
          final confirmMessage = action.confirmMessage?.call(l, data) ??
              l.confirmDeleteMessage('');
          final confirmed = await showConfirmDialog(
            context,
            title: confirmTitle,
            message: confirmMessage,
            isDestructive: action.isDestructive || action.kind == RowActionKind.delete,
          );
          if (!confirmed) return;
        }

        try {
          await action.run(data);
          if (context.mounted && (action.isDestructive || action.kind == RowActionKind.delete)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.deletedSuccessfully),
                backgroundColor: AppTheme.emerald,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ApiError.message(e, fallback: l.operationFailed)),
                backgroundColor: AppTheme.crimson,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      };
    }

    Widget button;
    if (action.kind == RowActionKind.edit) {
      button = FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: action.color ?? AppTheme.orange,
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    } else if (action.kind == RowActionKind.delete) {
      button = FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.crimson,
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    } else {
      button = OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: action.color ?? AppTheme.textPrimaryOf(context),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }

    if (action.disabledReason != null) {
      return Tooltip(
        message: action.disabledReason!,
        child: button,
      );
    }
    return button;
  }

  String _defaultActionLabel(RowActionKind kind, AppLocalizations l) {
    switch (kind) {
      case RowActionKind.view:
        return l.viewDetailsTooltip;
      case RowActionKind.edit:
        return l.editRecord;
      case RowActionKind.clone:
        return l.cloneRowTooltip;
      case RowActionKind.print:
        return l.printTooltip;
      case RowActionKind.history:
        return l.viewActivityLog;
      case RowActionKind.delete:
        return l.deleteTooltip;
      case RowActionKind.custom:
        return '';
    }
  }

  IconData _defaultActionIcon(RowActionKind kind) {
    switch (kind) {
      case RowActionKind.view:
        return Icons.visibility_rounded;
      case RowActionKind.edit:
        return Icons.edit_rounded;
      case RowActionKind.clone:
        return Icons.copy_all_rounded;
      case RowActionKind.print:
        return Icons.print_rounded;
      case RowActionKind.history:
        return Icons.history_rounded;
      case RowActionKind.delete:
        return Icons.delete_outline_rounded;
      case RowActionKind.custom:
        return Icons.more_horiz_rounded;
    }
  }
}

/// Shimmer placeholder skeleton for the entity details dialog.
class EntityDetailsShimmerSkeleton extends StatelessWidget {
  const EntityDetailsShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: AppTheme.borderOf(context));

    return AppShimmerEffect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1 Shimmer
          Container(
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShimmerBox(width: 130, height: 16, borderRadius: 4),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(width: double.infinity, height: 36, borderRadius: 4)),
                    SizedBox(width: 16),
                    Expanded(child: ShimmerBox(width: double.infinity, height: 36, borderRadius: 4)),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(width: double.infinity, height: 36, borderRadius: 4)),
                    SizedBox(width: 16),
                    Expanded(child: ShimmerBox(width: double.infinity, height: 36, borderRadius: 4)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Section 2 Shimmer
          Container(
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShimmerBox(width: 110, height: 16, borderRadius: 4),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(width: double.infinity, height: 36, borderRadius: 4)),
                    SizedBox(width: 16),
                    Expanded(child: ShimmerBox(width: double.infinity, height: 36, borderRadius: 4)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
