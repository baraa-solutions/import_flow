import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../models/container_loader_model.dart';

class ContainerLoaderService {
  final Dio _dio;

  ContainerLoaderService(this._dio);

  Future<List<ContainerSpecModel>> getSpecs() async {
    final response = await _dio.get('${ApiConstants.containerLoader}/specs');
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((item) => ContainerSpecModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ContainerLoaderEvaluationResultModel> evaluateLoading(Map<String, dynamic> request) async {
    final response = await _dio.post(
      '${ApiConstants.containerLoader}/evaluate',
      data: request,
    );
    return ContainerLoaderEvaluationResultModel.fromJson(response.data as Map<String, dynamic>);
  }
}
