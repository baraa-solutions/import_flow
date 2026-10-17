/// Pure payload builder for saving and updating customs consultation sessions.
/// Enforces the rule that broker is NEVER invented or defaulted (no `?? 1` or `'Customs Review'`).
class CustomsConsultationPayloadBuilder {
  /// Builds the payload for POST/PUT /api/v1/customs-consultations.
  /// When [brokerId] is null (e.g. in tax review mode), the payload does not contain
  /// 'broker_id' or 'broker_name' keys and never defaults to 1 or 'Customs Review'.
  static Map<String, dynamic> buildSavePayload({
    required String title,
    int? brokerId,
    String? brokerName,
    String? brokerContactPerson,
    int? brokerPriceListId,
    int? importFileId,
    int? poId,
    int? projectId,
    required double estimatedDutiesEgp,
    required double totalBrokerFeesEgp,
    String notes = '',
    required List<Map<String, dynamic>> checklistItems,
    List<Map<String, dynamic>> brokerQuoteItems = const [],
    bool isTaxReviewMode = false,
  }) {
    return {
      'title': title,
      if (brokerId != null) 'broker_id': brokerId,
      if (brokerName != null && brokerName.isNotEmpty) 'broker_name': brokerName,
      if (brokerContactPerson != null && brokerContactPerson.isNotEmpty)
        'broker_contact_person': brokerContactPerson,
      if (importFileId != null) 'import_file_id': importFileId,
      if (poId != null) 'po_id': poId,
      if (projectId != null) 'project_id': projectId,
      'estimated_duties_egp': estimatedDutiesEgp,
      'total_broker_fees_egp': totalBrokerFeesEgp,
      if (brokerPriceListId != null && !isTaxReviewMode)
        'broker_price_list_id': brokerPriceListId,
      'notes': notes,
      'checklist_items': checklistItems,
      'broker_quote_items': isTaxReviewMode ? [] : brokerQuoteItems,
    };
  }
}
