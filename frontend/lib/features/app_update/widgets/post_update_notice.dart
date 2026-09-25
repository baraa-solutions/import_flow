import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/update_models.dart';
import '../providers/app_update_providers.dart';
import 'update_rollback_dialog.dart';

/// Invisible listener placed on the home screen: reads `GET /last-result` on
/// mount and shows, once per result, "updated to vX" (success) or the failure
/// notice with a rollback shortcut for administrators (failed).
class PostUpdateNotice extends ConsumerStatefulWidget {
  const PostUpdateNotice({super.key});

  @override
  ConsumerState<PostUpdateNotice> createState() => _PostUpdateNoticeState();
}

class _PostUpdateNoticeState extends ConsumerState<PostUpdateNotice> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // Re-fetch only a result cached before this mount; otherwise the listen in
    // build creates the provider and fetches it once.
    if (ref.exists(lastUpdateResultProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(lastUpdateResultProvider);
      });
    }
  }

  Future<void> _handle(UpdateLastResult result) async {
    if (_handled || result.result == UpdateResultKind.none) return;
    _handled = true;
    final store = ref.read(updateNoticeStoreProvider);
    final key = result.noticeKey;
    if (await store.lastSeen() == key) return;
    await store.markSeen(key);
    if (!mounted) return;

    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final isRollback = result.isRollback;
    if (result.result == UpdateResultKind.success) {
      messenger.showSnackBar(SnackBar(
        content: Text(isRollback
            ? l.updateRollbackSucceeded(result.toVersion ?? '')
            : l.updateSucceeded(result.toVersion ?? '')),
        backgroundColor: AppTheme.emerald,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
      return;
    }
    if (isRollback) {
      // A failed rollback never offers another rollback.
      final detail = result.detail;
      messenger.showSnackBar(SnackBar(
        content: Text(detail == null ? l.updateRollbackFailed : '${l.updateRollbackFailed}: $detail'),
        backgroundColor: AppTheme.crimson,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 12),
      ));
      return;
    }
    final canRollback = ref.read(canInstallUpdatesProvider);
    messenger.showSnackBar(SnackBar(
      content: Text('${l.updateFailed}. ${l.updateFailedRollbackHint}'),
      backgroundColor: AppTheme.crimson,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 12),
      action: canRollback
          ? SnackBarAction(
              label: l.updateRollback,
              textColor: AppTheme.cloudWhite,
              onPressed: () {
                if (mounted) showUpdateRollbackDialog(context);
              },
            )
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UpdateLastResult>>(lastUpdateResultProvider, (_, next) {
      final value = next.valueOrNull;
      if (value != null) _handle(value);
    });
    return const SizedBox.shrink();
  }
}
