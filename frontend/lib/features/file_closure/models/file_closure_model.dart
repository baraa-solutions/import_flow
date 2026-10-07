import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/system_messages/system_message_renderer.dart';

class ClosureChecklistModel {
  final bool docsVerified;
  final bool customsCleared;
  final bool warehouseReceived;
  final bool landedCostSettled;
  final bool tasksClosed;
  final bool? dossierExported;
  final bool? emptyContainersReturned;

  ClosureChecklistModel({
    this.docsVerified = false,
    this.customsCleared = false,
    this.warehouseReceived = false,
    this.landedCostSettled = false,
    this.tasksClosed = false,
    this.dossierExported,
    this.emptyContainersReturned,
  });

  bool get isAllCompleted =>
      docsVerified &&
      customsCleared &&
      warehouseReceived &&
      landedCostSettled &&
      tasksClosed &&
      (dossierExported ?? true) &&
      (emptyContainersReturned ?? true);

  factory ClosureChecklistModel.fromJson(Map<String, dynamic> json) {
    return ClosureChecklistModel(
      // A key the server did not send is NOT passed (plan FE-07).
      docsVerified: json['docs_verified'] == true,
      customsCleared: json['customs_cleared'] == true,
      warehouseReceived: json['warehouse_received'] == true,
      landedCostSettled: json['landed_cost_settled'] == true,
      tasksClosed: json['tasks_closed'] == true,
      dossierExported: json['dossier_exported'] as bool?,
      // `closure_readiness` used `eir_returned` before the server added this key.
      emptyContainersReturned: (json['empty_containers_returned'] ?? json['eir_returned']) as bool?,
    );
  }

  /// The checklist as evaluated by the server (precheck `checklist_status`).
  /// Missing keys count as not passed.
  factory ClosureChecklistModel.fromStatusMap(Map<String, bool> status) {
    return ClosureChecklistModel(
      docsVerified: status['docs_verified'] ?? false,
      customsCleared: status['customs_cleared'] ?? false,
      warehouseReceived: status['warehouse_received'] ?? false,
      landedCostSettled: status['landed_cost_settled'] ?? false,
      tasksClosed: status['tasks_closed'] ?? false,
      dossierExported: status['dossier_exported'],
      emptyContainersReturned: status['empty_containers_returned'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'docs_verified': docsVerified,
      'customs_cleared': customsCleared,
      'warehouse_received': warehouseReceived,
      'landed_cost_settled': landedCostSettled,
      'tasks_closed': tasksClosed,
    };
    if (dossierExported != null) {
      map['dossier_exported'] = dossierExported;
    }
    if (emptyContainersReturned != null) {
      map['empty_containers_returned'] = emptyContainersReturned;
    }
    return map;
  }
}

class ImportFileClosureModel {
  final int closureId;
  final String closureCode;
  final int importFileId;
  final ClosureChecklistModel closureChecklist;
  final String auditorName;
  final String archiveLocation;
  final String? archivalNotes;
  final String status;
  final bool isActive;
  final String closedAt;
  final String createdAt;
  final String updatedAt;

  ImportFileClosureModel({
    required this.closureId,
    required this.closureCode,
    required this.importFileId,
    required this.closureChecklist,
    this.auditorName = '',
    this.archiveLocation = '',
    this.archivalNotes,
    this.status = 'Closed',
    this.isActive = true,
    required this.closedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFullyVerified => closureChecklist.isAllCompleted && status == 'Closed';

  factory ImportFileClosureModel.fromJson(Map<String, dynamic> json) {
    return ImportFileClosureModel(
      closureId: json['closure_id'],
      closureCode: json['closure_code'] ?? '',
      importFileId: json['import_file_id'],
      closureChecklist: ClosureChecklistModel.fromJson(json['closure_checklist'] ?? {}),
      auditorName: json['auditor_name'] ?? '',
      archiveLocation: json['archive_location'] ?? '',
      archivalNotes: json['archival_notes'],
      status: json['status'] ?? 'Closed',
      isActive: json['is_active'] ?? true,
      closedAt: json['closed_at'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'closure_id': closureId,
      'closure_code': closureCode,
      'import_file_id': importFileId,
      'closure_checklist': closureChecklist.toJson(),
      'auditor_name': auditorName,
      'archive_location': archiveLocation,
      'archival_notes': archivalNotes,
      'status': status,
    };
  }
}

/// A coded closure message (`blocking_messages` / `warning_messages` item). The text is
/// rendered in the user's language from the code; [fallback] is the server's own text.
class ClosureMessage {
  final String? code;
  final Map<String, dynamic>? params;
  final String fallback;

  const ClosureMessage({this.code, this.params, this.fallback = ''});

  factory ClosureMessage.fromJson(Object? raw) {
    if (raw is Map) {
      return ClosureMessage(
        code: (raw['msg_code'] ?? raw['code'])?.toString(),
        params: SystemMessageRenderer.parseParams(raw['msg_params'] ?? raw['params']),
        fallback: (raw['text'] ?? raw['message'] ?? '').toString(),
      );
    }
    return ClosureMessage(fallback: raw?.toString() ?? '');
  }

  String render(AppLocalizations l10n) {
    for (final part in const [SystemMessagePart.body, SystemMessagePart.note]) {
      final text = SystemMessageRenderer.tryRender(code: code, params: params, part: part, l10n: l10n);
      if (text != null) return text;
    }
    return fallback;
  }
}

class ClosurePrecheckResponseModel {
  final int importFileId;
  final String importFileCode;
  final String companyName;
  final String supplierName;
  final bool canClose;
  final List<String> blockingReasons;
  final List<String> warnings;
  final List<ClosureMessage> blockingMessages;
  final List<ClosureMessage> warningMessages;
  final Map<String, bool> checklistStatus;
  final double actualLandedCostEgp;
  final double? actualMarkupFactor;
  final String? dossierExportedAt;
  final String? dossierExportedBy;
  final String? emptyContainersReturnedAt;
  final String certificateCodePreview;

  ClosurePrecheckResponseModel({
    required this.importFileId,
    required this.importFileCode,
    required this.companyName,
    required this.supplierName,
    required this.canClose,
    this.blockingReasons = const [],
    this.warnings = const [],
    this.blockingMessages = const [],
    this.warningMessages = const [],
    this.checklistStatus = const {},
    this.actualLandedCostEgp = 0.0,
    this.actualMarkupFactor,
    this.dossierExportedAt,
    this.dossierExportedBy,
    this.emptyContainersReturnedAt,
    required this.certificateCodePreview,
  });

  /// Blocking reasons for display: coded messages when the server sent them, else the legacy text.
  List<String> blockingTexts(AppLocalizations l10n) =>
      blockingMessages.isNotEmpty ? blockingMessages.map((m) => m.render(l10n)).toList() : blockingReasons;

  List<String> warningTexts(AppLocalizations l10n) =>
      warningMessages.isNotEmpty ? warningMessages.map((m) => m.render(l10n)).toList() : warnings;

  factory ClosurePrecheckResponseModel.fromJson(Map<String, dynamic> json) {
    return ClosurePrecheckResponseModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      companyName: json['company_name'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      canClose: json['can_close'] ?? false,
      blockingReasons: (json['blocking_reasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      blockingMessages: (json['blocking_messages'] as List<dynamic>?)?.map(ClosureMessage.fromJson).toList() ?? const [],
      warningMessages: (json['warning_messages'] as List<dynamic>?)?.map(ClosureMessage.fromJson).toList() ?? const [],
      checklistStatus: (json['checklist_status'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v == true)) ??
          const {},
      actualLandedCostEgp:
          (json['actual_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      actualMarkupFactor:
          (json['actual_markup_factor'] as num?)?.toDouble(),
      dossierExportedAt: json['dossier_exported_at']?.toString(),
      dossierExportedBy: json['dossier_exported_by']?.toString(),
      emptyContainersReturnedAt:
          json['empty_containers_returned_at']?.toString(),
      certificateCodePreview: json['certificate_code_preview'] ?? '',
    );
  }
}

class OfficialClosureCertificateResponseModel {
  final bool success;
  final int closureId;
  final String closureCode;
  final int importFileId;
  final String importFileCode;
  final String companyName;
  final String supplierName;
  final String auditorName;
  final String archiveLocation;
  final String? archivalNotes;
  final String closedAt;
  final String status;
  final double progressPercent;
  final String currentStage;
  final String currentModule;
  final String nextAction;
  final String message;

  OfficialClosureCertificateResponseModel({
    required this.success,
    required this.closureId,
    required this.closureCode,
    required this.importFileId,
    required this.importFileCode,
    required this.companyName,
    required this.supplierName,
    required this.auditorName,
    required this.archiveLocation,
    this.archivalNotes,
    required this.closedAt,
    required this.status,
    required this.progressPercent,
    required this.currentStage,
    required this.currentModule,
    required this.nextAction,
    required this.message,
  });

  factory OfficialClosureCertificateResponseModel.fromJson(Map<String, dynamic> json) {
    return OfficialClosureCertificateResponseModel(
      success: json['success'] ?? false,
      closureId: json['closure_id'] ?? 0,
      closureCode: json['closure_code'] ?? '',
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      companyName: json['company_name'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      auditorName: json['auditor_name'] ?? '',
      archiveLocation: json['archive_location'] ?? '',
      archivalNotes: json['archival_notes']?.toString(),
      closedAt: json['closed_at'] ?? '',
      status: json['status'] ?? 'Closed',
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 100.0,
      currentStage: json['current_stage'] ?? '',
      currentModule: json['current_module'] ?? '',
      nextAction: json['next_action'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

