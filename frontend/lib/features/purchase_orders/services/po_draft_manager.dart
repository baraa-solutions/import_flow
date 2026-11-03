import '../../../core/services/form_draft_service.dart';

/// Manages local autosave drafts for Purchase Order form sessions.
/// Enables crash/power-loss recovery without committing partial state to the backend database.
/// Thin facade delegating to the centralized [FormDraftService].
class PODraftManager {
  static const String _scope = 'po_form';

  /// Saves a snapshot of in-progress PO form data to local persistent storage.
  static Future<void> saveDraft({
    required dynamic poId,
    required Map<String, dynamic> draftData,
  }) =>
      FormDraftService.saveDraft(
        scope: _scope,
        entityId: poId,
        data: draftData,
      );

  /// Retrieves the saved draft for the given PO session if one exists.
  static Future<Map<String, dynamic>?> loadDraft(dynamic poId) =>
      FormDraftService.loadDraft(scope: _scope, entityId: poId);

  /// Clears the saved draft after successful save or explicit discard.
  static Future<void> clearDraft(dynamic poId) =>
      FormDraftService.clearDraft(scope: _scope, entityId: poId);

  /// Checks if a draft exists for the given PO session.
  static Future<bool> hasDraft(dynamic poId) =>
      FormDraftService.hasDraft(scope: _scope, entityId: poId);
}
