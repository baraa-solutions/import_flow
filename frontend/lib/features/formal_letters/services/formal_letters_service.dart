import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../models/formal_letter_model.dart';

class FormalLettersService {
  final Dio _dio;

  FormalLettersService(this._dio);

  Future<List<FormalLetterTemplateInfo>> getTemplates() async {
    final response = await _dio.get('${ApiConstants.formalLetters}/templates');
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((item) => FormalLetterTemplateInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<FormalLetterResponseModel> generateLetter(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.formalLetters}/generate',
      data: payload,
    );
    return FormalLetterResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<FormalLetterRecordModel>> getHistory(int importFileId) async {
    final response = await _dio.get('${ApiConstants.formalLetters}/history/$importFileId');
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((item) => FormalLetterRecordModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
