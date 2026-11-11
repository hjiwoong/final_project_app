import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/token_storage.dart';
import '../config/env.dart';

String _newRequestId() {
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(
    36,
  );
  final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
  return '$timestamp-$random';
}

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
              options.headers['X-Request-ID'] =
                  options.headers['X-Request-ID'] ?? _newRequestId();
              final token = await TokenStorage.read();
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
            onResponse: (response, handler) {
              if (kDebugMode) {
                final requestId =
                    response.requestOptions.headers['X-Request-ID'] ??
                    'unknown';
                debugPrint(
                  'API 응답: ${response.requestOptions.method} '
                  '${response.requestOptions.path} HTTP ${response.statusCode} '
                  'request_id=$requestId',
                );
              }
              handler.next(response);
            },
            onError: (error, handler) {
              if (kDebugMode) {
                final requestId =
                    error.requestOptions.headers['X-Request-ID'] ?? 'unknown';
                debugPrint(
                  'API 오류: ${error.requestOptions.method} '
                  '${error.requestOptions.path} '
                  'HTTP ${error.response?.statusCode ?? 'none'} '
                  'type=${error.type.name} request_id=$requestId',
                );
              }
              handler.next(error);
            },
          ),
        );
}
