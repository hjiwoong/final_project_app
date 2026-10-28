import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import '../config/env.dart';

/// 모든 API 호출의 공통 클라이언트 (JWT 자동 첨부)
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final Dio dio =
      Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 15),
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await TokenStorage.read();
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
          ),
        );
}
