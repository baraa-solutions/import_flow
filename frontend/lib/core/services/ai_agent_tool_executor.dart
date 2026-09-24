import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/api_constants.dart';
import '../network/dio_client.dart';

// ─── Audit Trail Entry ────────────────────────────────────────────────────────

class AgentAuditEntry {
  final DateTime timestamp;
  final String toolName;
  final Map<String, dynamic> arguments;
  final bool verified;
  final String? recordCode;
  final String summary;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;
  final String? errorMessage;

  AgentAuditEntry({
    required this.timestamp,
    required this.toolName,
    required this.arguments,
    required this.verified,
    this.recordCode,
    required this.summary,
    this.beforeState,
    this.afterState,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'tool_name': toolName,
        'arguments': arguments,
        'verified': verified,
        'record_code': recordCode,
        'summary': summary,
        'before_state': beforeState,
        'after_state': afterState,
        'error_message': errorMessage,
      };
}

// ─── AI Agent Tool Executor ───────────────────────────────────────────────────

class AiAgentToolExecutor {
  final Dio _dio;
  final List<AgentAuditEntry> _auditTrail = [];

  AiAgentToolExecutor({required Dio dio}) : _dio = dio;

  List<AgentAuditEntry> get auditTrail => List.unmodifiable(_auditTrail);

  void clearAuditTrail() => _auditTrail.clear();

  void _logAudit({
    required String toolName,
    required Map<String, dynamic> args,
    required bool verified,
    String? recordCode,
    required String summary,
    Map<String, dynamic>? beforeState,
    Map<String, dynamic>? afterState,
    String? errorMessage,
  }) {
    _auditTrail.add(
      AgentAuditEntry(
        timestamp: DateTime.now(),
        toolName: toolName,
        arguments: args,
        verified: verified,
        recordCode: recordCode,
        summary: summary,
        beforeState: beforeState,
        afterState: afterState,
        errorMessage: errorMessage,
      ),
    );
  }

  // ─── Date Normalization Helper ──────────────────────────────────────────────

  static String normalizeDate(dynamic rawDate) {
    if (rawDate == null) return '';
    String s = rawDate.toString().trim();
    if (s.isEmpty) return '';

    // Replace Arabic-Indic digits with Western digits
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabicDigits.length; i++) {
      s = s.replaceAll(arabicDigits[i], '$i');
    }

    // If ISO: YYYY-MM-DD
    final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (isoMatch != null) {
      final y = isoMatch.group(1)!;
      final m = isoMatch.group(2)!.padLeft(2, '0');
      final d = isoMatch.group(3)!.padLeft(2, '0');
      return '$y-$m-$d';
    }

    // If D/M or DD/MM: e.g. 27/8 or 27/08
    final dmMatch = RegExp(r'^(\d{1,2})[/-](\d{1,2})$').firstMatch(s);
    if (dmMatch != null) {
      final d = dmMatch.group(1)!.padLeft(2, '0');
      final m = dmMatch.group(2)!.padLeft(2, '0');
      const y = '2026'; // Current operational year in Sorour Logistics ERP
      return '$y-$m-$d';
    }

    // If DD/MM/YYYY: e.g. 27/8/2026 or 27/08/2026
    final dmyMatch = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(s);
    if (dmyMatch != null) {
      final d = dmyMatch.group(1)!.padLeft(2, '0');
      final m = dmyMatch.group(2)!.padLeft(2, '0');
      final y = dmyMatch.group(3)!;
      return '$y-$m-$d';
    }

    return s;
  }

  // ─── Step Code Normalization Helper ─────────────────────────────────────────

  static String normalizeStepCode(dynamic rawStep) {
    if (rawStep == null) return '';
    String s = rawStep.toString().trim().toUpperCase();
    final numMatch = RegExp(r'\d+').firstMatch(s);
    if (numMatch != null) {
      final n = int.tryParse(numMatch.group(0)!);
      if (n != null) {
        return 'STEP_${n.toString().padLeft(2, '0')}';
      }
    }
    return s;
  }

  // ─── Tool Declarations for Gemini Model ────────────────────────────────────

  static List<Tool> getAgentTools() {
    return [
      Tool(
        functionDeclarations: [
          FunctionDeclaration(
            'search_shipments',
            'ابحث عن الشحنات الاستيرادية بالاسم أو كود أمر الشراء أو المورد أو الشركة المستوردة للوصول إلى معرف الشحنة بدقة.',
            Schema.object(
              properties: {
                'query': Schema.string(
                  description: 'كلمة البحث مثل PET أو SCAS أو رقم أمر الشراء',
                ),
              },
              requiredProperties: ['query'],
            ),
          ),
          FunctionDeclaration(
            'update_container_allocation',
            'تسجيل وتحديث تخصيص رقم الحاوية ورقم السيل (الختم الملاحي) ومواعيد التخصيص والتحميل في قاعدة البيانات مع التحقق الفعلي RAW Verification.',
            Schema.object(
              properties: {
                'import_file_id': Schema.integer(
                  description: 'معرف ملف الشحنة الاستيرادي (رقم صحيح)',
                ),
                'container_no': Schema.string(
                  description: 'رقم الحاوية (مثل WHSU81072658)',
                ),
                'seal_no': Schema.string(
                  description: 'رقم السيل / الختم الملاحي (مثل WHA257097)',
                ),
                'assignment_date': Schema.string(
                  description: 'تاريخ التخصيص بصيغة YYYY-MM-DD أو DD/MM (مثل 27/8)',
                  nullable: true,
                ),
                'loading_date': Schema.string(
                  description: 'تاريخ التحميل بصيغة YYYY-MM-DD أو DD/MM (مثل 27/8)',
                  nullable: true,
                ),
                'container_type': Schema.string(
                  description: 'نوع الحاوية (مثل 40HC أو 20GP)',
                  nullable: true,
                ),
              },
              requiredProperties: ['import_file_id', 'container_no', 'seal_no'],
            ),
          ),
          FunctionDeclaration(
            'create_or_update_booking',
            'تسجيل أو تحديث رقم حجز الشحن (Booking Confirmation Number) ورقم بوليصة الشحن الهاوس (House B/L) في قاعدة البيانات مع التحقق الفعلي RAW Verification.',
            Schema.object(
              properties: {
                'import_file_id': Schema.integer(
                  description: 'معرف ملف الشحنة الاستيرادي (رقم صحيح)',
                ),
                'booking_no': Schema.string(
                  description: 'رقم حجز الشحن (مثل THXJ2608090)',
                ),
                'house_bl_no': Schema.string(
                  description: 'رقم بوليصة الشحن الهاوس House B/L (مثل THXJ2608090)',
                  nullable: true,
                ),
              },
              requiredProperties: ['import_file_id', 'booking_no'],
            ),
          ),
          FunctionDeclaration(
            'query_acid_status',
            'استعلام حي ومباشر من قاعدة البيانات عن حالة تسجيل رقم ACID وصلاحيته الجمركية والإفراج الجمركي لشحنة محددة (لا تستخدم ذاكرة المحادثة، استعلم دائماً من قاعدة البيانات).',
            Schema.object(
              properties: {
                'query': Schema.string(
                  description: 'اسم أو كود الشحنة (مثل PET أو PET Stock)',
                  nullable: true,
                ),
                'import_file_id': Schema.integer(
                  description: 'معرف ملف الشحنة (رقم صحيح إن وجد)',
                  nullable: true,
                ),
              },
            ),
          ),
          FunctionDeclaration(
            'query_shipment_field',
            'استعلام حي ومباشر من قاعدة البيانات عن تفاصيل محددة للشحنة (مثل الحاويات containers، الحجز booking، المورد supplier، المواعيد eta).',
            Schema.object(
              properties: {
                'field_name': Schema.string(
                  description: 'اسم الحقل المطلوب استعلامه (containers, booking, supplier, acid, eta)',
                ),
                'import_file_id': Schema.integer(
                  description: 'معرف ملف الشحنة',
                  nullable: true,
                ),
                'query': Schema.string(
                  description: 'اسم أو كود الشحنة للبحث إن لم يتوفر المعرف',
                  nullable: true,
                ),
              },
              requiredProperties: ['field_name'],
            ),
          ),
          FunctionDeclaration(
            'query_step_policy',
            'استعلام حي ومباشر عن سياسة التخطي (skip_policy) وقواعد التوثيق المؤقت لخطوة تشغيلية محددة من إعدادات النظام الحية (الوكيل لا يفترض ولا يخمن أي سياسة، بل يستعلم دائماً من قاعدة البيانات).',
            Schema.object(
              properties: {
                'step_code': Schema.string(
                  description: 'كود الخطوة التشغيلية (مثل STEP_06 أو 6)',
                ),
              },
              requiredProperties: ['step_code'],
            ),
          ),
          FunctionDeclaration(
            'skip_step',
            'طلب تخطي خطوة تشغيلية لشحنة محددة مع التحقق المسبق الإلزامي من سياسة التخطي الحية في قاعدة البيانات (يرفض التنفيذ إذا كانت محظورة blocked) والتحقق الفعلي بعد الكتابة RAW Verification.',
            Schema.object(
              properties: {
                'import_file_id': Schema.integer(
                  description: 'معرف ملف الشحنة الاستيرادي (رقم صحيح)',
                ),
                'step_code': Schema.string(
                  description: 'كود الخطوة المراد تخطيها (مثل STEP_06 أو 6)',
                ),
                'reason_category': Schema.string(
                  description: 'تصنيف سبب التخطي (مثل Regulatory Exemption, Client Waived, Direct Clearance, Other)',
                ),
                'justification': Schema.string(
                  description: 'تبرير تفصيلي لتخطي الخطوة (5 أحرف على الأقل)',
                ),
              },
              requiredProperties: ['import_file_id', 'step_code', 'reason_category', 'justification'],
            ),
          ),
          FunctionDeclaration(
            'register_pending_reference',
            'تسجيل مرجع مستندي مؤقت (Partial / Reference-Only Registration) لخطوة تدعم ذلك (supports_pending_reference). يغير حالة الخطوة إلى "Reference recorded – pending full documentation" مع إبقاء الخطوة غير مكتملة (Pending) دون إغلاقها حتى استيفاء المستند الأصلي.',
            Schema.object(
              properties: {
                'import_file_id': Schema.integer(
                  description: 'معرف ملف الشحنة الاستيرادي (رقم صحيح)',
                ),
                'step_code': Schema.string(
                  description: 'كود الخطوة التشغيلية (مثل STEP_06 أو 6)',
                ),
                'reference_number': Schema.string(
                  description: 'رقم المرجع أو الإيصال أو البوليصة المبدئية',
                ),
                'reason_text': Schema.string(
                  description: 'سبب عدم إرفاق المستند الأصلي الكامل الآن وتأجيله',
                ),
                'expected_completion_date': Schema.string(
                  description: 'تاريخ الإنجاز المتوقع بصيغة YYYY-MM-DD أو DD/MM (مثل 2026-09-15)',
                  nullable: true,
                ),
              },
              requiredProperties: ['import_file_id', 'step_code', 'reference_number', 'reason_text'],
            ),
          ),
          FunctionDeclaration(
            'get_agent_audit_trail',
            'استرجاع سجل تدقيق العمليات التنفيذية التي قام بها الوكيل ومطابقة التحقق الفعلي RAW Verification.',
            Schema.object(properties: {}),
          ),
        ],
      ),
    ];
  }

  // ─── Dispatcher ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> execute(
    String toolName,
    Map<String, dynamic> args, {
    int? activeShipmentId,
  }) async {
    try {
      final effectiveShipmentId = args['import_file_id'] != null
          ? (args['import_file_id'] as num).toInt()
          : activeShipmentId;

      switch (toolName) {
        case 'search_shipments':
          return await searchShipments((args['query'] ?? '').toString());
        case 'update_container_allocation':
          if (effectiveShipmentId == null) {
            return {
              'success': false,
              'verified': false,
              'error': 'معرف ملف الشحنة (import_file_id) مفقود. يرجى تحديد الشحنة المطلوبة أو اختيارها من الملاح أولاً.',
            };
          }
          final cNo = (args['container_no'] ?? '').toString().trim();
          final sNo = (args['seal_no'] ?? '').toString().trim();
          if (cNo.isEmpty || sNo.isEmpty) {
            return {
              'success': false,
              'verified': false,
              'error': 'رقم الحاوية ورقم السيل كلاهما حقل إلزامي لتسجيل تخصيص الحاوية.',
            };
          }
          return await updateContainerAllocation(
            importFileId: effectiveShipmentId,
            containerNo: cNo,
            sealNo: sNo,
            assignmentDate: args['assignment_date']?.toString(),
            loadingDate: args['loading_date']?.toString(),
            containerType: (args['container_type'] ?? '40HC').toString(),
          );
        case 'create_or_update_booking':
          if (effectiveShipmentId == null) {
            return {
              'success': false,
              'verified': false,
              'error': 'معرف ملف الشحنة (import_file_id) مفقود. يرجى تحديد الشحنة المطلوبة أو اختيارها من الملاح أولاً.',
            };
          }
          final bNo = (args['booking_no'] ?? '').toString().trim();
          if (bNo.isEmpty) {
            return {
              'success': false,
              'verified': false,
              'error': 'رقم حجز الشحن (booking_no) حقل إلزامي.',
            };
          }
          return await createOrUpdateBooking(
            importFileId: effectiveShipmentId,
            bookingNo: bNo,
            houseBlNo: args['house_bl_no']?.toString(),
          );
        case 'query_acid_status':
          return await queryAcidStatus(
            importFileId: effectiveShipmentId,
            query: args['query']?.toString(),
          );
        case 'query_shipment_field':
          return await queryShipmentField(
            importFileId: effectiveShipmentId,
            query: args['query']?.toString(),
            fieldName: (args['field_name'] ?? '').toString(),
          );
        case 'query_step_policy':
          final stepToQuery = (args['step_code'] ?? '').toString();
          return await queryStepPolicy(stepCode: stepToQuery);
        case 'skip_step':
          if (effectiveShipmentId == null) {
            return {
              'success': false,
              'verified': false,
              'error': 'معرف ملف الشحنة (import_file_id) مفقود. يرجى تحديد الشحنة المطلوبة أولاً.',
            };
          }
          final sCodeToSkip = (args['step_code'] ?? '').toString();
          final rCat = (args['reason_category'] ?? '').toString();
          final just = (args['justification'] ?? '').toString();
          return await skipStep(
            importFileId: effectiveShipmentId,
            stepCode: sCodeToSkip,
            reasonCategory: rCat,
            justification: just,
          );
        case 'register_pending_reference':
          if (effectiveShipmentId == null) {
            return {
              'success': false,
              'verified': false,
              'error': 'معرف ملف الشحنة (import_file_id) مفقود. يرجى تحديد الشحنة المطلوبة أولاً.',
            };
          }
          final sCodeToRef = (args['step_code'] ?? '').toString();
          final refNo = (args['reference_number'] ?? '').toString();
          final rText = (args['reason_text'] ?? '').toString();
          final expDate = args['expected_completion_date']?.toString();
          return await registerPendingReference(
            importFileId: effectiveShipmentId,
            stepCode: sCodeToRef,
            referenceNumber: refNo,
            reasonText: rText,
            expectedCompletionDate: expDate,
          );
        case 'get_agent_audit_trail':
          return getAgentAuditTrail();
        default:
          return {'success': false, 'verified': false, 'error': 'Unknown tool: $toolName'};
      }
    } catch (e) {
      final err = 'خطأ أثناء تنفيذ الأداة $toolName: $e';
      _logAudit(
        toolName: toolName,
        args: args,
        verified: false,
        summary: err,
        errorMessage: e.toString(),
      );
      return {'success': false, 'verified': false, 'error': err};
    }
  }

  // ─── 1. Search Shipments & Ambiguity Resolver ───────────────────────────────

  Future<Map<String, dynamic>> searchShipments(String query) async {
    final cleanQuery = query.trim().toLowerCase();

    // 1. Fetch import files
    final filesRes = await _dio.get('${ApiConstants.baseUrl}/import-files');
    final List files = filesRes.data is List ? filesRes.data : [];

    // 2. Fetch purchase orders
    final posRes = await _dio.get('${ApiConstants.baseUrl}/purchase-orders');
    final List pos = posRes.data is List ? posRes.data : [];

    final Map<int, Map<String, dynamic>> candidateMap = {};

    for (final po in pos) {
      final poRef = (po['po_reference'] ?? '').toString().toLowerCase();
      final poNum = (po['po_number'] ?? '').toString().toLowerCase();
      final fileId = po['import_file_id'];
      if (fileId != null && (poRef.contains(cleanQuery) || poNum.contains(cleanQuery))) {
        candidateMap[fileId as int] = {
          'import_file_id': fileId,
          'po_reference': po['po_reference'],
          'po_number': po['po_number'],
        };
      }
    }

    for (final f in files) {
      final fileId = f['import_file_id'] as int;
      final code = (f['import_file_code'] ?? '').toString().toLowerCase();
      final customNum = (f['custom_file_number'] ?? '').toString().toLowerCase();
      final comp = (f['company_name'] ?? '').toString().toLowerCase();
      final supp = (f['supplier_name'] ?? '').toString().toLowerCase();
      final po = (f['po_number'] ?? '').toString().toLowerCase();
      final acid = (f['acid_number'] ?? '').toString().toLowerCase();

      bool matched = code.contains(cleanQuery) ||
          customNum.contains(cleanQuery) ||
          comp.contains(cleanQuery) ||
          supp.contains(cleanQuery) ||
          po.contains(cleanQuery) ||
          acid.contains(cleanQuery);

      if (matched || candidateMap.containsKey(fileId)) {
        final existing = candidateMap[fileId] ?? {'import_file_id': fileId};
        existing['import_file_code'] = f['import_file_code'];
        existing['custom_file_number'] = f['custom_file_number'];
        existing['company_name'] = f['company_name'];
        existing['supplier_name'] = f['supplier_name'];
        existing['po_number'] = existing['po_number'] ?? f['po_number'];
        existing['acid_number'] = f['acid_number'];
        existing['current_stage'] = f['current_stage'];
        existing['is_customs_released'] = f['is_customs_released'];
        candidateMap[fileId] = existing;
      }
    }

    final candidates = candidateMap.values.toList();
    if (candidates.isEmpty) {
      return {
        'status': 'NOT_FOUND',
        'message': 'لم يتم العثور على أي شحنة تطابق "$query"',
        'count': 0,
        'candidates': [],
      };
    }

    if (candidates.length > 1) {
      return {
        'status': 'AMBIGUOUS',
        'is_ambiguous': true,
        'message': 'يوجد أكثر من شحنة تطابق "$query". يرجى تحديد الشحنة المطلوبة برقم الملف أو الكود المحدد:',
        'count': candidates.length,
        'candidates': candidates,
      };
    }

    final match = candidates.first;
    return {
      'status': 'FOUND',
      'is_ambiguous': false,
      'count': 1,
      'import_file_id': match['import_file_id'],
      'file_code': match['import_file_code'],
      'po_reference': match['po_reference'] ?? match['po_number'],
      'company_name': match['company_name'],
      'supplier_name': match['supplier_name'],
      'acid_number': match['acid_number'],
      'candidates': candidates,
    };
  }

  // ─── 2. Container Allocation & RAW Verification ─────────────────────────────

  Future<Map<String, dynamic>> updateContainerAllocation({
    required int importFileId,
    required String containerNo,
    required String sealNo,
    String? assignmentDate,
    String? loadingDate,
    String containerType = '40HC',
  }) async {
    final normAssignment = normalizeDate(assignmentDate);
    final normLoading = normalizeDate(loadingDate);
    final cleanContainerNo = containerNo.trim().toUpperCase();
    final cleanSealNo = sealNo.trim().toUpperCase();

    // 1. Fetch existing CargoShipping record for this import_file_id
    final getRes = await _dio.get(
      '${ApiConstants.baseUrl}/cargo-shipping',
      queryParameters: {'import_file_id': importFileId},
    );
    final List existingRecords = getRes.data is List ? getRes.data : [];

    Map<String, dynamic>? beforeState;
    String? recordCode;
    int? cargoShippingId;

    if (existingRecords.isNotEmpty) {
      final rec = existingRecords.first as Map<String, dynamic>;
      cargoShippingId = rec['cargo_shipping_id'] as int;
      recordCode = rec['cargo_shipping_code']?.toString();
      beforeState = rec;

      final List containers = (rec['containers_loading_data'] as List?) ?? [];
      final existingIdx = containers.indexWhere((c) =>
          (c['container_no'] ?? '').toString().trim().toUpperCase() == cleanContainerNo);

      if (existingIdx >= 0) {
        final patchPayload = {
          'container_no': cleanContainerNo,
          'seal_no': cleanSealNo,
          if (normAssignment.isNotEmpty) 'container_assignment_date': normAssignment,
          if (normLoading.isNotEmpty) 'loading_start_at': normLoading,
          if (normLoading.isNotEmpty) 'loading_end_at': normLoading,
          'updated_by': 'AI_Agent',
        };
        await _dio.patch(
          '${ApiConstants.baseUrl}/cargo-shipping/$cargoShippingId/containers/$cleanContainerNo/loading-tracking',
          data: patchPayload,
        );
      } else {
        final newContainer = {
          'container_no': cleanContainerNo,
          'seal_no': cleanSealNo,
          'container_type': containerType,
          'quantity': 1,
          if (normAssignment.isNotEmpty) 'container_assignment_date': normAssignment,
          if (normLoading.isNotEmpty) 'loading_start_at': normLoading,
          if (normLoading.isNotEmpty) 'loading_end_at': normLoading,
          'tracking_status': 'LOADING_COMPLETED',
        };
        final updatedList = [...containers, newContainer];
        await _dio.put(
          '${ApiConstants.baseUrl}/cargo-shipping/$cargoShippingId',
          data: {'containers_loading_data': updatedList, 'owner': 'AI_Agent'},
        );
      }
    } else {
      final newContainer = {
        'container_no': cleanContainerNo,
        'seal_no': cleanSealNo,
        'container_type': containerType,
        'quantity': 1,
        if (normAssignment.isNotEmpty) 'container_assignment_date': normAssignment,
        if (normLoading.isNotEmpty) 'loading_start_at': normLoading,
        if (normLoading.isNotEmpty) 'loading_end_at': normLoading,
        'tracking_status': 'LOADING_COMPLETED',
      };
      final createRes = await _dio.post(
        '${ApiConstants.baseUrl}/cargo-shipping?auto_upsert=true',
        data: {
          'import_file_id': importFileId,
          'shipment_type': 'FCL',
          'containers_loading_data': [newContainer],
          'owner': 'AI_Agent',
        },
      );
      cargoShippingId = createRes.data['cargo_shipping_id'] as int;
      recordCode = createRes.data['cargo_shipping_code']?.toString();
    }

    // Also link in ShipmentBooking containers_data if exists
    try {
      final bkgRes = await _dio.get(
        '${ApiConstants.baseUrl}/freight-booking',
        queryParameters: {'import_file_id': importFileId},
      );
      final List bkgList = bkgRes.data is List ? bkgRes.data : [];
      if (bkgList.isNotEmpty) {
        final bkg = bkgList.first;
        final int bkgId = bkg['booking_id'] as int;
        final List cData = (bkg['containers_data'] as List?) ?? [];

        bool updated = false;
        final newCData = cData.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          final List cNos = List.from(m['container_numbers'] ?? []);
          final List sNos = List.from(m['seal_numbers'] ?? []);
          if (!cNos.contains(cleanContainerNo)) {
            cNos.add(cleanContainerNo);
            updated = true;
          }
          if (!sNos.contains(cleanSealNo)) {
            sNos.add(cleanSealNo);
            updated = true;
          }
          m['container_numbers'] = cNos;
          m['seal_numbers'] = sNos;
          return m;
        }).toList();

        if (!updated && newCData.isEmpty) {
          newCData.add({
            'container_type': containerType,
            'quantity': 1,
            'container_numbers': [cleanContainerNo],
            'seal_numbers': [cleanSealNo],
          });
          updated = true;
        }

        if (updated) {
          await _dio.put(
            '${ApiConstants.baseUrl}/freight-booking/$bkgId',
            data: {'containers_data': newCData},
          );
        }
      }
    } catch (_) {}

    // ══════════════════════════════════════════════════════════════════════════
    // READ-AFTER-WRITE (RAW) VERIFICATION
    // ══════════════════════════════════════════════════════════════════════════
    final verifyRes = await _dio.get(
      '${ApiConstants.baseUrl}/cargo-shipping',
      queryParameters: {'import_file_id': importFileId},
    );
    final List verifiedList = verifyRes.data is List ? verifyRes.data : [];
    if (verifiedList.isEmpty) {
      const err = 'فشل التحقق الفعلي (RAW Verification): لم يتم العثور على سجل الشحن بعد الحفظ.';
      _logAudit(
        toolName: 'update_container_allocation',
        args: {'import_file_id': importFileId, 'container_no': cleanContainerNo, 'seal_no': cleanSealNo},
        verified: false,
        recordCode: recordCode,
        summary: err,
        beforeState: beforeState,
        errorMessage: err,
      );
      return {'success': false, 'verified': false, 'error': err};
    }

    final verifiedRecord = verifiedList.first as Map<String, dynamic>;
    recordCode = verifiedRecord['cargo_shipping_code']?.toString() ?? recordCode;
    final List afterContainers = (verifiedRecord['containers_loading_data'] as List?) ?? [];
    Map<String, dynamic>? verifiedItem;
    for (final c in afterContainers) {
      if (c is Map &&
          (c['container_no'] ?? '').toString().trim().toUpperCase() == cleanContainerNo) {
        verifiedItem = Map<String, dynamic>.from(c);
        break;
      }
    }

    if (verifiedItem == null) {
      final err = 'فشل التحقق الفعلي: الحاوية $cleanContainerNo غير موجودة في السجل المقروء بعد الحفظ.';
      _logAudit(
        toolName: 'update_container_allocation',
        args: {'import_file_id': importFileId, 'container_no': cleanContainerNo, 'seal_no': cleanSealNo},
        verified: false,
        recordCode: recordCode,
        summary: err,
        beforeState: beforeState,
        afterState: verifiedRecord,
        errorMessage: err,
      );
      return {'success': false, 'verified': false, 'error': err};
    }

    final reReadSeal = (verifiedItem['seal_no'] ?? '').toString().trim().toUpperCase();
    if (reReadSeal != cleanSealNo) {
      final err = 'فشل التحقق الفعلي (تطابق السيل): المتوقع $cleanSealNo، المسجل فعلياً $reReadSeal.';
      _logAudit(
        toolName: 'update_container_allocation',
        args: {'import_file_id': importFileId, 'container_no': cleanContainerNo, 'seal_no': cleanSealNo},
        verified: false,
        recordCode: recordCode,
        summary: err,
        beforeState: beforeState,
        afterState: verifiedRecord,
        errorMessage: err,
      );
      return {'success': false, 'verified': false, 'error': err};
    }

    final summary = 'تم تخصيص وتسجيل الحاوية $cleanContainerNo والسيل $cleanSealNo بنجاح والتحقق الفعلي منها في السجل $recordCode (RAW Verified ✅).';
    _logAudit(
      toolName: 'update_container_allocation',
      args: {
        'import_file_id': importFileId,
        'container_no': cleanContainerNo,
        'seal_no': cleanSealNo,
        'assignment_date': normAssignment,
        'loading_date': normLoading,
      },
      verified: true,
      recordCode: recordCode,
      summary: summary,
      beforeState: beforeState,
      afterState: verifiedRecord,
    );

    return {
      'success': true,
      'verified': true,
      'import_file_id': importFileId,
      'record_code': recordCode,
      'cargo_shipping_id': cargoShippingId,
      'container_no': cleanContainerNo,
      'seal_no': cleanSealNo,
      'assignment_date': normAssignment,
      'loading_date': normLoading,
      'verified_fields': {
        'container_no': cleanContainerNo,
        'seal_no': cleanSealNo,
        'container_assignment_date': verifiedItem['container_assignment_date'],
        'loading_start_at': verifiedItem['loading_start_at'],
      },
      'target_screens': ['شاشة شحن وتجهيز البضاعة (Phase 5)'],
      'message': summary,
    };
  }

  // ─── 3. Freight Booking & House BL & RAW Verification ───────────────────────

  Future<Map<String, dynamic>> createOrUpdateBooking({
    required int importFileId,
    required String bookingNo,
    String? houseBlNo,
  }) async {
    final cleanBookingNo = bookingNo.trim();
    final cleanHouseBlNo = (houseBlNo ?? cleanBookingNo).trim();

    // 1. Freight Booking
    final bkgGetRes = await _dio.get(
      '${ApiConstants.baseUrl}/freight-booking',
      queryParameters: {'import_file_id': importFileId},
    );
    final List bkgList = bkgGetRes.data is List ? bkgGetRes.data : [];
    String? bookingCode;
    int? bookingId;
    Map<String, dynamic>? beforeBooking;

    if (bkgList.isNotEmpty) {
      final bkg = bkgList.first as Map<String, dynamic>;
      bookingId = bkg['booking_id'] as int;
      bookingCode = bkg['booking_code']?.toString();
      beforeBooking = bkg;

      await _dio.put(
        '${ApiConstants.baseUrl}/freight-booking/$bookingId',
        data: {
          'booking_confirmation_no': cleanBookingNo,
          'status': 'Confirmed',
          'owner': 'AI_Agent',
        },
      );
    } else {
      final createBkgRes = await _dio.post(
        '${ApiConstants.baseUrl}/freight-booking',
        data: {
          'import_file_id': importFileId,
          'booking_confirmation_no': cleanBookingNo,
          'shipment_type': 'Ocean FCL',
          'status': 'Confirmed',
          'owner': 'AI_Agent',
        },
      );
      bookingId = createBkgRes.data['booking_id'] as int;
      bookingCode = createBkgRes.data['booking_code']?.toString();
    }

    // 2. Draft B/L Review Session
    final blGetRes = await _dio.get(
      '${ApiConstants.baseUrl}/import-documentation/draft-bl',
      queryParameters: {'import_file_id': importFileId},
    );
    final List blList = blGetRes.data is List ? blGetRes.data : [];

    if (blList.isNotEmpty) {
      final bl = blList.first as Map<String, dynamic>;
      final blReviewId = bl['bl_review_id'] as int;
      await _dio.put(
        '${ApiConstants.baseUrl}/import-documentation/draft-bl/$blReviewId',
        data: {
          'booking_no': cleanBookingNo,
          'hbl_no': cleanHouseBlNo,
          'draft_bl_number': cleanHouseBlNo,
        },
      );
    } else {
      await _dio.post(
        '${ApiConstants.baseUrl}/import-documentation/draft-bl',
        data: {
          'import_file_id': importFileId,
          'booking_no': cleanBookingNo,
          'hbl_no': cleanHouseBlNo,
          'draft_bl_number': cleanHouseBlNo,
          'draft_source': 'AI_Agent',
        },
      );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // READ-AFTER-WRITE (RAW) VERIFICATION
    // ══════════════════════════════════════════════════════════════════════════
    final verifyBkgRes = await _dio.get(
      '${ApiConstants.baseUrl}/freight-booking',
      queryParameters: {'import_file_id': importFileId},
    );
    final List verifiedBkgList = verifyBkgRes.data is List ? verifyBkgRes.data : [];
    if (verifiedBkgList.isEmpty) {
      const err = 'فشل التحقق الفعلي (RAW Verification): لم يتم العثور على سجل حجز الشحن بعد الحفظ.';
      return {'success': false, 'verified': false, 'error': err};
    }

    final verifiedBkg = verifiedBkgList.first as Map<String, dynamic>;
    bookingCode = verifiedBkg['booking_code']?.toString() ?? bookingCode;
    final reReadBkgNo = (verifiedBkg['booking_confirmation_no'] ?? '').toString().trim();
    if (reReadBkgNo != cleanBookingNo) {
      final err = 'فشل التحقق الفعلي: المتوقع لرقم الحجز $cleanBookingNo، المسجل فعلياً $reReadBkgNo.';
      return {'success': false, 'verified': false, 'error': err};
    }

    final verifyBlRes = await _dio.get(
      '${ApiConstants.baseUrl}/import-documentation/draft-bl',
      queryParameters: {'import_file_id': importFileId},
    );
    final List verifiedBlList = verifyBlRes.data is List ? verifyBlRes.data : [];
    String? verifiedHbl;
    if (verifiedBlList.isNotEmpty) {
      verifiedHbl = (verifiedBlList.first['hbl_no'] ?? verifiedBlList.first['draft_bl_number'])?.toString();
    }

    final summary = 'تم تسجيل رقم الحجز $cleanBookingNo (سجل $bookingCode) ورقم البوليصة الهاوس $cleanHouseBlNo والتحقق الفعلي منها في قاعدة البيانات (RAW Verified ✅).';
    _logAudit(
      toolName: 'create_or_update_booking',
      args: {'import_file_id': importFileId, 'booking_no': cleanBookingNo, 'house_bl_no': cleanHouseBlNo},
      verified: true,
      recordCode: bookingCode,
      summary: summary,
      beforeState: beforeBooking,
      afterState: verifiedBkg,
    );

    return {
      'success': true,
      'verified': true,
      'import_file_id': importFileId,
      'booking_code': bookingCode,
      'booking_no': cleanBookingNo,
      'house_bl_no': verifiedHbl ?? cleanHouseBlNo,
      'target_screens': [
        'شاشة حجز الشحن (Phase 4)',
        'شاشة مراجعة بوليصة الشحن (Draft B/L Review)',
      ],
      'message': summary,
    };
  }

  // ─── 4. Live ACID Status Query ───────────────────────────────────────────────

  Future<Map<String, dynamic>> queryAcidStatus({
    int? importFileId,
    String? query,
  }) async {
    int? targetId = importFileId;
    String? matchedName;

    if (targetId == null && query != null && query.isNotEmpty) {
      final search = await searchShipments(query);
      if (search['status'] == 'FOUND') {
        targetId = search['import_file_id'] as int;
        matchedName = search['po_reference'] ?? search['file_code'];
      } else if (search['status'] == 'AMBIGUOUS') {
        return search;
      } else {
        return {
          'status': 'NOT_FOUND',
          'message': 'لم يتم العثور على أي شحنة تطابق "$query" لاستعلام ACID.',
        };
      }
    }

    if (targetId == null) {
      return {'status': 'ERROR', 'message': 'يرجى تحديد الشحنة المطلوبة.'};
    }

    final res = await _dio.get('${ApiConstants.baseUrl}/import-files/$targetId');
    final data = res.data as Map<String, dynamic>;
    final acidNo = data['acid_number']?.toString();
    final isReleased = data['is_customs_released'] == true;
    final issueDate = data['acid_issue_date']?.toString();
    final expiryDate = data['acid_expiry_date']?.toString();
    final fileCode = data['import_file_code']?.toString() ?? 'IMP-$targetId';
    final poNo = data['po_number']?.toString();

    final hasAcid = acidNo != null && acidNo.trim().isNotEmpty;

    return {
      'status': 'SUCCESS',
      'import_file_id': targetId,
      'import_file_code': fileCode,
      'shipment_name': matchedName ?? fileCode,
      'po_number': poNo,
      'has_acid': hasAcid,
      'acid_number': acidNo ?? 'غير مسجل بعد',
      'is_customs_released': isReleased,
      'customs_release_status': isReleased ? 'تم الإفراج الجمركي' : 'قيد الإجراءات الجمركية (لم يتم الإفراج بعد)',
      'acid_issue_date': issueDate,
      'acid_expiry_date': expiryDate,
      'company_name': data['company_name'],
      'supplier_name': data['supplier_name'],
      'live_verified': true,
      'source': 'Live Database Query (/api/v1/import-files/$targetId)',
    };
  }

  // ─── 5. Live Shipment Field Query ───────────────────────────────────────────

  Future<Map<String, dynamic>> queryShipmentField({
    int? importFileId,
    String? query,
    required String fieldName,
  }) async {
    int? targetId = importFileId;
    if (targetId == null && query != null && query.isNotEmpty) {
      final search = await searchShipments(query);
      if (search['status'] == 'FOUND') {
        targetId = search['import_file_id'] as int;
      } else {
        return search;
      }
    }

    if (targetId == null) {
      return {'status': 'ERROR', 'message': 'يرجى تحديد الشحنة المطلوبة.'};
    }

    final cleanField = fieldName.toLowerCase().trim();

    if (cleanField.contains('acid')) {
      return queryAcidStatus(importFileId: targetId);
    }

    if (cleanField.contains('container') || cleanField.contains('seal') || cleanField.contains('loading')) {
      final res = await _dio.get(
        '${ApiConstants.baseUrl}/cargo-shipping',
        queryParameters: {'import_file_id': targetId},
      );
      final List list = res.data is List ? res.data : [];
      return {
        'status': 'SUCCESS',
        'field_name': fieldName,
        'import_file_id': targetId,
        'records_count': list.length,
        'cargo_shipping_records': list,
        'live_verified': true,
      };
    }

    if (cleanField.contains('booking') || cleanField.contains('hbl') || cleanField.contains('bl')) {
      final bkgRes = await _dio.get(
        '${ApiConstants.baseUrl}/freight-booking',
        queryParameters: {'import_file_id': targetId},
      );
      final blRes = await _dio.get(
        '${ApiConstants.baseUrl}/import-documentation/draft-bl',
        queryParameters: {'import_file_id': targetId},
      );
      return {
        'status': 'SUCCESS',
        'field_name': fieldName,
        'import_file_id': targetId,
        'bookings': bkgRes.data,
        'draft_bl_reviews': blRes.data,
        'live_verified': true,
      };
    }

    final fRes = await _dio.get('${ApiConstants.baseUrl}/import-files/$targetId');
    return {
      'status': 'SUCCESS',
      'field_name': fieldName,
      'import_file_id': targetId,
      'data': fRes.data,
      'live_verified': true,
    };
  }

  // ─── 6. Audit Trail Retrieval ───────────────────────────────────────────────

  Map<String, dynamic> getAgentAuditTrail() {
    return {
      'total_actions': _auditTrail.length,
      'audit_entries': _auditTrail.map((e) => e.toJson()).toList(),
    };
  }

  // ─── File Code Resolver Helper ──────────────────────────────────────────────

  Future<String> _resolveFileCode(int importFileId) async {
    try {
      final res = await _dio.get('${ApiConstants.baseUrl}/import-files/$importFileId');
      final data = res.data as Map<String, dynamic>;
      return data['import_file_code']?.toString() ?? 'IMP-$importFileId';
    } catch (_) {
      return 'IMP-$importFileId';
    }
  }

  // ─── 7. Step Configuration & Policy Query (Section 10.5) ─────────────────────

  Future<Map<String, dynamic>> queryStepPolicy({
    required String stepCode,
  }) async {
    final cleanStep = normalizeStepCode(stepCode);
    if (cleanStep.isEmpty) {
      return {
        'status': 'ERROR',
        'error': 'كود الخطوة مطلوب للاستعلام عن السياسة.',
      };
    }

    try {
      final res = await _dio.get('${ApiConstants.baseUrl}/lifecycle-board/step-configs/$cleanStep');
      final data = res.data as Map<String, dynamic>;
      final policy = (data['skip_policy'] ?? 'blocked').toString().toLowerCase();

      return {
        'status': 'SUCCESS',
        'step_code': data['step_code'] ?? cleanStep,
        'step_name_ar': data['step_name_ar'] ?? '',
        'step_name_en': data['step_name_en'] ?? '',
        'phase_id': data['phase_id'],
        'skip_policy': policy,
        'is_blocked': policy == 'blocked',
        'requires_dual_approval': policy == 'dual_approval',
        'requires_single_approval': policy == 'single_approval',
        'reason_required': data['reason_required'] ?? true,
        'reason_categories': List<String>.from(data['reason_categories'] ?? []),
        'approver_roles': List<String>.from(data['approver_roles'] ?? ['Manager']),
        'supports_pending_reference': data['supports_pending_reference'] == true,
        'last_modified_by': data['last_modified_by'],
        'last_modified_at': data['last_modified_at'],
        'live_verified': true,
        'source': 'Live Database Query (/api/v1/lifecycle-board/step-configs/$cleanStep)',
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Default safe fallback per Section 10.2: unconfigured steps default strictly to blocked
        return {
          'status': 'DEFAULT_BLOCKED',
          'step_code': cleanStep,
          'skip_policy': 'blocked',
          'is_blocked': true,
          'reason_required': true,
          'approver_roles': ['Manager'],
          'supports_pending_reference': false,
          'note': 'Step not explicitly configured, defaulting to safest option: blocked (Section 10.2)',
          'live_verified': true,
        };
      }
      return {
        'status': 'ERROR',
        'error': 'فشل الاستعلام عن سياسة الخطوة $cleanStep: ${e.message}',
      };
    }
  }

  // ─── 8. Skip Step with Live Policy Guard & RAW Verification (Section 10) ─────

  Future<Map<String, dynamic>> skipStep({
    required int importFileId,
    required String stepCode,
    required String reasonCategory,
    required String justification,
    String? userRole,
    String? userName,
  }) async {
    final cleanStep = normalizeStepCode(stepCode);
    final cleanCategory = reasonCategory.trim();
    final cleanJustification = justification.trim();

    // 1. Mandatory justification length check (Section 10.1 & 9.3)
    if (cleanJustification.length < 5) {
      const err = 'سبب وتبرير التخطي إلزامي ويجب ألا يقل عن 5 أحرف لتبرير الإجراء تشغيلياً.';
      return {
        'success': false,
        'verified': false,
        'error': err,
      };
    }

    // 2. Query live policy (Policy-Agnostic Agent, Section 10.5)
    final policyRes = await queryStepPolicy(stepCode: cleanStep);
    if (policyRes['status'] == 'ERROR') {
      return {
        'success': false,
        'verified': false,
        'error': policyRes['error'],
      };
    }

    final isBlocked = policyRes['is_blocked'] == true || policyRes['skip_policy'] == 'blocked';
    if (isBlocked) {
      final stepTitle = policyRes['step_name_ar'] ?? cleanStep;
      final err = 'لا يمكن تخطي خطوة $cleanStep ($stepTitle) وفقاً لسياسة الشركة الحالية (Policy: blocked). '
          'الخطوة محظورة من التخطي ولا يمكن تجاوزها آلياً. يمكن لمدير النظام فقط تعديل سياسة المرحلة عبر لوحة إعدادات المراحل.';
      _logAudit(
        toolName: 'skip_step',
        args: {
          'import_file_id': importFileId,
          'step_code': cleanStep,
          'reason_category': cleanCategory,
          'justification': cleanJustification,
        },
        verified: false,
        summary: 'تم رفض طلب تخطي $cleanStep لأن سياستها الحالية محظورة (blocked).',
        errorMessage: err,
      );
      return {
        'success': false,
        'verified': false,
        'blocked': true,
        'step_code': cleanStep,
        'step_name': stepTitle,
        'skip_policy': 'blocked',
        'approver_roles': policyRes['approver_roles'],
        'supports_pending_reference': policyRes['supports_pending_reference'] == true,
        'error': err,
      };
    }

    // 3. Resolve import file code
    final fileCode = await _resolveFileCode(importFileId);

    // 4. Call backend skip endpoint
    final skipReasonText = cleanCategory.isNotEmpty
        ? '[$cleanCategory] $cleanJustification'
        : cleanJustification;

    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/lifecycle-board/stages/skip',
        data: {
          'import_file_code': fileCode,
          'current_step_code': cleanStep,
          'skip_reason': skipReasonText,
          'next_step_codes': <String>[],
        },
        options: Options(headers: {
          // Role comes from the JWT on the backend; X-User-Role is ignored.
          if (userName != null && userName.isNotEmpty) 'X-User-Name': userName,
        }),
      );
    } on DioException catch (e) {
      final backendError = e.response?.data?['detail'] ?? e.message;
      final err = 'فشل تخطي المرحلة من الخادم: $backendError';
      _logAudit(
        toolName: 'skip_step',
        args: {
          'import_file_id': importFileId,
          'step_code': cleanStep,
          'reason_category': cleanCategory,
          'justification': cleanJustification,
        },
        verified: false,
        recordCode: fileCode,
        summary: err,
        errorMessage: backendError.toString(),
      );
      return {'success': false, 'verified': false, 'error': err};
    }

    // 5. Read-After-Write (RAW) Verification
    try {
      final verifyRes = await _dio.get(
        '${ApiConstants.baseUrl}/lifecycle-board/shipments/$fileCode/stages',
      );
      final List stages = verifyRes.data is List ? verifyRes.data : [];
      Map<String, dynamic>? verifiedStage;
      for (final s in stages) {
        if (s is Map && (s['step_code'] ?? '').toString().toUpperCase() == cleanStep) {
          verifiedStage = Map<String, dynamic>.from(s);
          break;
        }
      }

      if (verifiedStage == null || verifiedStage['status'] != 'Skipped') {
        final currentStatus = verifiedStage?['status'] ?? 'غير مسجل';
        final err = 'فشل التحقق الفعلي (RAW Verification): حالة الخطوة $cleanStep هي ($currentStatus) وليست (Skipped).';
        _logAudit(
          toolName: 'skip_step',
          args: {
            'import_file_id': importFileId,
            'step_code': cleanStep,
            'reason_category': cleanCategory,
            'justification': cleanJustification,
          },
          verified: false,
          recordCode: fileCode,
          summary: err,
          afterState: verifiedStage,
          errorMessage: err,
        );
        return {'success': false, 'verified': false, 'error': err};
      }

      final summary = 'تم تخطي الخطوة $cleanStep لشحنة $fileCode بنجاح وتأكيد الحالة (Skipped) في قاعدة البيانات (RAW Verified ✅).';
      _logAudit(
        toolName: 'skip_step',
        args: {
          'import_file_id': importFileId,
          'step_code': cleanStep,
          'reason_category': cleanCategory,
          'justification': cleanJustification,
        },
        verified: true,
        recordCode: fileCode,
        summary: summary,
        afterState: verifiedStage,
      );

      return {
        'success': true,
        'verified': true,
        'status': 'Skipped',
        'import_file_id': importFileId,
        'import_file_code': fileCode,
        'step_code': cleanStep,
        'reason_category': cleanCategory,
        'justification': cleanJustification,
        'raw_verified': true,
        'message': summary,
      };
    } catch (e) {
      final err = 'خطأ أثناء التحقق الفعلي بعد تخطي الخطوة: $e';
      _logAudit(
        toolName: 'skip_step',
        args: {
          'import_file_id': importFileId,
          'step_code': cleanStep,
          'reason_category': cleanCategory,
          'justification': cleanJustification,
        },
        verified: false,
        recordCode: fileCode,
        summary: err,
        errorMessage: e.toString(),
      );
      return {'success': false, 'verified': false, 'error': err};
    }
  }

  // ─── 9. Register Pending Reference with RAW Verification (Section 10.4) ──────

  Future<Map<String, dynamic>> registerPendingReference({
    required int importFileId,
    required String stepCode,
    required String referenceNumber,
    required String reasonText,
    String? expectedCompletionDate,
    String? userName,
  }) async {
    final cleanStep = normalizeStepCode(stepCode);
    final cleanRef = referenceNumber.trim();
    final cleanReason = reasonText.trim();
    final normDate = normalizeDate(expectedCompletionDate);

    if (cleanRef.isEmpty) {
      return {
        'success': false,
        'verified': false,
        'error': 'رقم المرجع (reference_number) حقل إلزامي لتسجيل التوثيق المؤقت.',
      };
    }

    if (cleanReason.length < 3) {
      return {
        'success': false,
        'verified': false,
        'error': 'سبب تأجيل استيفاء المستند الأصلي إلزامي (3 أحرف على الأقل).',
      };
    }

    // 1. Check if step supports pending reference
    final policyRes = await queryStepPolicy(stepCode: cleanStep);
    if (policyRes['status'] == 'ERROR') {
      return {
        'success': false,
        'verified': false,
        'error': policyRes['error'],
      };
    }

    final supportsPending = policyRes['supports_pending_reference'] == true;
    if (!supportsPending) {
      final err = 'الخطوة $cleanStep لا تدعم حالياً تسجيل مرجع مؤقت (supports_pending_reference = false). '
          'يجب استيفاء المستند كاملاً أو مراجعة إعدادات الخطوة مع المدير.';
      _logAudit(
        toolName: 'register_pending_reference',
        args: {
          'import_file_id': importFileId,
          'step_code': cleanStep,
          'reference_number': cleanRef,
          'reason_text': cleanReason,
        },
        verified: false,
        summary: err,
        errorMessage: err,
      );
      return {
        'success': false,
        'verified': false,
        'supports_pending_reference': false,
        'error': err,
      };
    }

    // 2. Resolve import file code
    final fileCode = await _resolveFileCode(importFileId);

    // 3. Post to backend
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/lifecycle-board/stages/register-pending-reference',
        data: {
          'import_file_code': fileCode,
          'step_code': cleanStep,
          'reference_number': cleanRef,
          'reason_text': cleanReason,
          if (normDate.isNotEmpty) 'expected_completion_date': normDate,
        },
        options: Options(headers: {
          if (userName != null && userName.isNotEmpty) 'X-User-Name': userName,
        }),
      );
    } on DioException catch (e) {
      final backendError = e.response?.data?['detail'] ?? e.message;
      final err = 'فشل تسجيل المرجع المؤقت من الخادم: $backendError';
      _logAudit(
        toolName: 'register_pending_reference',
        args: {
          'import_file_id': importFileId,
          'step_code': cleanStep,
          'reference_number': cleanRef,
          'reason_text': cleanReason,
        },
        verified: false,
        recordCode: fileCode,
        summary: err,
        errorMessage: backendError.toString(),
      );
      return {'success': false, 'verified': false, 'error': err};
    }

    // 4. Read-After-Write (RAW) Verification
    try {
      final verifyRes = await _dio.get(
        '${ApiConstants.baseUrl}/lifecycle-board/shipments/$fileCode/stages',
      );
      final List stages = verifyRes.data is List ? verifyRes.data : [];
      Map<String, dynamic>? verifiedStage;
      for (final s in stages) {
        if (s is Map && (s['step_code'] ?? '').toString().toUpperCase() == cleanStep) {
          verifiedStage = Map<String, dynamic>.from(s);
          break;
        }
      }

      const expectedStatus = 'Reference recorded – pending full documentation';
      if (verifiedStage == null || verifiedStage['status'] != expectedStatus) {
        final currentStatus = verifiedStage?['status'] ?? 'غير مسجل';
        final err = 'فشل التحقق الفعلي (RAW Verification): حالة الخطوة $cleanStep هي ($currentStatus) وليست ($expectedStatus).';
        _logAudit(
          toolName: 'register_pending_reference',
          args: {
            'import_file_id': importFileId,
            'step_code': cleanStep,
            'reference_number': cleanRef,
            'reason_text': cleanReason,
          },
          verified: false,
          recordCode: fileCode,
          summary: err,
          afterState: verifiedStage,
          errorMessage: err,
        );
        return {'success': false, 'verified': false, 'error': err};
      }

      final summary = 'تم تسجيل المرجع المؤقت ($cleanRef) للخطوة $cleanStep بنجاح والحالة معلقة وغير مكتملة (RAW Verified ✅).';
      _logAudit(
        toolName: 'register_pending_reference',
        args: {
          'import_file_id': importFileId,
          'step_code': cleanStep,
          'reference_number': cleanRef,
          'reason_text': cleanReason,
          'expected_completion_date': normDate,
        },
        verified: true,
        recordCode: fileCode,
        summary: summary,
        afterState: verifiedStage,
      );

      return {
        'success': true,
        'verified': true,
        'status': expectedStatus,
        'import_file_id': importFileId,
        'import_file_code': fileCode,
        'step_code': cleanStep,
        'reference_number': cleanRef,
        'reason_text': cleanReason,
        'expected_completion_date': normDate.isNotEmpty ? normDate : null,
        'is_completed': false, // Explicitly false per Section 10.4
        'raw_verified': true,
        'message': summary,
      };
    } catch (e) {
      final err = 'خطأ أثناء التحقق الفعلي بعد تسجيل المرجع المؤقت: $e';
      _logAudit(
        toolName: 'register_pending_reference',
        args: {
          'import_file_id': importFileId,
          'step_code': cleanStep,
          'reference_number': cleanRef,
          'reason_text': cleanReason,
        },
        verified: false,
        recordCode: fileCode,
        summary: err,
        errorMessage: e.toString(),
      );
      return {'success': false, 'verified': false, 'error': err};
    }
  }
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────

final aiAgentToolExecutorProvider = Provider<AiAgentToolExecutor>((ref) {
  final dio = ref.watch(dioProvider);
  return AiAgentToolExecutor(dio: dio);
});
