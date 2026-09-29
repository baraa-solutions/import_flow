import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// Default texts that the app writes to the backend (default titles, names,
/// notes) come from here, never from `context.l10n`.
///
/// Stored values must not depend on the UI language
/// (docs/plans/single-language-storage-plan.md, tier T2): an Arabic session and
/// an English session save the same English default. The user can still type
/// any text; only the prefilled/system default is fixed.
const AppLocalizations storedText = AppLocalizationsEn();
