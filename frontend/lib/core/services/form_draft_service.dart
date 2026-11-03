import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 💾 Centralized Persistent Auto-Save & Draft Recovery Service for ImportFlow ERP.
///
/// Enables long-form screens (POs, Customs Declarations, Quotations, Consultations)
/// to transparently preserve work-in-progress state in client local storage, protecting
/// operators against power loss, unexpected desktop app closes, or accidental navigation.
class FormDraftService {
  static const String _keyPrefix = 'form_draft_';

  static String _formatKey(String scope, dynamic entityId) {
    return '$_keyPrefix${scope}_${entityId ?? "new"}';
  }

  /// Saves a snapshot of in-progress form data to local persistent storage.
  static Future<void> saveDraft({
    required String scope,
    required dynamic entityId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = Map<String, dynamic>.from(data);
      payload['saved_at'] = DateTime.now().toIso8601String();
      payload['form_scope'] = scope;
      payload['entity_id'] = entityId?.toString() ?? 'new';
      final jsonStr = jsonEncode(payload);
      await prefs.setString(_formatKey(scope, entityId), jsonStr);
    } catch (_) {
      // Non-blocking fallback: local persistence failure must never crash the UI
    }
  }

  /// Retrieves a saved draft for the given form scope and entity ID if one exists.
  static Future<Map<String, dynamic>?> loadDraft({
    required String scope,
    required dynamic entityId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_formatKey(scope, entityId));
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Clears the saved draft after successful submission or explicit user discard.
  static Future<void> clearDraft({
    required String scope,
    required dynamic entityId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_formatKey(scope, entityId));
    } catch (_) {
      // Non-blocking fallback
    }
  }

  /// Checks whether a draft exists for the given form scope and entity ID.
  static Future<bool> hasDraft({
    required String scope,
    required dynamic entityId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_formatKey(scope, entityId));
    } catch (_) {
      return false;
    }
  }
}
